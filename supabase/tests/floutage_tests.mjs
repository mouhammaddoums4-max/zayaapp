// Tests ZAYA — floutage automatique (migration 0057) : photos à flouter, échecs relancés avec délai puis abandonnés,
// fonctions et table réservées au serveur, tâche planifiée sans effet sans pg_net.
// Membre dédié ; les essais sur la file d'attente se font dans une transaction annulée à la fin.

export async function floutageTests({ db, test, assert, as, fails, seedMember }) {
  console.log('\nFloutage automatique des photos (0057)');
  const F = { mari: '00000000-0000-0000-0000-0000000057a1' };
  await seedMember(F.mari, 'Mariama', 'femme', '1997-05-05', null);
  const ids = (await db.query(`select id from profile_photos where user_id = $1 order by position`, [F.mari])).rows
    .map((r) => r.id);

  await test('réservé au serveur : un membre ne lit ni la file, ni les essais, et ne peut rien déclencher', async () => {
    await fails(as(F.mari, `select * from blur_backlog(3, 0)`), /permission denied/i);
    await fails(as(F.mari, `select blur_job_failed($1, 'x')`, [ids[0]]), /permission denied/i);
    await fails(as(F.mari, `select blur_photos_tick()`), /permission denied/i);
    await fails(as(F.mari, `select * from photo_blur_jobs`), /permission denied/i);
    await fails(as(null, `select * from blur_backlog(3, 0)`), /permission denied/i);
  });

  await test('file : photos sans version floutée, après le délai laissé à l’application ; échecs relancés puis abandonnés',
    async () => {
      await db.transaction(async (tx) => {
        // Seules les photos du membre de test restent à flouter.
        await tx.query(`update profile_photos set blur_path = 'deja/' || id || '.jpg' where user_id <> $1`, [F.mari]);
        await tx.exec(`set local role service_role`);
        const file = async (age = 0) => (await tx.query(`select id from blur_backlog(20, $1)`, [age])).rows.map((r) => r.id);

        let f = await file();
        assert(f.length === 3 && ids.every((id) => f.includes(id)), JSON.stringify(f));
        assert((await file(60)).length === 0, 'une photo envoyée à l’instant est laissée à l’application');

        await tx.exec(`reset role`);
        await tx.query(`update profile_photos set blur_path = $2 where id = $1`, [ids[1], `${F.mari}/${ids[1]}.jpg`]);
        await tx.exec(`set local role service_role`);
        f = await file();
        assert(f.length === 2 && !f.includes(ids[1]), 'une photo déjà floutée sort de la file');

        await tx.query(`select blur_job_failed($1, 'original introuvable')`, [ids[0]]);
        f = await file();
        assert(f.length === 1 && f[0] === ids[2], 'après un échec, le nouvel essai attend 5 minutes');
        const job = (await tx.query(`select attempts, last_error from photo_blur_jobs where photo_id = $1`, [ids[0]])).rows[0];
        assert(job.attempts === 1 && job.last_error === 'original introuvable', JSON.stringify(job));

        await tx.query(`update photo_blur_jobs set last_attempt_at = now() - interval '6 minutes' where photo_id = $1`,
          [ids[0]]);
        assert((await file()).includes(ids[0]), 'relancée une fois le délai passé');

        await tx.query(`update photo_blur_jobs set attempts = 5, last_attempt_at = now() - interval '1 day'
                        where photo_id = $1`, [ids[0]]);
        assert(!(await file()).includes(ids[0]), 'abandonnée après blur_max_attempts essais');

        await tx.query(`select blur_job_failed(gen_random_uuid(), 'x')`);
        assert((await tx.query(`select count(*)::int as n from photo_blur_jobs`)).rows[0].n === 1,
          'aucun essai enregistré pour une photo inexistante');

        await tx.exec(`reset role`);
        assert((await tx.query(`select blur_photos_tick() as r`)).rows[0].r === 0, 'sans pg_net ni coffre : rien');
        await tx.query(`delete from profile_photos where id = $1`, [ids[0]]);
        assert((await tx.query(`select count(*)::int as n from photo_blur_jobs`)).rows[0].n === 0,
          'les essais disparaissent avec la photo');
        await tx.rollback();
      });
    });
}
