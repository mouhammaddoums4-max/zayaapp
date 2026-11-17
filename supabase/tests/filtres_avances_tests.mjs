// Tests ZAYA — filtres avancés de Découvrir réservés à Premium (migration 0025) :
// langues parlées, projet de mariage, situation matrimoniale.
// Membres dédiés, pour ne pas dépendre de l'état laissé par les autres sections.

export async function filtresAvancesTests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nDécouvrir : filtres avancés Premium (0025)');
  const F = {
    kadi: '00000000-0000-0000-0000-0000000025a1',
    soussou: '00000000-0000-0000-0000-0000000025a2', // Soussou, projet « bientôt », célibataire
    poular: '00000000-0000-0000-0000-0000000025a3', // Poular, « sans date précise », divorcé
    vide: '00000000-0000-0000-0000-0000000025a4', // projet et situation non renseignés, aucune langue
  };
  await seedMember(F.kadi, 'Kadi', 'femme', '1997-04-04', null);
  await seedMember(F.soussou, 'Sylla', 'homme', '1993-05-05', null);
  await seedMember(F.poular, 'Barry', 'homme', '1991-06-06', null);
  await seedMember(F.vide, 'Kouyaté', 'homme', '1992-07-07', null);
  await db.query(
    `update profiles set languages = '{Soussou,Français}', marriage_horizon = 'soon', marital_status = 'single' where id = $1`,
    [F.soussou],
  );
  await db.query(
    `update profiles set languages = '{Poular}', marriage_horizon = 'no_date', marital_status = 'divorced' where id = $1`,
    [F.poular],
  );

  const prefs = (sql, params = []) => as(F.kadi, `update discovery_preferences set ${sql} where user_id = $1`, [F.kadi, ...params]);
  const reset = () => db.query(
    `update discovery_preferences set languages = '{}', marriage_horizons = '{}', marital_statuses = '{}', age_min = 18
     where user_id = $1`,
    [F.kadi],
  );
  /** Parmi les trois hommes de cette section, ceux que Kadi voit dans Découvrir. */
  const vus = async () => {
    const r = await as(F.kadi, `select id from discovery_feed(50)`);
    const ids = new Set(r.rows.map((x) => x.id));
    return ['soussou', 'poular', 'vide'].filter((k) => ids.has(F[k])).join(',');
  };

  await test('Gratuit : ne peut pas définir de filtre avancé, mais garde ses filtres de base', async () => {
    await fails(prefs(`languages = '{Soussou}'`), /PREMIUM_REQUIRED/);
    await fails(prefs(`marriage_horizons = '{soon}'`), /PREMIUM_REQUIRED/);
    await fails(prefs(`marital_statuses = '{single}'`), /PREMIUM_REQUIRED/);
    await prefs(`age_min = 20`);
    await prefs(`languages = '{}'`);
    assert((await vus()) === 'soussou,poular,vide', `vus : ${await vus()}`);
    await reset();
  });

  await test('Premium : langues, projet de mariage et situation restreignent ce que je vois', async () => {
    const g = await rpc(U.admin, 'admin_grant_premium', [F.kadi, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
    try {
      await prefs(`languages = '{Soussou,Malinké}'`);
      assert((await vus()) === 'soussou', `langues : ${await vus()}`);
      await prefs(`languages = '{}', marital_statuses = '{divorced,widowed}'`);
      assert((await vus()) === 'poular', `situation : ${await vus()}`);
      // Une information non renseignée ne correspond à aucun choix.
      await prefs(`marital_statuses = '{}', marriage_horizons = '{soon,no_date}'`);
      assert((await vus()) === 'soussou,poular', `projet : ${await vus()}`);
      // Sens unique : mes filtres ne me cachent pas aux personnes que j'écarte.
      const r = await as(F.vide, `select id from discovery_feed(50)`);
      assert(r.rows.some((x) => x.id === F.kadi), 'Kadi cachée à un membre que ses filtres écartent');
    } finally {
      await rpc(U.admin, 'admin_revoke_premium', [g, 'fin du test']);
    }
  });

  await test('Premium terminé : réglages conservés mais sans effet ; seul le retrait reste permis', async () => {
    const r = await db.query(`select marriage_horizons::text[] as h from discovery_preferences where user_id = $1`, [F.kadi]);
    assert(r.rows[0].h.join(',') === 'soon,no_date', `réglages perdus : ${JSON.stringify(r.rows[0])}`);
    assert((await vus()) === 'soussou,poular,vide', `filtres encore appliqués : ${await vus()}`);
    await prefs(`age_min = 19`); // filtres avancés inchangés : enregistrement accepté
    await fails(prefs(`marriage_horizons = '{soon}'`), /PREMIUM_REQUIRED/);
    await prefs(`marriage_horizons = '{}'`);
    await reset();
  });
}
