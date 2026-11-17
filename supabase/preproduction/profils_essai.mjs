// ZAYA — outil de PRÉPRODUCTION : 20 femmes et 20 hommes FICTIFS pour essayer Découvrir, les likes et les matchs.
//
// Ces personnes n'existent pas. Leurs photos sont des silhouettes illustrées générées par ce script (aucune
// photo de personne réelle). Les comptes utilisent une adresse e-mail en « .invalid » (domaine réservé, aucun
// message ne peut y être livré) : aucun vrai numéro de téléphone ne peut tomber sur l'un d'eux.
// Chaque compte porte la marque app_metadata.zaya_essai = true, qui permet de tous les supprimer.
//
// ⚠ À SUPPRIMER avant toute ouverture au public (commande « supprimer » ci-dessous) : de faux profils présentés
// à de vrais membres seraient trompeurs.
//
// Usage (la clé service_role ne doit JAMAIS être écrite dans un fichier du projet) :
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<clé> node supabase/preproduction/profils_essai.mjs creer
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<clé> node supabase/preproduction/profils_essai.mjs communaute
//   SUPABASE_URL=https://<ref>.supabase.co SUPABASE_SERVICE_ROLE_KEY=<clé> node supabase/preproduction/profils_essai.mjs supprimer
// « creer » ajoute aussi les publications fictives de la Communauté ; « communaute » les ajoute seules.
// « supprimer » ne touche qu'aux comptes marqués zaya_essai (jamais aux comptes de test par téléphone) ; leurs
// publications, commentaires et réactions disparaissent avec eux.
// La clé se lit dans Supabase → Project Settings → API Keys, ou avec `npx supabase projects api-keys --project-ref <ref>`.
// Relancer « creer » ne crée pas de doublon : les comptes existants sont complétés.
import { deflateSync } from 'node:zlib';

const BASE = (process.env.SUPABASE_URL ?? '').replace(/\/$/, '');
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
const MODE = process.argv[2];
const DOMAINE = 'zaya-essai.invalid';

// ───────────────────────────── Profils fictifs
// [prénom, âge, ville, métier, confession, situation, enfants, horizon, études, taille, langues, centres d'intérêt, bio]
const FEMMES = [
  ['Aïssatou', 27, 'Conakry — Ratoma', 'Santé', 'muslim', 'single', 0, 'few_months', 'Licence', 165, ['Français', 'Poular'], ['Famille', 'Cuisine', 'Lecture'],
    'Infirmière, attachée aux valeurs familiales. Je cherche un homme sérieux et posé, prêt à construire un foyer dans le respect.'],
  ['Mariama', 24, 'Conakry — Matoto', 'Étudiant(e)', 'muslim', 'single', 0, 'medium_term', 'Licence', 160, ['Français', 'Poular', 'Anglais'], ['Lecture', 'Voyages', 'Éducation'],
    'Étudiante en gestion, je termine mon master. J’aimerais rencontrer quelqu’un d’ambitieux et de bienveillant.'],
  ['Fatoumata', 30, 'Conakry — Kaloum', 'Banque / finance', 'muslim', 'single', 0, 'soon', 'Master', 168, ['Français', 'Malinké', 'Anglais'], ['Entrepreneuriat', 'Voyages', 'Famille'],
    'Je travaille dans une banque à Kaloum. Sincère et organisée, je souhaite me marier avec un homme de confiance.'],
  ['Kadiatou', 29, 'Labé', 'Éducation / enseignement', 'muslim', 'single', 0, 'few_months', 'Licence', 162, ['Français', 'Poular'], ['Éducation', 'Traditions', 'Cuisine'],
    'Enseignante à Labé, j’aime transmettre et apprendre. Je cherche un mari croyant, patient et respectueux.'],
  ['Fanta', 26, 'Kankan', 'Commerce', 'muslim', 'single', 0, 'soon', 'Baccalauréat', 158, ['Français', 'Malinké'], ['Entrepreneuriat', 'Cuisine', 'Famille'],
    'Commerçante dynamique, j’ai ma petite boutique. Je veux fonder une famille unie avec un homme travailleur.'],
  ['Hawa', 33, 'Conakry — Dixinn', 'Administration publique', 'muslim', 'divorced', 1, 'few_months', 'Master', 166, ['Français', 'Soussou', 'Malinké'], ['Famille', 'Lecture', 'Bénévolat'],
    'Maman d’une petite fille, je travaille dans l’administration. Je recherche un homme mature, prêt à accueillir une famille.'],
  ['Djénabou', 25, 'Mamou', 'Services', 'muslim', 'single', 0, 'medium_term', 'BTS', 163, ['Français', 'Poular'], ['Musique', 'Nature', 'Cuisine'],
    'Calme et souriante, j’aime la nature du Fouta et les repas en famille. Je prends le temps de bien connaître la personne.'],
  ['Mabinty', 28, 'Conakry — Matam', 'Informatique / télécoms', 'muslim', 'single', 0, 'few_months', 'Licence', 170, ['Français', 'Soussou', 'Anglais'], ['Technologie', 'Sport', 'Voyages'],
    'Développeuse dans une entreprise de télécoms. Je cherche un partenaire curieux avec qui partager projets et valeurs.'],
  ['Saran', 31, 'Kindia', 'Agriculture / élevage', 'muslim', 'single', 0, 'soon', 'BTS', 164, ['Français', 'Soussou', 'Malinké'], ['Nature', 'Entrepreneuriat', 'Famille'],
    'Je gère une exploitation fruitière près de Kindia. Simple et travailleuse, je veux bâtir un foyer solide.'],
  ['Christine', 27, 'N\'Zérékoré', 'Santé', 'christian', 'single', 0, 'few_months', 'Licence', 167, ['Français', 'Guerzé'], ['Musique', 'Bénévolat', 'Famille'],
    'Sage-femme à N’Zérékoré, je chante à la chorale. Je souhaite rencontrer un homme chrétien, sincère et doux.'],
  ['Oumou', 23, 'Conakry — Ratoma', 'Étudiant(e)', 'muslim', 'single', 0, 'medium_term', 'Licence', 159, ['Français', 'Poular'], ['Lecture', 'Éducation', 'Musique'],
    'Étudiante en droit, passionnée de lecture. Je cherche une relation sérieuse, avec le soutien de nos familles.'],
  ['Nènè', 35, 'Conakry — Kaloum', 'Commerce', 'muslim', 'widowed', 2, 'few_months', 'Baccalauréat', 161, ['Français', 'Poular', 'Soussou'], ['Famille', 'Cuisine', 'Traditions'],
    'Veuve et maman de deux enfants, je tiens un commerce de tissus. Je cherche un homme bon et responsable.'],
  ['Rouguiatou', 26, 'Boké', 'Industrie / mines', 'muslim', 'single', 0, 'soon', 'Licence', 169, ['Français', 'Poular', 'Anglais'], ['Sport', 'Voyages', 'Technologie'],
    'Ingénieure dans le secteur minier à Boké. Indépendante, mais très attachée à la famille.'],
  ['Aminata', 29, 'Coyah', 'Artisanat', 'muslim', 'single', 0, 'few_months', 'BTS', 162, ['Français', 'Soussou'], ['Traditions', 'Cuisine', 'Entrepreneuriat'],
    'Couturière, j’ai mon atelier à Coyah. Je cherche un homme honnête qui aime rire et partager.'],
  ['Mariam', 32, 'Conakry — Dixinn', 'Éducation / enseignement', 'muslim', 'single', 0, 'soon', 'Master', 165, ['Français', 'Malinké', 'Arabe'], ['Éducation', 'Lecture', 'Bénévolat'],
    'Professeure de lettres, pratiquante et ouverte d’esprit. Je souhaite me marier et fonder un foyer apaisé.'],
  ['Sira', 24, 'Siguiri', 'Services', 'muslim', 'single', 0, 'medium_term', 'Baccalauréat', 157, ['Français', 'Malinké'], ['Musique', 'Famille', 'Cuisine'],
    'Joyeuse et serviable, j’aime la musique mandingue. Je veux prendre le temps de construire quelque chose de vrai.'],
  ['Bintou', 28, 'Kamsar', 'Transport / logistique', 'muslim', 'single', 0, 'few_months', 'Licence', 166, ['Français', 'Soussou', 'Anglais'], ['Voyages', 'Sport', 'Entrepreneuriat'],
    'Je travaille dans la logistique portuaire. Organisée et franche, je cherche un homme stable et respectueux.'],
  ['Odile', 30, 'Guéckédou', 'Éducation / enseignement', 'christian', 'single', 0, 'few_months', 'Licence', 164, ['Français', 'Kissi'], ['Éducation', 'Nature', 'Bénévolat'],
    'Institutrice, engagée dans ma paroisse. J’aimerais rencontrer un homme de foi pour fonder une famille.'],
  ['Kadi', 27, 'Dubréka', 'Santé', 'muslim', 'single', 0, 'soon', 'Licence', 163, ['Français', 'Soussou'], ['Sport', 'Cuisine', 'Famille'],
    'Pharmacienne, j’aime le sport et les bons plats. Je recherche un homme attentionné et prêt pour le mariage.'],
  ['Hadja', 34, 'Conakry — Matoto', 'Banque / finance', 'muslim', 'divorced', 0, 'few_months', 'Master', 168, ['Français', 'Poular', 'Anglais'], ['Lecture', 'Voyages', 'Entrepreneuriat'],
    'Cadre en microfinance, je sais ce que je veux : une relation respectueuse qui mène au mariage.'],
];

const HOMMES = [
  ['Mamadou', 31, 'Conakry — Ratoma', 'Informatique / télécoms', 'muslim', 'single', 0, 'soon', 'Master', 178, ['Français', 'Poular', 'Anglais'], ['Technologie', 'Sport', 'Famille'],
    'Ingénieur réseau, croyant et posé. Je cherche une femme sérieuse pour fonder un foyer dans la confiance.'],
  ['Alpha', 29, 'Labé', 'Éducation / enseignement', 'muslim', 'single', 0, 'few_months', 'Licence', 175, ['Français', 'Poular'], ['Éducation', 'Lecture', 'Traditions'],
    'Professeur de mathématiques à Labé. J’apprécie la simplicité et les discussions sincères.'],
  ['Ibrahima', 34, 'Conakry — Kaloum', 'Banque / finance', 'muslim', 'single', 0, 'soon', 'Master', 180, ['Français', 'Malinké', 'Anglais'], ['Voyages', 'Entrepreneuriat', 'Lecture'],
    'Analyste financier, stable professionnellement. Je souhaite me marier avec une femme bienveillante et ambitieuse.'],
  ['Ousmane', 27, 'Kindia', 'Commerce', 'muslim', 'single', 0, 'few_months', 'Baccalauréat', 172, ['Français', 'Soussou', 'Poular'], ['Entrepreneuriat', 'Sport', 'Musique'],
    'Commerçant à Kindia, travailleur et souriant. Je veux construire un foyer solide avec la bénédiction de nos familles.'],
  ['Abdoulaye', 36, 'Conakry — Dixinn', 'Santé', 'muslim', 'divorced', 1, 'few_months', 'Doctorat', 177, ['Français', 'Poular', 'Arabe'], ['Famille', 'Lecture', 'Bénévolat'],
    'Médecin et papa d’un garçon. Je recherche une femme mature et patiente pour une nouvelle vie de famille.'],
  ['Thierno', 30, 'Mamou', 'Administration publique', 'muslim', 'single', 0, 'soon', 'Master', 176, ['Français', 'Poular', 'Arabe'], ['Traditions', 'Lecture', 'Famille'],
    'Fonctionnaire à Mamou, pratiquant. Je cherche une épouse croyante, avec qui partager les valeurs du foyer.'],
  ['Sékou', 28, 'Kankan', 'Transport / logistique', 'muslim', 'single', 0, 'few_months', 'BTS', 181, ['Français', 'Malinké'], ['Sport', 'Voyages', 'Musique'],
    'Responsable logistique à Kankan. Franc et fidèle, je veux une relation sérieuse qui mène au mariage.'],
  ['Mohamed', 33, 'Conakry — Matam', 'Bâtiment / BTP', 'muslim', 'single', 0, 'soon', 'Licence', 179, ['Français', 'Soussou', 'Malinké'], ['Entrepreneuriat', 'Sport', 'Famille'],
    'Chef de chantier, j’aime bâtir, au travail comme dans la vie. Je cherche une femme de cœur.'],
  ['Boubacar', 26, 'Conakry — Matoto', 'Étudiant(e)', 'muslim', 'single', 0, 'medium_term', 'Licence', 174, ['Français', 'Poular', 'Anglais'], ['Technologie', 'Lecture', 'Sport'],
    'En fin d’études d’ingénieur. Je prends le temps de rencontrer la bonne personne, avec sérieux.'],
  ['Jean-Paul', 32, 'N\'Zérékoré', 'Agriculture / élevage', 'christian', 'single', 0, 'few_months', 'BTS', 177, ['Français', 'Guerzé'], ['Nature', 'Musique', 'Famille'],
    'Exploitant agricole en Guinée forestière, chrétien engagé. Je souhaite fonder une famille avec une femme sincère.'],
  ['Lansana', 35, 'Boké', 'Industrie / mines', 'muslim', 'single', 0, 'soon', 'Master', 182, ['Français', 'Soussou', 'Anglais'], ['Voyages', 'Technologie', 'Sport'],
    'Ingénieur dans les mines, je suis prêt à m’engager. Je cherche une partenaire de vie honnête et joyeuse.'],
  ['Moussa', 29, 'Siguiri', 'Commerce', 'muslim', 'single', 0, 'few_months', 'Baccalauréat', 173, ['Français', 'Malinké'], ['Musique', 'Famille', 'Cuisine'],
    'Commerçant, j’aime les moments en famille et la musique. Je recherche une femme respectueuse et douce.'],
  ['Amadou', 38, 'Conakry — Kaloum', 'Administration publique', 'muslim', 'widowed', 2, 'few_months', 'Master', 176, ['Français', 'Poular', 'Soussou'], ['Famille', 'Lecture', 'Traditions'],
    'Veuf, papa de deux enfants. Je cherche une femme bienveillante pour reconstruire un foyer heureux.'],
  ['Souleymane', 27, 'Coyah', 'Artisanat', 'muslim', 'single', 0, 'medium_term', 'BTS', 171, ['Français', 'Soussou'], ['Traditions', 'Musique', 'Nature'],
    'Menuisier ébéniste, j’aime le travail bien fait. Patient, je veux une relation solide et sincère.'],
  ['Fodé', 31, 'Dubréka', 'Sécurité', 'muslim', 'single', 0, 'soon', 'Licence', 183, ['Français', 'Soussou', 'Malinké'], ['Sport', 'Famille', 'Bénévolat'],
    'Rigoureux et protecteur, je travaille dans la sécurité. Je souhaite me marier avec une femme de valeur.'],
  ['Cellou', 30, 'Conakry — Ratoma', 'Services', 'muslim', 'single', 0, 'few_months', 'Licence', 175, ['Français', 'Poular', 'Anglais'], ['Voyages', 'Cuisine', 'Entrepreneuriat'],
    'Gérant d’une agence de services. Ouvert et attentionné, je cherche une femme avec qui avancer.'],
  ['Karamoko', 34, 'Faranah', 'Éducation / enseignement', 'muslim', 'single', 0, 'soon', 'Master', 178, ['Français', 'Malinké', 'Arabe'], ['Éducation', 'Lecture', 'Traditions'],
    'Enseignant, pratiquant et attaché à l’instruction. Je recherche une épouse pieuse, curieuse et souriante.'],
  ['Michel', 29, 'Guéckédou', 'Santé', 'christian', 'single', 0, 'few_months', 'Licence', 174, ['Français', 'Kissi'], ['Bénévolat', 'Sport', 'Musique'],
    'Infirmier, engagé dans des actions de santé communautaire. Je cherche une femme chrétienne et sincère.'],
  ['Aboubacar', 25, 'Kamsar', 'Transport / logistique', 'muslim', 'single', 0, 'medium_term', 'BTS', 177, ['Français', 'Soussou', 'Poular'], ['Sport', 'Technologie', 'Voyages'],
    'Technicien au port de Kamsar. Jeune et motivé, je cherche une relation sérieuse.'],
  ['Elhadj', 40, 'Conakry — Dixinn', 'Commerce', 'muslim', 'divorced', 2, 'few_months', 'Baccalauréat', 179, ['Français', 'Poular', 'Arabe'], ['Famille', 'Traditions', 'Entrepreneuriat'],
    'Commerçant établi, père de deux enfants. Je cherche une femme posée pour un mariage dans le respect.'],
];

// ───────────────────────────── Publications fictives de la Communauté (aucune coordonnée, aucune affirmation sur ZAYA)
// [auteur, communauté (slug), type, texte, commentaires [[auteur, texte]…]]
const PUBLICATIONS = [
  ['Fatoumata', 'preparation-mariage', 'question',
    'Pour celles et ceux qui ont déjà franchi le pas : quelles questions vous ont le plus aidés à savoir si vous étiez sur la même longueur d’onde avant les fiançailles ?',
    [['Mamadou', 'Parler très tôt de la gestion de l’argent et du lieu de vie. Ça évite beaucoup de malentendus.'],
      ['Hawa', 'La place des familles dans les décisions. C’est un sujet à aborder franchement, dès le début.']]],
  ['Thierno', 'preparation-mariage', 'advice',
    'Mon conseil : impliquez vos familles au bon moment. Ni trop tôt, pour garder un espace pour vous connaître, ni trop tard, pour que personne ne se sente mis devant le fait accompli.',
    [['Kadiatou', 'Très juste. Chez nous, ce sont les tantes qui ont fait le lien entre les deux familles.']]],
  ['Christine', 'preparation-mariage', 'experience',
    'Notre préparation au mariage à la paroisse nous a beaucoup apporté : parler des valeurs, des enfants, du budget. Je la conseille à tous les couples chrétiens.',
    []],
  ['Kadiatou', 'vie-de-couple', 'question',
    'Comment gérez-vous les désaccords sans que la discussion ne monte ? J’aimerais des conseils concrets.',
    [['Abdoulaye', 'Attendre que la colère retombe avant d’en parler, puis écouter jusqu’au bout sans interrompre.'],
      ['Mariam', 'Se rappeler qu’on est dans la même équipe, pas l’un contre l’autre.']]],
  ['Ibrahima', 'vie-de-couple', 'advice',
    'Prendre dix minutes chaque soir pour se raconter sa journée, même quand on est fatigué. C’est simple, mais ça change tout.',
    [['Fanta', 'Et sans téléphone pendant ces dix minutes !']]],
  ['Aïssatou', 'conseils-experiences', 'experience',
    'Premier rendez-vous dans un salon de thé à Ratoma, avec ma cousine à une table voisine. J’étais plus détendue et la discussion a été naturelle. Je conseille un lieu public et de prévenir un proche.',
    [['Sira', 'Bonne idée, je retiens pour mon premier rendez-vous.']]],
  ['Sékou', 'conseils-experiences', 'advice',
    'Avant de rencontrer quelqu’un, je garde les échanges dans l’application le temps de faire connaissance. Et jamais d’argent envoyé à une personne qu’on n’a pas rencontrée.',
    [['Bintou', 'Merci de le rappeler, c’est essentiel.']]],
  ['Hawa', 'famille-parentalite', 'question',
    'Maman d’une petite fille, je me demande comment présenter un futur conjoint à mon enfant. Des expériences à partager ?',
    [['Amadou', 'Veuf avec deux enfants : nous avons pris le temps, d’abord des sorties en groupe. Les enfants ont besoin de repères.']]],
  ['Amadou', 'famille-parentalite', 'experience',
    'Recomposer une famille demande de la patience. Ce qui nous aide : des règles claires à la maison et beaucoup de dialogue.',
    []],
  ['Mabinty', 'developpement-personnel', 'advice',
    'L’an dernier, j’ai suivi une formation en ligne en informatique. Investir en soi rend plus confiant, y compris dans la vie à deux.',
    [['Boubacar', 'Tu peux partager le nom de la formation ? Ça m’intéresse.']]],
  ['Boubacar', 'developpement-personnel', 'question',
    'Étudiants : comment concilier la fin des études et un projet de mariage ? On attend d’avoir un emploi stable ou on avance ensemble ?',
    [['Oumou', 'Avancer ensemble, avec un plan clair et l’accord des familles.'],
      ['Alpha', 'Un emploi stable rassure les familles, mais ce n’est pas une raison pour tout repousser.']]],
  ['Djénabou', 'evenements-locaux', 'question',
    'Y a-t-il des conférences sur la préparation au mariage à Mamou ou à Labé dans les prochains mois ?',
    [['Kadiatou', 'Je me renseigne à Labé et je te dis.']]],
  ['Cellou', 'questions-reponses', 'question',
    'Quelles questions posez-vous lors d’une première conversation, pour aller au-delà du « ça va ? » ?',
    [['Rouguiatou', 'Ce qui la ou le rend fier dans son travail. On apprend beaucoup sur la personne.'],
      ['Ousmane', 'Comment elle imagine une journée idéale en famille.']]],
  ['Saran', 'langues-regions', 'experience',
    'Une pensée pour les personnes de Basse-Guinée : on se retrouve ici pour échanger en soussou !',
    [['Souleymane', 'Présent ! Coyah répond à l’appel.']]],
  ['Karamoko', 'langues-regions', 'question',
    'Qui parle malinké par ici ? J’aimerais échanger sur les traditions de mariage en Haute-Guinée.',
    [['Moussa', 'Siguiri est là. Les traditions de la dot sont un vrai sujet à partager.']]],
  ['Odile', 'questions-reponses', 'question',
    'Comment parlez-vous de foi et de pratique religieuse quand vous ne partagez pas exactement la même ?',
    [['Michel', 'Avec respect et sans chercher à convaincre. Il faut savoir ce qui est essentiel pour chacun.']]],
];

// ───────────────────────────── Appels à l'API Supabase (clé service_role : contourne RLS, usage serveur uniquement)
async function api(method, path, body, extraHeaders = {}) {
  const headers = { apikey: KEY, Authorization: `Bearer ${KEY}`, ...extraHeaders };
  let payload;
  if (body instanceof Uint8Array) payload = body;
  else if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(BASE + path, { method, headers, body: payload });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path.split('?')[0]} → HTTP ${res.status} : ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}

const upsert = (table, rows, onConflict) =>
  api('POST', `/rest/v1/${table}${onConflict ? `?on_conflict=${onConflict}` : ''}`, rows,
    { Prefer: 'resolution=merge-duplicates,return=minimal' });

async function comptesEssai() {
  const tous = [];
  for (let page = 1; ; page++) {
    const r = await api('GET', `/auth/v1/admin/users?page=${page}&per_page=200`);
    const users = r?.users ?? [];
    tous.push(...users);
    if (users.length < 200) break;
  }
  return tous.filter((u) => u.app_metadata?.zaya_essai === true);
}

// ───────────────────────────── Photos : silhouettes illustrées (PNG généré sans dépendance)
const PALETTES = [
  [[255, 120, 150], [170, 30, 95]], [[255, 170, 130], [205, 70, 100]], [[165, 140, 255], [90, 55, 170]],
  [[100, 200, 195], [30, 105, 125]], [[255, 205, 115], [210, 105, 55]], [[125, 175, 255], [50, 80, 170]],
  [[205, 125, 225], [115, 45, 140]], [[145, 205, 145], [45, 115, 90]],
];

const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

function silhouettePng(palette, decalage) {
  const W = 480, H = 640;
  const [haut, bas] = palette;
  const cx = W / 2 + decalage;
  const lignes = Buffer.alloc((W * 3 + 1) * H);
  const lisse = (d) => Math.min(1, Math.max(0, 0.5 - d / 1.5)); // anticrénelage sur 1,5 px
  const union = (a, b, k) => { // union arrondie de deux formes (raccord doux cou / épaules)
    const h = Math.max(k - Math.abs(a - b), 0) / k;
    return Math.min(a, b) - h * h * k * 0.25;
  };
  for (let y = 0; y < H; y++) {
    const o = y * (W * 3 + 1);
    lignes[o] = 0;
    for (let x = 0; x < W; x++) {
      const t = Math.min(1, (y + x * 0.25) / (H + W * 0.25));
      const tete = Math.hypot(x - cx, y - 310) - 104;
      const cou = Math.max(Math.abs(x - cx) - 46, Math.abs(y - 450) - 50);
      const ex = (x - cx) / 245, ey = (y - 705) / 225;
      const epaules = (Math.sqrt(ex * ex + ey * ey) - 1) * 225;
      const a = lisse(union(tete, union(cou, epaules, 60), 24)) * 0.88;
      for (let c = 0; c < 3; c++) {
        const fond = haut[c] + (bas[c] - haut[c]) * t;
        lignes[o + 1 + x * 3 + c] = Math.round(fond * (1 - a) + 255 * a);
      }
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0);
  ihdr.writeUInt32BE(H, 4);
  ihdr.set([8, 2, 0, 0, 0], 8); // 8 bits, RVB
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(lignes, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ───────────────────────────── Création
function dateNaissance(age, i) {
  const d = new Date(Date.UTC(new Date().getUTCFullYear() - age, new Date().getUTCMonth(), new Date().getUTCDate()));
  d.setUTCDate(d.getUTCDate() - ((i * 37) % 300) - 1);
  return d.toISOString().slice(0, 10);
}

async function creer() {
  const villes = new Map((await api('GET', '/rest/v1/cities?select=id,name&country_code=eq.GN')).map((c) => [c.name, c.id]));
  const metiers = new Map((await api('GET', '/rest/v1/professions?select=id,label_fr')).map((p) => [p.label_fr, p.id]));
  const existants = new Map((await comptesEssai()).map((u) => [u.email, u]));
  const personnes = [
    ...FEMMES.map((p, i) => ({ p, i, genre: 'femme', cherche: 'homme' })),
    ...HOMMES.map((p, i) => ({ p, i, genre: 'homme', cherche: 'femme' })),
  ];
  let crees = 0, completes = 0;

  for (const [n, { p, i, genre, cherche }] of personnes.entries()) {
    const [prenom, age, ville, metier, confession, situation, enfants, horizon, etudes, taille, langues, interets, bio] = p;
    if (!villes.has(ville)) throw new Error(`Ville inconnue dans la base : ${ville}`);
    if (!metiers.has(metier)) throw new Error(`Métier inconnu dans la base : ${metier}`);
    const email = `essai-${genre}-${String(i + 1).padStart(2, '0')}@${DOMAINE}`;

    let user = existants.get(email);
    const nouveau = !user;
    if (nouveau) {
      user = await api('POST', '/auth/v1/admin/users', {
        email, email_confirm: true, app_metadata: { zaya_essai: true }, user_metadata: { profil_essai: true },
      });
    }
    const id = user.id;

    await upsert('profiles', {
      id, account_type: 'candidate', display_name: prenom, birth_date: dateNaissance(age, n), gender: genre,
      seeking_gender: cherche, country_code: 'GN', nationality_code: 'GN', city_id: villes.get(ville),
      marital_status: situation, children_count: enfants, marriage_horizon: horizon, profession_id: metiers.get(metier),
      education_level: etudes, height_cm: taille, languages: langues, interests: interets, bio,
      status: 'active', is_phone_verified: true, verification_status: 'approved', onboarding_step: 99,
      last_active_at: new Date(Date.now() - ((n * 97) % 4000) * 60 * 1000).toISOString(),
    }, 'id');
    await upsert('profile_sensitive', { user_id: id, confession, show_confession: true }, 'user_id');
    await api('POST', '/rest/v1/discovery_preferences?on_conflict=user_id', { user_id: id },
      { Prefer: 'resolution=ignore-duplicates,return=minimal' });
    if (nouveau) {
      await api('POST', '/rest/v1/consents', ['tos', 'privacy', 'community'].map((kind) => (
        { user_id: id, kind, document_version: 'v0-draft', granted: true })), { Prefer: 'return=minimal' });
    }

    // 3 photos approuvées et publiques (minimum de Découvrir)
    const photos = await api('GET', `/rest/v1/profile_photos?select=id&user_id=eq.${id}&moderation=eq.approved`);
    if (photos.length < 3) {
      await api('DELETE', `/rest/v1/profile_photos?user_id=eq.${id}`, undefined, { Prefer: 'return=minimal' });
      const lignes = [];
      for (let k = 0; k < 3; k++) {
        const chemin = `${id}/essai-${k + 1}.png`;
        const png = silhouettePng(PALETTES[(n * 3 + k) % PALETTES.length], [-24, 0, 24][k]);
        await api('POST', `/storage/v1/object/profile-photos/${chemin}`, new Uint8Array(png),
          { 'Content-Type': 'image/png', 'x-upsert': 'true', 'cache-control': '3600' });
        lignes.push({ user_id: id, storage_path: chemin, position: k, visibility: 'public', moderation: 'approved' });
      }
      await api('POST', '/rest/v1/profile_photos', lignes, { Prefer: 'return=minimal' });
    }
    // Retirer des photos repasse la vérification à « à refaire » (trigger) : on la remet à « validée ».
    await api('PATCH', `/rest/v1/profiles?id=eq.${id}`, { verification_status: 'approved', status: 'active' },
      { Prefer: 'return=minimal' });

    if (nouveau) crees++; else completes++;
    console.log(`${nouveau ? '+' : '='} ${genre.padEnd(5)} ${prenom}, ${age} ans, ${ville}`);
  }

  // Contrôle : chaque profil d'essai remplit les conditions de Découvrir
  const ids = (await comptesEssai()).map((u) => u.id);
  const profils = await api('GET', `/rest/v1/profiles?select=id,status,verification_status&id=in.(${ids.join(',')})`);
  const photosOk = await api('GET', `/rest/v1/profile_photos?select=user_id&moderation=eq.approved&visibility=eq.public&user_id=in.(${ids.join(',')})`);
  const nbPhotos = new Map();
  for (const ph of photosOk) nbPhotos.set(ph.user_id, (nbPhotos.get(ph.user_id) ?? 0) + 1);
  const visibles = profils.filter((pr) => pr.status === 'active' && pr.verification_status === 'approved' && (nbPhotos.get(pr.id) ?? 0) >= 3);
  console.log(`\nCréés : ${crees} · complétés : ${completes} · profils d'essai visibles dans Découvrir : ${visibles.length} / ${ids.length}`);
}

// ───────────────────────────── Communauté : publications, commentaires et réactions des profils d'essai
async function communaute() {
  const comptes = await comptesEssai();
  if (!comptes.length) throw new Error('Aucun profil d’essai : lancez d’abord « creer ».');
  const ids = comptes.map((u) => u.id);
  const deja = await api('GET', `/rest/v1/posts?select=id&author_id=in.(${ids.join(',')})&limit=1`);
  if (deja.length) {
    console.log('Communauté : les publications d’essai existent déjà, rien à ajouter.');
    return;
  }
  const profils = await api('GET', `/rest/v1/profiles?select=id,display_name&id=in.(${ids.join(',')})`);
  const parPrenom = new Map(profils.map((p) => [p.display_name, p.id]));
  const auteur = (prenom) => {
    const id = parPrenom.get(prenom);
    if (!id) throw new Error(`Profil d’essai introuvable : ${prenom}`);
    return id;
  };
  const communautes = new Map((await api('GET', '/rest/v1/communities?select=id,slug')).map((c) => [c.slug, c.id]));

  let nPosts = 0, nComs = 0, nReactions = 0;
  for (const [i, [prenom, slug, kind, body, commentaires]] of PUBLICATIONS.entries()) {
    const communityId = communautes.get(slug);
    if (!communityId) throw new Error(`Communauté inconnue : ${slug}`);
    const auteurId = auteur(prenom);
    const quand = Date.now() - (PUBLICATIONS.length - i) * 7 * 3600 * 1000; // étalées sur environ 5 jours
    await api('POST', '/rest/v1/community_members?on_conflict=community_id,user_id',
      { community_id: communityId, user_id: auteurId }, { Prefer: 'resolution=ignore-duplicates,return=minimal' });
    const [post] = await api('POST', '/rest/v1/posts', {
      community_id: communityId, author_id: auteurId, kind, body, created_at: new Date(quand).toISOString(),
    }, { Prefer: 'return=representation' });
    nPosts++;
    for (const [k, [qui, texte]] of commentaires.entries()) {
      await api('POST', '/rest/v1/comments', {
        post_id: post.id, author_id: auteur(qui), body: texte,
        created_at: new Date(quand + (k + 1) * 45 * 60 * 1000).toISOString(),
      }, { Prefer: 'return=minimal' });
      nComs++;
    }
    // Quelques réactions de profils d'essai (nombre et personnes variés, déterministes)
    const reactions = profils.filter((_, k) => (k * 7 + i * 3) % 9 === 0 && profils[k].id !== auteurId)
      .map((p) => ({ post_id: post.id, user_id: p.id }));
    if (reactions.length) {
      await api('POST', '/rest/v1/post_reactions', reactions, { Prefer: 'resolution=ignore-duplicates,return=minimal' });
      nReactions += reactions.length;
    }
  }
  console.log(`Communauté : ${nPosts} publications, ${nComs} commentaires, ${nReactions} réactions ajoutés.`);
}

async function supprimer() {
  const comptes = await comptesEssai();
  for (const u of comptes) {
    for (const bucket of ['profile-photos', 'profile-photos-blur']) { // versions floutées : migration 0009
      const objets = await api('POST', `/storage/v1/object/list/${bucket}`, { prefix: `${u.id}/`, limit: 100 })
        .catch(() => []); // bucket absent si 0009 n'est pas appliquée
      const chemins = (objets ?? []).map((o) => `${u.id}/${o.name}`);
      if (chemins.length) await api('DELETE', `/storage/v1/object/${bucket}`, { prefixes: chemins });
    }
    await api('DELETE', `/auth/v1/admin/users/${u.id}`); // profil, photos, likes, matchs : supprimés en cascade
    console.log(`- ${u.email}`);
  }
  console.log(`\nComptes d'essai supprimés : ${comptes.length}`);
}

if (!BASE || !KEY || !['creer', 'communaute', 'supprimer'].includes(MODE)) {
  console.error('Usage : SUPABASE_URL=… SUPABASE_SERVICE_ROLE_KEY=… node supabase/preproduction/profils_essai.mjs creer|communaute|supprimer');
  process.exit(1);
}
const actions = { creer: async () => { await creer(); await communaute(); }, communaute, supprimer };
await actions[MODE]().catch((e) => {
  console.error(`Erreur : ${e.message}`);
  process.exit(1);
});
