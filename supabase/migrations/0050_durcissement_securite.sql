-- ZAYA — Durcissement de la sécurité (demande du propriétaire, 18/11/2026).
--
-- Audit en lecture seule de la base de préproduction (18/11/2026) :
--   • toutes les tables du schéma public ont la RLS activée ; anon n'a aucun droit sur les tables ;
--   • toutes les fonctions security definer fixent leur search_path ; aucune vue ne contourne la RLS ;
--   • les fonctions d'administration vérifient le rôle (auth_is_staff → FORBIDDEN) ; la Communauté passe par
--     community_guard ; les buckets de photos et de vérification sont privés (selfies lisibles par la modération
--     seulement), seul ad-media (visuels publicitaires) est public ;
--   • une seule fonction privilégiée restait exécutable par anon : guard_advanced_filters (0025), une fonction de
--     déclencheur, sans risque réel (elle ne s'appelle pas directement), fermée ici par principe.
-- Les autres mesures de cette demande sont dans 0051 (liens et limite de fréquence dans la messagerie) et dans
-- l'application Android (anti-capture, pas de sauvegarde des données, pas de trafic non chiffré).

revoke execute on function guard_advanced_filters() from public, anon, authenticated;
