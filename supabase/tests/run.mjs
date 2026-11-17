// Tests ZAYA : applique les migrations + le seed dans PGlite puis vérifie RLS et règles métier.
// Usage : npm install && npm test
import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const db = new PGlite();

// Émulation minimale de l'environnement Supabase (rôles, auth.uid(), storage)
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key, phone text, phone_confirmed_at timestamptz);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated;
  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean);
  create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable as $$
    select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
`);

const migrationsDir = join(here, '..', 'migrations');
for (const f of readdirSync(migrationsDir).sort()) {
  await db.exec(readFileSync(join(migrationsDir, f), 'utf8'));
  console.log(`migration appliquée : ${f}`);
}
await db.exec(readFileSync(join(here, '..', 'seed', 'seed.sql'), 'utf8'));
console.log('seed appliqué\n');

// ───────────── Outils
let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failed++;
    console.log(`  ✗ ${name}\n      ${e.message}`);
  }
}
function assert(cond, msg) {
  if (!cond) throw new Error(msg || 'assertion échouée');
}
/** Exécute une requête en tant que membre connecté (rôle authenticated + auth.uid()). */
async function as(userId, sql, params = []) {
  return db.transaction(async (tx) => {
    await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [userId ?? '']);
    await tx.exec(`set local role ${userId ? 'authenticated' : 'anon'}`);
    return tx.query(sql, params);
  });
}
async function rpc(userId, fn, args = []) {
  const ph = args.map((_, i) => `$${i + 1}`).join(', ');
  const r = await as(userId, `select ${fn}(${ph}) as r`, args);
  return r.rows[0].r;
}
async function fails(promise, pattern) {
  try {
    await promise;
  } catch (e) {
    assert(!pattern || pattern.test(e.message), `erreur inattendue : ${e.message}`);
    return;
  }
  throw new Error(`aurait dû échouer (${pattern})`);
}

const U = {
  aicha: '00000000-0000-0000-0000-00000000000a',
  moussa: '00000000-0000-0000-0000-00000000000b',
  fatou: '00000000-0000-0000-0000-00000000000c',
  paul: '00000000-0000-0000-0000-00000000000d',
  admin: '00000000-0000-0000-0000-0000000000ad',
  modo: '00000000-0000-0000-0000-0000000000a0',
};

/** Crée un membre complet, vérifié, avec 3 photos approuvées (données fictives). */
async function seedMember(id, name, gender, birth, confession) {
  const seeking = gender === 'femme' ? 'homme' : 'femme';
  await db.query(`insert into auth.users (id, phone, phone_confirmed_at) values ($1, $2, now())`, [id, '+2246' + id.slice(-8)]);
  await db.query(
    `insert into profiles (id, display_name, birth_date, gender, seeking_gender, country_code, city_id, status,
                           is_phone_verified, verification_status)
     values ($1, $2, $3, $4, $5, 'GN', (select id from cities limit 1), 'active', true, 'approved')`,
    [id, name, birth, gender, seeking],
  );
  await db.query(`insert into discovery_preferences (user_id) values ($1)`, [id]);
  if (confession) await db.query(`insert into profile_sensitive (user_id, confession) values ($1, $2)`, [id, confession]);
  for (let i = 0; i < 3; i++) {
    await db.query(
      `insert into profile_photos (user_id, storage_path, position, moderation) values ($1, $2, $3, 'approved')`,
      [id, `${id}/p${i}.jpg`, i],
    );
  }
}

await seedMember(U.aicha, 'Aïcha', 'femme', '1998-03-10', 'muslim');
await seedMember(U.moussa, 'Moussa', 'homme', '1994-07-22', 'muslim');
await seedMember(U.fatou, 'Fatou', 'femme', '1996-01-05', null);
await seedMember(U.paul, 'Paul', 'homme', '1992-11-30', 'christian');
for (const id of [U.admin, U.modo]) await db.query(`insert into auth.users (id) values ($1)`, [id]);
await db.query(`insert into staff_roles (user_id, role) values ($1, 'super_admin'), ($2, 'moderator')`, [U.admin, U.modo]);

// ───────────── Tests
console.log('Accès et confidentialité (RLS)');
await test("anon ne lit aucun profil", async () => {
  const r = await as(null, `select count(*)::int as n from profiles`).catch(() => ({ rows: [{ n: 0 }] }));
  assert(r.rows[0].n === 0, `anon voit ${r.rows[0].n} profils`);
});
await test("anon lit les pays (référentiel public)", async () => {
  const r = await as(null, `select count(*)::int as n from countries`);
  assert(r.rows[0].n > 0);
});
await test("un membre ne lit directement que son propre profil", async () => {
  const r = await as(U.aicha, `select id from profiles`);
  assert(r.rows.length === 1 && r.rows[0].id === U.aicha, `lignes visibles : ${r.rows.length}`);
});
await test("un membre ne lit pas la confession d'un autre membre", async () => {
  const r = await as(U.aicha, `select user_id from profile_sensitive`);
  assert(r.rows.length === 1 && r.rows[0].user_id === U.aicha);
});
await test("un membre ne peut pas s'auto-vérifier ni changer son type de compte", async () => {
  await db.query(`update profiles set verification_status = 'not_requested' where id = $1`, [U.paul]);
  await as(U.paul, `update profiles set verification_status = 'approved', account_type = 'counselor' where id = $1`, [U.paul]);
  const r = await db.query(`select verification_status, account_type from profiles where id = $1`, [U.paul]);
  assert(r.rows[0].verification_status === 'not_requested' && r.rows[0].account_type === 'candidate', JSON.stringify(r.rows[0]));
  await db.query(`update profiles set verification_status = 'approved' where id = $1`, [U.paul]);
});
await test("un membre ne peut pas modifier le profil d'un autre", async () => {
  await as(U.aicha, `update profiles set bio = 'piraté' where id = $1`, [U.moussa]);
  const r = await db.query(`select bio from profiles where id = $1`, [U.moussa]);
  assert(r.rows[0].bio === null);
});
await test("inscription refusée aux moins de 18 ans", async () => {
  const id = '00000000-0000-0000-0000-0000000000ee';
  await db.query(`insert into auth.users (id) values ($1)`, [id]);
  await fails(as(id, `insert into profiles (id, display_name, birth_date) values ($1, 'Mineur', current_date - 6000)`, [id]), /AGE_MINIMUM_18/);
});
await test("un membre peut mettre son profil en pause mais pas lever une suspension", async () => {
  await as(U.fatou, `update profiles set status = 'paused' where id = $1`, [U.fatou]);
  await as(U.fatou, `update profiles set status = 'active' where id = $1`, [U.fatou]);
  await db.query(`update profiles set status = 'suspended' where id = $1`, [U.fatou]);
  await fails(as(U.fatou, `update profiles set status = 'active' where id = $1`, [U.fatou]), /STATUS_CHANGE_NOT_ALLOWED/);
  await db.query(`update profiles set status = 'active' where id = $1`, [U.fatou]);
});
await test("un membre ne peut pas approuver ses propres photos", async () => {
  await as(U.paul, `insert into profile_photos (user_id, storage_path, position, moderation) values ($1, 'x/p9.jpg', 9, 'approved')`, [U.paul]);
  const r = await db.query(`select moderation from profile_photos where storage_path = 'x/p9.jpg'`);
  assert(r.rows[0].moderation === 'pending');
});

console.log('\nDécouverte (filtres réciproques)');
const feed = async (u) => (await as(u, `select * from discovery_feed(20)`)).rows;
await test("Aïcha voit les hommes éligibles, jamais elle-même ni les femmes", async () => {
  const names = (await feed(U.aicha)).map((r) => r.display_name).sort();
  assert(JSON.stringify(names) === JSON.stringify(['Moussa', 'Paul']), names.join(','));
});
await test("le fil n'expose ni date de naissance ni téléphone", async () => {
  const row = (await feed(U.aicha))[0];
  assert(!('birth_date' in row) && !('phone' in row) && typeof row.age === 'number');
});
await test("filtre « ma confession uniquement » : Paul (chrétien) est exclu, réciproquement aussi", async () => {
  await as(U.aicha, `update discovery_preferences set confession_mode = 'mine_only' where user_id = $1`, [U.aicha]);
  assert((await feed(U.aicha)).map((r) => r.display_name).join() === 'Moussa');
  assert(!(await feed(U.paul)).some((r) => r.display_name === 'Aïcha'), 'Paul voit encore Aïcha');
});
await test("un profil sans confession déclarée reste proposé (non classé arbitrairement)", async () => {
  await as(U.moussa, `update discovery_preferences set confession_mode = 'mine_only' where user_id = $1`, [U.moussa]);
  const names = (await feed(U.moussa)).map((r) => r.display_name).sort();
  assert(names.includes('Fatou') && names.includes('Aïcha'), names.join(','));
  await db.query(`update discovery_preferences set confession_mode = 'no_filter'`);
});
await test("préférence d'âge réciproque", async () => {
  await as(U.moussa, `update discovery_preferences set age_min = 35, age_max = 50 where user_id = $1`, [U.moussa]);
  assert(!(await feed(U.aicha)).some((r) => r.display_name === 'Moussa'));
  await db.query(`update discovery_preferences set age_min = 18, age_max = 60`);
});
await test("un profil non vérifié ou en pause n'apparaît pas", async () => {
  await db.query(`update profiles set verification_status = 'pending' where id = $1`, [U.paul]);
  assert(!(await feed(U.aicha)).some((r) => r.display_name === 'Paul'));
  await db.query(`update profiles set verification_status = 'approved', status = 'paused' where id = $1`, [U.paul]);
  assert(!(await feed(U.aicha)).some((r) => r.display_name === 'Paul'));
  await db.query(`update profiles set status = 'active' where id = $1`, [U.paul]);
});
await test("Gratuit et Premium se découvrent mutuellement", async () => {
  const g = await rpc(U.admin, 'admin_grant_premium', [U.paul, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
  const row = (await feed(U.aicha)).find((r) => r.display_name === 'Paul');
  assert(row && row.is_premium === true, 'Paul Premium invisible pour Aïcha (Gratuit)');
  assert((await feed(U.paul)).some((r) => r.display_name === 'Aïcha'), 'Aïcha (Gratuit) invisible pour Paul');
  await rpc(U.admin, 'admin_revoke_premium', [g, 'fin du test']);
});
await test("supprimer une photo sous le minimum retire le badge et sort le profil de la découverte", async () => {
  await as(U.paul, `delete from profile_photos where user_id = $1 and position = 0`, [U.paul]);
  const r = await db.query(`select verification_status from profiles where id = $1`, [U.paul]);
  assert(r.rows[0].verification_status === 'redo', r.rows[0].verification_status);
  assert(!(await feed(U.aicha)).some((x) => x.display_name === 'Paul'));
  await db.query(`insert into profile_photos (user_id, storage_path, position, moderation) values ($1, $2, 0, 'approved')`, [U.paul, `${U.paul}/p0b.jpg`]);
  await db.query(`update profiles set verification_status = 'approved' where id = $1`, [U.paul]);
});

console.log('\nLikes et matchs');
let matchId;
await test("un like unilatéral ne crée pas de match", async () => {
  const r = await rpc(U.aicha, 'send_like', [U.moussa]);
  assert(r.status === 'liked', JSON.stringify(r));
  const m = await db.query(`select count(*)::int as n from matches`);
  assert(m.rows[0].n === 0);
});
await test("insertion directe d'un match ou d'un like interdite (hors fonction)", async () => {
  await fails(as(U.aicha, `insert into matches (user_a, user_b) values ($1, $2)`, [U.aicha, U.paul]), /row-level security|permission/i);
  await fails(as(U.aicha, `insert into interests (from_user, to_user) values ($1, $2)`, [U.paul, U.aicha]), /row-level security|permission/i);
});
await test("Moussa ne voit pas qui l'a aimé sans Premium, mais voit le compteur", async () => {
  assert((await rpc(U.moussa, 'received_interests_count')) === 1);
  await fails(as(U.moussa, `select * from received_interests()`), /PREMIUM_REQUIRED/);
  const direct = await as(U.moussa, `select * from interests`);
  assert(direct.rows.length === 0, 'intérêts reçus lisibles directement');
});
await test("le like réciproque crée le match, révélé aux deux (Gratuit inclus)", async () => {
  const r = await rpc(U.moussa, 'send_like', [U.aicha]);
  assert(r.status === 'matched' && r.match_id, JSON.stringify(r));
  matchId = r.match_id;
  for (const u of [U.aicha, U.moussa]) {
    const m = await as(u, `select * from my_matches()`);
    assert(m.rows.length === 1, `match invisible pour ${u}`);
  }
});
await test("quota quotidien de likes appliqué côté serveur", async () => {
  await db.query(`update app_config set value = '1' where key = 'free_daily_likes'`);
  const r = await rpc(U.aicha, 'send_like', [U.paul]);
  assert(r.status === 'quota_reached' && r.resets_at, JSON.stringify(r));
  await db.query(`update app_config set value = '20' where key = 'free_daily_likes'`);
});

console.log('\nMessagerie');
let msgId;
await test("message entre matchs : envoyé et lisible par les deux seulement", async () => {
  const r = await rpc(U.aicha, 'send_message', [matchId, 'Bonjour Moussa, comment vas-tu ?']);
  assert(r.status === 'sent');
  msgId = r.id;
  assert((await as(U.moussa, `select * from messages`)).rows.length === 1);
  assert((await as(U.paul, `select * from messages`)).rows.length === 0, 'un tiers lit la conversation');
});
await test("un tiers ne peut pas écrire dans la conversation", async () => {
  await fails(rpc(U.paul, 'send_message', [matchId, 'coucou']), /MATCH_NOT_FOUND/);
  await fails(as(U.paul, `insert into messages (match_id, sender_id, body) values ($1, $2, 'x')`, [matchId, U.paul]), /row-level security|permission/i);
});
await test("message non conforme bloqué avant transmission et jamais stocké", async () => {
  const r = await rpc(U.moussa, 'send_message', [matchId, "Stp envoie-moi de l'argent par Orange Money"]);
  assert(r.status === 'blocked' && r.category === 'money_request', JSON.stringify(r));
  const n = await db.query(`select count(*)::int as n from messages`);
  assert(n.rows[0].n === 1, 'le message bloqué a été stocké');
  const v = await db.query(`select count(*)::int as n from message_violations where user_id = $1`, [U.moussa]);
  assert(v.rows[0].n === 1);
});
await test("modifier un message affiche « modifié » ; seul l'auteur le peut", async () => {
  await fails(rpc(U.moussa, 'edit_message', [msgId, 'faux']), /MESSAGE_NOT_FOUND/);
  const r = await rpc(U.aicha, 'edit_message', [msgId, 'Bonjour Moussa !']);
  assert(r.status === 'edited');
  const m = await db.query(`select body, edited_at from messages where id = $1`, [msgId]);
  assert(m.rows[0].body === 'Bonjour Moussa !' && m.rows[0].edited_at);
});
await test("« supprimer pour moi » ne retire le message que de ma vue", async () => {
  await rpc(U.moussa, 'hide_message', [msgId]);
  assert((await as(U.moussa, `select * from messages`)).rows.length === 0);
  assert((await as(U.aicha, `select * from messages`)).rows.length === 1);
});
await test("annuler l'envoi vide le contenu des deux côtés ; fenêtre de temps respectée", async () => {
  const r = await rpc(U.aicha, 'send_message', [matchId, 'message à annuler']);
  await rpc(U.aicha, 'unsend_message', [r.id]);
  const m = await db.query(`select body, unsent_at from messages where id = $1`, [r.id]);
  assert(m.rows[0].body === '' && m.rows[0].unsent_at);
  await db.query(`update messages set created_at = now() - interval '2 hours' where id = $1`, [msgId]);
  await fails(rpc(U.aicha, 'unsend_message', [msgId]), /UNSEND_NOT_ALLOWED/);
});

console.log('\nBlocage et signalement');
await test("le signalement est créé avec une priorité et reste invisible pour la personne signalée", async () => {
  const id = await rpc(U.aicha, 'report_user', [U.moussa, 'conversation', 'money_request', 'Demande d’argent', matchId]);
  const r = await db.query(`select priority from reports where id = $1`, [id]);
  assert(r.rows[0].priority === 'high');
  assert((await as(U.moussa, `select * from reports`)).rows.length === 0);
  assert((await as(U.modo, `select * from reports`)).rows.length === 1, 'le modérateur ne voit pas le signalement');
});
await test("le blocage met fin au match, coupe la messagerie et la découverte dans les deux sens", async () => {
  await rpc(U.aicha, 'block_user', [U.moussa]);
  await fails(rpc(U.moussa, 'send_message', [matchId, 'tu es là ?']), /MATCH_ENDED/);
  assert((await as(U.moussa, `select * from my_matches()`)).rows.length === 0);
  await fails(rpc(U.moussa, 'get_profile', [U.aicha]), /PROFILE_NOT_FOUND/);
  await fails(rpc(U.moussa, 'send_like', [U.aicha]), /TARGET_UNAVAILABLE/);
  assert((await as(U.moussa, `select * from blocks`)).rows.length === 0, 'la personne bloquée voit le blocage');
});

console.log('\nProfil public');
await test("get_profile masque la confession non partagée et les photos privées", async () => {
  await db.query(`update profile_photos set visibility = 'private' where user_id = $1 and position = 2`, [U.paul]);
  const p = await rpc(U.fatou, 'get_profile', [U.paul]);
  assert(p.confession === null, 'confession exposée');
  assert(p.photos.some((x) => x.visibility === 'private' && x.path === null), 'chemin de photo privée exposé');
  assert(!('birth_date' in p));
  const own = await rpc(U.paul, 'get_profile', [U.paul]);
  assert(own.confession === 'christian');
});

console.log('\nPremium administratif (V6.4)');
let grantId;
await test("un membre ou un modérateur ne peut pas accorder Premium", async () => {
  await fails(rpc(U.aicha, 'admin_grant_premium', [U.aicha, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'x', 'y']), /FORBIDDEN/);
  await fails(rpc(U.modo, 'admin_grant_premium', [U.aicha, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'x', 'y']), /FORBIDDEN/);
  await fails(as(U.aicha, `insert into premium_grants (user_id, source, starts_at, ends_at, reason, origin, created_by)
    values ($1, 'admin_grant', now(), now() + interval '1 year', 'x', 'y', $1)`, [U.aicha]), /row-level security|permission/i);
});
await test("motif et origine obligatoires", async () => {
  await fails(rpc(U.admin, 'admin_grant_premium', [U.fatou, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', '', 'promotion']), /REASON_AND_ORIGIN_REQUIRED/);
});
await test("attribution gratuite : Premium actif, aucune transaction, événement historisé", async () => {
  grantId = await rpc(U.admin, 'admin_grant_premium', [U.fatou, '2026-11-01T00:00:00Z', '2026-12-31T00:00:00Z', 'Geste commercial', 'compensation']);
  assert((await db.query(`select is_premium($1) as p`, [U.fatou])).rows[0].p === true);
  assert((await db.query(`select count(*)::int as n from transactions`)).rows[0].n === 0, 'transaction fictive créée');
  const ev = await as(U.fatou, `select action, actor from premium_events`);
  assert(ev.rows.length === 1 && ev.rows[0].action === 'granted' && ev.rows[0].actor === U.admin);
});
await test("prolongation : ajoute la durée à la date de fin", async () => {
  const ends = await rpc(U.admin, 'admin_extend_premium', [grantId, 30, 'Prolongation partenaire']);
  assert(new Date(ends).toISOString().startsWith('2027-01-30'), String(ends));
});
await test("retrait : badge et avantages désactivés, historique conservé", async () => {
  await rpc(U.admin, 'admin_revoke_premium', [grantId, 'Erreur d’attribution']);
  assert((await db.query(`select is_premium($1) as p`, [U.fatou])).rows[0].p === false);
  const ev = await db.query(`select action from premium_events where grant_id = $1 order by id`, [grantId]);
  assert(ev.rows.map((r) => r.action).join() === 'granted,extended,revoked', ev.rows.map((r) => r.action).join());
});
await test("Premium expiré = plus de badge, sans tâche planifiée", async () => {
  await rpc(U.admin, 'admin_grant_premium', [U.fatou, '2026-01-01T00:00:00Z', '2026-01-08T00:00:00Z', 'Ancien essai', 'promotion']);
  assert((await db.query(`select is_premium($1) as p`, [U.fatou])).rows[0].p === false);
});
await test("historique Premium et journal d'audit non modifiables, même par le super-admin", async () => {
  await fails(db.query(`delete from premium_events`), /APPEND_ONLY/);
  await fails(db.query(`update audit_log set reason = 'maquillé'`), /APPEND_ONLY/);
  // Via l'API, le super-admin n'a aucune politique de suppression : rien n'est touché.
  const before = (await db.query(`select count(*)::int as n from audit_log`)).rows[0].n;
  await as(U.admin, `delete from audit_log`).catch(() => {});
  const after = (await db.query(`select count(*)::int as n from audit_log`)).rows[0].n;
  assert(before > 0 && before === after, `journal d'audit : ${before} → ${after}`);
});
await test("le journal d'audit trace les actions Premium avec l'administrateur", async () => {
  const r = await db.query(`select count(*)::int as n from audit_log where action like 'premium.%' and actor = $1`, [U.admin]);
  assert(r.rows[0].n >= 3, `entrées : ${r.rows[0].n}`);
});

console.log('\nVérification du profil');
await test("demande refusée sans consentement biométrique, acceptée avec ; décision réservée au staff", async () => {
  await db.query(`update profiles set verification_status = 'not_requested' where id = $1`, [U.fatou]);
  await fails(rpc(U.fatou, 'request_verification', ['x/selfie.jpg']), /BIOMETRIC_CONSENT_REQUIRED/);
  await as(U.fatou, `insert into consents (user_id, kind, document_version, granted) values ($1, 'biometric', 'v0-draft', true)`, [U.fatou]);
  const r = await rpc(U.fatou, 'request_verification', [`${U.fatou}/selfie.jpg`]);
  assert(r.status === 'pending', JSON.stringify(r));
  await fails(as(U.fatou, `select admin_decide_verification($1, 'approved', null)`, [r.request_id]), /FORBIDDEN/);
  await as(U.modo, `select admin_decide_verification($1, 'approved', null)`, [r.request_id]);
  const p = await db.query(`select verification_status from profiles where id = $1`, [U.fatou]);
  assert(p.rows[0].verification_status === 'approved');
});
await test("les consentements ne peuvent être ni modifiés ni supprimés par le membre", async () => {
  await as(U.fatou, `update consents set granted = false where user_id = $1`, [U.fatou]);
  await as(U.fatou, `delete from consents where user_id = $1`, [U.fatou]);
  const r = await db.query(`select granted from consents where user_id = $1`, [U.fatou]);
  assert(r.rows.length === 1 && r.rows[0].granted === true);
});

console.log('\nCompte, données personnelles et cloisonnement');
await test("date de naissance et genre figés après l'inscription", async () => {
  await as(U.paul, `update profiles set birth_date = '2001-01-01', gender = 'femme', bio = 'Nouvelle bio' where id = $1`, [U.paul]);
  const r = await db.query(`select birth_date::text as b, gender, bio from profiles where id = $1`, [U.paul]);
  assert(r.rows[0].b === '1992-11-30' && r.rows[0].gender === 'homme', JSON.stringify(r.rows[0]));
  assert(r.rows[0].bio === 'Nouvelle bio', 'la bio aurait dû être modifiable');
});
await test("un tiers ne peut pas savoir si deux autres membres se sont bloqués", async () => {
  const mine = await as(U.aicha, `select blocked_between($1, $2) as b`, [U.aicha, U.moussa]);
  const other = await as(U.paul, `select blocked_between($1, $2) as b`, [U.aicha, U.moussa]);
  assert(mine.rows[0].b === true && other.rows[0].b === false);
});
await test("liste des personnes bloquées visible par le bloqueur seul ; déblocage possible", async () => {
  const a = await as(U.aicha, `select * from my_blocked_users()`);
  assert(a.rows.length === 1 && a.rows[0].display_name === 'Moussa', JSON.stringify(a.rows));
  assert((await as(U.moussa, `select * from my_blocked_users()`)).rows.length === 0);
  await as(U.aicha, `select unblock_user($1)`, [U.moussa]);
  assert((await as(U.aicha, `select * from my_blocked_users()`)).rows.length === 0);
});
await test("les fonctions internes et la configuration privée ne sont pas appelables par un membre", async () => {
  await fails(as(U.aicha, `select cfg_int('sms_monthly_budget_gnf', 0)`), /permission denied/i);
  await fails(as(U.aicha, `select message_violation_category('test')`), /permission denied/i);
  await fails(as(U.aicha, `select write_audit('x', 'y', 'z', null, null, null)`), /permission denied/i);
  const cfg = await as(U.aicha, `select key from app_config where key = 'sms_monthly_budget_gnf'`);
  assert(cfg.rows.length === 0, 'configuration privée lisible');
});
await test("anon ne peut appeler aucune fonction métier", async () => {
  await fails(as(null, `select my_like_quota()`), /permission denied/i);
  await fails(as(null, `select * from discovery_feed(5)`), /permission denied/i);
});
await test("demande de suppression : profil masqué immédiatement, annulable pendant le délai", async () => {
  const r = await rpc(U.fatou, 'request_account_deletion');
  assert(r.status === 'scheduled' && new Date(r.scheduled_for) > new Date(), JSON.stringify(r));
  assert((await db.query(`select status from profiles where id = $1`, [U.fatou])).rows[0].status === 'hidden');
  assert(!(await feed(U.paul)).some((x) => x.display_name === 'Fatou'), 'profil encore proposé');
  const again = await rpc(U.fatou, 'request_account_deletion');
  assert(again.scheduled_for === r.scheduled_for, 'la date a changé');
  await as(U.fatou, `select cancel_account_deletion()`);
  assert((await db.query(`select status from profiles where id = $1`, [U.fatou])).rows[0].status === 'active');
  await fails(as(U.fatou, `select cancel_account_deletion()`), /NO_DELETION_REQUEST/);
});
await test("export des données : mes données uniquement, sans identité d'autres membres", async () => {
  const data = await rpc(U.aicha, 'export_my_data');
  assert(data.profile.display_name === 'Aïcha');
  assert(data.messages_sent.length >= 1 && data.likes_sent.length >= 1 && data.consents.length === 0);
  // Aucun identifiant d'un autre membre (le prénom « Moussa » n'apparaît que dans les messages écrits par Aïcha).
  const raw = JSON.stringify(data);
  for (const other of [U.moussa, U.fatou, U.paul, U.admin, U.modo]) {
    assert(!raw.includes(other), `l'export contient l'identifiant d'un autre membre : ${other}`);
  }
  const withoutOwnMessages = JSON.stringify({ ...data, messages_sent: [] });
  assert(!withoutOwnMessages.includes('Moussa'), "l'export contient le nom d'un autre membre hors de mes propres messages");
});

console.log(`\n${passed} réussis, ${failed} échoués`);
process.exit(failed ? 1 : 0);
