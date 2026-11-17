# Design system ZAYA (application Rencontre)

## Référence de marque
Logo officiel fourni par le propriétaire : flamme blanche portant un « Z », sur dégradé rose-framboise.
Fichier : `mobile/flutter_app/assets/brand/zaya_logo.png`.

L'interface est **originale** : elle reprend des conventions génériques d'applications mobiles (barre d'onglets inférieure, cartes à glisser avec boutons alternatifs, parcours par étapes avec barre de progression), sans reproduire les écrans, textes, icônes ou couleurs d'un concurrent (cahier des charges §3).

## Couleurs

| Token | Valeur | Usage |
|---|---|---|
| `primary` | `#F5075E` | Actions principales, like, onglet actif (rose-framboise du logo) |
| `primaryDark` | `#C9004A` | État pressé, texte rose sur fond clair (contraste AA) |
| `primarySoft` | `#FFE8F0` | Fonds doux, puces sélectionnées |
| `gradientStart` → `gradientEnd` | `#FF2D55` → `#EC0677` | Dégradé de marque (accueil, écran de match, boutons clés) |
| `ink` | `#1B1020` | Texte principal |
| `muted` | `#6E6475` | Texte secondaire (contraste AA sur blanc) |
| `line` | `#F0E9EE` | Bordures |
| `surface` / `bg` | `#FFFFFF` / `#FFF8FA` | Cartes / fond chaud |
| `verified` | `#1D7FE0` | Badge bleu « Profil vérifié » (§22.8) |
| `premium` | `#C8962E` | Badge Premium (or) — distinct du badge vérifié (§41) |
| `danger` | `#B42318` | Message bloqué, signalement (rouge sombre, distinct du rose de marque) |
| `success` | `#12805C` | Confirmations |

## Typographie
- Titres : **Sora** (600–700), proche des formes rondes du logotype. Corps : **Inter** (400–600).
- Échelle : 32 / 24 / 20 / 17 / 15 / 13 / 11.

## Espacements et formes
- Grille de 4 : 4, 8, 12, 16, 20, 24, 32, 40.
- Rayons : 14 (champs, boutons), 20 (cartes), 28 (carte de découverte), pilule pour les puces.
- Cibles tactiles ≥ 48 × 48 dp.

## Navigation principale (4 onglets)
1. **Découvrir** — cartes de profils (glisser ou boutons ✕ / ♥).
2. **Matchs** — intérêts reçus (compteur gratuit, liste Premium) + matchs.
3. **Messages** — conversations, bouclier de sécurité.
4. **Profil** — mon profil, vérification, centre de confidentialité, abonnements, paiements.

(Onglet Communauté prévu au lot C, après mise en place de la modération.)

## Mouvement
- Durées : 150 ms (micro), 250 ms (transitions), 600 ms max (animation de match).
- `MediaQuery.disableAnimations` respecté : animations réduites à 0.
- Aucune animation ne bloque l'interaction.
