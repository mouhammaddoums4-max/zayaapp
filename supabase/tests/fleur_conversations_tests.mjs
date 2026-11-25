// Tests ZAYA (migration 0070) : Fleur Premium, suppression de conversations (pour moi), présence « en ligne ».

export async function fleurConversationsTests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nFleur Premium, suppression de conversations, en ligne (0070)');
  const id = (n) => `00000000-0000-0000-0000-00000070${String(n).padStart(4, '0')}`;
  const P = id(1), F = id(2), G = id(3), H = id(4), X = id(5);
  await seedMember(P, 'Premium', 'homme', '1990-01-01', null);
  await seedMember(F, 'Fanta', 'femme', '1994-04-04', null);
  await seedMember(G, 'Gnalen', 'femme', '1995-05-05', null);
  await seedMember(H, 'Hadja', 'femme', '1996-06-06', null);
  await seedMember(X, 'Gratuit', 'homme', '1991-01-01', null);
  await rpc(U.admin, 'admin_grant_premium', [P, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);

  await test('Fleur : réservée à Premium ; envoyée une fois ; visible par la destinataire, même sans Premium', async () => {
    await fails(rpc(X, 'send_flower', [F]), /PREMIUM_REQUIRED/);
    const r = await rpc(P, 'send_flower', [F]);
    assert(r.status === 'liked' && r.flower === true, JSON.stringify(r));
    assert((await rpc(P, 'send_flower', [F])).status === 'already_sent');
    const recues = (await as(F, `select * from received_flowers()`)).rows;
    assert(recues.length === 1 && recues[0].user_id === P && recues[0].display_name === 'Premium', JSON.stringify(recues));
    assert((await as(G, `select * from received_flowers()`)).rows.length === 0, 'rien chez une autre personne');
  });

  await test('Fleur : limite du jour ; bloquée = invisible ; fonction coupable par l’interrupteur', async () => {
    await db.query(`update app_config set value = '2' where key = 'flowers_per_day'`);
    try {
      assert((await rpc(P, 'send_flower', [G])).flower === true);
      await fails(rpc(P, 'send_flower', [H]), /FLOWER_LIMIT/);
    } finally {
      await db.query(`update app_config set value = '3' where key = 'flowers_per_day'`);
    }
    await db.query(`insert into blocks (blocker, blocked) values ($1, $2)`, [G, P]);
    assert((await as(G, `select * from received_flowers()`)).rows.length === 0, 'expéditeur bloqué : fleur masquée');
    await db.query(`update app_config set value = 'false' where key = 'flowers_enabled'`);
    await fails(rpc(P, 'send_flower', [H]), /FEATURE_DISABLED/);
    await db.query(`update app_config set value = 'true' where key = 'flowers_enabled'`);
  });

  await test('Fleur réciproque : un match se crée comme pour un « J’aime »', async () => {
    await rpc(H, 'send_like', [P]);
    const r = await rpc(P, 'send_flower', [H]);
    assert(r.status === 'matched' && r.flower === true, JSON.stringify(r));
  });

  // ── Conversations
  const match = async (a, b) => (await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid,$2::uuid), greatest($1::uuid,$2::uuid))
     on conflict (user_a, user_b) do update set ended_at = null returning id`, [a, b])).rows[0].id;

  await test('Supprimer des conversations : disparaissent pour moi seulement, reviennent avec un nouveau message', async () => {
    const M1 = await match(F, X);
    await rpc(F, 'send_message', [M1, 'Bonjour X']);
    await rpc(X, 'send_message', [M1, 'Bonjour F']);
    const avant = (await as(F, `select match_id from my_matches()`)).rows.map((r) => r.match_id);
    assert(avant.includes(M1));
    assert((await rpc(F, 'hide_conversations', [[M1]])) === 1);
    assert(!(await as(F, `select match_id from my_matches()`)).rows.some((r) => r.match_id === M1), 'masquée pour moi');
    assert((await as(F, `select 1 from messages where match_id = $1`, [M1])).rows.length === 0, 'historique effacé pour moi');
    assert((await as(X, `select match_id from my_matches()`)).rows.some((r) => r.match_id === M1), 'toujours là pour l’autre');
    assert((await as(X, `select 1 from messages where match_id = $1`, [M1])).rows.length === 2, 'rien d’effacé chez l’autre');
    await rpc(X, 'send_message', [M1, 'Tu es là ?']);
    const apres = (await as(F, `select match_id, last_message from my_matches()`)).rows.find((r) => r.match_id === M1);
    assert(apres && apres.last_message === 'Tu es là ?', JSON.stringify(apres));
    assert((await as(F, `select 1 from messages where match_id = $1`, [M1])).rows.length === 1, 'seul le nouveau message');
  });

  await test('Supprimer des conversations : sans effet sur celles des autres', async () => {
    const M2 = await match(G, H);
    assert((await rpc(F, 'hide_conversations', [[M2]])) === 0);
    assert((await db.query(`select count(*)::int n from conversation_hidden where match_id = $1`, [M2])).rows[0].n === 0);
  });

  // ── En ligne
  await test('En ligne : visible par mes matchs, selon le réglage des deux personnes et l’activité récente', async () => {
    const M3 = await match(F, H);
    await db.query(`update profiles set last_active_at = now(), show_online = true where id in ($1, $2)`, [F, H]);
    let enLigne = (await as(F, `select * from my_online_matches() as u`)).rows.map((r) => r.u);
    assert(enLigne.includes(H), JSON.stringify(enLigne));
    assert(!enLigne.includes(G), 'pas de match actif avec G : jamais affiché');
    await db.query(`update profiles set show_online = false where id = $1`, [H]);
    enLigne = (await as(F, `select * from my_online_matches() as u`)).rows.map((r) => r.u);
    assert(!enLigne.includes(H), 'H masque sa présence');
    await db.query(`update profiles set show_online = true where id = $1`, [H]);
    await db.query(`update profiles set show_online = false where id = $1`, [F]);
    assert((await as(F, `select * from my_online_matches() as u`)).rows.length === 0, 'qui se cache ne voit pas les autres');
    await db.query(`update profiles set show_online = true where id = $1`, [F]);
    await db.query(`update profiles set last_active_at = now() - interval '20 minutes' where id = $1`, [H]);
    assert(!(await as(F, `select * from my_online_matches() as u`)).rows.some((r) => r.u === H), 'inactif depuis 20 min');
    await db.query(`update matches set ended_at = now() where id = $1`, [M3]);
    await db.query(`update profiles set last_active_at = now() where id = $1`, [H]);
    assert(!(await as(F, `select * from my_online_matches() as u`)).rows.some((r) => r.u === H), 'match terminé');
  });
}
