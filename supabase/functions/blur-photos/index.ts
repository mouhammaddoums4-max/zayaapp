// ZAYA — fonction Edge « blur-photos » : fabrique côté serveur la version floutée des photos de profil
// (lot B, migration 0009 ; addendum V6.4 §9 : « l'image originale ne doit jamais être envoyée au client Gratuit »).
//
// Qui peut l'appeler (POST) — la fonction vérifie elle-même l'appelant ; elle se déploie donc avec --no-verify-jwt :
//   • un membre connecté (jeton de session de l'application ; la clé publique seule est refusée) :
//       { "photo_id": "<uuid>" }  floute cette photo si elle n'a pas encore de version floutée : la sienne
//                                 (appel de l'application juste après l'envoi) ou une photo publiée d'un autre membre ;
//       {}                        floute jusqu'à 3 de SES photos qui n'en ont pas encore ;
//   • la tâche planifiée (migration 0057, pg_cron + pg_net), avec l'en-tête x-zaya-cron = secret BLUR_CRON_TOKEN :
//       {}                        rattrapage automatique : jusqu'à 3 photos sans version floutée depuis plus d'une minute ;
//   • l'équipe technique avec la clé service_role : {} = rattrapage immédiat (relancer jusqu'à « traitees: 0 »).
// Un échec est tracé (blur_job_failed) : la tâche planifiée le retente 5 min plus tard, puis 10, 15… (0057).
// Le traitement utilise la clé service_role fournie par la plateforme, qui ne quitte jamais le serveur.
// Résultat : fichier JPEG dans le bucket privé profile-photos-blur, chemin enregistré dans profile_photos.blur_path.
// ImageScript : version Deno (deno.land/x) ; le paquet npm échoue sur Supabase (« unsupported arch/platform »).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { flouterRvba } from './flou.ts';

const LOT = 3; // une photo coûte environ 0,3 s de calcul, limité par Supabase
const AGE_MIN_SECONDES = 60; // la tâche planifiée laisse d'abord l'application demander elle-même la version floutée

type Photo = { id: string; user_id: string; storage_path: string; moderation?: string };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

/** Comparaison en temps constant (un jeton ne se devine pas caractère par caractère). */
function egal(a: string, b: string): boolean {
  if (a.length === 0 || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'Méthode POST attendue' });
  const cleService = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, cleService, { auth: { persistSession: false } });

  // ── Appelant
  const jeton = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  const parTache = egal(req.headers.get('x-zaya-cron') ?? '', Deno.env.get('BLUR_CRON_TOKEN') ?? '');
  const serveur = parTache || egal(jeton, cleService);
  let membre: string | null = null;
  if (!serveur) {
    if (!jeton) return json(401, { error: 'Connexion requise' });
    const { data, error } = await admin.auth.getUser(jeton);
    if (error || !data?.user) return json(401, { error: 'Connexion requise' });
    membre = data.user.id;
  }

  // ── Photos à traiter
  const corps = await req.json().catch(() => ({}));
  const photoId = typeof corps?.photo_id === 'string' ? corps.photo_id : null;
  let photos: Photo[];
  if (photoId) {
    const { data, error } = await admin.from('profile_photos').select('id, user_id, storage_path, moderation')
      .eq('id', photoId).is('blur_path', null).limit(1);
    if (error) return json(500, { error: error.message });
    // Un membre peut demander sa propre photo, ou une photo publiée qu'il consulte ; jamais une photo en attente d'autrui.
    photos = ((data ?? []) as Photo[]).filter((ph) => serveur || ph.user_id === membre || ph.moderation === 'approved');
  } else if (serveur) {
    const { data, error } = await admin.rpc('blur_backlog', {
      p_limit: LOT,
      p_min_age_seconds: parTache ? AGE_MIN_SECONDES : 0,
    });
    if (error) return json(500, { error: error.message });
    photos = (data ?? []) as Photo[];
  } else {
    const { data, error } = await admin.from('profile_photos').select('id, user_id, storage_path')
      .eq('user_id', membre!).is('blur_path', null).limit(LOT);
    if (error) return json(500, { error: error.message });
    photos = (data ?? []) as Photo[];
  }
  if (photos.length === 0) return json(200, { traitees: 0, resultats: [] });

  // Chargement à la demande, après le contrôle de l'appelant : une erreur de la bibliothèque d'images est renvoyée,
  // au lieu de faire planter la fonction.
  let Image: typeof import('https://deno.land/x/imagescript@1.3.0/mod.ts').Image;
  try {
    ({ Image } = await import('https://deno.land/x/imagescript@1.3.0/mod.ts'));
  } catch (e) {
    return json(500, { error: `Bibliothèque d'images indisponible : ${message(e)}` });
  }

  const resultats: { id: string; statut: string; message?: string }[] = [];
  for (const ph of photos) {
    try {
      const { data: fichier, error: e1 } = await admin.storage.from('profile-photos').download(ph.storage_path);
      if (e1 || !fichier) throw new Error(e1?.message ?? 'original introuvable');
      const image = (await Image.decode(new Uint8Array(await fichier.arrayBuffer()))) as InstanceType<typeof Image>;
      const flou = flouterRvba(image.bitmap, image.width, image.height);
      const sortie = new Image(flou.width, flou.height);
      sortie.bitmap.set(flou.data);
      const jpeg = await sortie.encodeJPEG(70);

      const chemin = `${ph.user_id}/${ph.id}.jpg`;
      const { error: e2 } = await admin.storage.from('profile-photos-blur')
        .upload(chemin, jpeg, { contentType: 'image/jpeg', upsert: true });
      if (e2) throw new Error(e2.message);
      const { error: e3 } = await admin.from('profile_photos').update({ blur_path: chemin }).eq('id', ph.id);
      if (e3) throw new Error(e3.message);
      await admin.from('photo_blur_jobs').delete().eq('photo_id', ph.id);
      resultats.push({ id: ph.id, statut: 'floutee' });
    } catch (e) {
      await admin.rpc('blur_job_failed', { p_photo: ph.id, p_error: message(e) });
      resultats.push({ id: ph.id, statut: 'erreur', message: message(e) });
    }
  }
  return json(200, { traitees: resultats.length, resultats });
});
