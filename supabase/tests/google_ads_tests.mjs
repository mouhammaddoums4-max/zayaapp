// Tests de la migration 0034 : réglages publicitaires décidés par le serveur (Google AdMob et campagnes directes).
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U, U.admin super-admin).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function googleAdsTests({ db, test, assert, as, rpc, fails, U }) {
  console.log('\nPublicités Google et réglages du membre (0034)');

  const setConfig = (key, value) => db.query(`update app_config set value = $2::jsonb where key = $1`, [key, value]);
  const settings = (who) => rpc(who, 'my_ad_settings');

  await test('par défaut, tout est éteint ; les réglages sont lisibles par l’application', async () => {
    await setConfig('ads_direct_enabled', 'false');
    await setConfig('ads_admob_enabled', 'false');
    const s = await settings(U.aicha);
    assert(s.direct === false && s.admob === false, JSON.stringify(s));
    assert(s.non_personalized === true, 'annonces Google non personnalisées par défaut');
    assert(s.interstitial_every_swipes === 0, 'aucun interstitiel tant que l’équipe ne l’a pas réglé');
    assert(JSON.stringify(s.banner_placements) === '["explore","community","profile"]', JSON.stringify(s.banner_placements));
    const pub = await as(null, `select count(*)::int as n from app_config
                                where is_public and key in ('ads_banner_placements', 'admob_interstitial_unit_android',
                                  'ads_interstitial_every_swipes', 'ads_interstitial_min_minutes', 'ads_explore_every',
                                  'ads_admob_non_personalized')`);
    assert(pub.rows[0].n === 6, `réglages publics : ${pub.rows[0].n}`);
    await fails(as(null, `select my_ad_settings()`), /permission denied/i);
  });

  await test('activés par l’équipe : rythme et identifiants servis tels quels, bornes de sécurité appliquées', async () => {
    await setConfig('ads_direct_enabled', 'true');
    await setConfig('ads_admob_enabled', 'true');
    await setConfig('admob_banner_unit_android', '"ca-app-pub-test/banner"');
    await setConfig('ads_interstitial_every_swipes', '15');
    await setConfig('ads_interstitial_min_minutes', '0');
    await setConfig('ads_community_every', '1');
    const s = await settings(U.aicha);
    assert(s.direct === true && s.admob === true, JSON.stringify(s));
    assert(s.banner_unit_android === 'ca-app-pub-test/banner', s.banner_unit_android);
    assert(s.interstitial_every_swipes === 15, String(s.interstitial_every_swipes));
    assert(s.interstitial_min_minutes === 1, 'au moins une minute entre deux interstitiels');
    assert(s.community_every === 2, 'jamais une publicité après chaque publication');
  });

  await test('Premium : publicités visibles par défaut (régie §1), masquées si l’équipe le décide', async () => {
    const g = await rpc(U.admin, 'admin_grant_premium',
      [U.fatou, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
    assert(g, 'Premium accordé');
    let s = await settings(U.fatou);
    assert(s.admob === true && s.direct === true, 'Premium voit les publicités par défaut');
    await setConfig('ads_show_to_premium', 'false');
    s = await settings(U.fatou);
    assert(s.admob === false && s.direct === false, JSON.stringify(s));
    const free = await settings(U.aicha);
    assert(free.admob === true, 'un compte gratuit les voit toujours');
    await setConfig('ads_show_to_premium', 'true');
  });

  await test('un membre ne change aucun réglage publicitaire', async () => {
    const touched = await as(U.aicha, `update app_config set value = 'true'::jsonb
                                       where key = 'ads_admob_non_personalized' returning key`).catch(() => ({ rows: [] }));
    assert(touched.rows.length === 0, 'aucune ligne modifiée par un membre');
    await setConfig('ads_direct_enabled', 'false');
    await setConfig('ads_admob_enabled', 'false');
    await setConfig('ads_community_every', '6');
    await setConfig('admob_banner_unit_android', '""');
    await setConfig('ads_interstitial_every_swipes', '0');
    await setConfig('ads_interstitial_min_minutes', '10');
  });
}
