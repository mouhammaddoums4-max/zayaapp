// ZAYA — Rappel SSV d'AdMob : crédite une récompense publicitaire seulement après vérification de la signature de
// Google (cahier « Régie publicitaire » v1 §3.3). Appelée par les serveurs de Google, jamais par l'application.
//
// Déploiement : `supabase functions deploy admob-ssv --no-verify-jwt` (Google n'envoie pas de jeton Supabase), puis
// renseigner cette URL comme « URL de rappel SSV » du bloc d'annonces récompensées dans la console AdMob.
// L'application fournit, à chaque publicité, ServerSideVerificationOptions(userId: <id Supabase>, customData: <code de
// la récompense>) : Google les renvoie tels quels dans user_id et custom_data.
// Secrets utilisés (fournis par Supabase) : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { readParams, verifySsv, type VerifierKey } from './verify.ts';

const KEYS_URL = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
let cachedKeys: { keys: VerifierKey[]; at: number } | null = null;

async function googleKeys(force = false): Promise<VerifierKey[]> {
  if (!force && cachedKeys && Date.now() - cachedKeys.at < 6 * 3600e3) return cachedKeys.keys;
  const res = await fetch(KEYS_URL);
  if (!res.ok) throw new Error(`clés Google indisponibles (${res.status})`);
  const body = await res.json() as { keys: VerifierKey[] };
  cachedKeys = { keys: body.keys ?? [], at: Date.now() };
  return cachedKeys.keys;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method !== 'GET') return new Response('Méthode non prise en charge', { status: 405 });
  const rawQuery = new URL(req.url).search;

  let valid = await verifySsv(rawQuery, await googleKeys()).catch(() => false);
  // Rotation des clés côté Google : une seconde tentative avec la liste rafraîchie.
  if (!valid) valid = await verifySsv(rawQuery, await googleKeys(true)).catch(() => false);
  if (!valid) return new Response('Signature invalide', { status: 403 });

  const p = readParams(rawQuery);
  // Le rappel de vérification envoyé par la console AdMob ne contient ni utilisateur ni récompense : on l'accepte.
  if (!p.userId && !p.customData) return new Response('ok', { status: 200 });
  if (!UUID.test(p.userId) || !p.transactionId || !p.customData) {
    return new Response('Paramètres incomplets', { status: 400 });
  }

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
  const { data, error } = await db.rpc('credit_rewarded_ad', {
    p_transaction: p.transactionId,
    p_user: p.userId,
    p_reward: p.customData,
    p_ad_network: p.adNetwork,
    p_ad_unit: p.adUnit,
  });
  if (error) {
    // Erreurs définitives (récompense ou membre inconnus) : 200 pour que Google ne réessaie pas sans fin.
    const definitive = /UNKNOWN_REWARD|UNKNOWN_USER|TRANSACTION_REQUIRED/.test(error.message);
    return new Response(definitive ? `refusé : ${error.message}` : 'erreur temporaire', { status: definitive ? 200 : 500 });
  }
  return Response.json(data ?? { status: 'ok' });
});
