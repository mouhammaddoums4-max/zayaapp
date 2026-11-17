// ZAYA — fonction Edge « blur-photos » : fabrique côté serveur la version floutée des photos de profil
// (lot B, migration 0009 ; addendum V6.4 §9 : « l'image originale ne doit jamais être envoyée au client Gratuit »).
//
// Appels (POST, jeton Supabase valide exigé : la vérification JWT de la plateforme reste active) :
//   { "photo_id": "<uuid>" }  floute cette photo, si elle n'a pas encore de version floutée
//                             (à appeler par l'application juste après l'ajout d'une photo) ;
//   {}                        rattrapage : floute jusqu'à 3 photos qui n'en ont pas encore (relancer jusqu'à
//                             « traitees: 0 ») ; une photo coûte environ 0,3 s de calcul, limité par Supabase.
// Le traitement utilise la clé service_role, fournie par la plateforme, qui ne quitte jamais le serveur.
// Résultat : fichier JPEG dans le bucket privé profile-photos-blur, chemin enregistré dans profile_photos.blur_path.
// ImageScript : version Deno (deno.land/x) ; le paquet npm échoue sur Supabase (« unsupported arch/platform »).
//
// Vérifié le 17/11/2026 sur le projet wocgmmwwopzrgleeevof : déployée, 120 photos floutées ; un membre Gratuit
// reçoit la version floutée et la demande directe de l'original lui est refusée.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { flouterRvba } from './flou.ts';

const LOT = 3;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
const message = (e: unknown) => (e instanceof Error ? e.message : String(e));

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'Méthode POST attendue' });
  // Chargement à la demande : une erreur de la bibliothèque d'images est renvoyée, au lieu de faire planter la fonction.
  let Image: typeof import('https://deno.land/x/imagescript@1.3.0/mod.ts').Image;
  try {
    ({ Image } = await import('https://deno.land/x/imagescript@1.3.0/mod.ts'));
  } catch (e) {
    return json(500, { error: `Bibliothèque d'images indisponible : ${message(e)}` });
  }
  const corps = await req.json().catch(() => ({}));
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  let requete = admin.from('profile_photos').select('id, user_id, storage_path').is('blur_path', null).limit(LOT);
  if (typeof corps?.photo_id === 'string') requete = requete.eq('id', corps.photo_id);
  const { data: photos, error } = await requete;
  if (error) return json(500, { error: error.message });

  const resultats: { id: string; statut: string; message?: string }[] = [];
  for (const ph of photos ?? []) {
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
      resultats.push({ id: ph.id, statut: 'floutee' });
    } catch (e) {
      resultats.push({ id: ph.id, statut: 'erreur', message: message(e) });
    }
  }
  return json(200, { traitees: resultats.length, resultats });
});
