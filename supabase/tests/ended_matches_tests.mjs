// Tests de la migration 0010 : liste des matchs terminés.
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function}} t */
export async function endedMatchesTests({ db, test, assert, as, rpc, fails }) {
  console.log('\nMatchs terminés (0010)');

  const E = {
    nadia: '00000000-0000-0000-0000-0000000000f1',
    karim: '00000000-0000-0000-0000-0000000000f2',
    tiers: '00000000-0000-0000-0000-0000000000f3',
    sira: '00000000-0000-0000-0000-0000000000f4',
    ferme: '00000000-0000-0000-0000-0000000000f5',
  };
  const member = async (id, name, gender) => {
    await db.query(`insert into auth.users (id, phone, phone_confirmed_at) values ($1, $2, now())`, [id, `22460${id.slice(-6)}`]);
    await db.query(
      `insert into profiles (id, display_name, birth_date, gender, seeking_gender, country_code, city_id, status,
                             is_phone_verified, verification_status)
       values ($1, $2, '1994-04-04', $3, $4, 'GN', (select id from cities limit 1), 'active', true, 'approved')`,
      [id, name, gender, gender === 'homme' ? 'femme' : 'homme'],
    );
  };
  const match = async (a, b) => (await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid)) returning id`,
    [a, b])).rows[0].id;
  const ended = async (who) => (await rpc(who, 'my_ended_matches_json')).rows;

  await member(E.nadia, 'Nadia', 'femme');
  await member(E.karim, 'Karim', 'homme');
  await member(E.tiers, 'Tiers', 'homme');
  await member(E.sira, 'Sira', 'femme');
  await member(E.ferme, 'Compte fermé', 'homme');
  // Lecture pratique pour les tests : la fonction renvoie une table.
  await db.exec(`create function my_ended_matches_json() returns jsonb language sql as $$
    select jsonb_build_object('rows', coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)) from my_ended_matches() e $$;
    grant execute on function my_ended_matches_json() to authenticated;`);

  await test('après un dématch : listé des deux côtés, plus dans les conversations, plus d’envoi, historique lisible',
    async () => {
      const id = await match(E.nadia, E.karim);
      await db.query(`insert into messages (match_id, sender_id, body) values ($1, $2, 'Bonjour Karim')`, [id, E.nadia]);
      await as(E.karim, `select unmatch($1)`, [id]);

      const forNadia = await ended(E.nadia);
      const forKarim = await ended(E.karim);
      assert(forNadia.length === 1 && forNadia[0].display_name === 'Karim' && forNadia[0].ended_by_me === false,
        JSON.stringify(forNadia));
      assert(forKarim.length === 1 && forKarim[0].display_name === 'Nadia' && forKarim[0].ended_by_me === true,
        JSON.stringify(forKarim));
      assert((await ended(E.tiers)).length === 0, 'un tiers ne voit rien');

      const active = await as(E.nadia, `select match_id from my_matches() where match_id = $1`, [id]);
      assert(active.rows.length === 0, 'le match ne doit plus être dans les conversations');
      await fails(rpc(E.nadia, 'send_message', [id, 'Tu es encore là ?']), /MATCH_ENDED/);
      const history = await as(E.nadia, `select body from messages where match_id = $1`, [id]);
      assert(history.rows.length === 1, 'l’historique reste lisible');
      await rpc(E.nadia, 'report_user', [E.karim, 'conversation', 'harassment', null, id]);
    });

  await test('un blocage retire le match terminé de la liste, des deux côtés', async () => {
    await rpc(E.nadia, 'block_user', [E.karim]);
    assert((await ended(E.nadia)).length === 0 && (await ended(E.karim)).length === 0, 'aucune trace après blocage');
  });

  await test('compte fermé : le nom est masqué ; anon ne peut pas appeler la fonction', async () => {
    const id = await match(E.sira, E.ferme);
    await as(E.ferme, `select unmatch($1)`, [id]);
    await db.query(`update profiles set status = 'banned' where id = $1`, [E.ferme]);
    const rows = await ended(E.sira);
    assert(rows.length === 1 && rows[0].display_name === null && rows[0].account_closed === true, JSON.stringify(rows));
    await fails(as(null, `select * from my_ended_matches()`), /permission denied/i);
  });
}
