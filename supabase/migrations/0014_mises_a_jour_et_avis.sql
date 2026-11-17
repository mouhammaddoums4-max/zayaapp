-- ZAYA — Mises à jour de l'application et demande d'avis sur le store.
-- Tout est réglable sans nouvelle version : l'application lit ces clés publiques au lancement.
--   • latest_app_version : au-dessus de la version installée → proposition de mise à jour (une fois par version).
--   • min_app_version : au-dessus de la version installée → mise à jour obligatoire (écran bloquant), par exemple
--     après une correction de sécurité.
--   • app_update_url : lien de la mise à jour ; vide = fiche Google Play de l'application.
--   • rating_* : la fenêtre d'avis de Google Play n'est proposée que de temps en temps, jamais aux nouveaux membres.

insert into app_config (key, value, description, is_public) values
  ('latest_app_version', '"0.1.0"', 'Dernière version publiée de l''application (proposition de mise à jour)', true),
  ('min_app_version', '"0.1.0"', 'Version minimale acceptée : en dessous, la mise à jour est obligatoire', true),
  ('app_update_url', '""', 'Lien de la mise à jour ; vide = fiche Google Play de l''application', true),
  ('rating_prompt_enabled', 'true', 'Proposer de temps en temps de noter l''application sur le store', true),
  ('rating_min_days', '7', 'Jours depuis la première ouverture avant la première demande d''avis', true),
  ('rating_min_sessions', '5', 'Nombre d''ouvertures de l''application avant la première demande d''avis', true),
  ('rating_interval_days', '90', 'Jours minimum entre deux demandes d''avis', true)
on conflict (key) do nothing;
