# Demandes du propriétaire — suivi

Demandes faites directement par le propriétaire du projet pendant les sessions de travail, avec leur état et la session
qui s'en occupe. Les deux sessions mettent à jour leurs propres lignes. Le cahier des charges reste la référence : une
demande qui s'en écarte est notée dans [DECISIONS_A_CONFIRMER.md](DECISIONS_A_CONFIRMER.md).

États : **fait** (vérifié : tests passés, poussé, appliqué sur la préproduction) · **en cours** · **à faire** ·
**à confirmer** (une question au propriétaire bloque).

Sessions : **S1** = session « serveur, Découvrir, Likes, Communauté, Discussions » ; **S2** = session « Profil, Réglages,
Explorer, achats, publicité ».

## Faites

| Demande (17/11/2026) | Session | Notes |
|---|---|---|
| Code de connexion par Nimba SMS (WhatsApp écarté) | S1 | Hook prêt ; non déployé : solde SMS Nimba à 0. Connexion par numéros de test en attendant |
| Profils d'essai : 20 femmes + 20 hommes, photos par défaut | S1 | Silhouettes illustrées, comptes `.invalid`, supprimables (`profils_essai.mjs`) |
| Publications par défaut dans la Communauté | S1 | 16 publications, 18 commentaires, 75 réactions |
| 100 profils d'essai de plus (140 au total) | S1 | 70 femmes + 70 hommes, tous visibles dans Découvrir, photos floutées comprises |
| Likes : onglets « Reçus » et « Envoyés » ; compteur aligné sur la liste | S1 | 0024 ; identité des likes reçus réservée à Premium (CDC V3.0 §4.3) |
| Match entre les comptes 620 00 00 01 et 620 00 00 02 | S1 | Créé directement en base (préproduction) |
| Swipes : 50 toutes les 8 h (likes + passages), écran de limite avec compte à rebours et Premium | S1 | 0016, 0026 ; retour arrière : serveur prêt, bouton par S4 |
| Messagerie : le dernier message toujours en bas | S1 | f6aa4c4 |
| Toucher la photo d'une personne pour voir ses photos | S1 | Visionneuse plein écran, zoom, sans enregistrement |
| Floutage des photos (Gratuit : photo principale nette, suivantes floutées) | S1 | Serveur (0009, fonction `blur-photos`) et application (galerie, libellés honnêtes) |
| Photos des autres membres invisibles (bug) | S1 | Corrigé par 0007 |
| Découvrir : logo retiré, Boost puis notifications | S1 | |
| Filtres : point sur l'icône quand un filtre est actif ; encadrés retirés | S1 | |
| Filtre par ville ou commune | S1 | 0012 ; « Tout Conakry », communes, autres villes |
| Barre du téléphone de la couleur de l'application ; accueil en plein écran | S1 | Bord à bord, barres transparentes ; à vérifier sur le téléphone |
| Profil 620 00 00 01 certifié, puis Premium | S1 | Premium jusqu'au 17/11/2027, avec historique et audit |
| Réglages, langue, aide, documents légaux, matchs terminés | S2 | |
| Fin d'inscription, compte à rebours du code, nationalité et profession | S2 | |
| Mise à jour de l'application et avis Google Play | S2 | 0014 |
| Filtres avancés réservés à Premium | S3 | 0025 ; Premium : langues parlées, projet de mariage, situation matrimoniale. Gratuit garde âge, ville/commune, confession. Contrôlé par le serveur (sans Premium : ignorés et non modifiables). Pas de filtre « vérifiés uniquement » : Découvrir ne montre déjà que des profils vérifiés |

## En cours ou à faire

| Demande | Session | État | Notes |
|---|---|---|---|
| Confidentialité des photos : choisir publique / floutée / privée, autoriser une personne précise | S1 | à faire | 0013 ; addendum V6.4 §3.2–3.3 |
| Communauté : mentions @ | S1 | à faire | 0017 |
| Communauté : nombre de vues, publication anonyme | S1 | à faire | 0020 ; anonymat vis-à-vis des membres seulement, jamais de la modération |
| Communauté : photo, GIF, vidéo, appareil photo ; humeur et emoji | S1 | à faire | 0021 ; médias modérés |
| Communauté : création de communauté réservée aux membres Premium | S1 | à faire | 0018 ; validée par la modération avant d'être publique |
| Discussions : écrans d'après les captures (conversations, demande de re-match, nouveaux matchs) | S1 | à confirmer | Voir questions ci-dessous |
| Animations qui « tremblent » | S3 | fait | ebd18b7 (session zaya-app-fa) |
| Sécurité renforcée contre le piratage | S3 | en cours | Audit serveur fait (RLS, fonctions, stockage, secrets : sains) ; 0050 ; Android : anti-capture (FLAG_SECURE, CDC §7), pas de sauvegarde des données. Restent : fonction blur-photos (S1), clé de signature release (décision du propriétaire) |
| Interdiction des liens dans les messages | S3 + S1 | en cours | 0051 (serveur : envoi et modification, catégorie « link », anti-spam 20 messages/minute réglable) ; application : libellé et contrôle avant envoi (S1) |
| Niveau d'études et nombre d'enfants dans le profil, filtres Premium | S3 + S2 | en cours | 0052 (liste des niveaux administrable, filtres) ; inscription (S3), éditeur de profil (zaya-app-ac) |
| Animation de recherche avant les profils (onglet Mariage), photo du membre au centre | S3 + zaya-app-55 | en cours | Widget `radar_search.dart` ; branchement dans l'écran Mariage par zaya-app-55 |
| Mises à jour instantanées (photos, likes, matchs, Premium…) | S3 | à faire | Supabase Realtime dans la session de l'application |
| Application rapide : données chargées avant l'ouverture | S3 | à faire | Préchargement pendant l'écran de démarrage |
| Retirer les « bientôt disponible » et les infos peu utiles | S1 + S2 | à faire | Chaque session sur ses écrans ; on garde les avertissements de sécurité et les mentions légales |
| Écran Profil/Menu d'après les captures, « en mieux » | S2 | en cours | Sans compte à rebours d'offre (addendum V6.4 §1.6) |
| Formules Premium semaine / mois / trimestre, avec des noms ZAYA | S2 | à faire | Prix fixés par l'administration, jamais en dur |
| Partage de profil | S2 | à faire | CDC 17 : lien opaque, durée limitée, révocable |
| Proches (cercle de confiance) | S2 | à faire | CDC §8 |
| Explorer : onglets Pour toi / Événements / Historique, filtre, membres à proximité | S2 | à faire | Consentement de géolocalisation, position approximative |
| Boutique : cadeaux, compliments, emojis | S2 | à faire | Régie publicitaire §6–7 |
| Publicité : AdMob, publicités directes, « Sponsorisé » dans la Communauté, récompenses, portefeuille | S2 | à faire | [Régie publicitaire](cahier-des-charges/ZAYA_Regie_publicitaire_v1.md) ; 0015 |
| Sauvegarde des données, pause, suppression du compte | S2 | à faire | Fonctions serveur déjà présentes |
| Tous les prix (achats, Premium, cadeaux) fixés par l'administration | S2 | à faire | `app_config` / catalogue administrable |

| Messagerie : envoi de photos et notes vocales, emojis dans une bulle | S1 | à faire | Stockage privé et modération |
| Notifications avec son | — | à confirmer | Projet Firebase (Google) nécessaire |
| Lieu détecté automatiquement d’après la position | S2 | à faire | Consentement, position approximative |

## Questions au propriétaire

- **Conversations actives limitées** : les captures montrent « 5 conversations actives à la fois ». Faut-il une limite
  chez ZAYA, et combien (réglable dans `app_config`) ?
- **Onglet « Amis »** dans les discussions : ZAYA est une application de rencontre en vue du mariage ; faut-il vraiment un
  mode « amis » ?
- **Appels audio et vidéo** dans la discussion : service d’appels externe (payant au volume) : lequel, et quand ?
- **Notifications avec son** : créer un projet Firebase (gratuit) au nom de ZAYA ?
