// ZAYA — Crée un compte de connexion (numéro + code à 4 chiffres), PRÉPRODUCTION SEULEMENT.
// Demande du propriétaire (25/11/2026) : compte 627843030 avec le code 6236, à changer à la première connexion.
//
// Usage (la clé de service n'est jamais écrite dans un fichier ni dans Git) :
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<clé> node supabase/preproduction/creer_compte_code.mjs 627843030 6236
//
// Le compte est créé avec un numéro confirmé et sans profil : à la première connexion, le membre remplit son
// profil (inscription), puis remplace le code imposé par le sien. Aucune dépendance : API Auth et REST de Supabase.

const [numero, code] = process.argv.slice(2);
const BASE = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
if (!BASE || !KEY) throw new Error('SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont requis (variables d’environnement).');
if (!/^\d{9}$/.test(numero ?? '') || !/^\d{4}$/.test(code ?? '')) {
  throw new Error('Usage : node creer_compte_code.mjs <numéro à 9 chiffres> <code à 4 chiffres>');
}

const headers = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };
async function call(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, { ...options, headers });
  const text = await res.text();
  if (!res.ok) throw new Error(`${options.method ?? 'GET'} ${path} : ${res.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

const phone = `224${numero}`;
const liste = await call('/auth/v1/admin/users?page=1&per_page=1000');
let userId = (liste.users ?? []).find((u) => u.phone === phone)?.id;
if (!userId) {
  const cree = await call('/auth/v1/admin/users', {
    method: 'POST',
    body: JSON.stringify({ phone: `+${phone}`, phone_confirm: true }),
  });
  userId = cree.id;
  console.log(`Compte créé : +${phone} (${userId})`);
} else {
  console.log(`Compte existant : +${phone} (${userId})`);
}

await call('/rest/v1/rpc/admin_set_member_pin', {
  method: 'POST',
  body: JSON.stringify({ p_user: userId, p_pin: code }),
});
console.log('Code posé ; il devra être changé à la première connexion.');
