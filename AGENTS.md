# AGENTS.md — Règles pour les assistants (Claude Code, Codex)

## À lire avant toute modification
1. `documentation/cahier-des-charges/ZAYA_Cahier_des_charges_v6.4.md` (référence fonctionnelle).
2. `documentation/PLAN_LOTS.md` (lot en cours, critères d'acceptation, statut vérifié / non vérifié).
3. `documentation/DECISIONS_A_CONFIRMER.md` — **ne jamais inventer** une décision listée ici : la rendre configurable (`app_config`) ou la signaler comme bloquante.

## Règles non négociables
- Ne jamais déployer en production ni engager une dépense sans autorisation explicite.
- Ne jamais prétendre qu'un test a réussi s'il n'a pas été exécuté. Distinguer « vérifié » et « non vérifié ».
- Aucun secret (service_role, Nimba, paiement) dans Git ni dans `mobile/`.
- Toute règle d'accès (forfait, visibilité, quota, blocage, match) est vérifiée **côté serveur** (RLS + fonctions `security definer`), jamais uniquement dans l'UI.
- Données sensibles (confession, ethnie, biométrie) : table séparée `profile_sensitive`, consentement explicite, jamais utilisées pour la publicité.
- Ne pas copier les textes, visuels, marques ou interfaces d'un concurrent (cahier des charges §3). S'inspirer uniquement de conventions génériques.
- Historiques financiers et Premium : append-only. Corrections par nouvel événement, jamais par effacement.

## Collaboration
- Claude implémente un lot sur une branche `lot/<nom>` ; Codex relit indépendamment.
- Ne pas modifier simultanément les mêmes fichiers.
- Chaque lot livre : critères d'acceptation, tests, documentation, résumé (terminé / restant / non vérifié).

## Conventions
- SQL : `snake_case`, une migration par sujet, numérotée `NNNN_sujet.sql`. Fonctions `security definer` avec `set search_path = public`.
- Dart : `lowerCamelCase`, fichiers `snake_case.dart`, une feature par dossier `lib/features/<feature>/`.
- Textes UI : centralisés dans `lib/core/l10n/` (FR puis EN). Jamais de numéro WhatsApp, prix ou quota codé en dur : tout vient de `app_config`.
- Design : tokens dans `lib/core/theme/` (référence de marque : `documentation/design/DESIGN_SYSTEM.md`).

## Commandes de vérification
```bash
cd supabase/tests && npm test
cd mobile/flutter_app && flutter analyze && flutter test
```
