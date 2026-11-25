// Tests ZAYA — mises à jour instantanées (0055) : signaux déposés pour le bon membre, sans identité, lisibles par
// leur seul destinataire. Membres dédiés, pour ne pas dépendre de l'état laissé par les autres sections.

export async function signauxTests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nMises à jour instantanées : signaux (0055)');
  const G = {
    w: '00000000-0000-0000-0000-0000000055a1',
    m: '00000000-0000-0000-0000-0000000055a2',
    x: '00000000-0000-0000-0000-0000000055a3', // tiers : ne doit rien recevoir
  };
  await seedMember(G.w, 'Djénabou', 'femme', '1995-03-03', null);
  await seedMember(G.m, 'Sékou', 'homme', '1991-04-04', null);
  await seedMember(G.x, 'Tiers', 'homme', '1990-05-05', null);
  const signaux = async (id) =>
    (await db.query(`select kind from member_signals where user_id = $1 order by id`, [id])).rows.map((r) => r.kind);
  const vider = () => db.query(`delete from member_signals where user_id in ($1, $2, $3)`, [G.w, G.m, G.x]);
  await vider();

  await test('like reçu : un signal « like » pour la personne aimée seulement, sans identité', async () => {
    assert((await rpc(G.w, 'send_like', [G.m])).status === 'liked');
    assert((await signaux(G.m)).join() === 'like', `Sékou : ${await signaux(G.m)}`);
    assert((await signaux(G.w)).length === 0, `Djénabou : ${await signaux(G.w)}`);
    // Aucune colonne d'identité de l'auteur ; entity_id (0063, accusés de réception) ne porte qu'un identifiant de
    // message, jamais rien pour un like.
    const cols = (await db.query(
      `select column_name from information_schema.columns where table_name = 'member_signals' order by 1`,
    )).rows.map((r) => r.column_name);
    assert(!cols.some((c) => /from|actor|sender|author|viewer|liker/.test(c)), `colonne d’identité : ${cols}`);
    if (cols.includes('entity_id')) {
      const e = await db.query(`select entity_id from member_signals where user_id = $1 and kind = 'like'`, [G.m]);
      assert(e.rows.length > 0 && e.rows.every((x) => x.entity_id === null), 'information jointe à un like');
    }
  });

  await test('match puis message : « match » pour les deux, « message » pour le destinataire', async () => {
    await vider();
    const r = await rpc(G.m, 'send_like', [G.w]);
    assert(r.status === 'matched', JSON.stringify(r));
    assert((await signaux(G.w)).includes('match') && (await signaux(G.m)).includes('match'), 'match manquant');
    await vider();
    assert((await rpc(G.w, 'send_message', [r.match_id, 'Bonjour Sékou'])).status === 'sent');
    assert((await signaux(G.m)).join() === 'message', `Sékou : ${await signaux(G.m)}`);
    assert((await signaux(G.w)).length === 0 && (await signaux(G.x)).length === 0, 'signal envoyé à tort');
  });

  await test('photo modérée et Premium accordé : signal pour le propriétaire', async () => {
    await vider();
    await db.query(`update profile_photos set moderation = 'approved' where user_id = $1 and position = 0`, [G.w]);
    await db.query(
      `insert into profile_photos (user_id, storage_path, position, moderation) values ($1, $2, 9, 'pending')`,
      [G.w, `${G.w}/p9.jpg`],
    );
    assert((await signaux(G.w)).includes('photo'), `photo : ${await signaux(G.w)}`);
    const g = await rpc(U.admin, 'admin_grant_premium', [G.w, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
    try {
      assert((await signaux(G.w)).includes('premium'), `premium : ${await signaux(G.w)}`);
    } finally {
      await rpc(U.admin, 'admin_revoke_premium', [g, 'fin du test']);
    }
  });

  await test('confidentialité : chacun ne lit que ses signaux ; aucune écriture possible par l’application', async () => {
    // Djénabou a des signaux (photo, Premium) ; d'autres membres en ont aussi dans la table.
    await db.query(`select signal_member($1, 'visit')`, [G.m]);
    const autres = await db.query(`select count(*)::int as n from member_signals where user_id <> $1`, [G.w]);
    assert(autres.rows[0].n > 0, 'test sans signaux d’autres membres');
    const r = await as(G.w, `select user_id from member_signals`);
    assert(r.rows.length > 0, 'aucun de ses propres signaux visible');
    assert(r.rows.every((x) => x.user_id === G.w), 'signaux d’autrui visibles');
    const a = await as(null, `select count(*)::int as n from member_signals`).catch(() => ({ rows: [{ n: 0 }] }));
    assert(a.rows[0].n === 0, 'visible sans connexion');
    await fails(as(G.m, `insert into member_signals (user_id, kind) values ($1, 'like')`, [G.m]), /row-level security|permission denied/i);
    await fails(as(G.m, `select signal_member($1, 'like')`, [G.w]), /permission denied/i);
  });

  await test('les signaux de plus d’un jour sont effacés au fil de l’eau', async () => {
    await vider();
    await db.query(`insert into member_signals (user_id, kind, created_at) values ($1, 'visit', now() - interval '2 days')`, [G.x]);
    await db.query(`select signal_member($1, 'profile')`, [G.x]);
    assert((await signaux(G.x)).join() === 'profile', `restant : ${await signaux(G.x)}`);
  });
}
