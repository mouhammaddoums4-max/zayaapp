// Tests ZAYA 2.0 — Lot 2 (migration 0069) : Questions, Surprise quotidienne, Challenge.

export async function lot2Tests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nZAYA 2.0 — Lot 2 : Questions, Surprise, Challenge (0069)');
  const id = (n) => `00000000-0000-0000-0000-00000069${String(n).padStart(4, '0')}`;
  const A = id(1), B = id(2), S = id(3), NV = id(4), BLK = id(5);
  await seedMember(A, 'Aminata', 'femme', '1995-05-05', null);
  await seedMember(B, 'Boubacar', 'homme', '1992-02-02', null);
  await seedMember(S, 'Sidiki', 'homme', '1990-10-10', null);
  await seedMember(NV, 'Nonverif', 'homme', '1990-10-11', null);
  await seedMember(BLK, 'Bloque', 'homme', '1990-10-12', null);
  await db.query(`update profiles set verification_status = 'not_requested' where id = $1`, [NV]);
  await db.query(`insert into blocks (blocker, blocked) values ($1, $2)`, [A, BLK]);
  const M = (await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid,$2::uuid), greatest($1::uuid,$2::uuid)) returning id`,
    [A, B])).rows[0].id;
  const Q = (await db.query(`select id from marriage_questions order by position limit 1`)).rows[0].id;
  const voit = async (viewer) => JSON.parse(JSON.stringify(await rpc(viewer, 'answers_of', [A])));

  await test('Questions : privées par défaut ; chaque niveau de visibilité est appliqué côté serveur', async () => {
    assert((await rpc(A, 'answer_question', [Q, 'Le respect et la patience.'])).status === 'saved');
    assert((await voit(A)).length === 1, 'moi seul : je me vois');
    assert((await voit(B)).length === 0, 'moi seul : invisible pour un match');
    await rpc(A, 'answer_question', [Q, 'Le respect et la patience.', 'matches']);
    assert((await voit(B)).length === 1, 'mes matchs : visible par B');
    assert((await voit(S)).length === 0, 'mes matchs : invisible pour un inconnu');
    await rpc(A, 'answer_question', [Q, 'Le respect et la patience.', 'verified']);
    assert((await voit(S)).length === 1, 'membres vérifiés : visible par un vérifié');
    assert((await voit(NV)).length === 0, 'membres vérifiés : invisible pour un non vérifié');
    assert((await voit(BLK)).length === 0, 'utilisateur bloqué : rien');
  });

  await test('Questions : lecture directe de la table limitée à soi ; suppression immédiate ; match terminé = invisible', async () => {
    assert((await as(B, `select 1 from question_answers where user_id = $1`, [A])).rows.length === 0, 'B ne lit pas la table de A');
    assert((await as(A, `select 1 from question_answers`)).rows.length === 1);
    await rpc(A, 'answer_question', [Q, 'Le respect et la patience.', 'matches']);
    await rpc(A, 'unmatch', [M]);
    assert((await voit(B)).length === 0, 'match terminé : plus visible');
    await rpc(A, 'delete_answer', [Q]);
    assert((await voit(A)).length === 0, 'supprimée aussitôt');
  });

  await test('Questions : numéro, lien et termes interdits refusés ; visibilité inconnue refusée ; interrupteur', async () => {
    assert((await rpc(A, 'answer_question', [Q, 'Appelle-moi au +224 622 11 22 33 ou sur www.exemple.com'])).status === 'blocked');
    await fails(rpc(A, 'answer_question', [Q, 'Bonjour', 'tous']), /INVALID_VISIBILITY/);
    await db.query(`update app_config set value = 'false' where key = 'feature_questions_enabled'`);
    await fails(rpc(A, 'answer_question', [Q, 'Bonjour']), /FEATURE_DISABLED/);
    assert((await voit(A)).length === 0);
    await db.query(`update app_config set value = 'true' where key = 'feature_questions_enabled'`);
  });

  await test('Surprise : une seule par jour même en parallèle, réservée aux vérifiés, probabilités publiques', async () => {
    const odds = await rpc(A, 'surprise_odds');
    assert(odds.length === 1 && odds[0].code === 'question' && Number(odds[0].percent) === 100, JSON.stringify(odds));
    assert((await rpc(NV, 'open_daily_surprise')).status === 'not_eligible');
    const tirages = await Promise.all(Array.from({ length: 20 }, () => rpc(S, 'open_daily_surprise')));
    assert(tirages.filter((t) => t.status === 'opened').length === 1, '20 ouvertures : un seul tirage');
    assert((await db.query(`select count(*)::int n from daily_surprises where user_id = $1`, [S])).rows[0].n === 1);
    const encore = await rpc(S, 'open_daily_surprise');
    assert(encore.status === 'already_opened' && encore.prize === 'question');
    await fails(as(S, `select * from daily_surprises`), /permission denied/);
  });

  await test('Surprise : récompense créditée une seule fois au registre, même si la ligne du jour est rejouée', async () => {
    await db.query(`update surprise_prizes set weight = 0 where code = 'question'`);
    await db.query(`update surprise_prizes set weight = 1, amount = 4, active = true where code = 'swipes'`);
    try {
      const r = await rpc(B, 'open_daily_surprise');
      assert(r.status === 'opened' && r.prize === 'swipes' && r.amount === 4, JSON.stringify(r));
      const odds = await rpc(B, 'surprise_odds');
      assert(odds.length === 1 && Number(odds[0].percent) === 100 && odds[0].amount === 4);
      await db.query(`delete from daily_surprises where user_id = $1`, [B]);
      await rpc(B, 'open_daily_surprise');
      const n = (await db.query(`select count(*)::int n, sum(amount)::int total from reward_ledger where user_id = $1 and source = 'surprise'`, [B])).rows[0];
      assert(n.n === 1 && n.total === 4, JSON.stringify(n));
    } finally {
      await db.query(`update surprise_prizes set weight = 100 where code = 'question'`);
      await db.query(`update surprise_prizes set weight = 0, amount = 0, active = false where code = 'swipes'`);
    }
    await db.query(`update app_config set value = 'false' where key = 'feature_surprise_enabled'`);
    assert((await rpc(S, 'open_daily_surprise')).status === 'disabled');
    await db.query(`update app_config set value = 'true' where key = 'feature_surprise_enabled'`);
  });

  await test('Challenge : validé par des événements réels, une seule fois par jour, refusé sans l’événement', async () => {
    await fails(rpc(S, 'claim_challenge', ['discover_profiles']), /NOT_COMPLETED/);
    const vus = [A, B, NV, BLK, U.aicha];
    for (const v of vus) await db.query(`insert into profile_views (viewer, viewed) values ($1, $2)`, [S, v]);
    const liste = (await rpc(S, 'my_challenges')).challenges;
    const d = liste.find((c) => c.code === 'discover_profiles');
    assert(d.progress === 5 && d.claimed === false, JSON.stringify(d));
    assert((await rpc(S, 'claim_challenge', ['discover_profiles'])).status === 'claimed');
    await fails(rpc(S, 'claim_challenge', ['discover_profiles']), /ALREADY_CLAIMED/);
    assert((await rpc(S, 'my_challenges')).challenges.find((c) => c.code === 'discover_profiles').claimed === true);
    await fails(rpc(NV, 'claim_challenge', ['discover_profiles']), /NOT_ELIGIBLE/);
    await fails(rpc(S, 'claim_challenge', ['inconnu']), /CHALLENGE_NOT_FOUND/);
  });

  await test('Challenge : réponse à une question comptée ; plafond journalier et plafond par appareil', async () => {
    await fails(rpc(B, 'claim_challenge', ['answer_question']), /NOT_COMPLETED/);
    await rpc(B, 'answer_question', [Q, 'Une réponse sincère.']);
    await db.query(`update challenges set reward_amount = 2`);
    await db.query(`update app_config set value = '1' where key = 'challenge_daily_reward_cap'`);
    try {
      assert((await rpc(B, 'claim_challenge', ['answer_question'])).reward === 2);
      assert((await db.query(`select count(*)::int n from reward_ledger where user_id = $1 and source = 'challenge'`, [B])).rows[0].n === 1);
      await db.query(`insert into profile_views (viewer, viewed) select $1, id from profiles where id <> $1 limit 6`, [B]);
      await fails(rpc(B, 'claim_challenge', ['discover_profiles']), /REWARD_CAP_REACHED/);
      // Plafond par appareil : deux comptes sur le même appareil partagent le plafond du jour.
      await db.query(`update app_config set value = '3' where key = 'challenge_daily_reward_cap'`);
      await db.query(`update app_config set value = '1' where key = 'challenge_device_daily_cap'`);
      const dev = 'd'.repeat(32);
      await rpc(B, 'register_device', [dev]);
      await rpc(S, 'register_device', [dev]);
      await fails(rpc(B, 'claim_challenge', ['discover_profiles']), /DEVICE_LIMIT/);
    } finally {
      await db.query(`update challenges set reward_amount = 0`);
      await db.query(`update app_config set value = '3' where key = 'challenge_daily_reward_cap'`);
      await db.query(`update app_config set value = '6' where key = 'challenge_device_daily_cap'`);
    }
    await db.query(`update app_config set value = 'false' where key = 'feature_challenge_enabled'`);
    await fails(rpc(B, 'claim_challenge', ['discover_profiles']), /FEATURE_DISABLED/);
    await db.query(`update app_config set value = 'true' where key = 'feature_challenge_enabled'`);
  });
}
