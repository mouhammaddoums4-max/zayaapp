# ZAYA — Rencontres sérieuses en vue du mariage

Monorepo du projet ZAYA (marché pilote : Guinée / Conakry).
Référence fonctionnelle : [documentation/cahier-des-charges/ZAYA_Cahier_des_charges_v6.4.md](documentation/cahier-des-charges/ZAYA_Cahier_des_charges_v6.4.md).

## Structure

```
ZAYA APP/
├── mobile/flutter_app/     Application Flutter (Android d'abord, compatible iOS)
├── supabase/
│   ├── migrations/         Schéma PostgreSQL, RLS, fonctions métier
│   ├── functions/          Edge Functions (Deno) — ex. hook SMS Nimba
│   ├── seed/               Données de référence (pays, villes, métiers…) — aucune donnée personnelle
│   └── tests/              Tests SQL/RLS exécutables (PGlite, sans Docker)
├── web/                    (Lots suivants) console admin + site vitrine Next.js
├── documentation/          Cahier des charges, architecture, sécurité, plan par lots
├── AGENTS.md               Règles pour Claude Code / Codex
└── README.md
```

## État d'avancement

Voir [documentation/PLAN_LOTS.md](documentation/PLAN_LOTS.md) — chaque lot indique ce qui est **terminé**, **vérifié** et **non vérifié**.

## Démarrage

### 1. Base de données (tests locaux, sans Docker)

```bash
cd supabase/tests
npm install
npm test          # applique toutes les migrations + seed dans un Postgres WASM et vérifie RLS / règles métier
```

### 2. Application mobile

Prérequis : [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) installé **dans un chemin sans espace** (ex. `C:\src\flutter`).

```bash
cd mobile/flutter_app
flutter create . --platforms=android,ios,web --org com.zaya.app   # génère android/ ios/ web/ sans écraser lib/
flutter pub get
flutter run -d chrome          # mode démo (données fictives, aucun backend requis)
flutter test
```

Connexion à un projet Supabase (staging) :

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Sans ces variables, l'application démarre en **mode démo** avec des profils fictifs.

### 3. Supabase (staging)

```bash
supabase link --project-ref <ref-staging>
supabase db push                 # applique supabase/migrations
psql "$DB_URL" -f supabase/seed/seed.sql
supabase functions deploy send-sms-hook
supabase secrets set NIMBA_SERVICE_ID=... NIMBA_SECRET=... NIMBA_SENDER=ZAYA SEND_SMS_HOOK_SECRET=...
```

Aucun déploiement en production ni aucune dépense ne doit être engagé sans accord explicite du propriétaire du projet.

## Sécurité

- Aucun secret dans Git ni dans l'application mobile : seules `SUPABASE_URL` et la clé **anon** (publique, protégée par RLS) sont injectées côté client.
- La clé `service_role` et les clés Nimba / paiement restent dans les secrets Supabase.
- Voir [documentation/securite/SECURITE.md](documentation/securite/SECURITE.md).
