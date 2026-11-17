// Tests de la migration 0008 : assistance dans l'application et langues actives.
// Appelé par run.mjs avec ses outils (base PGlite déjà migrée et peuplée, membres fictifs U).

/** @param {{db: any, test: Function, assert: Function, as: Function, rpc: Function, fails: Function, U: Record<string, string>}} t */
export async function assistanceTests({ db, test, assert, as, rpc, fails, U }) {
  console.log('\nAssistance et langues (0008)');

  await test('une demande à l’assistance : lue par son auteur et par l’équipe seulement ; aucune écriture directe',
    async () => {
      const id = await rpc(U.aicha, 'create_support_ticket', ['account', 'Je n’arrive pas à modifier mon prénom.', 'fr']);
      const own = await as(U.aicha, `select id, status::text as status, priority, app_language from support_tickets`);
      assert(own.rows.length === 1 && own.rows[0].id === id, JSON.stringify(own.rows));
      assert(own.rows[0].status === 'open' && own.rows[0].priority === 2 && own.rows[0].app_language === 'fr');
      const other = await as(U.moussa, `select id from support_tickets where id = $1`, [id]);
      assert(other.rows.length === 0, 'un autre membre ne doit pas lire la demande');
      const staff = await as(U.modo, `select id from support_tickets where id = $1`, [id]);
      assert(staff.rows.length === 1, 'l’équipe lit la demande');
      await fails(as(U.aicha, `insert into support_tickets (user_id, category, message) values ($1, 'other', 'Écriture directe interdite')`,
        [U.aicha]), /permission denied/i);
      await fails(as(U.aicha, `update support_tickets set status = 'closed' where id = $1`, [id]), /permission denied/i);
      await fails(as(null, `select create_support_ticket('other', 'Un visiteur non connecté', null)`), /permission denied/i);
    });

  await test('sécurité en priorité ; sujet inconnu et message trop court refusés ; limite par 24 h', async () => {
    const id = await rpc(U.moussa, 'create_support_ticket', ['safety', 'On me menace de publier mes photos.', null]);
    const r = await db.query(`select priority from support_tickets where id = $1`, [id]);
    assert(r.rows[0].priority === 1, 'un problème de sécurité doit être prioritaire');
    await fails(rpc(U.moussa, 'create_support_ticket', ['inconnu', 'Sujet qui n’existe pas du tout', null]),
      /INVALID_CATEGORY/);
    await fails(rpc(U.moussa, 'create_support_ticket', ['other', '  court  ', null]), /MESSAGE_TOO_SHORT/);

    await db.query(`update app_config set value = '3' where key = 'support_tickets_per_day'`);
    for (let i = 0; i < 3; i++) await rpc(U.fatou, 'create_support_ticket', ['bug', `Problème technique numéro ${i}`, null]);
    await fails(rpc(U.fatou, 'create_support_ticket', ['bug', 'Une demande de trop aujourd’hui', null]),
      /SUPPORT_RATE_LIMITED/);
    await db.query(`update app_config set value = '5' where key = 'support_tickets_per_day'`);
  });

  await test('réponse de l’équipe réservée au staff et tracée ; l’export contient mes demandes', async () => {
    const id = await rpc(U.paul, 'create_support_ticket', ['verification', 'Ma vérification est en attente depuis longtemps.', 'fr']);
    await fails(as(U.paul, `select admin_answer_support_ticket($1, 'Je me réponds', 'answered')`, [id]), /FORBIDDEN/);
    await fails(as(U.modo, `select admin_answer_support_ticket($1, '', 'answered')`, [id]), /REPLY_REQUIRED/);
    await as(U.modo, `select admin_answer_support_ticket($1, 'Votre demande a été traitée.', 'answered')`, [id]);
    const seen = await as(U.paul, `select status::text as status, reply from support_tickets where id = $1`, [id]);
    assert(seen.rows[0].status === 'answered' && seen.rows[0].reply === 'Votre demande a été traitée.',
      JSON.stringify(seen.rows));
    const audit = await db.query(
      `select count(*)::int as n from audit_log where action = 'support.answered' and actor = $1 and entity_id = $2`,
      [U.modo, id]);
    assert(audit.rows[0].n === 1, 'la réponse doit être tracée');

    const data = await rpc(U.paul, 'export_my_data');
    assert(Array.isArray(data.support_requests) && data.support_requests.length === 1, JSON.stringify(data.support_requests));
    assert(data.profile && Array.isArray(data.community_posts), 'le reste de l’export doit être conservé');
    await fails(as(U.paul, `select export_my_data_base()`), /permission denied/i);
  });

  await test('langues actives : réglage public, français et anglais au départ', async () => {
    const r = await as(null, `select value from app_config where key = 'active_languages'`);
    assert(r.rows.length === 1 && JSON.stringify(r.rows[0].value) === '["fr","en"]', JSON.stringify(r.rows));
  });

  await test('délai avant renvoi du code (0011) : réglage public, 60 secondes au départ', async () => {
    const r = await as(null, `select value from app_config where key = 'otp_resend_seconds'`);
    assert(r.rows.length === 1 && r.rows[0].value === 60, JSON.stringify(r.rows));
  });
}
