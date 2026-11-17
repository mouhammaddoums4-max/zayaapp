# Architecture ZAYA

## Vue d'ensemble

```
┌──────────────────────┐      HTTPS (clé anon + JWT)      ┌───────────────────────────────┐
│ App Flutter          │ ───────────────────────────────▶ │ Supabase                      │
│ Android → iOS → Web  │   RPC (fonctions SQL)            │  • Auth (téléphone + OTP)     │
│ Mode démo hors-ligne │   Realtime (messages)            │  • PostgreSQL + RLS           │
└──────────────────────┘   Storage (URLs signées)         │  • Storage (buckets privés)   │
                                                          │  • Edge Functions (Deno)      │
┌──────────────────────┐                                  └──────────┬────────────────────┘
│ Console admin Next.js│ ── service role côté serveur ──────────────┘   │ Send SMS Hook
│ Site vitrine Next.js │    uniquement (Vercel)                         ▼
└──────────────────────┘                                       ┌────────────────┐
                                                               │ API Nimba SMS  │
                       FCM (push, lot B)                       └────────────────┘
```

## Choix techniques

| Sujet | Choix | Justification |
|---|---|---|
| Mobile | Flutter 3.x, `supabase_flutter`, `go_router` | Une base Android/iOS/Web ; dépendances compatibles iOS. |
| État | `ChangeNotifier` + injection simple | Peu de dépendances, lisible, suffisant pour le MVP. |
| Backend | Supabase (Postgres 15+) | Auth, RLS, Realtime, Storage dans une seule offre gratuite au départ. |
| Logique métier | Fonctions SQL `security definer` appelées en RPC | Les règles (quota, match réciproque, blocage, filtre de messages, Premium) sont appliquées **côté serveur** et testables en SQL. |
| OTP | Supabase Auth Phone + **Send SMS Hook** → Edge Function → Nimba | Nimba n'est pas un fournisseur natif Supabase ; le hook garde la clé Nimba côté serveur, applique plafond et journal des coûts. |
| Médias | Buckets privés `profile-photos`, `profile-photos-blur`, `verification` ; URLs signées courtes | Floutage fabriqué côté serveur (migration 0009, fonction Edge `blur-photos`) : `photo_access()` décide original / flouté / rien pour chaque visiteur, et les règles de stockage refusent l'original à qui n'y a pas droit, même par adresse directe. |
| Fuseau | Calculs en UTC (= heure de Conakry, GMT sans heure d'été) | Référence documentée (V6.4 §40.2) ; affichage local côté client. |

## Modèle de données (lot A + socle V6.4)

- **Référentiels administrables** : `countries`, `cities`, `ethnic_groups` (par pays, versionné), `professions`, `app_config` (quotas, minimum de photos, durées…), `legal_documents`.
- **Profil** : `profiles` (données publiques/structurées), `profile_sensitive` (confession, ethnie — propriétaire seul), `discovery_preferences`, `profile_photos`, `consents` (append-only, version du document).
- **Interactions** : `interests` (like = demande), `passes`, `matches` (créé uniquement par réciprocité), `messages`, `message_hidden` (« supprimer pour moi »), `blocks`, `reports`, `profile_views`.
- **Confiance** : `verification_requests` (téléphone / selfie / identité), `sanctions`, `moderation_terms` (filtre avant envoi).
- **Premium & paiements (V6.4)** : `premium_grants` (achat / attribution admin / partenaire), `premium_events` (append-only), `transactions` + `transaction_events` (idempotence, statuts contrôlés).
- **Administration** : `staff_roles` (super_admin, admin, moderator, support, finance, ads, tech), `audit_log` (append-only, protégé par trigger).

## Règles serveur principales (fonctions RPC)

| Fonction | Règle |
|---|---|
| `discovery_feed()` | Filtres d'éligibilité **réciproques** : 18+, actif, vérifié, non bloqué, non déjà vu, genre recherché mutuel, âge mutuel, pays, préférence confessionnelle mutuelle (profils sans confession non classés arbitrairement), incognito. Gratuit et Premium se découvrent mutuellement. |
| `send_like(target)` | Quota quotidien configurable (Premium : quota élevé anti-abus). Match créé **seulement** si l'autre a déjà liké. |
| `send_message(match, body)` | Match actif, pas de blocage, filtre de termes **avant** insertion : un message non conforme n'est jamais stocké ni transmis. |
| `edit_message` / `unsend_message` | Fenêtre configurable (`message_edit_window_minutes`). |
| `block_user` / `unmatch` / `report_user` | Blocage immédiat + fin du match ; signalement priorisé. Gratuits. |
| `admin_grant_premium` / `admin_revoke_premium` | Rôle requis, motif + origine obligatoires, aucune transaction fictive, événement + audit. |
| `is_premium(user)` | Calculé depuis `premium_grants` actifs : le badge disparaît à l'expiration sans tâche planifiée. |

## Environnements

- **dev** : PGlite (tests) + mode démo Flutter. Données fictives uniquement.
- **staging** : projet Supabase séparé, clés de test Nimba.
- **production** : projet Supabase séparé, secrets séparés, sauvegardes, MFA admin. **Non créé** — nécessite l'accord du propriétaire.

## Messagerie et chiffrement (décision à confirmer)

Le filtrage avant envoi (V5.0 §24.3) et le masquage des numéros (V6.3) exigent que le serveur lise le texte. Le MVP retient donc **chiffrement en transit + au repos (Supabase)**, sans chiffrement de bout en bout. Ne pas annoncer de « chiffrement de bout en bout » (V6.3 §34.7).
