// ZAYA — Connexion par numéro + code à 4 chiffres (migration 0071, décision du propriétaire du 25/11/2026).
//
// 1. Le code est vérifié par la base (pin_login_check) : blocage après 5 erreurs, limite par adresse IP.
// 2. Si le code est bon, la fonction ouvre une session Supabase avec un mot de passe technique dérivé d'un secret
//    serveur (HMAC du PIN_LOGIN_SECRET et de l'identifiant du membre). Ce mot de passe n'est jamais envoyé à
//    l'application et le code à 4 chiffres ne sert jamais de mot de passe Supabase (6 caractères minimum).
// 3. L'application reçoit les jetons de session et les installe (auth.setSession).
//
// Déploiement : `supabase functions deploy pin-login --no-verify-jwt` (appelée avant toute connexion).
// Secrets : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY (fournis par Supabase) et PIN_LOGIN_SECRET
// (64 caractères aléatoires : `supabase secrets set PIN_LOGIN_SECRET=...`, jamais dans Git).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SECRET = Deno.env.get('PIN_LOGIN_SECRET') ?? '';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
}

/** Mot de passe technique du membre : stable, impossible à deviner sans le secret serveur. */
export async function derivedPassword(secret: string, userId: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`zaya-pin-login:${userId}`)));
  let bin = '';
  for (const b of sig) bin += String.fromCharCode(b);
  // Préfixe : satisfait d'éventuelles règles de complexité (majuscule, chiffre, symbole).
  return 'Zy9!' + btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ status: 'error' }, 405);
  if (SECRET.length < 32 || !SUPABASE_URL || !SERVICE_KEY || !ANON_KEY) {
    return json({ status: 'error', reason: 'not_configured' }, 503);
  }

  let phone = '';
  let pin = '';
  try {
    const body = await req.json();
    phone = String(body?.phone ?? '');
    pin = String(body?.pin ?? '');
  } catch {
    return json({ status: 'error' }, 400);
  }
  const ip = (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() || 'inconnue';

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await admin.rpc('pin_login_check', { p_phone: phone, p_pin: pin, p_ip: ip });
  if (error || !data) return json({ status: 'error' }, 500);
  // Code faux, compte bloqué, numéro inconnu, limite atteinte… : la réponse de la base est renvoyée telle quelle.
  if (data.status !== 'ok') return json(data);

  const password = await derivedPassword(SECRET, data.user_id);
  const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  let signIn = await anon.auth.signInWithPassword({ phone: data.phone, password });
  if (signIn.error || !signIn.data.session) {
    // Première connexion par code : le mot de passe technique est posé, puis la connexion est refaite.
    const update = await admin.auth.admin.updateUserById(data.user_id, { password });
    if (update.error) return json({ status: 'error' }, 500);
    signIn = await anon.auth.signInWithPassword({ phone: data.phone, password });
    if (signIn.error || !signIn.data.session) return json({ status: 'error' }, 500);
  }
  return json({
    status: 'ok',
    must_change: data.must_change === true,
    access_token: signIn.data.session.access_token,
    refresh_token: signIn.data.session.refresh_token,
  });
});
