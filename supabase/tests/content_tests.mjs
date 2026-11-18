// Tests des migrations 0019 (aide administrable), 0022 (formules Premium) et 0023 (photos et invitation).
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U, U.admin super-admin).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function contentTests({ db, test, assert, as, fails, U }) {
  console.log('\nContenus administrables et photos (0019, 0022, 0023)');

  await test('aide : questions lisibles par tous dans chaque langue ; seule l’équipe les modifie', async () => {
    const fr = await as(null, `select count(*)::int as n from help_articles where lang = 'fr'`);
    const en = await as(null, `select count(*)::int as n from help_articles where lang = 'en'`);
    assert(fr.rows[0].n === 10 && en.rows[0].n === 10, `${fr.rows[0].n} / ${en.rows[0].n}`);
    await fails(as(U.aicha, `insert into help_articles (section, lang, question, answer) values ('X', 'fr', 'Question ?', 'Réponse.')`),
      /row-level security/i);
    const touched = await as(U.aicha, `update help_articles set answer = 'Piraté' where lang = 'fr' returning id`);
    assert(touched.rows.length === 0, 'un membre ne modifie aucune question');
    await as(U.admin, `insert into help_articles (section, lang, question, answer, position, active)
                       values ('Essai', 'fr', 'Question masquée ?', 'Réponse masquée.', 999, false)`);
    const hidden = await as(null, `select count(*)::int as n from help_articles where question = 'Question masquée ?'`);
    assert(hidden.rows[0].n === 0, 'une question désactivée n’est pas servie');
  });

  await test('formules Premium : noms et durées lisibles, prix vides (C7), modifiables par l’équipe seulement', async () => {
    const plans = await as(null, `select code, name_fr, duration_days, price_gnf from premium_plans order by position`);
    assert(plans.rows.map((p) => p.name_fr).join(',') === 'Étincelle,Flamme,Alliance', JSON.stringify(plans.rows));
    assert(plans.rows.map((p) => p.duration_days).join(',') === '7,30,90');
    assert(plans.rows.every((p) => p.price_gnf === null), 'aucun prix inventé');
    const changed = await as(U.aicha, `update premium_plans set price_gnf = 1 returning code`);
    assert(changed.rows.length === 0, 'un membre ne fixe aucun prix');
    await as(U.admin, `update premium_plans set tagline_fr = 'Une semaine pour essayer' where code = 'week'`);
    const features = await as(null, `select count(*)::int as n, count(*) filter (where in_free)::int as free
                                     from premium_features`);
    assert(features.rows[0].n === 10 && features.rows[0].free === 6, JSON.stringify(features.rows));
  });

  await test('photos : 6 au plus par profil, refus côté serveur ; réglages publics', async () => {
    const id = '00000000-0000-0000-0000-0000000000c6';
    await db.query(`insert into auth.users (id, phone, phone_confirmed_at) values ($1, '224620009966', now())`, [id]);
    await db.query(
      `insert into profiles (id, display_name, birth_date, gender, seeking_gender, country_code, city_id, status)
       values ($1, 'Six', '1996-06-06', 'femme', 'homme', 'GN', (select id from cities limit 1), 'active')`, [id]);
    for (let i = 0; i < 6; i++) {
      await as(id, `insert into profile_photos (user_id, storage_path, position) values ($1, $2, $3)`,
        [id, `${id}/p${i}.jpg`, i]);
    }
    await fails(as(id, `insert into profile_photos (user_id, storage_path, position) values ($1, $2, 6)`,
      [id, `${id}/p6.jpg`]), /MAX_PHOTOS/);
    await as(id, `delete from profile_photos where storage_path = $1`, [`${id}/p5.jpg`]);
    await as(id, `insert into profile_photos (user_id, storage_path, position) values ($1, $2, 5)`, [id, `${id}/p7.jpg`]);
    const n = await db.query(`select count(*)::int as n from profile_photos where user_id = $1`, [id]);
    assert(n.rows[0].n === 6, 'après une suppression, une nouvelle photo est acceptée');
    const cfg = await as(null, `select key, value from app_config where key in ('max_profile_photos', 'invite_url')`);
    const v = Object.fromEntries(cfg.rows.map((r) => [r.key, r.value]));
    assert(v.max_profile_photos === 6 && String(v.invite_url).startsWith('https://'), JSON.stringify(v));
  });
}
