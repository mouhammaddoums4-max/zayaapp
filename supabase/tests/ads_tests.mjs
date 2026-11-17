// Tests de la migration 0015 : régie publicitaire (campagnes directes, emplacements, statistiques).
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U, U.admin super-admin).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function adsTests({ db, test, assert, as, rpc, fails, U }) {
  console.log('\nRégie publicitaire (0015)');

  const served = async (who, placement) => (await as(who, `select * from sponsored_ads($1, 5)`, [placement])).rows;
  const setConfig = (key, value) => db.query(`update app_config set value = $2::jsonb where key = $1`, [key, value]);
  let advertiser;
  let live;

  await test('réservé à l’équipe publicité : un membre ne crée rien et ne lit aucune table', async () => {
    await fails(rpc(U.aicha, 'admin_save_advertiser', [null, 'Boutique test', null, null, null, null, null]), /FORBIDDEN/);
    advertiser = await rpc(U.admin, 'admin_save_advertiser',
      [null, 'Orange Guinée (fictif)', null, 'Service pub', '+224000000', 'pub@exemple.test', 'Contrat négocié']);
    const own = await as(U.aicha, `select count(*)::int as n from advertisers`);
    assert(own.rows[0].n === 0, 'un membre ne doit voir aucun annonceur');
    await fails(as(null, `select * from sponsored_ads('community_feed', 3)`), /permission denied/i);
  });

  await test('campagne : enregistrée en brouillon, publiée avec motif tracé, emplacements fermés', async () => {
    const now = Date.now();
    live = await rpc(U.admin, 'admin_save_campaign', [null, JSON.stringify({
      advertiser_id: advertiser, name: 'Forfait mariage', placements: ['community_feed'],
      headline: 'Votre forfait pour le grand jour', body: 'Appels et internet pour les préparatifs.',
      cta_label: 'Découvrir', destination_url: 'https://exemple.test/offre',
      starts_at: new Date(now - 3600e3).toISOString(), ends_at: new Date(now + 86400e3).toISOString(),
      max_impressions_per_user_per_day: 2, budget_gnf: 5000000,
    })]);
    const draft = await db.query(`select status::text as s from ad_campaigns where id = $1`, [live]);
    assert(draft.rows[0].s === 'draft');
    await fails(as(U.admin, `select admin_set_campaign_status($1, 'suspended', '')`, [live]), /REASON_REQUIRED/);
    await as(U.admin, `select admin_set_campaign_status($1, 'active', 'Validée')`, [live]);
    const audit = await db.query(
      `select count(*)::int as n from audit_log where action like 'ads.%' and actor = $1`, [U.admin]);
    assert(audit.rows[0].n >= 3, 'annonceur, campagne et publication doivent être tracés');
    await fails(rpc(U.admin, 'admin_save_campaign', [null, JSON.stringify({
      advertiser_id: advertiser, name: 'Dans les messages', placements: ['conversation'], headline: 'Interdit',
      starts_at: new Date(now).toISOString(), ends_at: new Date(now + 3600e3).toISOString(),
    })]), /violates check constraint|placements/);
  });

  await test('diffusion désactivée par défaut, puis seulement sur l’emplacement prévu', async () => {
    assert((await served(U.aicha, 'community_feed')).length === 0, 'rien tant que ads_direct_enabled = false');
    await setConfig('ads_direct_enabled', 'true');
    const feed = await served(U.aicha, 'community_feed');
    assert(feed.length === 1 && feed[0].headline === 'Votre forfait pour le grand jour', JSON.stringify(feed));
    assert(feed[0].advertiser_name === 'Orange Guinée (fictif)');
    assert((await served(U.aicha, 'explore')).length === 0, 'pas sur un autre emplacement');
  });

  await test('plafond d’affichages par membre et par jour ; au-delà, plus servie ni comptée', async () => {
    assert(await rpc(U.aicha, 'record_ad_event', [live, 'impression', 'community_feed']) === true);
    assert(await rpc(U.aicha, 'record_ad_event', [live, 'impression', 'community_feed']) === true);
    assert((await served(U.aicha, 'community_feed')).length === 0, 'plafond de 2 atteint');
    assert(await rpc(U.aicha, 'record_ad_event', [live, 'impression', 'community_feed']) === false);
    assert((await served(U.moussa, 'community_feed')).length === 1, 'le plafond est propre à chaque membre');
  });

  await test('un clic n’est compté qu’après un affichage réel, une fois par jour', async () => {
    assert(await rpc(U.moussa, 'record_ad_event', [live, 'click', 'community_feed']) === false, 'clic sans affichage');
    await rpc(U.moussa, 'record_ad_event', [live, 'impression', 'community_feed']);
    assert(await rpc(U.moussa, 'record_ad_event', [live, 'click', 'community_feed']) === true);
    assert(await rpc(U.moussa, 'record_ad_event', [live, 'click', 'community_feed']) === false, 'second clic ignoré');
    await fails(rpc(U.moussa, 'record_ad_event', [live, 'reward', 'community_feed']), /INVALID_EVENT/);
  });

  await test('démarrage et arrêt automatiques selon les dates ; suspension immédiate', async () => {
    const now = Date.now();
    const future = await rpc(U.admin, 'admin_save_campaign', [null, JSON.stringify({
      advertiser_id: advertiser, name: 'Plus tard', placements: ['explore'], headline: 'Bientôt',
      starts_at: new Date(now + 86400e3).toISOString(), ends_at: new Date(now + 2 * 86400e3).toISOString(),
    })]);
    await as(U.admin, `select admin_set_campaign_status($1, 'scheduled', null)`, [future]);
    assert((await served(U.fatou, 'explore')).length === 0, 'programmée : pas encore diffusée');
    await db.query(`update ad_campaigns set starts_at = now() - interval '2 days', ends_at = now() - interval '1 day'
                    where id = $1`, [future]);
    const st = await as(U.admin, `select status::text as s from ad_campaign_stats where campaign_id = $1`, [future]);
    assert(st.rows[0].s === 'ended', JSON.stringify(st.rows));
    await as(U.admin, `select admin_set_campaign_status($1, 'suspended', 'Visuel à corriger')`, [live]);
    assert((await served(U.fatou, 'community_feed')).length === 0, 'suspendue : plus diffusée');
    await as(U.admin, `select admin_set_campaign_status($1, 'active', 'Corrigée')`, [live]);
  });

  await test('statistiques par campagne : affichages, clics, taux ; invisibles pour un membre', async () => {
    const s = await as(U.admin, `select impressions::int as i, clicks::int as c, ctr_percent::float as r
                                 from ad_campaign_stats where campaign_id = $1`, [live]);
    assert(s.rows[0].i === 3 && s.rows[0].c === 1 && Math.abs(s.rows[0].r - 33.33) < 0.01, JSON.stringify(s.rows));
    const member = await as(U.aicha, `select count(*)::int as n from ad_campaign_stats`);
    assert(member.rows[0].n === 0, 'un membre ne voit aucune statistique');
    await setConfig('ads_direct_enabled', 'false');
  });
}
