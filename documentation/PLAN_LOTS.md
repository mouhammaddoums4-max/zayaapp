# Plan des lots — ZAYA

Suivi demandé par [AGENTS.md](../AGENTS.md) : lot en cours, critères d'acceptation, ce qui est vérifié et ce qui ne
l'est pas. Lots et priorités : cahier des charges V6.4 §22.18 (lots A à D), §17 (phases) et §37 (à livrer avant
l'ouverture publique). Décisions en attente : [DECISIONS_A_CONFIRMER.md](DECISIONS_A_CONFIRMER.md).
Écrans : [CARTE_ECRANS.md](design/CARTE_ECRANS.md).

Mis à jour le 17/11/2026.

**Statuts.** *Vérifié* : un test automatique a été exécuté et a réussi (cité dans la colonne Preuve).
*Non vérifié* : réalisé, mais jamais essayé dans la condition indiquée (vrai serveur, vrai téléphone…).
*À faire* : pas commencé. *Bloqué* : attend une décision ou un accès.

## 1. Où en est-on

- **Lot en cours : A** (indispensable avant l'ouverture). Étape actuelle : mise en route sur la préproduction et
  premier essai de l'application connectée sur un téléphone Android.
- **Dernière vérification complète** (17/11/2026, commit `1a90ab6`) : `flutter analyze` sans problème,
  `flutter test` 51 réussis, tests SQL 66 réussis. Depuis : outil de préproduction ajouté, tests SQL 67 réussis.
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
| Fonctions serveur appelées par l'application | Les 43 existent dans les migrations installées (contrôle du code) |
| Connexion par téléphone | **Activée** le 17/11/2026 avec l'accord du propriétaire, avec deux numéros de test, sans aucun envoi : 224620000001 et 224620000002, code 123456, valables jusqu'au 31/01/2027. Vérifié par appel réel : code demandé, session ouverte avec 123456, mauvais code refusé ; ensuite profil vide (l'application ouvrira l'inscription), villes lisibles, profils des autres invisibles |
| Envoi réel du code aux autres numéros | Non configuré (décision B3) : ces numéros ne reçoivent rien |
| Application connectée installée sur un téléphone | Non vérifié (première construction Android en cours) |

## 2. Lot A — indispensable avant l'ouverture

Critères d'acceptation : cahier des charges §18 (tests fonctionnels), §36 et §42 (critères V6.3 et V6.4).

| # | Bloc | Statut | Preuve | Reste à faire |
|---|---|---|---|---|
| A1 | Socle : dépôt GitHub, application Flutter (Android d'abord, iOS compatible), migrations `0001` à `0006`, fichier d'installation unique, tests | Vérifié | 67 tests SQL, 51 tests Flutter | Intégration continue (§17, phase 1) ; build iOS jamais lancé (pas de Mac) ; branches `lot/<nom>` et relecture Codex (jusqu'ici, tout est poussé sur `main`) |
| A2 | Connexion par téléphone et code | Vérifié sur le serveur avec un numéro de test ; non vérifié dans l'application sur téléphone | Appel réel à la préproduction (§1) ; mode démo : code incorrect refusé | Envoi réel du code (B3) ; essai depuis l'application ; compte à rebours avant renvoi du code (§9) ; récupération du compte (CARTE_ECRANS, Q2) |
| A3 | Inscription et consentements : 18 ans minimum, reprise du brouillon, conditions jamais restaurées | Vérifié | SQL : moins de 18 ans refusé, consentements non modifiables, date de naissance et genre figés. Flutter : parcours d'inscription, contrôle de majorité | Textes juridiques définitifs (B1) |
| A4 | Profil, photos, données sensibles à part (`profile_sensitive`) | Vérifié côté serveur ; envoi réel de photos non vérifié | SQL : confession d'autrui illisible, photos privées masquées, auto-approbation des photos interdite | Essai d'envoi de photos sur le vrai stockage |
| A5 | Vérification de profil | Vérifié côté serveur | SQL : consentement biométrique exigé, décision réservée à l'équipe. Flutter : impossible avant 3 photos | Écran de revue dans la console (A12) ; prestataire (B2). En attendant, outil de préproduction (§4) |
| A6 | Découverte et filtres réciproques (genre, âge, confession) | Vérifié | SQL : éligibilité, filtre de confession réciproque, profil sans confession, âge réciproque, profils non vérifiés ou en pause exclus | Essai sur Android d'entrée de gamme et réseau lent (A16) |
| A7 | Likes et Match réciproque ; quota quotidien côté serveur | Vérifié | SQL : like unilatéral sans match, insertion directe interdite, liste des likes reçus réservée à Premium, quota | — |
| A8 | Messagerie texte entre matchs : contrôle avant envoi, modifier, supprimer pour moi, annuler l'envoi, numéros masqués | Vérifié côté serveur et en démo ; temps réel non vérifié | SQL : 6 tests de messagerie. Flutter : message refusé, modifier / annuler / supprimer, masquage des numéros | Essai entre deux téléphones sur la préproduction |
| A9 | Signalement et blocage | Vérifié | SQL : signalement prioritaire et invisible pour la personne signalée, blocage dans les deux sens, liste et déblocage | Traitement des signalements dans la console (A12) |
| A10 | Confidentialité : pause, suppression avec délai annulable, export | Vérifié | SQL et Flutter : 3 tests chacun | Effacement définitif à la fin du délai (tâche planifiée) |
| A11 | Communauté, phase 1 : fil texte, règles, signalement, blocage, modération (décisions C13 à C16) | Vérifié | SQL : 16 tests. Flutter : 8 tests du mode démo, 3 de détection des coordonnées, 1 parcours complet | Outils de modération dans la console (A12) ; ouverture au public seulement avec une modération en place (C13) |
| A12 | Console de modération (web) | À faire | — | Signalements, vérifications, sanctions, Premium, Communauté, journal d'audit (§37 : avant l'ouverture) |
| A13 | Premium : historique non modifiable et attribution manuelle (V6.4 §40) | Vérifié côté serveur | SQL : 8 tests (droits, motif obligatoire, prolongation, retrait, expiration, audit) | Écrans dans la console (A12) ; paiement : décisions ouvertes |
| A14 | Protection anti-capture des écrans sensibles (Android) | À faire | — | Empêcher les captures sur profils, photos et messagerie ; masquer l'aperçu dans les applications récentes |
| A15 | Site vitrine, FAQ, politiques, assistance | À faire | — | §17, phase 4 (P0/P1) ; dépend de B1 |
| A16 | Essais sur Android d'entrée de gamme et réseau lent ; accessibilité ; charge | À faire | — | Exigé avant l'activation de chaque lot (§22.18) |

## 3. Lots suivants (§22.18)

| Lot | Contenu | Quand | État |
|---|---|---|---|
| B | Visites de profil, Boost, Premium, quotas, notifications pertinentes, console de gestion | Après un pilote fonctionnel | Écrans Boost, Premium et Notifications présents en mode démo ; rien côté serveur (ni Boost, ni visites, ni notifications push) |
| C | Messagerie enrichie, photos modérées, vocaux, appels audio et vidéo, rendez-vous, Zaya AI ; Communauté phase 2 | Déploiement progressif | À faire |
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
4. Console de modération minimale (A12), puis protection anti-capture (A14) et intégration continue (A1).
