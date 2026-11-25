// Tests de la migration 0035 : boutique de cadeaux et de compliments (pièces achetées uniquement).
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U, U.admin super-admin).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function shopTests({ db, test, assert, as, rpc, fails, U }) {
  console.log('\nBoutique : cadeaux et compliments (0035)');

  const item = async (code) => (await db.query(`select id from shop_items where code = $1`, [code])).rows[0].id;
  const buyCoins = (user, n, ref) => db.query(
    `insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
     values ($1, 'coins', 'coins', $2, 'Achat de pièces (test)', $3)`, [user, n, ref]);

  await test('catalogue visible, sans aucun prix inventé ; envoi impossible tant que l’équipe n’a pas fixé le prix', async () => {
    const c = await rpc(U.aicha, 'shop_catalog');
    assert(c.enabled === true && c.coins === 0, JSON.stringify({ enabled: c.enabled, coins: c.coins }));
    assert(c.items.length === 8 && c.items.every((i) => i.price_coins === null), 'prix vides au départ');
    assert(c.items.some((i) => i.kind === 'compliment' && i.message_fr), 'compliments écrits par l’équipe');
    await fails(rpc(U.aicha, 'send_shop_item', [await item('rose'), U.moussa]), /PRICE_NOT_SET/);
    await fails(as(null, `select shop_catalog()`), /permission denied/i);
  });

  await test('prix fixé par l’équipe seulement, tracé ; un membre ne modifie rien', async () => {
    await fails(rpc(U.aicha, 'admin_save_shop_item', [await item('rose'), JSON.stringify({ price_coins: 1 })]), /FORBIDDEN/);
    await rpc(U.admin, 'admin_save_shop_item', [await item('rose'), JSON.stringify({ price_coins: 10 })]);
    await rpc(U.admin, 'admin_save_shop_item', [await item('sourire'), JSON.stringify({ price_coins: 5 })]);
    const touched = await as(U.aicha, `update shop_items set price_coins = 1 returning id`).catch(() => ({ rows: [] }));
    assert(touched.rows.length === 0, 'aucun article modifié par un membre');
    const audit = await db.query(`select count(*)::int as n from audit_log where action = 'shop_item.saved'`);
    assert(audit.rows[0].n === 2, `modifications tracées : ${audit.rows[0].n}`);
  });

  await test('pièces achetées seulement : crédits publicitaires et cadeaux ZAYA ne paient rien', async () => {
    await db.query(`insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
                    values ($1, 'ad_credit', 'swipes', 50, 'Publicité récompensée', 'test-shop-ad')`, [U.aicha]);
    await fails(rpc(U.aicha, 'send_shop_item', [await item('rose'), U.moussa]), /INSUFFICIENT_COINS/);
  });

  await test('envoi : débit et cadeau indissociables, solde jamais négatif, historique des deux côtés', async () => {
    await buyCoins(U.aicha, 12, 'test-achat-1');
    const r = await rpc(U.aicha, 'send_shop_item', [await item('rose'), U.moussa]);
    assert(r.status === 'sent' && r.coins === 2, JSON.stringify(r));
    await fails(rpc(U.aicha, 'send_shop_item', [await item('rose'), U.moussa]), /INSUFFICIENT_COINS/);
    const bal = await db.query(`select sum(amount)::int as n from wallet_transactions
                                where user_id = $1 and category = 'coins'`, [U.aicha]);
    assert(bal.rows[0].n === 2, `solde : ${bal.rows[0].n}`);
    const received = await rpc(U.moussa, 'my_shop_history', ['received', 10]);
    assert(received.length === 1 && received[0].code === 'rose' && received[0].other_id === U.aicha,
      JSON.stringify(received));
    const sent = await rpc(U.aicha, 'my_shop_history', ['sent', 10]);
    assert(sent.length === 1 && sent[0].other_id === U.moussa, JSON.stringify(sent));
    const other = await rpc(U.fatou, 'my_shop_history', ['received', 10]);
    assert(other.length === 0, 'un tiers ne voit rien');
    await fails(db.query(`delete from shop_sends`), /APPEND_ONLY/);
  });

  await test('refus : soi-même, membre bloqué, article désactivé, limite quotidienne', async () => {
    await buyCoins(U.aicha, 200, 'test-achat-2');
    await fails(rpc(U.aicha, 'send_shop_item', [await item('sourire'), U.aicha]), /INVALID_TARGET/);
    await rpc(U.moussa, 'block_user', [U.aicha]);
    await fails(rpc(U.aicha, 'send_shop_item', [await item('sourire'), U.moussa]), /TARGET_UNAVAILABLE/);
    const hidden = await rpc(U.moussa, 'my_shop_history', ['received', 10]);
    assert(hidden.length === 0, 'cadeaux d’un membre bloqué masqués');
    await rpc(U.moussa, 'unblock_user', [U.aicha]);
    await rpc(U.admin, 'admin_save_shop_item', [await item('sourire'), JSON.stringify({ active: false })]);
    await fails(rpc(U.aicha, 'send_shop_item', [await item('sourire'), U.moussa]), /ITEM_NOT_FOUND/);
    await rpc(U.admin, 'admin_save_shop_item', [await item('sourire'), JSON.stringify({ active: true })]);
    await db.query(`update app_config set value = '2' where key = 'shop_sends_per_day'`);
    await rpc(U.aicha, 'send_shop_item', [await item('sourire'), U.fatou]);
    await fails(rpc(U.aicha, 'send_shop_item', [await item('sourire'), U.fatou]), /DAILY_LIMIT/);
    await db.query(`update app_config set value = '20' where key = 'shop_sends_per_day'`);
  });
}
