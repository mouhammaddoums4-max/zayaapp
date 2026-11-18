// Tests de la migration 0031 (portefeuille et récompenses) et de la vérification SSV d'AdMob (fonction admob-ssv).
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U).

import { webcrypto } from 'node:crypto';
import { derToRaw, readParams, verifySsv } from '../functions/admob-ssv/verify.ts';

/** Signature brute r||s (WebCrypto) → DER, comme celle envoyée par Google. */
function rawToDer(raw) {
  const int = (bytes) => {
    let v = Array.from(bytes);
    while (v.length > 1 && v[0] === 0) v.shift();
    if (v[0] & 0x80) v = [0, ...v];
    return [0x02, v.length, ...v];
  };
  const body = [...int(raw.slice(0, 32)), ...int(raw.slice(32))];
  return Uint8Array.from([0x30, body.length, ...body]);
}
const b64url = (bytes) => Buffer.from(bytes).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function rewardsTests({ db, test, assert, as, rpc, fails, U }) {
  console.log('\nPortefeuille et récompenses publicitaires (0031, SSV)');

  const credit = async (tx, user, reward = 'extra_swipes') =>
    (await db.query(`select credit_rewarded_ad($1, $2, $3, 'admob', 'unite-test') as r`, [tx, user, reward])).rows[0].r;

  await test('SSV : seule une signature de Google sur le message exact est acceptée', async () => {
    const pair = await webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
    const spki = Buffer.from(await webcrypto.subtle.exportKey('spki', pair.publicKey)).toString('base64');
    const keys = [{ keyId: 3335741209, base64: spki }];
    const message = `ad_network=5450213213286189855&ad_unit=1234567890&custom_data=extra_swipes&reward_amount=10` +
      `&reward_item=swipes&timestamp=1763400000000&transaction_id=tx-ssv-1&user_id=${U.aicha}`;
    const raw = new Uint8Array(await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, pair.privateKey,
      new TextEncoder().encode(message)));
    const der = rawToDer(raw);
    assert(Buffer.from(derToRaw(der)).equals(Buffer.from(raw)), 'conversion DER → brut');
    const query = `?${message}&signature=${b64url(der)}&key_id=3335741209`;
    assert(await verifySsv(query, keys, webcrypto.subtle) === true, 'signature valide refusée');
    assert(await verifySsv(query.replace('reward_amount=10', 'reward_amount=99'), keys, webcrypto.subtle) === false,
      'message modifié accepté');
    assert(await verifySsv(query.replace('key_id=3335741209', 'key_id=1'), keys, webcrypto.subtle) === false,
      'clé inconnue acceptée');
    assert(await verifySsv(`?${message}`, keys, webcrypto.subtle) === false, 'requête sans signature acceptée');
    const p = readParams(query);
    assert(p.transactionId === 'tx-ssv-1' && p.userId === U.aicha && p.customData === 'extra_swipes', JSON.stringify(p));
  });

  await test('crédit vérifié : swipes accordés une seule fois par transaction, historisés dans le portefeuille', async () => {
    const r = await credit('tx-1', U.fatou);
    assert(r.status === 'credited' && r.amount === 10, JSON.stringify(r));
    const again = await credit('tx-1', U.fatou);
    assert(again.status === 'duplicate', 'une transaction rejouée ne doit rien créditer');
    const swipes = await db.query(`select coalesce(sum(amount), 0)::int as n from swipe_credits where user_id = $1`, [U.fatou]);
    assert(swipes.rows[0].n === 10, `swipes crédités : ${swipes.rows[0].n}`);
    const wallet = await rpc(U.fatou, 'my_wallet');
    assert(wallet.ad_credits.swipes === 10 && wallet.coins === 0, JSON.stringify(wallet));
    assert(wallet.history.length === 1 && wallet.history[0].category === 'ad_credit', JSON.stringify(wallet.history));
  });

  await test('limite quotidienne côté serveur ; récompense désactivée : rien n’est crédité mais tout est tracé', async () => {
    await credit('tx-2', U.fatou);
    await credit('tx-3', U.fatou);
    const fourth = await credit('tx-4', U.fatou);
    assert(fourth.status === 'limit_reached', JSON.stringify(fourth));
    const boost = await credit('tx-5', U.fatou, 'boost_credit');
    assert(boost.status === 'disabled', JSON.stringify(boost));
    const log = await db.query(`select status, count(*)::int as n from ad_reward_transactions where user_id = $1
                                group by status order by status`, [U.fatou]);
    assert(JSON.stringify(log.rows) === JSON.stringify([
      { status: 'credited', n: 3 }, { status: 'disabled', n: 1 }, { status: 'limit_reached', n: 1 },
    ]), JSON.stringify(log.rows));
    await fails(credit('tx-6', U.fatou, 'pieces_gratuites'), /UNKNOWN_REWARD/);
  });

  await test('un membre ne crédite rien lui-même ; portefeuille et journal non modifiables', async () => {
    await fails(as(U.fatou, `select credit_rewarded_ad('tx-x', $1, 'extra_swipes', 'a', 'b')`, [U.fatou]),
      /permission denied/i);
    await fails(as(U.fatou, `insert into wallet_transactions (user_id, category, asset, amount, reason)
                             values ($1, 'coins', 'coins', 1000, 'triche')`, [U.fatou]), /permission denied/i);
    await fails(db.query(`update wallet_transactions set amount = 999 where user_id = $1`, [U.fatou]), /APPEND_ONLY/);
    await fails(db.query(`delete from ad_reward_transactions where user_id = $1`, [U.fatou]), /APPEND_ONLY/);
    const other = await as(U.aicha, `select count(*)::int as n from wallet_transactions where user_id = $1`, [U.fatou]);
    assert(other.rows[0].n === 0, 'un autre membre ne voit pas ce portefeuille');
  });

  await test('offre annoncée avant le visionnage : indisponible tant qu’AdMob est désactivé, puis avec le reste du jour',
    async () => {
      const off = await rpc(U.moussa, 'my_reward_offer', ['extra_swipes']);
      assert(off.available === false && off.amount === 10, JSON.stringify(off));
      await db.query(`update app_config set value = 'true' where key = 'ads_admob_enabled'`);
      const on = await rpc(U.moussa, 'my_reward_offer', ['extra_swipes']);
      assert(on.available === true && on.remaining_today === 3, JSON.stringify(on));
      const fatou = await rpc(U.fatou, 'my_reward_offer', ['extra_swipes']);
      assert(fatou.available === false && fatou.remaining_today === 0, JSON.stringify(fatou));
      await db.query(`update app_config set value = 'false' where key = 'ads_admob_enabled'`);
    });
}
