const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-push-webhook-secret',
};

type Signal = { user_id?: string; kind?: string };

// Signaux qui méritent une alerte sonore ; les autres (photo, Premium, profil, visite, portefeuille) servent seulement
// à synchroniser l'application en temps réel. Textes neutres : aucun nom ni contenu privé sur l'écran verrouillé.
const NOTIFIED_KINDS: Record<string, { title: string; body: string }> = {
  message: { title: 'Nouveau message', body: 'Vous avez reçu un message.' },
  match: { title: 'Nouveau match', body: 'Une nouvelle rencontre vous attend.' },
  like: { title: 'Nouvel intérêt', body: 'Quelqu’un s’intéresse à votre profil.' },
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const hookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!hookSecret || request.headers.get('x-push-webhook-secret') !== hookSecret) {
    return new Response('Unauthorized', { status: 401 });
  }

  let signal: Signal;
  try {
    const payload = await request.json();
    signal = payload.record ?? payload;
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  if (!signal.user_id || !signal.kind) return new Response('Missing signal fields', { status: 400 });
  const content = NOTIFIED_KINDS[signal.kind];
  if (!content) return new Response(null, { status: 204 });

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const accountValue = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!serviceRoleKey || !supabaseUrl || !accountValue) {
    return new Response('Push sender is not configured', { status: 503 });
  }

  try {
    let account: { client_email: string; private_key: string; project_id: string };
    try {
      account = JSON.parse(accountValue);
    } catch {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON');
    }
    if (!account.client_email || !account.private_key || !account.project_id) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON lacks client_email, private_key or project_id');
    }
    const accessToken = await getGoogleAccessToken(account);
    const tokenResponse = await fetch(
      `${supabaseUrl}/rest/v1/member_push_tokens?select=token&user_id=eq.${encodeURIComponent(signal.user_id)}`,
      { headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` } },
    );
    if (!tokenResponse.ok) return new Response('Unable to read device registrations', { status: 502 });
    const devices = (await tokenResponse.json()) as Array<{ token: string }>;

    if (devices.length === 0) {
      console.warn('Push signal has no registered devices');
      return new Response(JSON.stringify({ sent: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const unreadCount = signal.kind === 'message'
      ? await getUnreadMessageCount(supabaseUrl, serviceRoleKey, signal.user_id)
      : undefined;

    const results = await Promise.all(devices.map(({ token }) => fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: content,
            data: { kind: signal.kind },
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: 'zaya_notifications_v3',
                sound: 'default',
              tag: `zaya-${signal.kind}`,
                ...(unreadCount == null ? {} : { notification_count: unreadCount }),
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  ...(unreadCount == null ? {} : { badge: unreadCount }),
                },
              },
            },
          },
        }),
      },
    )));
    const failures: string[] = [];
    for (let i = 0; i < results.length; i++) {
      const result = results[i];
      if (result.ok) continue;
      const providerError = await result.json().catch(() => null) as
        { error?: { status?: string; details?: Array<{ errorCode?: string }> } } | null;
      const code = providerError?.error?.details?.find((d) => d.errorCode)?.errorCode ?? providerError?.error?.status;
      console.error('FCM delivery failed', { httpStatus: result.status, providerStatus: code });
      // Téléphone désinstallé ou jeton périmé : on le retire, il ne recevra plus rien.
      if (code === 'UNREGISTERED' || code === 'INVALID_ARGUMENT') {
        await fetch(`${supabaseUrl}/rest/v1/member_push_tokens?token=eq.${encodeURIComponent(devices[i].token)}`, {
          method: 'DELETE',
          headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` },
        }).catch(() => null);
      }
      failures.push(`${result.status} ${code ?? ''}`.trim());
    }
    if (failures.length === devices.length) {
      return new Response(`FCM refused every device: ${failures.join(', ')}`, { status: 502 });
    }
    return new Response(JSON.stringify({ sent: devices.length - failures.length, failed: failures }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    const reason = error instanceof Error ? error.message : 'Unknown error';
    console.error('Push dispatch failed', reason);
    // Raison sans secret (étape et code d'erreur de Google), lisible dans net._http_response par l'équipe.
    return new Response(`Push dispatch failed: ${reason}`, { status: 502 });
  }
});

async function getUnreadMessageCount(baseUrl: string, serviceRoleKey: string, userId: string): Promise<number> {
  const response = await fetch(`${baseUrl}/rest/v1/rpc/unread_message_count`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ p_user: userId }),
  });
  if (!response.ok) {
    console.error('Unread message count lookup failed', { httpStatus: response.status });
    return 1;
  }
  const count: unknown = await response.json();
  return typeof count === 'number' && Number.isFinite(count) ? Math.max(1, Math.floor(count)) : 1;
}

async function getGoogleAccessToken(account: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: unknown) => base64Url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const binary = Uint8Array.from(atob(pem), (character) => character.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', binary, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    const detail = await response.json().catch(() => null) as { error?: string; error_description?: string } | null;
    throw new Error(`Google OAuth ${response.status} ${detail?.error ?? ''} ${detail?.error_description ?? ''}`.trim());
  }
  const result = await response.json();
  return result.access_token as string;
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
