// Tests de la migration 0033 : boîte mystère de bienvenue (tout côté serveur, une seule ouverture par membre).
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function mysteryBoxTests({ db, test, assert, as, rpc, fails, U }) {
  console.log('\nBoîte mystère de bienvenue (0033)');

  const onlyPrize = (code) =>
    db.query(`update mystery_box_prizes set weight = case when code = $1 then 1 else 0 end`, [code]);

  await test('avant l’ouverture : lots et probabilités réelles visibles, total de 100 %', async () => {
    const st = await rpc(U.aicha, 'mystery_box_status');
    assert(st.enabled === true && st.eligible === true && st.opened === false, JSON.stringify(st));
    const total = st.prizes.reduce((s, p) => s + Number(p.probability_percent), 0);
    assert(st.prizes.length === 3 && Math.abs(total - 100) < 0.2, JSON.stringify(st.prizes));
  });

  await test('une seule ouverture : le second appel renvoie le même lot, sans nouveau tirage ni second crédit', async () => {
    await onlyPrize('swipes_20');
    const first = await rpc(U.aicha, 'open_mystery_box');
    assert(first.status === 'opened' && first.prize.code === 'swipes_20', JSON.stringify(first));
    await onlyPrize('swipes_50');
    const again = await rpc(U.aicha, 'open_mystery_box');
    assert(again.status === 'already_opened' && again.prize.code === 'swipes_20', JSON.stringify(again));
    const swipes = await db.query(`select coalesce(sum(amount), 0)::int as n from swipe_credits
                                   where user_id = $1 and source = 'mystery_box'`, [U.aicha]);
    assert(swipes.rows[0].n === 20, `swipes crédités : ${swipes.rows[0].n}`);
    const wallet = await rpc(U.aicha, 'my_wallet');
    assert(wallet.bonus.swipes === 20 && wallet.ad_credits.swipes === 0, JSON.stringify(wallet));
  });

  await test('Premium offert : historique et Premium actif ; stock décompté, lot épuisé retiré', async () => {
    await db.query(`update mystery_box_prizes set stock = 1 where code = 'premium_7'`);
    await onlyPrize('premium_7');
    const r = await rpc(U.moussa, 'open_mystery_box');
    assert(r.prize.code === 'premium_7', JSON.stringify(r));
    const prem = await db.query(`select is_premium($1) as p`, [U.moussa]);
    assert(prem.rows[0].p === true, 'Premium actif après le lot');
    const ev = await db.query(`select count(*)::int as n from premium_events e join premium_grants g on g.id = e.grant_id
                               where g.user_id = $1 and g.source = 'promotion'`, [U.moussa]);
    assert(ev.rows[0].n === 1, 'attribution historisée');
    const stock = await db.query(`select stock from mystery_box_prizes where code = 'premium_7'`);
    assert(stock.rows[0].stock === 0);
    const st = await rpc(U.fatou, 'mystery_box_status');
    assert(!st.prizes.some((p) => p.code === 'premium_7'), 'un lot épuisé n’est plus proposé');
    await fails(rpc(U.fatou, 'open_mystery_box'), /MYSTERY_BOX_EMPTY/);
  });

  await test('réservée aux premiers inscrits ; désactivable ; aucune écriture directe', async () => {
    await db.query(`update mystery_box_prizes set weight = 1`);
    await db.query(`update app_config set value = '1' where key = 'mystery_box_first_members'`);
    await fails(rpc(U.paul, 'open_mystery_box'), /MYSTERY_BOX_NOT_ELIGIBLE/);
    await db.query(`update app_config set value = '1000' where key = 'mystery_box_first_members'`);
    await db.query(`update app_config set value = 'false' where key = 'mystery_box_enabled'`);
    await fails(rpc(U.paul, 'open_mystery_box'), /MYSTERY_BOX_DISABLED/);
    await db.query(`update app_config set value = 'true' where key = 'mystery_box_enabled'`);
    await fails(as(U.paul, `insert into mystery_box_openings (user_id, prize_code, kind, amount)
                            values ($1, 'swipes_50', 'extra_swipes', 50)`, [U.paul]), /permission denied/i);
    await fails(as(U.paul, `update mystery_box_prizes set weight = 1000 where code = 'premium_7'`).then(async () => {
      const w = await db.query(`select weight from mystery_box_prizes where code = 'premium_7'`);
      if (w.rows[0].weight === 1000) throw new Error('modifié par un membre');
      throw new Error('aucune ligne modifiée');
    }), /aucune ligne modifiée/);
    await fails(db.query(`delete from mystery_box_openings where user_id = $1`, [U.aicha]), /APPEND_ONLY/);
  });
}
