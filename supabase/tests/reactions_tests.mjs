// Tests ZAYA — messagerie (migration 0066) : réactions et réponses à un message.

export async function reactionsTests({ db, test, assert, as, rpc, fails, seedMember }) {
  console.log('\nMessagerie : réactions et réponses (0066)');
  const W = '00000000-0000-0000-0000-0000000066a1';
  const X = '00000000-0000-0000-0000-0000000066b1';
  const Z = '00000000-0000-0000-0000-0000000066c1';
  await seedMember(W, 'Awa', 'femme', '1995-03-03', null);
  await seedMember(X, 'Sory', 'homme', '1991-06-06', null);
  await seedMember(Z, 'Intrus', 'homme', '1990-01-01', null);
  const M = (await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid,$2::uuid), greatest($1::uuid,$2::uuid)) returning id`,
    [W, X])).rows[0].id;
  const first = (await rpc(W, 'send_message', [M, 'Bonjour'])).id;

  await test('réponse : citation reliée au bon message, refus d’un message inconnu', async () => {
    const r = await rpc(X, 'send_message', [M, 'Salut !', first]);
    assert(r.status === 'sent', JSON.stringify(r));
    const q = (await as(X, `select reply_to_id from messages where id = $1`, [r.id])).rows;
    assert(q.length === 1 && q[0].reply_to_id === first, JSON.stringify(q));
    await fails(rpc(X, 'send_message', [M, 'Hum', '00000000-0000-0000-0000-000000000999']), /INVALID_REPLY/);
  });
  await test('réaction : poser, remplacer, retirer ; un seul emoji par membre', async () => {
    assert((await rpc(X, 'react_to_message', [first, '❤️'])) === 'set');
    assert((await rpc(X, 'react_to_message', [first, '😂'])) === 'set');
    const rows = (await as(W, `select emoji from message_reactions where message_id = $1`, [first])).rows;
    assert(rows.length === 1 && rows[0].emoji === '😂', JSON.stringify(rows));
    assert((await rpc(X, 'react_to_message', [first, '😂'])) === 'removed');
    assert((await as(W, `select 1 from message_reactions where message_id = $1`, [first])).rows.length === 0);
  });
  await test('réaction : emoji hors liste refusé, tiers sans accès, lecture réservée aux participants', async () => {
    await fails(rpc(X, 'react_to_message', [first, '🍆']), /INVALID_REACTION/);
    await fails(rpc(Z, 'react_to_message', [first, '👍']), /MESSAGE_NOT_FOUND/);
    await rpc(W, 'react_to_message', [first, '👍']);
    assert((await as(Z, `select 1 from message_reactions`)).rows.length === 0, 'un tiers ne doit rien voir');
    assert((await as(X, `select 1 from message_reactions`)).rows.length === 1);
  });
  await test('réaction : impossible après la fin du match', async () => {
    await rpc(W, 'unmatch', [M]);
    await fails(rpc(X, 'react_to_message', [first, '🙏']), /MATCH_ENDED/);
  });
}
