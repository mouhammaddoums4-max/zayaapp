# Carte des écrans — application mobile ZAYA (espace Rencontre)

**Statut : proposition à valider par le propriétaire du projet — 16 novembre 2026, mise à jour le 17 novembre 2026 (cinq onglets, en-tête de Découvrir, conventions du secteur en section 7).**

Complète [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) (couleurs, typographie, espacements). Références : cahier des charges v6.4 (cité « CDC »), fonctions SQL de `supabase/migrations/0002_fonctions.sql`, interface `ZayaRepository`.

> **Origine.** La structure reprend uniquement des conventions génériques des applications mobiles de rencontre : barre d'onglets, cartes à glisser doublées de boutons, inscription par étapes, feuilles inférieures pour les actions courtes, offre payante présentée seulement quand une limite réelle est atteinte. Aucun nom d'écran, texte, visuel, couleur, icône ou dimension d'une application concurrente n'est repris (AGENTS.md, CDC §3).

---

## 1. Navigation

### 1.1 Arborescence

```
Lancement
└─ Aiguillage de session (A01)
   ├─ pas de session ─────► Accueil (A02) ─┬─► Inscription B01 → B12 ─► Vérification (F04) ou Découvrir
   │                                       └─► Connexion téléphone + code (A03) ─► Récupération (A04)
   ├─ suspendu / banni ───► Compte restreint (A05)
   └─ compte actif ───────► Barre d'onglets
        ├─ Découvrir (C01) ─► Filtres (C03) · Notifications (N01) · Boost (P04) · Fiche profil (C02) · Likes épuisés (C04) · Match (C05)
        ├─ Explorer (X01) ──► Sélection (X02) ─► Fiche profil (C02)
        ├─ Likes (D01) ─────► Intérêts reçus (D02) · Visites (D03)
        ├─ Messages (E01) ──► Conversation (E02) ─► Bouclier (E03) · Fiche profil (C02)
        └─ Profil (F01) ────► Modifier (F02) · Photos (F03) · Vérification (F04) · Confidentialité (F06)
                              · Abonnements (F10) · Paiements (F11) · Aide (F12) · Documents légaux (F13)
```

### 1.2 Règles

1. **Cinq onglets** (choix du propriétaire, en place dans le code au 17/11/2026) : Découvrir, Explorer, Likes, Messages, Profil. Les nouveaux matchs apparaissent en tête de Messages. Jamais plus de cinq onglets : la Communauté (lot C) devra trouver sa place sans en ajouter un sixième (Q6).
2. La barre d'onglets n'apparaît que sur les quatre écrans racines. Un écran ouvert depuis un onglet la recouvre. Chaque onglet conserve sa position de défilement.
3. **Bouton retour Android** : écran ouvert → écran précédent ; onglet autre que Découvrir → Découvrir ; Découvrir → sortie de l'application. Dans l'inscription : étape précédente, brouillon conservé (CDC §3, §23.2).
4. **Aiguillage (A01)** selon `profiles.status` :

   | Statut | Destination |
   |---|---|
   | `draft` | Reprise de l'inscription à la dernière étape enregistrée |
   | `active` | Barre d'onglets |
   | `paused` | Barre d'onglets + bandeau « profil en pause — réactiver » |
   | `hidden` | Barre d'onglets + bandeau « profil masqué » ; si une suppression est programmée : date et « Annuler la suppression » |
   | `suspended`, `banned` | Compte restreint (A05) |
   | `deleted` | Déconnexion, retour à l'Accueil |

5. **Mode de présentation** selon la nature de l'action :

   | Présentation | Quand | Exemples |
   |---|---|---|
   | Écran plein | Tâche longue ou lecture | Conversation, fiche profil, filtres, édition, réglages |
   | Feuille inférieure | Action courte, une seule décision | Signaler, bouclier, options d'un message, likes épuisés, offre Premium contextuelle |
   | Dialogue | Action sensible ou irréversible | Bloquer, mettre fin au match, afficher un numéro, supprimer le compte |
   | Superposition | Moment fort, toujours fermable | Animation de match (≤ 600 ms, supprimée si réduction des animations) |
   | Bandeau | État durable non bloquant | Hors ligne, vérification à faire, profil en pause |

6. **Notifications push (lot B)** : nouveau match ou nouveau message → E02 ; décision de vérification → F04 ; sécurité du compte → F06. Aucun contenu privé sur l'écran verrouillé par défaut (CDC §9).
7. **Liens profonds (lot B et suivants)** : un lien de profil partagé ouvre C02 seulement après connexion et contrôle serveur des droits ; sinon page d'atterrissage neutre (CDC §17). Le retour automatique après installation n'est pas annoncé tant qu'il n'est pas testé.

---

## 2. Inventaire des écrans

**Lot** : A = avant ouverture publique ; B = après pilote ; C et D = déploiement progressif (CDC §22.18, §37).
**Serveur** : toute règle d'accès est appliquée par ces fonctions ou par la RLS ; l'écran ne fait qu'afficher le résultat. Les clés `app_config` sont citées avec leur décision de [DECISIONS_A_CONFIRMER.md](../DECISIONS_A_CONFIRMER.md) (C1…C12, B1…B6).

### 2.1 Accès et compte

| ID | Écran | Contenu essentiel | Serveur (RPC · `app_config`) | CDC | Lot |
|---|---|---|---|---|---|
| A01 | Aiguillage de session | Chargement puis redirection (§1.2, règle 4) | `profiles.status` | §3 | A |
| A02 | Accueil | Logo, promesse (relation sérieuse en vue du mariage), « Créer mon profil », « Se connecter », mention 18 ans et plus | — | §3 ét. 1, §23.1 | A |
| A03 | Connexion par téléphone | Numéro (+224 par défaut), code reçu par SMS, délai avant renvoi, modifier le numéro, rappel « le numéro n'apparaît jamais sur le profil » | Auth OTP → hook SMS → Nimba · `sms_monthly_budget_gnf` (0 = envoi bloqué, B3) | §9, §22.9 | A |
| A04 | Récupération du compte | Numéro perdu ou changé : vérification renforcée, puis assistance | À définir (Q2) | §22.9 | A |
| A05 | Compte restreint | Nature, durée et motif compréhensible de la sanction ; « Contester » (réexamen humain) ; accès à l'aide | Table `sanctions` ; pas encore de RPC de lecture ni de recours | §7, §24.2 | A |

### 2.2 Inscription

Une étape par écran : en-tête « Étape n sur N », barre de progression, bouton principal en bas, « Passer » visible sur les étapes facultatives, brouillon sauvegardé à chaque étape. Plusieurs étapes logiques peuvent partager un écran tant qu'il reste court.
Les champs **obligatoires** sont ceux qu'exige `complete_onboarding` : nom d'affichage, date de naissance, genre, genre recherché, pays, ville, consentements, téléphone confirmé. Tout le reste est facultatif et marqué comme tel.

| ID | Étape | Contenu essentiel | Serveur | CDC | Lot |
|---|---|---|---|---|---|
| B01 | Majorité | Confirmation « 18 ans et plus », contrôlée ensuite par la date de naissance (B05) | `profiles_guard` (`AGE_MINIMUM_18`) | §3 ét. 2 | A |
| B02 | Intention | Projet et horizon de mariage | — | §3 ét. 3, §23.2 B | A |
| B03 | Confession (facultative) | Cinq choix, consentement explicite distinct ; stockée à part | `profile_sensitive` (propriétaire seul) | §4.1, §15 | A |
| B04 | Préférences de découverte | Genre recherché, tranche d'âge, préférence confessionnelle (4 modes) ; modifiables ensuite en C03 | `discovery_preferences`, `confession_ok` | §4.2, §22.1 | A |
| B05 | Identité et lieu | Nom d'affichage, date de naissance, genre (C1), pays de résidence (C10), ville | `countries`, `cities` | §23.2 A | A |
| B06 | Situation familiale (facultative) | Situation matrimoniale, enfants, enfants vivant avec le membre | — | §23.2 B | A |
| B07 | Origine (facultative) | Nationalité ; ethnie selon le pays (catalogue administrable, C3), « autre », « je préfère ne pas répondre » ; consentement sensible | `ethnic_groups`, `profile_sensitive` | §23.2 C | A |
| B08 | Activité (facultative) | Profession (liste avec recherche + « autre »), statut d'activité | `professions` | §23.2 D | A |
| B09 | Photos | Au moins `min_profile_photos` (C5), conseils de conformité, ordre, compression avant envoi | `profile_photos`, `photos_guard` | §3 ét. 7, §22.8 | A |
| B10 | Téléphone | Numéro + code (même composant que A03) | Auth OTP | §3 ét. 9 | A |
| B11 | Conditions et consentements | CGU, confidentialité, règles communautaires (version enregistrée) ; consentements facultatifs séparés (marketing) | `legal_documents`, `consents` (append-only) | §22.14 | A |
| B12 | Fin d'inscription | Explique que le profil n'est publié qu'après vérification ; « Vérifier maintenant » → F04, ou « Plus tard » → Découvrir avec bandeau | `complete_onboarding` | §3 ét. 11, §22.8 | A |
| — | Présentation vidéo | Facultative et modérée | — | §3 ét. 8 | C |
| — | Compatibilité | Questionnaire facultatif, complété depuis le profil | — | §23.2 E, §31 | B |

### 2.3 Découvrir (onglet 1)

| ID | Écran | Contenu essentiel | Serveur (RPC · `app_config`) | CDC | Lot |
|---|---|---|---|---|---|
| C01 | Découvrir | En-tête : filtres à gauche ; à droite, likes restants (l'heure de renouvellement s'affiche en C04), notifications (N01) et Boost (P04 : flamme qui s'anime de temps en temps, immobile si le système réduit les animations). Carte : photo principale, prénom, âge, ville, badges, intention. Boutons Passer ✕ et Aimer ♥ (≥ 48 dp) en plus du geste. Bandeau si le profil du membre n'est pas encore publié | `discovery_feed`, `send_like`, `pass_profile`, `my_like_quota` · `free_daily_likes`, `premium_daily_likes`, `likes_reset_hour_utc` (C4) | §6, §22.1, §22.4 | A |
| C02 | Fiche profil | Galerie, présentation, intention et horizon, informations renseignées et visibles, badges dont le détail précise le contrôle effectué, menu Signaler / Bloquer. Lot B : points communs, partage | `get_profile`, `record_profile_view` | §5, §25.3, §41 | A |
| C03 | Filtres | Base gratuite : genre recherché, âge, pays, ville, confession(s). Rayon (5 à 100 km, toute la ville, tout le pays) seulement si la localisation est autorisée, position arrondie. Filtres avancés (Premium) : langues, profession, études, situation, projet de vie, autres pays | `discovery_preferences`, appliquées dans `discovery_feed` | §6, §22.1–22.2 | A (base), B (avancés) |
| C04 | Likes épuisés (feuille) | Quota et heure de renouvellement ; on peut continuer à parcourir et à discuter ; lien Premium seulement si `payments_enabled` | `my_like_quota` · `payments_enabled` (C7) | §22.4 | A |
| C05 | Match (superposition) | Animation courte, deux photos, « Envoyer un message » → E02, « Continuer à découvrir » | Résultat `matched` de `send_like` | §22.10, §13 | A |
| N01 | Notifications | Événements réels seulement (match, message, décision de vérification) ; état vide en attendant les notifications push ; jamais de fausse pastille | FCM au lot B | §9, §22.17 | A (vide), B |

### 2.4 Explorer (onglet 2) et Likes (onglet 3)

| ID | Écran | Contenu essentiel | Serveur | CDC | Lot |
|---|---|---|---|---|---|
| X01 | Explorer | Sélections thématiques construites à partir des réponses réelles et des préférences (horizon de mariage proche, près de chez vous, même langue, mêmes centres d'intérêt, prennent leur temps), avec le nombre de profils de chacune | Mêmes règles serveur que Découvrir : filtres réciproques, blocages, vérification | §22.1, §31 | A |
| X02 | Sélection | Profils d'une sélection, puis « Vous avez tout vu » | Idem X01 | §22.1 | A |
| D01 | Likes | Compteur des intérêts reçus (gratuit, jamais de faux like) ; identités masquées en Gratuit ; « Parcourir les profils » | `received_interests_count` | V3.0 §4.2 | A |
| D02 | Intérêts reçus | Liste nominative ; aimer en retour (match immédiat) ou refuser | `received_interests` (refus serveur `PREMIUM_REQUIRED`) | V3.0 §4.3, §32 | B |
| D03 | Visites du profil | Vues totales et visiteurs uniques sur 7 et 30 jours ; identités seulement en Premium et hors navigation discrète | `my_profile_view_stats` | §22.7 | B |

### 2.5 Messages (onglet 3)

| ID | Écran | Contenu essentiel | Serveur (RPC · `app_config`) | CDC | Lot |
|---|---|---|---|---|---|
| E01 | Conversations | Nouveaux matchs sans message, puis conversations par activité récente, compteur de non-lus | `my_matches` | §25.1 | A |
| E02 | Conversation | En-tête : photo et nom (→ C02, position conservée au retour), bouclier. Info-box de la charte au premier usage. Bulles : envoyé, lu (selon réglages), « Modifié », « Message retiré », refusé par le filtre (rouge, explication, correction possible). Numéros masqués. Saisie limitée à 2 000 caractères | `send_message`, `edit_message`, `unsend_message`, `hide_message`, `mark_conversation_read`, Realtime · `message_edit_window_minutes` (C6) | §24.3, §25, §34.1 | A |
| E03 | Bouclier de sécurité (feuille) | Conseils, Signaler, Bloquer, Mettre fin au match, règles, centre d'aide ; utilisable même hors ligne (envoi mis en file) | `report_user`, `block_user`, `unmatch` | §34.5 | A |
| E04 | Options d'un message (feuille) | Modifier et Annuler l'envoi (dans la fenêtre configurée), Supprimer pour moi, Signaler | `edit_message`, `unsend_message`, `hide_message` | §25.2 | A |
| E05 | Afficher un numéro (dialogue) | Texte de sécurité du CDC §34.2, « Afficher le numéro » / « Annuler » | Aucun : masquage à l'affichage, le texte complet est transmis au client | §34.1–34.2 | A |
| E06 | Mettre fin au match (dialogue) | Explique la différence avec le blocage | `unmatch` | §32 | A |

### 2.6 Sécurité (partagé)

| ID | Écran | Contenu essentiel | Serveur | CDC | Lot |
|---|---|---|---|---|---|
| S01 | Signaler (feuille) | Motifs structurés, précisions facultatives, signalement confidentiel | `report_user` | §7, V2.2 §3.2 | A |
| S02 | Bloquer (dialogue) | Conséquences (fin du match, plus d'interaction), confirmation | `block_user` | §7 | A |

### 2.7 Profil (onglet 4)

| ID | Écran | Contenu essentiel | Serveur (RPC · `app_config`) | CDC | Lot |
|---|---|---|---|---|---|
| F01 | Mon profil | Aperçu de ma carte, complétude (champs facultatifs restants), statut de vérification, badges, accès aux sections | Lecture du profil (RLS propriétaire) | §5, §41 | A |
| F02 | Modifier mon profil | Sections ; chaque ligne ouvre un éditeur selon le type de champ : choix unique, choix multiple, texte court, texte long, date, lieu avec recherche ; visibilité par champ | `profiles` (RLS + `profiles_guard`), `profile_sensitive` | §5, §23.2 | A |
| F03 | Mes photos | Grille ordonnable, ajout, suppression, statut de modération ; alerte avant de passer sous le minimum (badge retiré, profil retiré de la découverte). Lot B : visibilité par photo (publique, floutée, privée) | `profile_photos`, `photos_guard`, `photos_after_change` · `min_profile_photos` (C5) | §22.8, V3.0 §3.3 | A |
| F04 | Vérification | Statut (non demandée, en attente, informations requises, approuvée, refusée, à refaire), consentement biométrique séparé, selfie guidé, demande de réexamen | `request_verification` (`BIOMETRIC_CONSENT_REQUIRED`) ; revue manuelle (B2) | §22.8, §41.2–41.3 | A |
| F05 | Aperçu de mon profil | Tel que le voit un compte Gratuit, puis un compte Premium | `get_profile` + floutage serveur (C12) | V3.0 §3.3 | B |
| F06 | Confidentialité et sécurité | Visibilité (visible, en pause, masqué), navigation discrète, masquer « en ligne », incognito (Q4), comptes bloqués, consentements, mes données, suppression du compte. Plus tard : verrouillage biométrique local, sessions et appareils | Mise à jour du profil (RLS), `profiles.status` | §22.9, V3.0 §6 et §8 | A |
| F07 | Comptes bloqués | Liste, débloquer | `my_blocked_users`, `unblock_user` | V3.0 §6.3 | A |
| F08 | Supprimer mon compte | Différence pause / suppression, délai de rétractation, données conservées pour obligations légales, annulation possible pendant le délai | `request_account_deletion`, `cancel_account_deletion` · `account_deletion_delay_days` | §22.9 | A |
| F09 | Mes données | Export dans un format courant | `export_my_data` | §22.9 | A |
| F10 | Mes abonnements | Offre actuelle, statut, dates, mode d'obtention (achat, offert, partenaire ; un accès offert n'est jamais présenté comme un paiement), historique | `premium_grants` (lecture propriétaire) | §40.1 | A (lecture) |
| F11 | Mes paiements | Liste filtrable ; détail : référence, montant, devise, moyen, statut ; reçu seulement si le paiement est confirmé | `transactions` (lecture propriétaire) | §39.4 | A (lecture) |
| F12 | Aide et assistance | Articles par catégorie, « Cette réponse vous a-t-elle aidé ? », ticket, WhatsApp (masqué si `support_whatsapp` est vide, C9), parcours sécurité prioritaire | `support_whatsapp` ; tickets : table à créer | V5.0 §25 | A (minimum) |
| F13 | Documents légaux | CGU, confidentialité, règles (version acceptée) ; nouvelle acceptation si une version change | `legal_documents`, `consents` | §22.14 | A |
| F14 | Langue | Français / anglais, puis langues nationales après relecture | Réglage local | §22.15 | A |
| F15 | Déconnexion | Confirmation | Auth | — | A |
| F16 | Notifications | Catégories (match, message, likes, visites, sécurité, marketing), heures silencieuses, contenu sur l'écran verrouillé | FCM | §9, V3.0 §6.4 | B |

### 2.8 Premium et achats

| ID | Écran | Contenu essentiel | Serveur | CDC | Lot |
|---|---|---|---|---|---|
| P01 | Premium | Comparatif Gratuit / Premium stable ; durées 7, 30 et 90 jours ; prix, renouvellement, résiliation et remboursement affichés avant paiement. Achat masqué tant que `payments_enabled` = false | `is_premium` · prix C7 | §22.5, V3.0 §4.4 | B |
| P02 | Offre contextuelle (demi-écran) | Seulement après une limite réelle (likes épuisés, filtre avancé, intérêts reçus, autre pays) ; toujours fermable ; « Continuer gratuitement » | Refus serveur `PREMIUM_REQUIRED` | §22.4, §22.17 | B |
| P03 | Paiement | Moyens réellement activés pour le pays, récapitulatif, attente de la confirmation serveur | `transactions` (idempotence) · C8 | §39 | B |
| P04 | Boost | Prix, durée, début, fin, statut ; pas de renouvellement automatique | À créer · prix C7 | §22.6 | B |

### 2.9 Lots C et D (points d'entrée seulement)

| Module | Écrans | CDC | Lot |
|---|---|---|---|
| Communauté (5ᵉ onglet) | Fil et thèmes, explorer, détail d'une communauté, créer une publication, publication et commentaires, favoris, notifications, règles, suivi des signalements | V2.3 §2–3, V6.0 §26 | C |
| Messagerie enrichie | Photos modérées, notes vocales, invitation de rendez-vous avec conseils, cartes de questions, Zaya AI (suggestions validées par le membre), appels | §22.10–22.11, §34.6 | C |
| Cercle de confiance | Invitation d'un proche, permissions détaillées, révocation | §8 (règles à confirmer) | C |
| Projet Mariage, Compatibilité, ZAYA Voice, Academy | Entrées depuis le Profil | V2.2 §1–6 | B–C |
| ZAYA Event | Consultable sans profil de rencontre : entrée dès l'Accueil (A02) | V4.0 §13, §15 | D |
| ZAYA Shop, Conseil matrimonial | Entrées dédiées | V4.0 §14, V6.0 §27 | D |

---

## 3. États communs à tous les écrans

| État | Présentation |
|---|---|
| Chargement | Squelette de la forme du contenu ; seul A01 utilise un indicateur plein écran |
| Vide | `EmptyState` : icône, titre, explication, action utile |
| Erreur réseau | `EmptyState` « Connexion interrompue » + « Réessayer » ; le contenu déjà affiché reste visible |
| Hors ligne | Bandeau persistant ; signalement et blocage mis en file sécurisée (CDC §34.5) |
| Refus du serveur | Message compréhensible associé au code d'erreur (`PREMIUM_REQUIRED`, `EDIT_WINDOW_EXPIRED`, `MATCH_ENDED`…), jamais le code brut |
| Réduction des animations | Durées à 0 (`MediaQuery.disableAnimations`) ; aucune animation ne bloque l'interaction |
| Écran sensible | Protection anti-capture Android (`FLAG_SECURE`) et masquage de l'aperçu multitâche sur C01, C02, D02, E02, F03, F04 et F05 ; l'application explique la limite (une photo de l'écran reste possible) — CDC V2.3 §1, V3.0 §7 |

---

## 4. Composants

### 4.1 Existants

| Composant | Usage |
|---|---|
| `ZayaLogo` | Accueil, aiguillage |
| `VerifiedBadge` | Badge bleu `verified`, infobulle précisant la portée du contrôle |
| `PremiumBadge` | Pastille or `premium`, distincte du badge vérifié |
| `GradientButton` | Action principale de marque |
| `ChoiceTile` | Choix simple ou multiple (inscription, filtres) |
| `ProfileAvatar` | Photo ronde, ou initiale sur dégradé |
| `EmptyState` | États vide et erreur |
| `showZayaSnack` | Confirmation discrète |

Composants propres aux écrans : carte de découverte, boutons ronds Passer / Aimer, squelette de carte, superposition de match et bandeau de vérification (`discovery_screen.dart`) ; encart des intérêts et ligne de match (`matches_screen.dart`).

### 4.2 À créer (partagés)

| Composant | Rôle | Écrans |
|---|---|---|
| Gabarit d'étape | En-tête « Étape n sur N », barre de progression, bouton principal, « Passer » | B01–B12, F04 |
| Ligne de champ de profil | Libellé, valeur ou « Ajouter », mention « facultatif », visibilité | F02 |
| Puce de statut | Statut de vérification, de paiement ou d'abonnement : texte + couleur, jamais la couleur seule | F04, F10, F11 |
| Encadré de sécurité | Conseils réutilisables | E03, E05, rendez-vous |
| Demi-écran d'offre | Offre Premium fermable avec « Continuer gratuitement » | P02 |
| Dialogue de confirmation | Action sensible : libellé explicite, bouton couleur `danger` | S02, E06, F08 |
| Bandeau d'état | Hors ligne, vérification à faire, profil en pause ou masqué | A01, C01 |
| Photo protégée | Affiche la miniature floutée produite par le serveur ; ne floute jamais localement un original | C01, C02, D02 |
| Ligne de réglage | Icône, libellé, valeur, chevron ou interrupteur | F06–F16 |

### 4.3 Dimensions de référence

Valeurs ZAYA issues de DESIGN_SYSTEM.md et de `lib/core/theme.dart` :

- Grille de 4 : 4, 8, 12, 16, 20, 24, 32, 40. Marge latérale : 24 dans l'inscription, 16 au minimum ailleurs.
- Rayons : 14 (champs, boutons, puces de choix), 20 (cartes), 28 (carte de découverte), pilule (badges).
- Cibles tactiles ≥ 48 × 48 dp ; boutons pleine largeur de hauteur 52.
- Barre d'onglets : hauteur 68, fond blanc, indicateur `primarySoft`, icône et libellé actifs `primaryDark`, inactifs `muted`.
- Typographie : Sora 32 / 24 / 20 / 17 pour les titres ; Inter 15 / 13 pour le texte ; 11 pour les badges.

### 4.4 Écarts à harmoniser entre le design system et le code

1. `ZSpace` ne définit ni 20 ni 40, pourtant présents dans la grille du design system.
2. Deux hauteurs de bouton principal coexistent : 52 (`FilledButton`, `OutlinedButton`) et 54 (`GradientButton`).
3. `dangerSoft` existe dans `theme.dart` mais pas dans le tableau des couleurs du design system.
4. Les textes sont écrits directement dans les écrans, alors qu'AGENTS.md demande de les centraliser dans `lib/core/l10n/` (FR puis EN).
5. Contraste (WCAG AA, texte de moins de 19 px en gras) : texte blanc sur `primary` #F5075E = 4,1:1 et sur le dégradé = 3,6 à 4,3:1, sous le seuil de 4,5:1 ; texte blanc 11 px du `PremiumBadge` sur `premium` #C8962E = 2,7:1. Passent : blanc sur `primaryDark` #C9004A (5,9:1), texte `ink` sur or (6,9:1). Réserver `primary` et le dégradé aux surfaces sans petit texte, ou aux titres d'au moins 24 px.
6. Bordure des champs et des puces non sélectionnées en `line` #F0E9EE : 1,2:1 sur blanc, alors que WCAG 1.4.11 demande 3:1 pour repérer un champ. Une bordure #948A99 (3,3:1) suffit.

---

## 5. Correspondance avec le code

État relevé le 16/11/2026 à 14 h 50, complété le 17/11 : `discovery/explore_screen.dart` (X01–X02), `likes/likes_screen.dart` (D01), `profile/` (F01, F02, F04, F06 et préférences C03), `premium/premium_screens.dart` (P01, F10, F11), `notifications/notifications_screen.dart` (N01), `boost/boost_button.dart` (bouton et feuille P04). Une session de développement ajoute des écrans en parallèle.

| Fichier | Écrans couverts |
|---|---|
| `lib/app.dart` (`_RootGate`) | A01 (sans session → Accueil, sinon onglets) |
| `features/onboarding/welcome_screen.dart` | A02 |
| `features/onboarding/phone_login_screen.dart` | A03, B10 |
| `features/onboarding/onboarding_flow.dart` | 7 étapes : B01, B02, B03, B04, B05 (+ situation matrimoniale et présentation), B10, B11 ; brouillon sauvegardé |
| `features/home/home_shell.dart` | Barre d'onglets (4 destinations) |
| `features/discovery/discovery_screen.dart` | C01, C04, C05, bandeau de vérification |
| `features/matches/matches_screen.dart` | D01 |
| `features/chat/conversations_screen.dart` | E01 |
| `features/chat/chat_screen.dart` | E02 (avec info-box), E03, E05, E06 ; E04 sans « Modifier » |
| `features/safety/safety_sheets.dart` | S01, S02 |

---

## 6. Questions ouvertes

À reporter dans [DECISIONS_A_CONFIRMER.md](../DECISIONS_A_CONFIRMER.md) après validation.

| # | Question |
|---|---|
| Q1 | Un membre non vérifié peut-il envoyer des likes ? Aujourd'hui `send_like` exige seulement un profil actif, alors que son propre profil n'est publié qu'après vérification (`is_discoverable`). |
| Q2 | Récupération du compte : e-mail facultatif, pièce justificative ou assistance seule ? Le CDC §23.2 A cite un mot de passe, alors que l'authentification prévue repose uniquement sur le code SMS. |
| Q3 | Visites du profil (D03) : dans l'onglet Likes, à côté des intérêts reçus, ou dans le Profil ? |
| Q4 | Mode incognito : gratuit ou avantage Premium (CDC V3.0 §5.2) ? La navigation discrète (§22.7) est une option distincte. |
| Q5 | Étapes facultatives B06 à B08 : dans l'inscription avec « Passer », ou seulement dans la complétude du profil ? |
| Q6 | Communauté (lot C) : les cinq onglets sont pris. Entrée depuis Explorer ou le Profil, ou remplacement d'un onglet ? Le CDC prévoit de trancher par des tests d'ergonomie. |
| Q7 | Présentation vidéo : dans l'inscription ou seulement dans le profil, selon le coût de modération ? |

---

## 7. Conventions du secteur : retenues et écartées

Relevé fait le 17/11/2026 sur des captures d'écran d'une application de rencontre du même secteur, fournies par le propriétaire du projet. Seules des conventions génériques sont retenues ; le logo, les illustrations, le nom des offres, les couleurs, la typographie et les textes de cette application ne sont pas repris.

### 7.1 Retenues, adaptées à l'identité ZAYA

| Convention | Écrans ZAYA | CDC |
|---|---|---|
| Une question par écran : barre de progression fine, retour à gauche, aide à droite, bouton principal en bas inactif tant que la réponse manque, « Passer » sur les questions facultatives | B01–B12 | §3, §23.2 |
| Date de naissance par roue jour / mois / année, avec l'âge calculé affiché avant de continuer | B01, B05 | §3 ét. 2 |
| Cartes de choix pour l'intention ; puces pour l'horizon (temps pour se connaître, horizon du mariage) | B02 | §23.2 B |
| Liste avec recherche pour la profession | B08 | §23.2 D |
| Mention « n'apparaît pas sur votre profil » sous les questions concernées | B03, B07, B10 | §15 |
| Grille de photos : photo principale signalée, emplacements vides, consignes photo, minimum annoncé | B09, F03 | §22.8 |
| Indicatif pays avec drapeau ; code à 6 chiffres avec compte à rebours avant renvoi | A03, B10 | §9 |
| Écran d'explication avant la demande système d'autorisation des notifications, refus possible | après B11 (lot B) | §9, §22.14 |
| Vérification : photo à comparer, explication, selfie guidé dans un cadre, mention du prestataire | F04 | §22.8, B2 |
| En-tête d'onglet avec les actions à droite (notifications) | C01 | — |
| Conversation : en-tête photo + nom + badge, onglets « Discuter / Profil », messages système (match, fin de match) | E02 | §25.3, §32 |
| Liste des matchs terminés, avec une explication | E01 | §32 |
| Réglages par sections à grands titres ; lignes « valeur + chevron » ; interrupteurs accompagnés d'une phrase | F06–F16 | — |
| Frise d'un éventuel essai gratuit : début, rappel, date du premier débit | P01 | §22.5 |

### 7.2 Écartées, car contraires au cahier des charges

| Pratique observée | Règle ZAYA | CDC |
|---|---|---|
| Compte à rebours « l'offre se termine dans X jours » | Pas de fausse urgence | §22.4, §22.17, §33.2 |
| Chiffres de communauté et de mariages réussis mis en avant | Aucun chiffre non vérifié, aucune promesse | V2.2 §16 |
| Nombre de conversations actives limité, débloqué en payant | La messagerie après un match reste gratuite | V3.0 §5.1, §5.3 |
| Onglet Profil rempli d'offres payantes | Une entrée Premium stable ; offres seulement après une limite réelle | §22.4, §22.5 |
| Payer pour être de nouveau montré à tout le monde | Pas de visibilité payante qui contourne les règles | §22.6, §22.17 |
| Option réservée à un seul genre (bloquer les demandes venant d'un genre) | Toute option vaut pour tous les genres | §22.1 |
| Proche qui reçoit automatiquement une copie des conversations | Accord des deux personnes obligatoire | §8, V6.0 §28 |
| Aperçu du message activé par défaut dans les notifications | Contenu privé masqué par défaut | §9 |
| Messages promotionnels dans la boîte de notifications | Notifications de service et marketing séparées | §9 |

### 7.3 Pistes à confirmer

- Icône d'application discrète, comme option de confidentialité gratuite.
- Masquer son profil aux personnes de son carnet d'adresses (autorisation Contacts, consentement explicite).
- Question facultative « Comment avez-vous connu ZAYA ? » pour mesurer le pilote, à justifier au regard de la minimisation (§15).
- Courant religieux et niveau de pratique : données sensibles (consentement, `profile_sensitive`), à arbitrer avec la liste des confessions (C2).
- Habitudes de vie, par exemple l'alcool, en question facultative.
