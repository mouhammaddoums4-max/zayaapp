// Tests ZAYA (migration 0071) : connexion par numéro + code à 4 chiffres, blocage, réinitialisation après SMS.

export async function codeConnexionTests({ db, test, assert, as, rpc, fails, seedMember }) {
  console.log('\nConnexion par code à 4 chiffres (0071)');
  await db.query(`insert into vault.decrypted_secrets (name, decrypted_secret) values ('zaya_pin_pepper', 'poivre-de-test-0123456789')`);
  await test('désactivée par défaut tant que la fonction pin-login n’est pas déployée', async () => {
    assert((await rpc(null, 'pin_phone_status', ['627843030'])) === 'disabled');
  });
  await db.query(`update app_config set value = 'true' where key = 'pin_login_enabled'`);
  const id = (n) => `00000000-0000-0000-0000-00000071${String(n).padStart(4, '0')}`;
  const A = id(1), B = id(2), C = id(3);
  await seedMember(A, 'Aissata', 'femme', '1995-01-01', null);
  await seedMember(B, 'Boubacar', 'homme', '1990-01-01', null);
  await seedMember(C, 'Camara', 'homme', '1991-01-01', null);
  // Forme stockée par Supabase Auth : chiffres seuls, indicatif compris.
  await db.query(`update auth.users set phone = '224627843030' where id = $1`, [A]);
  await db.query(`update auth.users set phone = '224655510002' where id = $1`, [B]);
  await db.query(`update auth.users set phone = '224655510003' where id = $1`, [C]);
  const check = async (phone, pin, ip = '10.0.0.1') =>
    (await db.query(`select pin_login_check($1, $2, $3) as r`, [phone, pin, ip])).rows[0].r;
  /** Appel en tant que membre avec des revendications de jeton (méthode de connexion « amr »). */
  const asClaims = (userId, claims, sql, params = []) => db.transaction(async (tx) => {
    await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [userId]);
    await tx.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: userId, ...claims })]);
    await tx.exec(`set local role authenticated`);
    return tx.query(sql, params);
  });

  await test('état d’un numéro : nouveau, compte sans code, compte avec code ; formats acceptés ; appelable sans compte', async () => {
    assert((await rpc(null, 'pin_phone_status', ['+224 699 99 99 99'])) === 'new');
    assert((await rpc(null, 'pin_phone_status', ['627 84 30 30'])) === 'no_pin');
    await db.query(`select admin_set_member_pin($1, '6236')`, [A]);
    for (const forme of ['627843030', '+224627843030', '00224 627 84 30 30', '224627843030']) {
      assert((await rpc(null, 'pin_phone_status', [forme])) === 'pin', forme);
    }
    await fails(rpc(null, 'pin_phone_status', ['12']), /INVALID_PHONE/);
  });

  await test('code imposé (6236) : connexion acceptée, changement obligatoire signalé ; mauvais code refusé', async () => {
    const ok = await check('627843030', '6236');
    assert(ok.status === 'ok' && ok.user_id === A && ok.must_change === true && ok.phone === '224627843030', JSON.stringify(ok));
    const ko = await check('627843030', '0000');
    assert(ko.status === 'wrong' && ko.remaining === 4, JSON.stringify(ko));
    assert((await check('699999999', '6236')).status === 'unknown');
    assert((await check('655510003', '1234')).status === 'no_pin');
  });

  await test('blocage : 5 erreurs bloquent le compte 15 min, même avec le bon code ; libéré ensuite', async () => {
    await db.query(`select admin_set_member_pin($1, '4826')`, [B]);
    for (let i = 0; i < 4; i++) { const w = await check('655510002', '1111', '10.0.0.2'); assert(w.status === 'wrong', 'essai ' + i + ' : ' + JSON.stringify(w)); }
    const bloque = await check('655510002', '1111', '10.0.0.2');
    assert(bloque.status === 'locked', JSON.stringify(bloque));
    assert((await check('655510002', '4826', '10.0.0.2')).status === 'locked', 'bloqué même avec le bon code');
    await db.query(`update private.member_pins set locked_until = now() - interval '1 second' where user_id = $1`, [B]);
    { const o = await check('655510002', '4826', '10.0.0.2'); assert(o.status === 'ok', 'après déblocage : ' + JSON.stringify(o)); }
  });

  await test('limite par adresse IP : au-delà du réglage, refus quel que soit le compte', async () => {
    await db.query(`update app_config set value = '3' where key = 'pin_attempts_per_ip'`);
    try {
      for (let i = 0; i < 3; i++) await check('655510002', '9999', '10.9.9.9');
      assert((await check('655510002', '4826', '10.9.9.9')).status === 'rate_limited');
      { const o = await check('655510002', '4826', '10.0.0.7'); assert(o.status === 'ok', 'autre adresse : ' + JSON.stringify(o)); }
    } finally {
      await db.query(`update app_config set value = '30' where key = 'pin_attempts_per_ip'`);
    }
  });

  await test('codes illisibles et fonctions de service interdites aux membres et aux visiteurs', async () => {
    await fails(as(A, `select * from private.member_pins`), /permission denied/);
    await fails(as(null, `select * from private.member_pins`), /permission denied/);
    await fails(rpc(A, 'pin_login_check', ['627843030', '6236', 'x']), /permission denied/);
    await fails(rpc(A, 'admin_set_member_pin', [A, '0000']), /permission denied/);
    const etat = await rpc(A, 'my_pin_status');
    assert(etat.has_pin === true && etat.must_change === true, JSON.stringify(etat));
  });

  await test('premier code : une seule fois ; trop facile ou mal formé refusé', async () => {
    await fails(rpc(C, 'set_my_pin', ['1111']), /PIN_TOO_WEAK/);
    await fails(rpc(C, 'set_my_pin', ['1234']), /PIN_TOO_WEAK/);
    await fails(rpc(C, 'set_my_pin', ['12a4']), /PIN_FORMAT/);
    await rpc(C, 'set_my_pin', ['7391']);
    await fails(rpc(C, 'set_my_pin', ['5820']), /PIN_ALREADY_SET/);
    { const o = await check('655510003', '7391'); assert(o.status === 'ok', 'premier code : ' + JSON.stringify(o)); }
  });

  await test('changement : ancien code exigé ; le nouveau remplace le code imposé et lève l’obligation', async () => {
    await fails(rpc(A, 'change_my_pin', ['0000', '5917']), /PIN_WRONG/);
    await fails(rpc(A, 'change_my_pin', ['6236', '6236']), /PIN_TOO_WEAK/);
    await rpc(A, 'change_my_pin', ['6236', '5917']);
    assert((await check('627843030', '6236')).status === 'wrong', 'l’ancien code ne marche plus');
    const ok = await check('627843030', '5917');
    assert(ok.status === 'ok' && ok.must_change === false, JSON.stringify(ok));
  });

  await test('code oublié : réinitialisation seulement après un SMS vérifié depuis moins de 5 minutes', async () => {
    const now = Math.floor(Date.now() / 1000);
    await fails(rpc(C, 'reset_my_pin', ['2468']), /OTP_REQUIRED/);
    await fails(asClaims(C, { amr: [{ method: 'password', timestamp: now }] }, `select reset_my_pin('2468')`), /OTP_REQUIRED/);
    await fails(asClaims(C, { amr: [{ method: 'otp', timestamp: now - 600 }] }, `select reset_my_pin('2468')`), /OTP_REQUIRED/);
    await asClaims(C, { amr: [{ method: 'otp', timestamp: now - 30 }] }, `select reset_my_pin('2468')`);
    { const o = await check('655510003', '2468'); assert(o.status === 'ok', 'après réinitialisation : ' + JSON.stringify(o)); }
    assert((await check('655510003', '7391')).status === 'wrong');
  });

  await test('interrupteur : connexion par code coupable sans nouvelle version de l’application', async () => {
    await db.query(`update app_config set value = 'false' where key = 'pin_login_enabled'`);
    try {
      assert((await rpc(null, 'pin_phone_status', ['627843030'])) === 'disabled');
      assert((await check('627843030', '5917')).status === 'disabled');
    } finally {
      await db.query(`update app_config set value = 'true' where key = 'pin_login_enabled'`);
    }
  });
}
