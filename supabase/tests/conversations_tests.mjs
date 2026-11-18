// Tests ZAYA — messagerie (migration 0040) : conversations actives limitées, demande de re-match.
// Membres dédiés, pour ne pas dépendre de l'état laissé par les autres sections.

export async function conversationsTests({ db, test, assert, as, rpc, fails, seedMember }) {
  console.log('\nMessagerie : conversations actives et re-match (0040)');
  const C = {
    w: '00000000-0000-0000-0000-0000000040a1',
    m1: '00000000-0000-0000-0000-0000000040b1',
    m2: '00000000-0000-0000-0000-0000000040b2',
    m3: '00000000-0000-0000-0000-0000000040b3',
    x: '00000000-0000-0000-0000-0000000040c1',
  };
  await seedMember(C.w, 'Nafi', 'femme', '1996-04-04', null);
  for (const [id, nom] of [[C.m1, 'Bangoura'], [C.m2, 'Condé'], [C.m3, 'Sylla'], [C.x, 'Touré']]) {
    await seedMember(id, nom, 'homme', '1992-05-05', null);
  }
  const match = async (a, b) => (await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid)) returning id`,
    [a, b])).rows[0].id;
  const M1 = await match(C.w, C.m1);
  const M2 = await match(C.w, C.m2);
  const M3 = await match(C.w, C.m3);
  const cfg = (v) => db.query(`update app_config set value = $1 where key = 'max_active_conversations'`, [v]);

  await test('conversations actives : premier message refusé au-delà de la limite, réponse toujours possible', async () => {
    await cfg('2');
    try {
      assert((await rpc(C.w, 'send_message', [M1, 'Bonjour'])).status === 'sent');
      assert((await rpc(C.w, 'send_message', [M2, 'Bonjour'])).status === 'sent');
      const r = await rpc(C.w, 'send_message', [M3, 'Bonjour']);
      assert(r.status === 'active_limit' && r.active === 2 && r.limit === 2, JSON.stringify(r));
      assert((await rpc(C.w, 'send_message', [M1, 'Comment vas-tu ?'])).status === 'sent', 'conversation déjà ouverte');
      assert((await rpc(C.m1, 'send_message', [M1, 'Très bien'])).status === 'sent', 'réponse de l’autre membre');
      const places = await rpc(C.w, 'my_conversation_slots');
      assert(places.active === 2 && places.limit === 2, JSON.stringify(places));
      await rpc(C.w, 'unmatch', [M2]); // terminer une conversation libère une place
      assert((await rpc(C.w, 'send_message', [M3, 'Bonjour'])).status === 'sent');
    } finally {
      await cfg('5');
    }
  });

  await test('re-match : demande, réception, acceptation ; jamais par un tiers', async () => {
    // M2 a été terminé par Nafi : Condé demande à reprendre.
    assert((await rpc(C.m2, 'rematch_state', [M2])) === 'none');
    const r = await rpc(C.m2, 'request_rematch', [M2]);
    assert(r.status === 'pending' && r.mine === true, JSON.stringify(r));
    assert((await rpc(C.m2, 'rematch_state', [M2])) === 'sent');
    assert((await rpc(C.w, 'rematch_state', [M2])) === 'received');
    const recues = (await as(C.w, `select * from my_rematch_requests()`)).rows;
    assert(recues.length === 1 && recues[0].display_name === 'Condé', JSON.stringify(recues));
    await fails(rpc(C.x, 'request_rematch', [M2]), /MATCH_NOT_FOUND/);
    await fails(rpc(C.m2, 'respond_rematch', [M2, true]), /REQUEST_NOT_FOUND/); // pas à lui de répondre
    assert((await rpc(C.w, 'respond_rematch', [M2, true])).status === 'rematched');
    const fin = (await db.query(`select ended_at from matches where id = $1`, [M2])).rows[0].ended_at;
    assert(fin === null, 'le match doit reprendre');
  });

  await test('re-match : demandes croisées = accord ; refus définitif ; impossible en cas de blocage', async () => {
    // Demandes croisées sur M3.
    await rpc(C.m3, 'unmatch', [M3]);
    assert((await rpc(C.m3, 'request_rematch', [M3])).status === 'pending');
    assert((await rpc(C.w, 'request_rematch', [M3])).status === 'rematched', 'la demande croisée vaut accord');
    // Refus sur M1, puis aucune nouvelle demande possible.
    await rpc(C.w, 'unmatch', [M1]);
    await rpc(C.m1, 'request_rematch', [M1]);
    assert((await rpc(C.w, 'respond_rematch', [M1, false])).status === 'declined');
    const encore = await rpc(C.m1, 'request_rematch', [M1]);
    assert(encore.status === 'declined', JSON.stringify(encore));
    // Blocage : plus de re-match.
    await rpc(C.w, 'unmatch', [M3]);
    await rpc(C.w, 'block_user', [C.m3]);
    await fails(rpc(C.m3, 'request_rematch', [M3]), /REMATCH_UNAVAILABLE/);
  });

  await test('demandes de re-match illisibles directement', async () => {
    await fails(as(C.w, `select * from rematch_requests`), /permission denied/i);
    await fails(as(C.w, `select active_conversations_count($1)`, [C.w]), /permission denied/i);
  });
}
