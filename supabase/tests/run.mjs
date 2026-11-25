// Tests ZAYA : applique les migrations + le seed dans PGlite puis vérifie RLS et règles métier.
// Vérifie aussi que le fichier d'installation Supabase (supabase/deploy) est à jour et s'installe d'un bloc.
// Usage : npm install && npm test
import { PGlite } from '@electric-sql/pglite';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildInstallSql, installPath, normalizeEol } from '../deploy/build.mjs';
import { adsTests } from './ads_tests.mjs';
import { assistanceTests } from './assistance_tests.mjs';
import { contentTests } from './content_tests.mjs';
import { mysteryBoxTests } from './mystery_box_tests.mjs';
import { googleAdsTests } from './google_ads_tests.mjs';
import { rewardsTests } from './rewards_tests.mjs';
import { swipesTests } from './swipes_tests.mjs';
import { conversationsTests } from './conversations_tests.mjs';
import { endedMatchesTests } from './ended_matches_tests.mjs';
import { filtresAvancesTests } from './filtres_avances_tests.mjs';
import { securiteTests } from './securite_tests.mjs';
import { etudesEnfantsTests } from './etudes_enfants_tests.mjs';
import { signauxTests } from './signaux_tests.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const db = new PGlite();

/** Émulation minimale de l'environnement Supabase (rôles, auth.uid(), storage). */
async function emulateSupabase(target) {
  await target.exec(`
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
}
await emulateSupabase(db);

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
  // En mode « validation préalable » (0032 : photo_auto_publish = false), la photo reste en attente quoi qu'il envoie.
  await db.query(`update app_config set value = 'false' where key = 'photo_auto_publish'`);
  await as(U.paul, `insert into profile_photos (user_id, storage_path, position, moderation) values ($1, 'x/p9.jpg', 9, 'approved')`, [U.paul]);
  const r = await db.query(`select moderation from profile_photos where storage_path = 'x/p9.jpg'`);
  await db.query(`update app_config set value = 'true' where key = 'photo_auto_publish'`);
  assert(r.rows[0].moderation === 'pending');
});
await test("un membre voit le fichier des photos approuvées et publiques des autres, jamais des privées", async () => {
  await db.exec(`grant usage on schema storage to authenticated;
                 grant select on storage.objects to authenticated`); // droits accordés par Supabase
  const [publique, privee] = [`${U.aicha}/p0.jpg`, `${U.aicha}/privee.jpg`];
  await db.query(`insert into storage.objects (bucket_id, name) values ('profile-photos', $1), ('profile-photos', $2)`,
    [publique, privee]);
  await db.query(`insert into profile_photos (user_id, storage_path, position, visibility, moderation)
                  values ($1, $2, 5, 'private', 'approved')`, [U.aicha, privee]);
  const vus = async (id) => (await as(id, `select name from storage.objects
    where bucket_id = 'profile-photos' and name like $1 order by name`, [`${U.aicha}/%`])).rows.map((x) => x.name);
  try {
    assert(JSON.stringify(await vus(U.moussa)) === JSON.stringify([publique]), `Moussa voit : [${await vus(U.moussa)}]`);
    assert((await vus(U.aicha)).length === 2, 'la propriétaire doit voir toutes ses photos');
  } finally {
    await db.query(`delete from profile_photos where storage_path = $1`, [privee]);
    await db.query(`delete from storage.objects where name in ($1, $2)`, [publique, privee]);
  }
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
await test("filtre par ville ou commune : restreint ce que je vois, sans me cacher aux autres villes", async () => {
  const nomsVus = async (u) => (await feed(U.moussa === u ? U.moussa : u)).map((r) => r.display_name).sort().join();
  const villeDesFemmes = (await db.query(`select city_id from profiles where id = $1`, [U.aicha])).rows[0].city_id;
  const autreVille = (await db.query(`select id from cities where id <> $1 limit 1`, [villeDesFemmes])).rows[0].id;
  const avant = await nomsVus(U.moussa);
  assert(avant.length > 0, 'jeu de test : Moussa doit voir au moins un profil');
  try {
    await as(U.moussa, `update discovery_preferences set city_ids = $2 where user_id = $1`, [U.moussa, [autreVille]]);
    assert((await nomsVus(U.moussa)) === '', `ville sans profil : Moussa voit ${await nomsVus(U.moussa)}`);
    await as(U.moussa, `update discovery_preferences set city_ids = $2 where user_id = $1`, [U.moussa, [autreVille, villeDesFemmes]]);
    assert((await nomsVus(U.moussa)) === avant, 'plusieurs villes : les profils de l’une d’elles doivent être proposés');
    // Sens unique : le filtre d'Aïcha ne la cache pas à Moussa.
    await as(U.aicha, `update discovery_preferences set city_ids = $2 where user_id = $1`, [U.aicha, [autreVille]]);
    await as(U.moussa, `update discovery_preferences set city_ids = '{}' where user_id = $1`, [U.moussa]);
    assert((await nomsVus(U.moussa)) === avant, 'le filtre de ville d’Aïcha l’a cachée à Moussa');
  } finally {
    await db.query(`update discovery_preferences set city_ids = '{}' where user_id in ($1, $2)`, [U.moussa, U.aicha]);
  }
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
await test("likes envoyés : Aïcha voit Moussa ; un like d'un profil invisible n'est pas compté", async () => {
  const envoyes = (await as(U.aicha, `select * from my_sent_interests()`)).rows;
  assert(envoyes.length === 1 && envoyes[0].display_name === 'Moussa', JSON.stringify(envoyes));
  assert(!('birth_date' in envoyes[0]) && typeof envoyes[0].age === 'number');
  await db.query(`update profiles set verification_status = 'pending' where id = $1`, [U.aicha]);
  try {
    assert((await rpc(U.moussa, 'received_interests_count')) === 0,
      'le compteur doit suivre la liste : Aïcha, non visible, n’apparaît pas dans la liste');
  } finally {
    await db.query(`update profiles set verification_status = 'approved' where id = $1`, [U.aicha]);
  }
  assert((await rpc(U.moussa, 'received_interests_count')) === 1);
  assert((await as(U.moussa, `select * from my_sent_interests()`)).rows.length === 0, 'Moussa n’a encore aimé personne');
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
await test("quota de swipes appliqué côté serveur (0016 : likes et passages comptés ensemble)", async () => {
  await db.query(`update app_config set value = '1' where key = 'swipe_quota_free'`);
  const r = await rpc(U.aicha, 'send_like', [U.paul]);
  assert(r.status === 'quota_reached' && r.resets_at, JSON.stringify(r));
  await db.query(`update app_config set value = '50' where key = 'swipe_quota_free'`);
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

console.log('\nPhotos floutées (addendum V6.4 §3, C12)');
const photosVues = async (viewer, owner) => {
  const p = await rpc(viewer, 'get_profile', [owner]);
  const rows = (await db.query(`select id, visibility from profile_photos where user_id = $1 and moderation = 'approved'`, [owner])).rows;
  return p.photos.map((x) => ({ ...x, vis: rows.find((r) => r.id === x.id)?.visibility }));
};
await test("visiteur Gratuit : seule la photo principale est nette, les suivantes floutées, sans chemin d'original", async () => {
  const photos = await photosVues(U.fatou, U.paul); // Fatou (Gratuit) consulte Paul
  const publiques = photos.filter((x) => x.visibility === 'public');
  assert(publiques.length >= 2, 'jeu de test : il faut au moins 2 photos publiques');
  assert(publiques[0].access === 'original' && publiques[0].path, 'la photo principale doit rester nette');
  for (const x of publiques.slice(1)) {
    assert(x.access === 'blurred' && x.path === null, `photo ${x.id} : ${x.access}, chemin ${x.path}`);
  }
  assert(photos.filter((x) => x.visibility === 'private').every((x) => x.access === 'none' && !x.path && !x.blur_path));
});
await test("visiteur Premium : photos publiques nettes ; une photo floutée par sa propriétaire reste floutée", async () => {
  const cible = (await db.query(`select id from profile_photos where user_id = $1 order by position limit 1 offset 1`, [U.fatou])).rows[0].id;
  await db.query(`update profile_photos set visibility = 'blurred' where id = $1`, [cible]);
  const g = await rpc(U.admin, 'admin_grant_premium', [U.paul, '2026-01-01T00:00:00Z', '2099-01-01T00:00:00Z', 'Test', 'compte de test']);
  try {
    const photos = await photosVues(U.paul, U.fatou); // Paul (Premium) consulte Fatou
    for (const x of photos) {
      const attendu = x.id === cible ? 'blurred' : 'original';
      assert(x.access === attendu, `photo ${x.id} : ${x.access} au lieu de ${attendu}`);
      assert(attendu === 'original' ? !!x.path : x.path === null);
    }
  } finally {
    await db.query(`update profile_photos set visibility = 'public' where id = $1`, [cible]);
    await rpc(U.admin, 'admin_revoke_premium', [g, 'fin du test']);
  }
});
await test("le nombre de photos nettes pour un visiteur Gratuit se règle dans app_config", async () => {
  await db.query(`update app_config set value = '2' where key = 'free_clear_photos'`);
  try {
    const nettes = (await photosVues(U.fatou, U.paul)).filter((x) => x.access === 'original').length;
    assert(nettes === 2, `${nettes} photos nettes au lieu de 2`);
  } finally {
    await db.query(`update app_config set value = '1' where key = 'free_clear_photos'`);
  }
});
await test("stockage : un visiteur Gratuit n'obtient jamais le fichier original d'une photo floutée, seulement sa version floutée", async () => {
  const ph = (await db.query(`select id, storage_path from profile_photos
    where user_id = $1 and moderation = 'approved' and visibility = 'public' order by position, created_at, id`, [U.paul])).rows;
  const [nette, floue] = ph;
  const fichierFlou = `${U.paul}/${floue.id}.jpg`;
  await db.query(`update profile_photos set blur_path = $1 where id = $2`, [fichierFlou, floue.id]);
  await db.query(`insert into storage.objects (bucket_id, name) values ('profile-photos', $1), ('profile-photos', $2),
                  ('profile-photos-blur', $3)`, [nette.storage_path, floue.storage_path, fichierFlou]);
  const lit = async (viewer, bucket, name) => (await as(viewer,
    `select count(*)::int as n from storage.objects where bucket_id = $1 and name = $2`, [bucket, name])).rows[0].n === 1;
  try {
    assert(await lit(U.fatou, 'profile-photos', nette.storage_path), 'Gratuit : photo principale refusée');
    assert(!(await lit(U.fatou, 'profile-photos', floue.storage_path)), 'Gratuit : original d’une photo floutée servi');
    assert(await lit(U.fatou, 'profile-photos-blur', fichierFlou), 'Gratuit : version floutée refusée');
    const p = await rpc(U.fatou, 'get_profile', [U.paul]);
    assert(p.photos.find((x) => x.id === floue.id).blur_path === fichierFlou, 'chemin flouté absent de get_profile');
    assert(await lit(U.paul, 'profile-photos', floue.storage_path), 'le propriétaire doit lire ses originaux');
    assert(await lit(U.paul, 'profile-photos-blur', fichierFlou), 'le propriétaire doit lire sa version floutée');
  } finally {
    await db.query(`delete from storage.objects where name in ($1, $2, $3)`, [nette.storage_path, floue.storage_path, fichierFlou]);
  }
});
await test("un membre ne peut pas écrire lui-même le chemin flouté de ses photos", async () => {
  const ph = (await db.query(`select id, blur_path from profile_photos where user_id = $1 limit 1`, [U.fatou])).rows[0];
  await as(U.fatou, `update profile_photos set blur_path = 'triche.jpg' where id = $1`, [ph.id]);
  const apres = (await db.query(`select blur_path from profile_photos where id = $1`, [ph.id])).rows[0].blur_path;
  assert(apres === ph.blur_path, `chemin flouté modifié par le membre : ${apres}`);
  await as(U.fatou, `insert into profile_photos (user_id, storage_path, position, blur_path) values ($1, $2, 8, 'triche.jpg')`,
    [U.fatou, `${U.fatou}/p8.jpg`]);
  const neuve = (await db.query(`select blur_path from profile_photos where storage_path = $1`, [`${U.fatou}/p8.jpg`])).rows[0];
  assert(neuve.blur_path === null, 'chemin flouté accepté à l’ajout d’une photo');
  await db.query(`delete from profile_photos where storage_path = $1`, [`${U.fatou}/p8.jpg`]);
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

console.log('\nCommunauté');
const communityId = async (slug) => (await db.query(`select id from communities where slug = $1`, [slug])).rows[0].id;
const prep = await communityId('preparation-mariage');
const couple = await communityId('vie-de-couple');
let postId;
await test('détection des coordonnées : numéros, e-mails, liens ; pas les montants, dates ni petits nombres', async () => {
  const yes = [
    'Appelle-moi au 622 11 22 33',
    'mon numéro +224622112233',
    'écris-moi : awa.diallo@gmail.com',
    'mon whatsapp : wa.me/224622112233',
    'contacte-moi sur t.me/awa',
  ];
  const no = [
    'La dot était de 5 000 000 GNF',
    'Budget : 25 000 000 de francs',
    'Rendez-vous le 12/05/2026 à 18h30',
    'Nous avons 2 enfants de 4 et 7 ans',
    'En 2025 nous nous sommes mariés',
  ];
  for (const t of yes) {
    assert((await db.query(`select contains_contact_details($1) as c`, [t])).rows[0].c === true, `non détecté : ${t}`);
  }
  for (const t of no) {
    assert((await db.query(`select contains_contact_details($1) as c`, [t])).rows[0].c === false, `faux positif : ${t}`);
  }
});
await test('les 8 communautés de départ sont listées ; anon n’a accès à rien', async () => {
  const r = await as(U.aicha, `select * from list_communities()`);
  assert(r.rows.length === 8 && r.rows.every((c) => c.joined === false), r.rows.map((c) => c.slug).join());
  await fails(as(null, `select * from list_communities()`), /permission denied/i);
  await fails(as(null, `select * from community_feed()`), /permission denied/i);
});
await test('un profil non vérifié peut lire mais pas publier', async () => {
  await db.query(`update profiles set verification_status = 'pending' where id = $1`, [U.paul]);
  await fails(rpc(U.paul, 'create_post', [prep, 'question', 'Bonjour à tous']), /VERIFICATION_REQUIRED/);
  await fails(rpc(U.paul, 'add_comment', [prep, 'Bonjour']), /VERIFICATION_REQUIRED/);
  assert(Array.isArray((await as(U.paul, `select * from community_feed()`)).rows));
  await db.query(`update profiles set verification_status = 'approved' where id = $1`, [U.paul]);
});
await test('filtre avant publication : coordonnées et termes interdits jamais enregistrés', async () => {
  const before = (await db.query(`select count(*)::int as n from posts`)).rows[0].n;
  const a = await rpc(U.aicha, 'create_post', [prep, 'question', 'Écrivez-moi au 622 11 22 33 pour en parler']);
  assert(a.status === 'blocked' && a.category === 'contact_details', JSON.stringify(a));
  const b = await rpc(U.aicha, 'create_post', [prep, 'advice', "Envoie-moi de l'argent et je t'explique"]);
  assert(b.status === 'blocked' && b.category === 'money_request', JSON.stringify(b));
  assert((await db.query(`select count(*)::int as n from posts`)).rows[0].n === before, 'contenu bloqué enregistré');
  const v = await db.query(
    `select count(*)::int as n from message_violations where user_id = $1 and context = 'post'`, [U.aicha]);
  assert(v.rows[0].n === 2);
});
await test('publier fait suivre la communauté ; « Pour vous » ne montre que les communautés suivies', async () => {
  const r = await rpc(U.aicha, 'create_post', [prep, 'question', 'Quels sujets aborder avant de s’engager ?']);
  assert(r.status === 'published' && r.id, JSON.stringify(r));
  postId = r.id;
  const mine = await as(U.aicha, `select * from list_communities() where joined`);
  assert(mine.rows.length === 1 && mine.rows[0].slug === 'preparation-mariage');
  // Paul ne suit aucune communauté : il voit tout.
  assert((await as(U.paul, `select * from community_feed()`)).rows.some((p) => p.post_id === postId));
  // Paul suit une autre communauté : la publication sort de « Pour vous » mais reste dans sa communauté.
  await as(U.paul, `select join_community($1)`, [couple]);
  assert(!(await as(U.paul, `select * from community_feed()`)).rows.some((p) => p.post_id === postId));
  assert((await as(U.paul, `select * from community_feed($1)`, [prep])).rows.some((p) => p.post_id === postId));
  const row = (await as(U.paul, `select * from community_post($1)`, [postId])).rows[0];
  assert(row.author_name === 'Aïcha' && row.author_verified === true && row.is_mine === false, JSON.stringify(row));
  assert(!('author_photo' in row) && !('phone' in row), 'la publication expose plus que le nom et le badge');
});
await test('aucune lecture directe des publications par un membre ; la modération y a accès', async () => {
  assert((await as(U.paul, `select * from posts`)).rows.length === 0);
  assert((await as(U.paul, `select * from comments`)).rows.length === 0);
  assert((await as(U.paul, `select * from post_reactions`)).rows.length === 0);
  assert((await as(U.modo, `select * from posts`)).rows.length >= 1);
  await fails(as(U.paul, `insert into posts (community_id, author_id, body) values ($1, $2, 'x')`, [prep, U.paul]),
    /row-level security|permission/i);
});
await test('réactions, commentaires filtrés, enregistrement', async () => {
  assert((await rpc(U.paul, 'react_to_post', [postId, true])) === 1);
  assert((await rpc(U.paul, 'react_to_post', [postId, true])) === 1, 'double réaction comptée');
  assert((await rpc(U.fatou, 'react_to_post', [postId, true])) === 2);
  assert((await rpc(U.fatou, 'react_to_post', [postId, false])) === 1);
  const c = await rpc(U.paul, 'add_comment', [postId, 'Les finances et le lieu de vie, sans hésiter.']);
  assert(c.status === 'published', JSON.stringify(c));
  const blocked = await rpc(U.paul, 'add_comment', [postId, 'Écris-moi : paul@exemple.com']);
  assert(blocked.status === 'blocked' && blocked.category === 'contact_details', JSON.stringify(blocked));
  await as(U.fatou, `select save_post($1, true)`, [postId]);
  const saved = await as(U.fatou, `select * from saved_community_posts()`);
  assert(saved.rows.length === 1 && saved.rows[0].saved === true);
  const row = (await as(U.aicha, `select * from community_post($1)`, [postId])).rows[0];
  assert(row.reaction_count === 1 && row.comment_count === 1 && row.is_mine === true, JSON.stringify(row));
});
await test('seul l’auteur peut désactiver les commentaires', async () => {
  await fails(as(U.paul, `select set_post_comments($1, false)`, [postId]), /POST_NOT_FOUND/);
  await as(U.aicha, `select set_post_comments($1, false)`, [postId]);
  await fails(rpc(U.fatou, 'add_comment', [postId, 'Merci pour la question']), /COMMENTS_DISABLED/);
  await as(U.aicha, `select set_post_comments($1, true)`, [postId]);
});
await test('modifier : seul l’auteur ; la version précédente est conservée pour la modération', async () => {
  await fails(rpc(U.paul, 'edit_post', [postId, 'piraté']), /POST_NOT_FOUND/);
  const r = await rpc(U.aicha, 'edit_post', [postId, 'Quels sujets avez-vous abordés avant de vous engager ?']);
  assert(r.status === 'published');
  const row = (await as(U.paul, `select * from community_post($1)`, [postId])).rows[0];
  assert(row.edited === true && row.body.startsWith('Quels sujets avez-vous'), JSON.stringify(row));
  const rev = await db.query(`select previous_body from post_revisions where post_id = $1`, [postId]);
  assert(rev.rows.length === 1 && rev.rows[0].previous_body.startsWith('Quels sujets aborder'));
});
await test('blocage : publications et commentaires invisibles dans les deux sens', async () => {
  await as(U.fatou, `select block_user($1)`, [U.paul]);
  assert((await as(U.fatou, `select * from post_comments($1)`, [postId])).rows.length === 0,
    'commentaire d’une personne bloquée visible');
  assert((await as(U.fatou, `select * from community_post($1)`, [postId])).rows[0].comment_count === 0,
    'compteur incluant un commentaire invisible');
  const pr = await rpc(U.paul, 'create_post', [couple, 'advice', 'Parler des désaccords à tête reposée.']);
  assert(!(await as(U.fatou, `select * from community_feed()`)).rows.some((p) => p.post_id === pr.id));
  const pf = await rpc(U.fatou, 'create_post', [couple, 'experience', 'Premier rendez-vous dans un lieu public.']);
  assert(!(await as(U.paul, `select * from community_feed($1)`, [couple])).rows.some((p) => p.post_id === pf.id));
  await as(U.fatou, `select unblock_user($1)`, [U.paul]);
  assert((await as(U.paul, `select * from community_feed($1)`, [couple])).rows.some((p) => p.post_id === pf.id));
});
await test('signaler masque aussitôt pour soi ; la modération retire et restaure, avec audit', async () => {
  const id = await rpc(U.moussa, 'report_post', [postId, 'spam', null]);
  const rep = await db.query(`select priority, context, post_id from reports where id = $1`, [id]);
  assert(rep.rows[0].context === 'post' && rep.rows[0].post_id === postId && rep.rows[0].priority === 'low');
  await fails(as(U.moussa, `select * from community_post($1)`, [postId]), /POST_NOT_FOUND/);
  assert((await as(U.paul, `select * from community_post($1)`, [postId])).rows.length === 1, 'masqué pour tous');
  await fails(as(U.aicha, `select admin_moderate_post($1, 'remove', 'test')`, [postId]), /FORBIDDEN/);
  await as(U.modo, `select admin_moderate_post($1, 'remove', 'Hors sujet')`, [postId]);
  await fails(as(U.paul, `select * from community_post($1)`, [postId]), /POST_NOT_FOUND/);
  await as(U.modo, `select admin_moderate_post($1, 'restore', 'Erreur de modération')`, [postId]);
  assert((await as(U.paul, `select * from community_post($1)`, [postId])).rows.length === 1);
  const audit = await db.query(
    `select action, actor from audit_log where entity = 'posts' and entity_id = $1 order by id`, [postId]);
  assert(audit.rows.map((r) => r.action).join() === 'post.remove,post.restore' && audit.rows[0].actor === U.modo);
});
await test('l’auteur supprime sa publication : elle disparaît pour tous, conservée pour la modération', async () => {
  const r = await rpc(U.paul, 'create_post', [couple, 'question', 'Comment gérer les avis de la famille ?']);
  await fails(as(U.aicha, `select delete_post($1)`, [r.id]), /POST_NOT_FOUND/);
  await as(U.paul, `select delete_post($1)`, [r.id]);
  await fails(as(U.aicha, `select * from community_post($1)`, [r.id]), /POST_NOT_FOUND/);
  assert((await db.query(`select status from posts where id = $1`, [r.id])).rows[0].status === 'deleted');
});
await test('limite de publications par jour ; un compte restreint lit mais ne publie pas', async () => {
  await db.query(`update app_config set value = '1' where key = 'community_posts_per_day'`);
  await fails(rpc(U.aicha, 'create_post', [prep, 'question', 'Encore une question']), /RATE_LIMITED/);
  await db.query(`update app_config set value = '5' where key = 'community_posts_per_day'`);
  await db.query(
    `insert into sanctions (user_id, kind, reason, created_by, ends_at)
     values ($1, 'restriction', 'Test', $2, now() + interval '1 day')`, [U.moussa, U.modo]);
  await fails(rpc(U.moussa, 'create_post', [prep, 'question', 'Bonjour']), /ACCOUNT_RESTRICTED/);
  assert(Array.isArray((await as(U.moussa, `select * from community_feed()`)).rows), 'la lecture reste possible');
  await db.query(`delete from sanctions where user_id = $1`, [U.moussa]);
});
await test('communauté fermée par la configuration : lecture et publication refusées', async () => {
  await db.query(`update app_config set value = 'false' where key = 'community_enabled'`);
  await fails(as(U.aicha, `select * from community_feed()`), /COMMUNITY_DISABLED/);
  await fails(rpc(U.aicha, 'create_post', [prep, 'question', 'Bonjour']), /COMMUNITY_DISABLED/);
  await db.query(`update app_config set value = 'true' where key = 'community_enabled'`);
});
await test('quitter une communauté, régler ses notifications', async () => {
  await as(U.paul, `select set_community_notifications($1, 'none')`, [couple]);
  const c = (await as(U.paul, `select * from list_communities() where slug = 'vie-de-couple'`)).rows[0];
  assert(c.joined === true && c.notif_level === 'none' && c.member_count >= 2, JSON.stringify(c));
  await as(U.paul, `select leave_community($1)`, [couple]);
  assert((await as(U.paul, `select * from list_communities() where joined`)).rows.length === 0);
  await fails(as(U.paul, `select set_community_notifications($1, 'all')`, [couple]), /NOT_A_MEMBER/);
});
await test('fonctions internes de la communauté non appelables ; export avec mes contenus', async () => {
  await fails(as(U.aicha, `select * from post_query($1, null, null, false, false, null, 5)`, [U.aicha]),
    /permission denied/i);
  await fails(as(U.aicha, `select community_violation('x')`), /permission denied/i);
  const data = await rpc(U.aicha, 'export_my_data');
  assert(data.community_posts.length === 1 && data.communities_followed[0] === 'Préparation au mariage',
    JSON.stringify(data.community_posts));
});

console.log('\nOutil de préproduction (supabase/preproduction)');
await test('valider les comptes d’essai : seulement les numéros listés, au nom d’un modérateur, tracé, sans effet si relancé',
  async () => {
    const script = readFileSync(join(here, '..', 'preproduction', 'valider_verifications_essai.sql'), 'utf8');
    const essai = {
      a: ['00000000-0000-0000-0000-0000000000e1', '224620000001', 'homme'],
      b: ['00000000-0000-0000-0000-0000000000e2', '224620000002', 'femme'],
      horsListe: ['00000000-0000-0000-0000-0000000000e3', '224620000003', 'femme'],
    };
    for (const [id, phone, gender] of Object.values(essai)) {
      await db.query(`insert into auth.users (id, phone, phone_confirmed_at) values ($1, $2, now())`, [id, phone]);
      await db.query(
        `insert into profiles (id, display_name, birth_date, gender, seeking_gender, country_code, city_id, status,
                               is_phone_verified)
         values ($1, 'Essai', '1995-05-05', $2, $3, 'GN', (select id from cities limit 1), 'active', true)`,
        [id, gender, gender === 'homme' ? 'femme' : 'homme'],
      );
      for (let i = 0; i < 3; i++) {
        await db.query(`insert into profile_photos (user_id, storage_path, position) values ($1, $2, $3)`,
          [id, `${id}/p${i}.jpg`, i]);
      }
      await as(id, `insert into consents (user_id, kind, document_version, granted) values ($1, 'biometric', 'v0-draft', true)`,
        [id]);
      assert((await rpc(id, 'request_verification', [`${id}/selfie.jpg`])).status === 'pending');
    }
    const ids = Object.values(essai).map(([id]) => id);
    const statut = async () => Object.fromEntries((await db.query(
      `select id, verification_status::text as s from profiles where id = any($1::uuid[])`, [ids])).rows.map((r) => [r.id, r.s]));
    const validations = async () => (await db.query(
      `select count(*)::int as n from audit_log where action = 'verification.approved' and actor = $1`, [essai.a[0]])).rows[0].n;

    // Premier numéro inconnu : refus explicite, rien n'est modifié.
    await fails(db.exec(script.replace("array['224620000001'", "array['224699999999'")), /Aucun compte avec le numéro/);
    assert(Object.values(await statut()).every((s) => s === 'pending'), JSON.stringify(await statut()));

    const resultats = await db.exec(script);
    const s = await statut();
    assert(s[essai.a[0]] === 'approved' && s[essai.b[0]] === 'approved', JSON.stringify(s));
    assert(s[essai.horsListe[0]] === 'pending', 'un numéro hors liste ne doit pas être validé');
    const photos = await db.query(`select count(*)::int as n from profile_photos where user_id = any($1::uuid[])
                                   and moderation = 'approved'`, [[essai.a[0], essai.b[0]]]);
    assert(photos.rows[0].n === 6, 'les photos des comptes validés sont approuvées');
    const roles = await db.query(`select role::text as r from staff_roles where user_id = $1`, [essai.a[0]]);
    assert(roles.rows.length === 1 && roles.rows[0].r === 'moderator', JSON.stringify(roles.rows));
    assert((await validations()) === 2, 'deux validations tracées au nom du modérateur');
    const tableau = resultats.at(-1).rows.find((r) => r.numero === '224620000002');
    assert(tableau && tableau.verification === 'approved', 'le tableau final montre l’état des comptes');

    await db.exec(script);
    assert((await validations()) === 2, 'relancer le script ne doit rien valider de plus');
    const sub = await db.query(`select coalesce(current_setting('request.jwt.claim.sub', true), '') as s`);
    assert(sub.rows[0].s === '', 'l’identité du modérateur ne doit pas rester active après le script');
  });

await assistanceTests({ db, test, assert, as, rpc, fails, U });
await endedMatchesTests({ db, test, assert, as, rpc, fails });
await adsTests({ db, test, assert, as, rpc, fails, U });
await contentTests({ db, test, assert, as, rpc, fails, U });
await rewardsTests({ db, test, assert, as, rpc, fails, U });
await mysteryBoxTests({ db, test, assert, as, rpc, fails, U });
await googleAdsTests({ db, test, assert, as, rpc, fails, U });
await swipesTests({ db, test, assert, as, rpc, fails, U, seedMember });
await conversationsTests({ db, test, assert, as, rpc, fails, seedMember });
await filtresAvancesTests({ db, test, assert, as, rpc, fails, U, seedMember });
await securiteTests({ db, test, assert, as, rpc, fails, seedMember });
await etudesEnfantsTests({ db, test, assert, as, rpc, fails, U, seedMember });
await signauxTests({ db, test, assert, as, rpc, fails, U, seedMember });

console.log('\nFichier d’installation Supabase');
await test('le fichier d’installation est à jour (régénéré à partir des migrations et du seed)', async () => {
  assert(normalizeEol(readFileSync(installPath, 'utf8')) === buildInstallSql(),
    'fichier périmé : lancer « npm run build:install » dans supabase/tests');
});
await test('il s’installe d’un seul bloc sur une base vierge ; une seconde installation est refusée sans rien modifier',
  async () => {
    const fresh = new PGlite();
    await emulateSupabase(fresh);
    const sql = readFileSync(installPath, 'utf8');
    await fresh.exec(sql);
    const count = async () => (await fresh.query(`select count(*)::int as n from communities`)).rows[0].n;
    assert((await count()) === 8);
    assert((await fresh.query(`select count(*)::int as n from cities`)).rows[0].n > 0);
    await fails(fresh.exec(sql), /déjà installé/);
    await fresh.exec('rollback');
    assert((await count()) === 8, 'la seconde exécution a modifié la base');
    await fresh.close();
  });

console.log(`\n${passed} réussis, ${failed} échoués`);
process.exit(failed ? 1 : 0);
