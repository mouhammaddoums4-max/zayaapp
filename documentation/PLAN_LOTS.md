# Plan des lots — ZAYA

Suivi demandé par [AGENTS.md](../AGENTS.md) : lot en cours, critères d'acceptation, ce qui est vérifié et ce qui ne
l'est pas. Lots et priorités : cahier des charges V6.4 §22.18 (lots A à D), §17 (phases) et §37 (à livrer avant
l'ouverture publique). Décisions en attente : [DECISIONS_A_CONFIRMER.md](DECISIONS_A_CONFIRMER.md).
Écrans : [CARTE_ECRANS.md](design/CARTE_ECRANS.md).

Mis à jour le 22/11/2026.

**Statuts.** *Vérifié* : un test automatique a été exécuté et a réussi (cité dans la colonne Preuve).
*Non vérifié* : réalisé, mais jamais essayé dans la condition indiquée (vrai serveur, vrai téléphone…).
*À faire* : pas commencé. *Bloqué* : attend une décision ou un accès.

## 1. Où en est-on

- **Lot en cours : A** (indispensable avant l'ouverture). Étape actuelle : mise en route sur la préproduction et
  premier essai de l'application connectée sur un téléphone Android.
- **Dernière vérification complète** (17/11/2026, commit `05dce78`) : `flutter analyze` sans problème,
  `flutter test` 63 réussis, tests SQL 81 réussis.
- Les tests SQL tournent sur PGlite (PostgreSQL en mémoire) avec une émulation de Supabase : ils prouvent les règles
  d'accès (RLS, fonctions `security definer`), **pas** le fonctionnement sur le vrai projet. Les tests Flutter
  utilisent le mode démo (aucun serveur).

### Préproduction (projet Supabase `wocgmmwwopzrgleeevof`, décision B5)

Le projet s'appelle « zaya-production » dans le tableau de bord, mais il sert de préproduction tant qu'aucun vrai
membre n'est inscrit. Avant l'ouverture : créer un projet de production distinct, ou retirer les comptes d'essai,
les numéros de test et le rôle de modérateur d'essai.

Constaté le 17/11/2026 :

| Point | État |
|---|---|
| Base installée ([INSTALLATION_SUPABASE.md](INSTALLATION_SUPABASE.md)) | Oui : 9 pays et 18 villes lisibles ; profils et communautés refusés à un visiteur non connecté, comme prévu |
| Migrations | `0001` à `0011` appliquées (0007 et 0009 par la session « photos » ; 0008, 0010 et 0011 le 17/11/2026, sur consigne du propriétaire « toujours pousser vers GitHub et Supabase »). 0008 et 0010 vérifiées par de vrais appels : demande à l'assistance, lecture de ses seules demandes, écriture directe et visiteur refusés, matchs terminés, langues actives |
| Connexion par téléphone | **Activée** le 17/11/2026 avec l'accord du propriétaire, avec deux numéros de test, sans aucun envoi : 224620000001 et 224620000002, code 123456, valables jusqu'au 31/01/2027. Vérifié par appel réel : code demandé, session ouverte avec 123456, mauvais code refusé ; ensuite profil vide (l'application ouvrira l'inscription), villes lisibles, profils des autres invisibles |
| Envoi réel du code aux autres numéros | Non configuré (décision B3) : ces numéros ne reçoivent rien |
| Application connectée installée sur un téléphone | Oui : APK release installé et lancé sur le téléphone du propriétaire (Android 13) le 17/11/2026 ; profil d'essai créé, vérifié, 3 photos |

## 2. Lot A — indispensable avant l'ouverture

Critères d'acceptation : cahier des charges §18 (tests fonctionnels), §36 et §42 (critères V6.3 et V6.4).

| # | Bloc | Statut | Preuve | Reste à faire |
|---|---|---|---|---|
| A1 | Socle : dépôt GitHub, application Flutter (Android d'abord, iOS compatible), migrations `0001` à `0010`, fichier d'installation unique, tests | Vérifié | 80 tests SQL, 61 tests Flutter ; APK release construit | Intégration continue (§17, phase 1) ; build iOS jamais lancé (pas de Mac) ; branches `lot/<nom>` et relecture Codex (jusqu'ici, tout est poussé sur `main`) |
| A2 | Connexion par téléphone et code ; compte à rebours avant renvoi (`app_config.otp_resend_seconds`) | Vérifié sur le serveur et sur téléphone avec un numéro de test | Appel réel à la préproduction (§1) ; profil créé depuis le téléphone ; Flutter : compte à rebours affiché | Envoi réel du code (B3) ; récupération du compte (CARTE_ECRANS, Q2) |
| A3 | Inscription et consentements : 18 ans minimum, reprise du brouillon, conditions jamais restaurées ; nationalité et profession avec recherche (facultatives) ; fin d'inscription vers photos et selfie | Vérifié | SQL : moins de 18 ans refusé, consentements non modifiables, date de naissance et genre figés. Flutter : parcours d'inscription, contrôle de majorité | Textes juridiques définitifs (B1) |
| A4 | Profil, photos, données sensibles à part (`profile_sensitive`) | Vérifié côté serveur ; envoi réel de photos non vérifié | SQL : confession d'autrui illisible, photos privées masquées, auto-approbation des photos interdite | Essai d'envoi de photos sur le vrai stockage |
| A5 | Vérification de profil | Vérifié côté serveur | SQL : consentement biométrique exigé, décision réservée à l'équipe. Flutter : impossible avant 3 photos | Écran de revue dans la console (A12) ; prestataire (B2). En attendant, outil de préproduction (§4) |
| A6 | Découverte et filtres réciproques (genre, âge, confession) | Vérifié | SQL : éligibilité, filtre de confession réciproque, profil sans confession, âge réciproque, profils non vérifiés ou en pause exclus | Essai sur Android d'entrée de gamme et réseau lent (A16) |
| A7 | Likes et Match réciproque ; quota quotidien côté serveur | Vérifié | SQL : like unilatéral sans match, insertion directe interdite, liste des likes reçus réservée à Premium, quota | — |
| A8 | Messagerie texte entre matchs : contrôle avant envoi, modifier, supprimer pour moi, annuler l'envoi, numéros masqués | Vérifié côté serveur et en démo ; temps réel non vérifié | SQL : 6 tests de messagerie. Flutter : message refusé, modifier / annuler / supprimer, masquage des numéros | Essai entre deux téléphones sur la préproduction |
| A9 | Signalement et blocage | Vérifié | SQL : signalement prioritaire et invisible pour la personne signalée, blocage dans les deux sens, liste et déblocage | Traitement des signalements dans la console (A12) |
| A10 | Confidentialité : pause, suppression avec délai annulable, export | Vérifié | SQL et Flutter : 3 tests chacun | Effacement définitif à la fin du délai (tâche planifiée) |
| A11 | Communauté, phase 1 : fil texte, règles, signalement, blocage, modération (décisions C13 à C16) | Vérifié | SQL : 16 tests. Flutter : 8 tests du mode démo, 3 de détection des coordonnées, 1 parcours complet | Outils de modération dans la console (A12) ; ouverture au public seulement avec une modération en place (C13) |
| A12b | Réglages, langue de l'application (FR/EN, langues nationales préparées), aide et assistance, documents légaux, matchs terminés | Vérifié (serveur, démo) ; non vérifié sur téléphone | SQL : 4 tests assistance, 3 tests matchs terminés. Flutter : parcours complet de ces écrans, tests de la langue | Traduire tous les écrans existants avant d'activer l'anglais ; textes en pular, maninka, soussou à écrire et faire relire (§22.15) ; réponses aux demandes dans la console (A12) |
| A12 | Console de modération (web) | À faire | — | Signalements, vérifications, sanctions, Premium, Communauté, journal d'audit (§37 : avant l'ouverture) |
| A13 | Premium : historique non modifiable et attribution manuelle (V6.4 §40) | Vérifié côté serveur | SQL : 8 tests (droits, motif obligatoire, prolongation, retrait, expiration, audit) | Écrans dans la console (A12) ; paiement : décisions ouvertes |
| A14 | Protection anti-capture des écrans sensibles (Android) | À faire | — | Empêcher les captures sur profils, photos et messagerie ; masquer l'aperçu dans les applications récentes |
| A15 | Site vitrine, FAQ, politiques, assistance | En partie : aide, questions fréquentes, demandes à l'assistance et documents légaux dans l'application (A12b) | — | Site vitrine ; textes juridiques définitifs (B1) |
| A16 | Essais sur Android d'entrée de gamme et réseau lent ; accessibilité ; charge | À faire | — | Exigé avant l'activation de chaque lot (§22.18) |

## 3. Lots suivants (§22.18)

| Lot | Contenu | Quand | État |
|---|---|---|---|
| B | Visites de profil, Boost, Premium, quotas, notifications pertinentes, console de gestion | Après un pilote fonctionnel | Fonction/webhook Supabase déployés, secret FCM configuré et un jeton d'appareil précédemment présent. Le client v3 ajoute les journaux d'erreurs, le compteur non lu et le regroupement des alertes ; migration 0065 et redéploiement à faire. Le projet distant s'appelle `zaya-production` et l'auto-review a bloqué la modification distante, bien qu'il soit désigné comme préproduction dans B5. Essai réel sur téléphone à faire ; iOS/APNs reste à configurer. Historique migrations absent ; `db push` interdit jusqu'à réconciliation. |
| C | Messagerie enrichie, photos modérées, vocaux, appels audio et vidéo, rendez-vous, Zaya AI ; Communauté phase 2 | Déploiement progressif | En cours : brouillons locaux, recherche, vocaux, animations/GIFs ZAYA prédéfinis, emojis natifs du clavier, suggestions locales selon le dernier message, jeu de questions et statuts Envoyé/Reçu/Lu/Non lu. Les suggestions ne transmettent pas la conversation à un service externe et ne s'envoient jamais seules. Appels audio/vidéo en haut mais inactifs à la demande. Photo dans le champ de saisie ; envoi bloqué jusqu'à la configuration de la modération. Pièces jointes retirées de la barre. Réactions (6 emojis), réponse à un message citée, copie et repère « Messages non lus » livrés (migration 0066, serveur vérifié ; repère non vérifié sur téléphone). Transfert, archivage et statut « en ligne » restent à traiter (vie privée à confirmer). |
| D | Zaya Shop, packs d'emojis et cadeaux, langues nationales, extension multi-pays | Selon l'adoption et le budget | À faire |

Également prévus après le pilote (§37) : moteur de compatibilité expliqué (§31 ; seuls les points communs, jamais
inventés, sont faits), révélation contrôlée des numéros, détection graduée des risques, Promotions et coupons,
statistiques, rendez-vous sécurisés.

## 4. Prochaines étapes

1. ~~Activer la connexion par téléphone sur la préproduction~~ : fait le 17/11/2026 (numéros de test, §1).
2. **Installer l'application connectée** sur un téléphone Android et faire le parcours complet, avec deux comptes
   d'essai pour le like, le match et la messagerie. Un compte seul ne voit personne dans Découvrir : c'est normal.
3. **Valider la vérification des comptes d'essai** avec
   [`supabase/preproduction/valider_verifications_essai.sql`](../supabase/preproduction/valider_verifications_essai.sql)
   (éditeur SQL de Supabase), tant que la console n'existe pas. Vérifié sur l'émulation (test SQL), non vérifié sur le
   vrai projet. Réservé à la préproduction.
4. ~~Profession, nationalité, fin d'inscription vers les photos, compte à rebours du code~~ : faits le 17/11/2026.
   Restent à arbitrer (CARTE_ECRANS §7.3) : « Comment avez-vous connu ZAYA ? », courant religieux et pratique,
   habitudes de vie.
5. Traduire en anglais tous les écrans existants (environ 800 textes), puis activer l'anglais.
6. Console de modération minimale (A12), puis protection anti-capture (A14) et intégration continue (A1).

## 5. ZAYA 2.0 et demandes du 25/11/2026 (session zaya-app-0d)

État au 25/11/2026. « Vérifié » = tests exécutés et réussis. **En ligne depuis le 25/11/2026** (projet
`wocgmmwwopzrgleeevof`) : mises à jour 0055-0059, 0060-0065 et 0066-0071 appliquées, présence de chaque migration
contrôlée ; fonction Edge `pin-login` déployée avec son secret ; connexion par code activée et essayée de bout en
bout sur un compte d'essai (code accepté, changement imposé, session ouverte). Si une fonction est coupée côté
serveur, l'application masque le bloc ou affiche « arrive bientôt » au lieu d'une erreur.

| Sujet | Migration | État | Tests |
|---|---|---|---|
| Réactions (6 emojis), réponse citée, copie, « Messages non lus », clavier qui ne se ferme plus, « + » et photo masqués pendant la saisie, bulles grises | 0066 | Vérifié (serveur + démo) ; non vérifié sur téléphone | 4 SQL, chat_reactions_test |
| Lot 0 : interrupteurs par fonction, registre de crédits (relié au portefeuille), anti-arnaque (avertissement aux deux), limite de messages sans réponse, score de confiance, doublons de photos | 0067 | Vérifié côté serveur. Empreintes de photos : fonction Edge à brancher | 8 SQL, zaya2_test |
| Lot 1 : Match du jour, Pulse (accord explicite), Invitation (anti-fraude, récompense 0 tant que non fixée) | 0068 | Vérifié (serveur + démo) | 9 SQL, zaya2_test |
| Lot 2 : Questions (visibilité par réponse), Surprise quotidienne, Défis | 0069 | Vérifié (serveur + démo) | 6 SQL, zaya2_test |
| Fleur Premium réellement envoyée, suppression de conversations (pour moi, sélection multiple), point vert « en ligne » | 0070 | Vérifié (serveur + démo) | 6 SQL, messagerie_fleur_test |
| Connexion par numéro + code à 4 chiffres, blocage, code oublié par SMS (5 min), changement du code | 0071 + fonction Edge `pin-login` | Serveur vérifié ; fonction Edge non testée (Deno absent) ; parcours vérifiés en démo | 9 SQL, connexion_code_test |
| Mon profil : mes photos (principale, ajout, suppression), aperçu public | — (RLS existante) | Vérifié en démo | my_profile_test |
| Fond blanc partout, accueil et démarrage allégés, jeux retirés | — | Vérifié (analyse, tests) ; aperçus à refaire | — |

Mise en ligne :
1. ~~Appliquer 0055 à 0071~~ : fait le 25/11/2026 (`supabase/deploy/mise_a_jour_*.sql`, dans l'ordre).
2. ~~Poivre des codes dans Vault (`zaya_pin_pepper`)~~ : créé par `mise_a_jour_0066_0071.sql`.
3. ~~Fonction Edge `pin-login` et secret `PIN_LOGIN_SECRET`~~ : déployés ; `pin_login_enabled = true`.
4. ~~Code 6236 pour les comptes existants (préproduction)~~ : 142 comptes, changement imposé à la connexion.
5. À faire : durée du code SMS à 300 s (Authentication > Providers > Phone > OTP expiry) pour le « code oublié ».
6. À faire : compte 627843030 (aucun compte avec ce numéro) : à créer en s'inscrivant dans l'application ou depuis
   Authentication > Users > Add user (numéro confirmé), puis `select admin_set_member_pin(id, '6236') from auth.users
   where phone = '224627843030';` (la clé de service n'est pas accessible à l'assistant).
7. Fixer les montants de récompense (D8, D10, D11) dans `app_config` quand le propriétaire les aura décidés.
