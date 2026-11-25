# Décisions à confirmer par le propriétaire du projet

Tant qu'une décision n'est pas confirmée, elle reste **configurable** (`app_config` ou catalogue administrable) ou est signalée comme **bloquante**. Valeurs actuellement utilisées = valeurs provisoires.

## Bloquantes avant ouverture publique

| # | Décision | Valeur provisoire dans le code | Où la changer |
|---|---|---|---|
| B1 | Nom légal de l'éditeur, statut juridique, textes CGU / confidentialité / règles communautaires | Documents `v0-draft` | `legal_documents` |
| B2 | Prestataire de vérification selfie / identité + politique de conservation biométrique | Revue **manuelle** par un modérateur | `verification_requests` |
| B3 | Code OTP par **Nimba SMS** (confirmé le 17/11/2026, WhatsApp écarté). Compte fourni, expéditeur « Pinal Group » accepté. Reste : crédit SMS (solde 0 le 17/11), coût unitaire réel et plafond mensuel | `sms_monthly_budget_gnf = 0` (envoi bloqué tant que non défini) | `app_config` + secrets `NIMBA_*` ([INSTALLATION_SUPABASE.md](INSTALLATION_SUPABASE.md) §4) |
| B4 | Budget et capacité de modération (délais critique < 2 h…) | SLA du cahier des charges | `app_config.report_sla_hours` |
| B5 | Projet Supabase staging / production (création = engagement) | Projet `wocgmmwwopzrgleeevof` fourni le 17/11/2026, utilisé comme **préproduction** ; production non créée | [INSTALLATION_SUPABASE.md](INSTALLATION_SUPABASE.md) |
| B6 | Chiffrement de la messagerie (E2E incompatible avec le filtrage serveur) | Chiffrement transit + repos, pas d'E2E | Architecture |

## Configurables (non bloquantes)

| # | Décision | Valeur provisoire |
|---|---|---|
| C1 | Catégories de genre du profil | `femme`, `homme` |
| C2 | Liste des confessions et libellés | 5 valeurs du §4.1 |
| C3 | Catalogue ethnies par pays (relu localement) | Guinée : 6 groupes cités au §23.2 + « autre » |
| C4 | Quota de likes gratuits / jour et heure de renouvellement | 20 / 00:00 UTC |
| C5 | Nombre minimum de photos | 3 |
| C6 | Durée d'édition / annulation d'un message | 15 min |
| C7 | Prix Premium (7 / 30 / 90 jours) et Boost | Non définis → achat désactivé (`payments_enabled = false`) |
| C8 | Moyens de paiement actifs par pays | Aucun actif |
| C9 | Numéro WhatsApp officiel du support | Vide → bouton masqué |
| C10 | Pays ouverts | Guinée uniquement |
| C11 | Liste des termes interdits (filtre messagerie) | Liste minimale de démonstration, à compléter par les modérateurs |
| C12 | Visibilité Gratuit des photos (floutage) | Photo principale nette, photos suivantes floutées pour un visiteur Gratuit (`free_clear_photos = 1`) ; Premium : photos publiques nettes ; une photo « floutée » par sa propriétaire reste floutée pour tous. Flou fabriqué côté serveur (migration 0009, fonction `blur-photos`) |
| C13 | Ouverture de la Communauté au public | Ouverte en préproduction (`community_enabled = true`) ; ne l'ouvrir au public qu'avec une modération opérationnelle (CDC V2.3 §4) |
| C14 | Conditions pour publier dans la Communauté | Profil vérifié exigé (`community_post_requires_verification`), 5 publications / 24 h, 20 commentaires / heure ; coordonnées (numéro, e-mail, lien de messagerie) refusées |
| C15 | Identité affichée dans la Communauté | Nom de profil, initiale et badge vérifié ; aucune photo, pour ne pas contourner les règles de visibilité des photos. Pseudonyme : à décider (CDC V2.3 §2.6) |
| C16 | Place de la Communauté dans la navigation | 4ᵉ onglet (Découvrir · Explorer · Messages · Communauté · Profil) ; les likes reçus passent en tête d'Explorer |
| C17 | Annonces Google personnalisées | Non personnalisées (`ads_admob_non_personalized = true`) : aucun profilage publicitaire ; des annonces personnalisées exigeraient un recueil de consentement (formulaire Google UMP) et une revue juridique, données sensibles exclues |
| C18 | Rythme des publicités | Une carte publicitaire toutes les 6 publications de la Communauté et toutes les 8 cartes d'Explorer ; interstitiel Google désactivé (`ads_interstitial_every_swipes = 0`), au plus un toutes les 10 minutes s'il est activé ; jamais dans les messages (migration 0034) |
| C19 | Boîte mystère de bienvenue (tirage aléatoire) | Offerte aux 1 000 premiers membres, gratuite, chances réelles affichées, une ouverture par compte, aucun achat lié (0033). À faire valider par un juriste avant le lancement public (jeux de hasard, publicité des lots) |
| C20 | Photos publiées dès l'envoi | `photo_auto_publish = true` (demande du propriétaire, 0032) : modération a posteriori, retrait par l'équipe avec motif tracé |
| C21 | Boutique de cadeaux et de compliments | Catalogue de départ : rose, thé à la menthe, bouquet, parfum, bague, 3 compliments écrits par l'équipe ; prix par défaut (0036, demandés par le propriétaire le 25/11/2026) : 10, 15, 30, 60 et 150 pièces, compliments 5 pièces, modifiables par l'équipe ; valeur d'une pièce en GNF à fixer avec les paiements ; envoi possible à tout membre actif non bloqué, pas seulement aux matchs ; 20 envois par jour ; aucun texte libre. Payé uniquement en pièces achetées (0035) |
| C22 | Verrouillage de l'application | Code à 4 chiffres, empreinte ou visage, délai au choix (immédiat, 1 min, 5 min) ; un seul code avec la future connexion par code (zaya-app-0d) ; après 5 erreurs, attente de 30 s qui double jusqu'à 15 min |

## ZAYA 2.0 et demandes du 25/11/2026 (valeurs provisoires, toutes dans `app_config`)

Chaque valeur ci-dessous a été choisie par défaut pour que la fonction soit testable ; aucune récompense n'est
promise tant que son montant n'est pas fixé (montant 0 = rien n'est crédité ni annoncé).

| # | Décision | Valeur par défaut | Où |
|---|---|---|---|
| D1 | Interrupteurs des fonctions ZAYA 2.0 | Toutes activées en préproduction (`feature_*_enabled`) ; coupure immédiate côté serveur | 0067 |
| D2 | Messages consécutifs sans réponse | 8 (`max_unanswered_messages`) ; au-delà, refus UNANSWERED_LIMIT | 0067 |
| D3 | Avertissement anti-arnaque | Mobile Money, coordonnées bancaires, investissement, demande d'argent : message transmis avec avertissement aux deux personnes, événement gardé pour la modération (pas de blocage) | 0067 |
| D4 | Score de confiance minimal pour être recommandé | 30 / 100 (`trust_min_for_recommendations`), jamais affiché | 0067 |
| D5 | Photos identiques sur deux comptes | Distance ≤ 6 (`photo_hash_max_distance`) ; signalement à la modération, aucune sanction automatique. L'empreinte doit être calculée par la fonction Edge des photos (à brancher) | 0067 |
| D6 | Pulse : taille minimale d'un groupe statistique | 20 personnes (`pulse_min_group`) | 0068 |
| D7 | Pulse : durée d'apparition d'un nouveau membre | 14 jours, seulement avec son accord (désactivé par défaut) | 0068 |
| D8 | Parrainage : récompense, délai, plafond | 0 swipe (rien n'est promis), 7 jours d'activité du filleul vérifié, 10 par mois puis revue manuelle | 0068 |
| D9 | Domaine des liens d'invitation | Vide : seul le code est partagé (`referral_link_base`) | 0068 |
| D10 | Surprise quotidienne : lots et chances | Une question (100 %) ; lot « swipes » prévu mais inactif, montant 0 | 0069 |
| D11 | Défis : récompenses et plafonds | Montants 0 ; plafonds 3 par jour, 10 par semaine, 6 par appareil et par jour | 0069 |
| D12 | Questions « Mieux se connaître » | 8 questions de départ (famille et enfants marquées sensibles), visibilité « moi seul » par défaut | 0069 |
| D13 | Fleur Premium : nombre par jour | 3 (`flowers_per_day`) ; la destinataire voit l'expéditeur, même sans Premium | 0070 |
| D14 | « Supprimer une conversation » | Pour moi seulement : l'historique disparaît de mon côté, le match reste ; un nouveau message la fait réapparaître | 0070 |
| D15 | Point vert « en ligne » | Actif dans les 5 dernières minutes ; visible seulement par les matchs ; qui masque sa présence ne voit pas celle des autres | 0070 |
| D16 | Connexion par code à 4 chiffres | Numéro vérifié par SMS une seule fois (inscription), puis numéro + code ; 5 erreurs → blocage 15 min ; 30 essais par heure et par adresse IP | 0071 |
| D17 | Code par défaut des comptes existants | 6236, changement obligatoire à la première connexion — **préproduction seulement** (`supabase/preproduction/codes_par_defaut.sql`) : un code connu de tous permet d'ouvrir un compte tant que son titulaire ne l'a pas changé | script |
| D18 | Code oublié | SMS valable 5 minutes (réglage Auth `sms_otp_exp = 300`), nouveau code exigé dans les 5 minutes | 0071 + réglage Auth |
| D19 | Numéro inconnu à la connexion | L'application propose de créer un profil ; l'existence d'un numéro est donc révélée (choix du propriétaire), freiné par 30 vérifications / 10 min par adresse IP | 0071 |
