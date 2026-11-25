// Tests ZAYA 2.0 — Lot 1 (migration 0068) : Match du jour, Pulse, Invitation.

export async function lot1Tests({ db, test, assert, as, rpc, fails, U, seedMember }) {
  console.log('\nZAYA 2.0 — Lot 1 : Match du jour, Pulse, Invitation (0068)');
  const id = (n) => `00000000-0000-0000-0000-00000068${String(n).padStart(4, '0')}`;
  const W = id(1);   // membre qui reçoit
  const C1 = id(2), C2 = id(3), BLOQ = id(4), NONV = id(5);
  await seedMember(W, 'Mariama', 'femme', '1996-06-06', null);
  for (const [c, nom] of [[C1, 'Alpha'], [C2, 'Boubacar'], [BLOQ, 'Cellou'], [NONV, 'Demba']]) {
    await seedMember(c, nom, 'homme', '1991-01-01', null);
  }
  await db.query(`update profiles set verification_status = 'not_requested' where id = $1`, [NONV]);
  await db.query(`insert into blocks (blocker, blocked) values ($1, $2)`, [W, BLOQ]);

  await test('Match du jour : un candidat éligible, le même toute la journée, jamais bloqué ni non vérifié', async () => {
    const r1 = await rpc(W, 'my_daily_match');
    assert(r1.status === 'ready', JSON.stringify(r1));
    const choisi = r1.profile.id;
    assert(choisi !== BLOQ && choisi !== NONV);
    const r2 = await rpc(W, 'my_daily_match');
    assert(r2.profile.id === choisi, 'même suggestion toute la journée');
    assert((await db.query(`select count(*)::int n from daily_matches where user_id = $1`, [W])).rows[0].n === 1);
    await fails(as(W, `select * from daily_matches`), /permission denied/);
  });

  await test('Match du jour : traité après un like, retiré si le profil devient inéligible, coupé par l’interrupteur', async () => {
    const choisi = (await rpc(W, 'my_daily_match')).profile.id;
    await db.query(`update profiles set verification_status = 'not_requested' where id = $1`, [choisi]);
    assert((await rpc(W, 'my_daily_match')).status === 'none', 'profil devenu non vérifié : jamais présenté');
    await db.query(`update profiles set verification_status = 'approved' where id = $1`, [choisi]);
    await rpc(W, 'send_like', [choisi]);
    assert((await rpc(W, 'my_daily_match')).status === 'done');
    await db.query(`update app_config set value = 'false' where key = 'feature_match_of_day_enabled'`);
    assert((await rpc(W, 'my_daily_match')).status === 'disabled');
    await db.query(`update app_config set value = 'true' where key = 'feature_match_of_day_enabled'`);
  });

  await test('Pulse : désactivé par défaut ; un membre n’y apparaît qu’après son accord, jamais bloqué ni non vérifié', async () => {
    let feed = await rpc(W, 'pulse_feed');
    assert(feed.status === 'ready' && feed.opted_in === false && feed.items.length === 0, JSON.stringify(feed));
    for (const c of [C1, C2, BLOQ, NONV]) await rpc(c, 'set_pulse_optin', [true]);
    feed = await rpc(W, 'pulse_feed');
    const ids = feed.items.map((i) => i.user_id);
    assert(ids.includes(C1) && ids.includes(C2), JSON.stringify(ids));
    assert(!ids.includes(BLOQ), 'bloqué absent');
    assert(!ids.includes(NONV), 'non vérifié absent');
    await rpc(C1, 'set_pulse_optin', [false]);
    assert(!(await rpc(W, 'pulse_feed')).items.some((i) => i.user_id === C1), 'retrait immédiat');
    assert(!(await rpc(W, 'pulse_feed')).items.some((i) => i.user_id === W), 'jamais soi-même');
    await db.query(`update app_config set value = 'false' where key = 'feature_pulse_enabled'`);
    await fails(rpc(C1, 'set_pulse_optin', [true]), /FEATURE_DISABLED/);
    assert((await rpc(W, 'pulse_feed')).status === 'disabled');
    await db.query(`update app_config set value = 'true' where key = 'feature_pulse_enabled'`);
  });

  await test('Pulse : statistiques réelles, seulement pour un groupe d’au moins N personnes', async () => {
    await db.query(`update app_config set value = '100000' where key = 'pulse_min_group'`);
    assert((await rpc(W, 'pulse_feed')).stats.length === 0, 'groupe trop petit : aucune statistique');
    await db.query(`update app_config set value = '2' where key = 'pulse_min_group'`);
    const stats = (await rpc(W, 'pulse_feed')).stats;
    assert(stats.length >= 1);
    const reel = (await db.query(
      `select count(*)::int n from profiles p join cities c on c.id = p.city_id
       where c.name = $1 and p.country_code = (select country_code from profiles where id = $2)
         and p.status = 'active' and p.account_type = 'candidate'`, [stats[0].city, W])).rows[0].n;
    assert(stats[0].members === reel, `statistique ${stats[0].members} ≠ réel ${reel}`);
    await db.query(`update app_config set value = '20' where key = 'pulse_min_group'`);
  });

  // ── Invitation
  const P = id(10), F = id(11), F2 = id(12), F3 = id(13), AUTRE = id(14);
  for (const [m, nom, sexe] of [[P, 'Parrain', 'homme'], [F, 'Filleul', 'femme'], [F2, 'Filleule2', 'femme'],
                                [F3, 'Filleule3', 'femme'], [AUTRE, 'Autre', 'femme']]) {
    await seedMember(m, nom, sexe, '1993-03-03', null);
  }
  const DEV_P = 'a'.repeat(32);

  await test('code d’invitation : 10 caractères aléatoires, stable, révocable, jamais deux codes actifs', async () => {
    const c1 = await rpc(P, 'my_referral_code');
    assert(/^[0-9A-F]{10}$/.test(c1), c1);
    assert((await rpc(P, 'my_referral_code')) === c1, 'même code tant qu’il n’est pas révoqué');
    const autre = await rpc(AUTRE, 'my_referral_code');
    assert(autre !== c1, 'codes distincts');
    await rpc(P, 'revoke_my_referral_code');
    await fails(rpc(F, 'redeem_referral', [c1]), /INVALID_CODE/);
    const c2 = await rpc(P, 'my_referral_code');
    assert(c2 !== c1);
    await fails(as(P, `select * from referral_codes`), /permission denied/);
  });

  await test('anti-fraude : auto-parrainage refusé, même appareil rejeté sans récompense, code inconnu refusé', async () => {
    const code = await rpc(P, 'my_referral_code');
    await fails(rpc(P, 'redeem_referral', [code]), /SELF_REFERRAL/);
    await fails(rpc(F, 'redeem_referral', ['ZZZZZZZZZZ']), /INVALID_CODE/);
    await rpc(P, 'register_device', [DEV_P]);
    await rpc(F2, 'register_device', [DEV_P]);
    const fraude = await rpc(F2, 'redeem_referral', [code]);
    assert(fraude.status === 'rejected', JSON.stringify(fraude));
    assert((await db.query(`select reject_reason from referrals where referee = $1`, [F2])).rows[0].reject_reason === 'same_device');
    await fails(rpc(F2, 'redeem_referral', [code]), /ALREADY_REFERRED/);
  });

  await test('récompense : seulement après 7 jours d’activité du filleul vérifié, une seule fois, jamais fixée par le client', async () => {
    const code = await rpc(P, 'my_referral_code');
    assert((await rpc(F, 'redeem_referral', [code])).status === 'pending');
    await db.query(`update app_config set value = '5' where key = 'referral_reward_swipes'`);
    let s = await rpc(P, 'my_referral_summary');
    assert(s.pending === 1 && s.rewarded === 0, 'trop tôt : aucune récompense');
    await db.query(`update profiles set created_at = now() - interval '8 days', last_active_at = now() where id in ($1, $2)`, [F, P]);
    s = await rpc(P, 'my_referral_summary');
    assert(s.rewarded === 1 && s.pending === 0, JSON.stringify(s));
    await rpc(P, 'my_referral_summary');
    await rpc(P, 'my_referral_summary');
    const n = (await db.query(`select count(*)::int n, sum(amount)::int total from reward_ledger where user_id = $1 and source = 'referral'`, [P])).rows[0];
    assert(n.n === 1 && n.total === 5, JSON.stringify(n));
    assert((await db.query(`select count(*)::int n from swipe_credits where user_id = $1 and source = 'zaya2_referral'`, [P])).rows[0].n === 1);
    await fails(rpc(P, 'settle_referrals', [P]), /permission denied/);
  });

  await test('filleul non vérifié : rien ; filleul banni après récompense : annulation et ligne négative', async () => {
    const code = await rpc(P, 'my_referral_code');
    assert((await rpc(F3, 'redeem_referral', [code])).status === 'pending');
    await db.query(`update profiles set created_at = now() - interval '8 days', last_active_at = now(), verification_status = 'not_requested' where id = $1`, [F3]);
    assert((await rpc(P, 'my_referral_summary')).pending === 1, 'non vérifié : reste en attente');
    await db.query(`update profiles set verification_status = 'approved' where id = $1`, [F3]);
    assert((await rpc(P, 'my_referral_summary')).rewarded === 2);
    await db.query(`update profiles set status = 'banned' where id = $1`, [F3]);
    const s = await rpc(P, 'my_referral_summary');
    assert(s.rewarded === 1, JSON.stringify(s));
    const total = (await db.query(`select sum(amount)::int t from reward_ledger where user_id = $1 and source in ('referral', 'reversal')`, [P])).rows[0].t;
    assert(total === 5, `solde du registre ${total}`);
    assert((await rpc(P, 'my_wallet')).bonus.swipes === 5, 'le portefeuille du parrain reflète l’annulation');
  });

  await test('plafond mensuel : au-delà, revue manuelle au lieu de la récompense', async () => {
    await db.query(`update app_config set value = '1' where key = 'referral_monthly_cap'`);
    const X = id(20);
    await seedMember(X, 'Xenia', 'femme', '1994-04-04', null);
    const code = await rpc(P, 'my_referral_code');
    await rpc(X, 'redeem_referral', [code]);
    await db.query(`update profiles set created_at = now() - interval '8 days', last_active_at = now() where id = $1`, [X]);
    await rpc(P, 'my_referral_summary');
    assert((await db.query(`select status from referrals where referee = $1`, [X])).rows[0].status === 'review');
    await db.query(`update app_config set value = '10' where key = 'referral_monthly_cap'`);
    await db.query(`update app_config set value = '0' where key = 'referral_reward_swipes'`);
  });
}
