// Tests ZAYA — durcissement de la sécurité (0050) ; messagerie : liens interdits et limite de fréquence (0051).
// Membres dédiés, pour ne pas dépendre de l'état laissé par les autres sections.

export async function securiteTests({ db, test, assert, as, rpc, fails, seedMember }) {
  console.log('\nSécurité : liens interdits et limite de fréquence dans la messagerie (0050, 0051)');
  const S = {
    w: '00000000-0000-0000-0000-0000000051a1',
    m: '00000000-0000-0000-0000-0000000051a2',
  };
  await seedMember(S.w, 'Hawa', 'femme', '1995-08-08', null);
  await seedMember(S.m, 'Lamine', 'homme', '1990-09-09', null);
  const r = await db.query(
    `insert into matches (user_a, user_b) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid)) returning id`,
    [S.w, S.m],
  );
  const M = r.rows[0].id;
  const lien = async (texte) => (await db.query(`select contains_link($1) as l`, [texte])).rows[0].l;
  const cfg = (k, v) => db.query(`update app_config set value = $2 where key = $1`, [k, v]);

  await test('liens détectés : protocole, www, domaines, raccourcisseurs, chemins, écritures détournées', async () => {
    for (const t of [
      'Regarde https://exemple.org/page', 'http://192.168.1.10:8080', 'Va sur www.monsite.gn',
      'Clique sur WWW . arnaque . com', 'mon-site.com', 'Profil sur facebook.com/awa.diallo',
      'bit.ly/3xYz', 'Écris-moi sur wa.me/224620000000', 'zaya.app', 'boutique.shop', 'intent://scan',
      'monsite.gn/inscription', 'site . com', 'arnaque point com', 'cadeau.online',
    ]) assert(await lien(t), `non détecté : ${t}`);
  });

  await test('phrases ordinaires acceptées : fins de phrase, e-mails, abréviations, nombres', async () => {
    for (const t of [
      'Bonjour, comment vas-tu ?', 'C’est bon. Top !', 'Merci. Info du jour : il pleut.', 'ok.Ma sœur arrive',
      'Bien.Me voilà', 'M.Diallo et Dr.Bah', 'Mon e-mail : awa.diallo@gmail.com', 'Il coûte 2.500.000 GNF',
      'Rendez-vous à 14h.30', 'etc. Comment allez-vous ?', 'Je suis à Conakry. Comment ça va ?',
    ]) assert(!(await lien(t)), `faux positif : ${t}`);
  });

  await test('message avec un lien : ni stocké ni transmis, tentative comptée (catégorie link)', async () => {
    const avant = (await db.query(`select count(*)::int as n from messages where match_id = $1`, [M])).rows[0].n;
    const res = await rpc(S.w, 'send_message', [M, 'Mon profil : www.exemple.com']);
    assert(res.status === 'blocked' && res.category === 'link', JSON.stringify(res));
    const apres = (await db.query(`select count(*)::int as n from messages where match_id = $1`, [M])).rows[0].n;
    assert(apres === avant, 'le message bloqué a été stocké');
    const v = await db.query(`select count(*)::int as n from message_violations where user_id = $1 and category = 'link'`, [S.w]);
    assert(v.rows[0].n === 1, `violations : ${v.rows[0].n}`);
    assert((await rpc(S.w, 'send_message', [M, 'Bonjour Lamine'])).status === 'sent');
  });

  await test('un lien ne peut pas entrer par la modification d’un message', async () => {
    const id = (await rpc(S.m, 'send_message', [M, 'Bonjour Hawa'])).id;
    const res = await rpc(S.m, 'edit_message', [id, 'Bonjour, va sur bit.ly/abc']);
    assert(res.status === 'blocked' && res.category === 'link', JSON.stringify(res));
    const b = await db.query(`select body from messages where id = $1`, [id]);
    assert(b.rows[0].body === 'Bonjour Hawa', `texte modifié : ${b.rows[0].body}`);
    assert((await rpc(S.m, 'edit_message', [id, 'Bonjour Hawa, bonne journée'])).status === 'edited');
  });

  await test('limite de fréquence : au-delà du réglage par minute, refus MESSAGE_RATE_LIMITED', async () => {
    await cfg('message_rate_per_minute', '4');
    try {
      await db.query(`delete from messages where sender_id = $1`, [S.w]);
      for (let i = 0; i < 4; i++) assert((await rpc(S.w, 'send_message', [M, `Message ${i}`])).status === 'sent');
      await fails(rpc(S.w, 'send_message', [M, 'Message de trop']), /MESSAGE_RATE_LIMITED/);
      // L'autre membre n'est pas concerné par la limite de Hawa.
      assert((await rpc(S.m, 'send_message', [M, 'Je réponds'])).status === 'sent');
    } finally {
      await cfg('message_rate_per_minute', '20');
    }
  });

  await test('fonctions internes non exécutables par un membre ni par anon', async () => {
    await fails(as(S.w, `select contains_link('x')`), /permission denied/i);
    await fails(as(null, `select contains_link('x')`), /permission denied/i);
    const g = await db.query(
      `select has_function_privilege('anon', 'guard_advanced_filters()', 'execute') as a,
              has_function_privilege('authenticated', 'guard_advanced_filters()', 'execute') as m`,
    );
    assert(!g.rows[0].a && !g.rows[0].m, JSON.stringify(g.rows[0]));
  });
}
