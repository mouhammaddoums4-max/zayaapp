// Tests ZAYA — swipes (migration 0016) : quota par période, swipes supplémentaires, retour arrière.
// Membres dédiés, pour ne pas dépendre de l'état laissé par les autres sections.

export async function swipesTests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nSwipes : quota par période et retour arrière (0016)');
  const S = {
    awa: '00000000-0000-0000-0000-0000000005a1',
    h1: '00000000-0000-0000-0000-0000000005a2',
    h2: '00000000-0000-0000-0000-0000000005a3',
    h3: '00000000-0000-0000-0000-0000000005a4',
  };
  await seedMember(S.awa, 'Awa', 'femme', '1997-02-02', null);
  for (const [id, nom] of [[S.h1, 'Bah'], [S.h2, 'Camara'], [S.h3, 'Diallo']]) {
    await seedMember(id, nom, 'homme', '1993-03-03', null);
  }
  const cfg = (k, v) => db.query(`update app_config set value = $2 where key = $1`, [k, v]);
  const quota = async () => rpc(S.awa, 'my_swipe_quota');

  await test('likes et passages comptent ensemble ; quota atteint : like refusé avec l’heure de reprise, passage refusé', async () => {
    await cfg('swipe_quota_free', '2');
    try {
      assert((await quota()).resets_at === null, 'aucune période avant le premier swipe');
      assert((await rpc(S.awa, 'send_like', [S.h1])).status === 'liked');
      await rpc(S.awa, 'pass_profile', [S.h2]);
      const q = await quota();
      assert(q.used === 2 && q.remaining === 0 && q.resets_at, JSON.stringify(q));
      const heures = (new Date(q.resets_at) - Date.now()) / 3600e3;
      assert(heures > 7.9 && heures <= 8, `reprise dans ${heures} h au lieu de 8 h`);
      const r = await rpc(S.awa, 'send_like', [S.h3]);
      assert(r.status === 'quota_reached' && r.resets_at && r.limit === 2, JSON.stringify(r));
      await fails(rpc(S.awa, 'pass_profile', [S.h3]), /SWIPE_QUOTA_REACHED/);
    } finally {
      await cfg('swipe_quota_free', '50');
    }
  });

  await test('swipes supplémentaires : crédités une seule fois par référence, jamais par le membre lui-même', async () => {
    await cfg('swipe_quota_free', '2');
    try {
      await fails(as(S.awa, `select grant_extra_swipes($1, 5, 'triche', 'x')`, [S.awa]), /permission denied/i);
      await fails(as(S.awa, `insert into swipe_credits (user_id, amount, source, ref) values ($1, 5, 'triche', 'y')`, [S.awa]),
        /permission denied|row-level security/i);
      const ok = (await db.query(`select grant_extra_swipes($1, 1, 'publicite_recompensee', 'ssv-123') as ok`, [S.awa])).rows[0].ok;
      const encore = (await db.query(`select grant_extra_swipes($1, 1, 'publicite_recompensee', 'ssv-123') as ok`, [S.awa])).rows[0].ok;
      assert(ok === true && encore === false, 'un même jeton ne doit créditer qu’une fois');
      assert((await quota()).extra === 1);
      assert((await rpc(S.awa, 'send_like', [S.h3])).status === 'liked', 'le swipe supplémentaire doit être utilisé');
      assert((await quota()).extra === 0);
      await fails(db.query(`delete from swipe_credits where user_id = $1`, [S.awa]), /APPEND_ONLY/);
    } finally {
      await cfg('swipe_quota_free', '50');
    }
  });

  await test('fin de période : le quota repart à zéro', async () => {
    await cfg('swipe_quota_free', '2');
    try {
      await db.query(`update swipe_periods set started_at = now() - interval '9 hours' where user_id = $1`, [S.awa]);
      const q = await quota();
      assert(q.remaining === 2 && q.resets_at === null, JSON.stringify(q));
      // Compatibilité (0026) : les anciennes versions de l'application exigent une date de reprise.
      const ancien = await rpc(S.awa, 'my_like_quota');
      const heures = (new Date(ancien.resets_at) - Date.now()) / 3600e3;
      assert(ancien.remaining === 2 && heures > 7.9 && heures <= 8, JSON.stringify(ancien));
    } finally {
      await cfg('swipe_quota_free', '50');
    }
  });

  await test('retour arrière : Gratuit, seulement le dernier profil passé ; le swipe n’est pas rendu', async () => {
    await rpc(S.awa, 'pass_profile', [S.h2]); // re-passe h2 (nouvelle période)
    const avant = (await quota()).used;
    const r = await rpc(S.awa, 'rewind_last_pass');
    assert(r.status === 'rewound' && r.id === S.h2 && r.display_name === 'Camara', JSON.stringify(r));
    assert(!('birth_date' in r) && typeof r.age === 'number');
    assert((await db.query(`select count(*)::int as n from passes where from_user = $1 and to_user = $2`, [S.awa, S.h2])).rows[0].n === 0);
    assert((await as(S.awa, `select id from discovery_feed(50)`)).rows.some((x) => x.id === S.h2), 'le profil doit revenir dans Découvrir');
    assert((await quota()).used === avant, 'le retour arrière ne rend pas le swipe');
    assert((await rpc(S.awa, 'rewind_last_pass')).status === 'nothing', 'Gratuit : un seul retour');
  });

  await test('retour arrière Premium : plusieurs profils passés, du plus récent au plus ancien', async () => {
    await rpc(S.awa, 'pass_profile', [S.h2]);
    await rpc(S.awa, 'pass_profile', [S.h3]);
    const g = await rpc(U.admin, 'admin_grant_premium', [S.awa, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
    try {
      assert((await rpc(S.awa, 'rewind_last_pass')).id === S.h3);
      assert((await rpc(S.awa, 'rewind_last_pass')).id === S.h2);
    } finally {
      await rpc(U.admin, 'admin_revoke_premium', [g, 'fin du test']);
    }
  });

  await test('journal des swipes illisible et non modifiable par les membres', async () => {
    await fails(as(S.awa, `select * from swipe_events`), /permission denied/i);
    await fails(as(S.awa, `select consume_swipe($1, $2, 'like')`, [S.awa, S.h1]), /permission denied/i);
    await fails(db.query(`update swipe_events set action = 'like' where user_id = $1`, [S.awa]), /APPEND_ONLY/);
  });
}
