// ZAYA — Supabase Auth « Send SMS Hook » → Nimba SMS.
// Supabase Auth génère le code OTP et appelle cette fonction ; la clé Nimba ne quitte jamais le serveur.
//
// Secrets requis (supabase secrets set …) :
//   SEND_SMS_HOOK_SECRET  secret du hook (format « v1,whsec_… » fourni par Supabase)
//   NIMBA_SERVICE_ID, NIMBA_SECRET, NIMBA_SENDER
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (fournis par la plateforme)
//
// NON VÉRIFIÉ : jamais exécuté contre l'API Nimba réelle. À tester en staging avec des clés de test
// avant toute activation (tarifs, expéditeur et accusés de livraison à confirmer — décision B3).
import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const NIMBA_URL = 'https://api.nimbasms.com/v1/messages'; // sans slash final

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function hookError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  const payload = await req.text();
  const secret = (Deno.env.get('SEND_SMS_HOOK_SECRET') ?? '').replace('v1,whsec_', '');
  let event: { user: { phone: string }; sms: { otp: string } };
  try {
    event = new Webhook(secret).verify(payload, Object.fromEntries(req.headers)) as typeof event;
  } catch {
    return hookError(401, 'Signature du hook invalide');
  }

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const phone = event.user.phone.startsWith('+') ? event.user.phone : `+${event.user.phone}`;
  const phoneHash = await sha256(phone);

  // Plafond de dépenses mensuel et coût unitaire configurables (app_config)
  const { data: cfg } = await admin.from('app_config').select('key, value')
    .in('key', ['sms_monthly_budget_gnf', 'sms_unit_cost_gnf']);
  const budget = Number(cfg?.find((c) => c.key === 'sms_monthly_budget_gnf')?.value ?? 0);
  const unitCost = Number(cfg?.find((c) => c.key === 'sms_unit_cost_gnf')?.value ?? 0);
  const monthStart = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1)).toISOString();
  const { data: spentRows } = await admin.from('sms_log').select('cost_gnf').eq('status', 'sent').gte('created_at', monthStart);
  const spent = (spentRows ?? []).reduce((s, r) => s + Number(r.cost_gnf), 0);
  if (budget <= 0 || spent + unitCost > budget) {
    await admin.from('sms_log').insert({ phone_hash: phoneHash, status: 'blocked_budget' });
    return hookError(429, 'Envoi de SMS temporairement indisponible');
  }

  // Limitation par numéro : 3 envois maximum par tranche de 15 minutes
  const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const { count } = await admin.from('sms_log').select('id', { count: 'exact', head: true })
    .eq('phone_hash', phoneHash).gte('created_at', since);
  if ((count ?? 0) >= 3) return hookError(429, 'Trop de tentatives. Réessayez dans quelques minutes.');

  const auth = btoa(`${Deno.env.get('NIMBA_SERVICE_ID')}:${Deno.env.get('NIMBA_SECRET')}`);
  const res = await fetch(NIMBA_URL, {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to: [phone.replace('+', '')],
      sender_name: Deno.env.get('NIMBA_SENDER') ?? 'ZAYA',
      message: `ZAYA : votre code de vérification est ${event.sms.otp}. Ne le communiquez à personne.`,
    }),
  });
  const body = await res.json().catch(() => ({}));
  await admin.from('sms_log').insert({
    phone_hash: phoneHash,
    status: res.ok ? 'sent' : `error_${res.status}`,
    cost_gnf: res.ok ? unitCost : 0,
    provider_ref: body?.messageid ?? null,
  });
  if (!res.ok) return hookError(502, "Le SMS n'a pas pu être envoyé");
  return new Response(JSON.stringify({}), { status: 200, headers: { 'Content-Type': 'application/json' } });
});
