// Tests ZAYA 2.0 — Lot 0 (migration 0067) : interrupteurs, registre de crédits, anti-arnaque, confiance, doublons de photos.

export async function lot0Tests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nZAYA 2.0 — Lot 0 : socle de sécurité (0067)');
  const A = '00000000-0000-0000-0000-0000000067a1';
  const B = '00000000-0000-0000-0000-0000000067b1';
  const C = '00000000-0000-0000-0000-0000000067c1';
  await seedMember(A, 'Hawa', 'femme', '1995-02-02', null);
  await seedMember(B, 'Ibrahima', 'homme', '1990-03-03', null);
  await seedMember(C, 'Bakary', 'homme', '1991-04-04', null);
  const M = (await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid,$2::uuid), greatest($1::uuid,$2::uuid)) returning id`,
    [A, B])).rows[0].id;

  await test('interrupteur : une fonctionnalité coupée est refusée côté serveur, rétablie ensuite', async () => {
    assert((await rpc(A, 'feature_enabled', ['pulse'])) === true);
    await db.query(`update app_config set value = 'false' where key = 'feature_pulse_enabled'`);
    assert((await rpc(A, 'feature_enabled', ['pulse'])) === false);
    await db.query(`update app_config set value = 'true' where key = 'feature_pulse_enabled'`);
    assert((await rpc(A, 'feature_enabled', ['inconnue'])) === false, 'une fonctionnalité inconnue reste coupée');
  });

  await test('registre de crédits : même clé = un seul crédit ; le client ne peut ni créditer ni modifier', async () => {
    const first = (await db.query(`select grant_reward($1, 'challenge', 'swipes', 3, 'k-67-1', 'Essai') as r`, [A])).rows[0].r;
    const second = (await db.query(`select grant_reward($1, 'challenge', 'swipes', 3, 'k-67-1', 'Essai') as r`, [A])).rows[0].r;
    assert(first === true && second === false, `${first}/${second}`);
    const tries = await Promise.all(Array.from({ length: 20 }, () =>
      db.query(`select grant_reward($1, 'challenge', 'boost', 1, 'k-67-par', 'Essai') as r`, [A])));
    assert(tries.filter((t) => t.rows[0].r).length === 1, '20 demandes : une seule attribution');
    assert((await db.query(`select count(*)::int n from swipe_credits where ref = 'k-67-1'`)).rows[0].n === 1,
      'les swipes sont réellement crédités une seule fois');
    const wallet = await rpc(A, 'my_wallet');
    assert(wallet.bonus.swipes === 3 && wallet.bonus.boosts === 1, `portefeuille du membre : ${JSON.stringify(wallet.bonus)}`);
    await fails(rpc(A, 'grant_reward', [A, 'challenge', 'swipes', 99, 'k-67-self', 'Triche']), /permission denied/);
    await fails(as(A, `insert into reward_ledger (user_id, source, asset, amount, idempotency_key, reason)
                       values ($1, 'admin', 'swipes', 9, 'k-67-ins', 'Triche')`, [A]), /permission denied/);
    await fails(db.query(`update reward_ledger set amount = 99`), /append|modif|interdit|forbid/i);
  });

  await test('annulation par l’équipe : ligne négative, une seule fois, refusée à un membre', async () => {
    const id = (await db.query(`select id from reward_ledger where idempotency_key = 'k-67-1'`)).rows[0].id;
    await fails(rpc(A, 'admin_reverse_reward', [id, 'Je me rembourse']), /FORBIDDEN/);
    await rpc(U.admin, 'admin_reverse_reward', [id, 'Fraude confirmée']);
    const neg = (await db.query(`select amount, reverses from reward_ledger where idempotency_key = $1`, ['reverse:' + id])).rows;
    assert(neg.length === 1 && neg[0].amount === -3 && neg[0].reverses === id, JSON.stringify(neg));
    await fails(rpc(U.admin, 'admin_reverse_reward', [id, 'Encore']), /ALREADY_REVERSED/);
    assert((await rpc(A, 'my_wallet')).bonus.swipes === 0, 'l’annulation apparaît aussi dans le portefeuille');
  });

  await test('anti-arnaque : demande d’argent et Mobile Money avertissent, message normal non', async () => {
    const cas = [
      ['Peux-tu m’envoyer 50000 GNF par Orange Money ?', 'mobile_money'],
      ['Donne-moi ton numéro de compte bancaire', 'bank_details'],
      ['J’ai besoin d’argent urgent svp', 'money_request'],
      ['Envoie moi de l’argent stp', 'money_request'],
      ['Investis en bitcoin avec moi', 'investment'],
    ];
    for (const [texte, attendu] of cas) {
      const cat = (await db.query(`select scam_category($1) as c`, [texte])).rows[0].c;
      assert(cat === attendu, `« ${texte} » → ${cat}, attendu ${attendu}`);
    }
    for (const ok of ['Je travaille dans une banque', 'J’ai besoin de temps pour réfléchir', 'Je t’envoie une photo de ma famille',
                      'Bonne journée, et ton travail ?', 'Mon frère a un RIB différent… non, rien']) {
      const cat = (await db.query(`select scam_category($1) as c`, [ok])).rows[0].c;
      assert(cat === null || ok.includes('RIB'), `faux positif : « ${ok} » → ${cat}`);
    }
  });

  await test('anti-arnaque : le message passe avec avertissement stocké pour les deux, événement pour la modération', async () => {
    const r = await rpc(B, 'send_message', [M, 'Envoie-moi de l’argent par Orange Money']);
    assert(r.status === 'sent' && r.warning === 'mobile_money', JSON.stringify(r));
    const vu = (await as(A, `select scam_category from messages where id = $1`, [r.id])).rows[0];
    assert(vu.scam_category === 'mobile_money', 'l’autre personne voit aussi l’avertissement');
    assert((await db.query(`select count(*)::int n from scam_events where user_id = $1`, [B])).rows[0].n === 1);
    assert((await as(A, `select 1 from scam_events`).catch(() => ({ rows: [] }))).rows.length === 0, 'illisible par un membre');
    const ok = await rpc(B, 'send_message', [M, 'Bonne soirée']);
    assert(ok.warning === null, JSON.stringify(ok));
    const edited = await rpc(B, 'edit_message', [ok.id, 'Donne-moi ton RIB']);
    assert(edited.warning === 'bank_details', 'une modification est aussi analysée');
  });

  await test('messages sans réponse : limite atteinte puis levée quand l’autre personne répond', async () => {
    const M2 = (await db.query(
      `insert into matches (user_a, user_b) values (least($1::uuid,$2::uuid), greatest($1::uuid,$2::uuid)) returning id`,
      [A, C])).rows[0].id;
    await db.query(`update app_config set value = '3' where key = 'max_unanswered_messages'`);
    try {
      for (let i = 0; i < 3; i++) assert((await rpc(C, 'send_message', [M2, 'Bonjour ' + i])).status === 'sent');
      await fails(rpc(C, 'send_message', [M2, 'Bonjour encore']), /UNANSWERED_LIMIT/);
      assert((await rpc(A, 'send_message', [M2, 'Bonjour !'])).status === 'sent');
      assert((await rpc(C, 'send_message', [M2, 'Content de te lire'])).status === 'sent', 'la réponse lève la limite');
    } finally {
      await db.query(`update app_config set value = '8' where key = 'max_unanswered_messages'`);
    }
  });

  await test('score de confiance : baisse avec les signalements, jamais lisible par un membre', async () => {
    const avant = (await db.query(`select trust_score($1) as s`, [C])).rows[0].s;
    await db.query(`insert into reports (reporter, reported_user, context, reason) values ($1, $2, 'profile', 'faux profil'), ($3, $2, 'profile', 'arnaque')`, [A, C, B]);
    const apres = (await db.query(`select trust_score($1) as s`, [C])).rows[0].s;
    assert(apres < avant && apres >= 0 && apres <= 100, `${avant} → ${apres}`);
    await fails(rpc(A, 'trust_score', [C]), /permission denied/);
  });

  await test('doublons de photos : la même image sur deux comptes est signalée à la modération', async () => {
    const pa = (await db.query(`select id from profile_photos where user_id = $1 order by position limit 1`, [A])).rows[0].id;
    const pb = (await db.query(`select id from profile_photos where user_id = $1 order by position limit 1`, [B])).rows[0].id;
    const pc = (await db.query(`select id from profile_photos where user_id = $1 order by position limit 1`, [C])).rows[0].id;
    assert((await db.query(`select register_photo_hash($1, 123456789012345::bigint) as n`, [pa])).rows[0].n === 0);
    // Une seule différence de bits : même photo recompressée.
    assert((await db.query(`select register_photo_hash($1, 123456789012344::bigint) as n`, [pb])).rows[0].n === 1);
    // Très différente : aucun signalement.
    assert((await db.query(`select register_photo_hash($1, -4611686018427387904::bigint) as n`, [pc])).rows[0].n === 0);
    assert((await as(U.modo, `select count(*)::int n from photo_duplicate_flags`)).rows[0].n === 1);
    assert((await as(A, `select 1 from photo_duplicate_flags`).catch(() => ({ rows: [] }))).rows.length === 0);
    await fails(rpc(A, 'register_photo_hash', [pa, 1]), /permission denied/);
  });
}
