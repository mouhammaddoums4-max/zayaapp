// Vérification des rappels SSV d'AdMob (Server-Side Verification), sans dépendance : utilisable par Deno (fonction
// Edge) et par Node (tests). Référence : https://developers.google.com/admob/android/ssv
//
// Google appelle notre URL avec des paramètres de requête, dans cet ordre, les deux derniers étant toujours
// « signature » puis « key_id ». Le message signé est la chaîne de requête qui précède « &signature= ». La signature
// est un ECDSA P-256 / SHA-256 encodé en DER puis en base64 « URL ». Les clés publiques de Google sont publiées sur
// https://www.gstatic.com/admob/reward/verifier-keys.json (format : { keys: [{ keyId, base64, pem }] }).

export type VerifierKey = { keyId: number | string; base64: string };

export type SsvParams = {
  transactionId: string;
  userId: string;
  customData: string;
  adNetwork: string;
  adUnit: string;
  rewardAmount: string;
  rewardItem: string;
};

/** Sépare le message signé, la signature et l'identifiant de clé. Renvoie null si la requête est mal formée. */
export function splitQuery(rawQuery: string): { message: string; signature: string; keyId: string } | null {
  const query = rawQuery.startsWith('?') ? rawQuery.slice(1) : rawQuery;
  const at = query.indexOf('&signature=');
  if (at <= 0) return null;
  const message = query.slice(0, at);
  const tail = new URLSearchParams(query.slice(at + 1));
  const signature = tail.get('signature') ?? '';
  const keyId = tail.get('key_id') ?? '';
  if (!signature || !keyId) return null;
  return { message, signature, keyId };
}

export function base64Decode(input: string): Uint8Array {
  const normal = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normal + '='.repeat((4 - (normal.length % 4)) % 4);
  const bin = atob(padded);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Signature ECDSA DER (SEQUENCE { INTEGER r, INTEGER s }) → format brut r||s de 64 octets attendu par WebCrypto. */
export function derToRaw(der: Uint8Array): Uint8Array {
  if (der.length < 8 || der[0] !== 0x30) throw new Error('DER_INVALIDE');
  let offset = 2;
  if (der[1] & 0x80) offset = 2 + (der[1] & 0x7f);
  const readInt = (): Uint8Array => {
    if (der[offset] !== 0x02) throw new Error('DER_INVALIDE');
    const len = der[offset + 1];
    const value = der.slice(offset + 2, offset + 2 + len);
    offset += 2 + len;
    // Retire le zéro de tête éventuel, puis complète à 32 octets.
    let v = value;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    if (v.length > 32) throw new Error('DER_INVALIDE');
    const padded = new Uint8Array(32);
    padded.set(v, 32 - v.length);
    return padded;
  };
  const r = readInt();
  const s = readInt();
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

/** Vrai seulement si la signature correspond à une clé publiée par Google et au message reçu, octet pour octet. */
export async function verifySsv(rawQuery: string, keys: VerifierKey[], subtle: SubtleCrypto = crypto.subtle): Promise<boolean> {
  const parts = splitQuery(rawQuery);
  if (!parts) return false;
  const key = keys.find((k) => String(k.keyId) === parts.keyId);
  if (!key) return false;
  try {
    const publicKey = await subtle.importKey('spki', base64Decode(key.base64), { name: 'ECDSA', namedCurve: 'P-256' },
      false, ['verify']);
    return await subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, derToRaw(base64Decode(parts.signature)),
      new TextEncoder().encode(parts.message));
  } catch {
    return false;
  }
}

/** Paramètres utiles d'un rappel déjà vérifié. */
export function readParams(rawQuery: string): SsvParams {
  const p = new URLSearchParams(rawQuery.startsWith('?') ? rawQuery.slice(1) : rawQuery);
  return {
    transactionId: p.get('transaction_id') ?? '',
    userId: p.get('user_id') ?? '',
    customData: p.get('custom_data') ?? '',
    adNetwork: p.get('ad_network') ?? '',
    adUnit: p.get('ad_unit') ?? '',
    rewardAmount: p.get('reward_amount') ?? '',
    rewardItem: p.get('reward_item') ?? '',
  };
}
