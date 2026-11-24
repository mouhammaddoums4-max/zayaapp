-- 0034 : publicités Google (bannières, interstitiels) et réglages publicitaires de chaque membre, décidés par le serveur.
-- Régie v1 §2.1 (formats AdMob), §9.2 (gestion AdMob depuis l'administration), §1 (Premium ne supprime pas
-- automatiquement les publicités). Tout reste désactivé tant que le compte éditeur AdMob n'est pas validé
-- (ads_admob_enabled = false) et que les identifiants de blocs ne sont pas saisis.

insert into app_config (key, value, description, is_public) values
  ('admob_interstitial_unit_android', '""', 'Identifiant du bloc d''annonces interstitielles AdMob (Android)', true),
  ('ads_banner_placements', '["explore", "community", "profile"]',
   'Écrans où une bannière Google peut apparaître (jamais dans les conversations)', true),
  ('ads_interstitial_every_swipes', '0',
   'Interstitiel Google après N actions de swipe (0 = jamais)', true),
  ('ads_interstitial_min_minutes', '10', 'Délai minimal entre deux interstitiels Google pour un membre', true),
  ('ads_explore_every', '8', 'Une carte « Sponsorisé » toutes les N cartes dans Explorer', true),
  ('ads_admob_non_personalized', 'true',
   'Demander des annonces Google non personnalisées (aucun profilage publicitaire)', true)
on conflict (key) do nothing;

-- Réglages publicitaires effectifs pour le membre connecté : l'application n'a qu'à suivre ce que le serveur décide
-- (activation, règle Premium, emplacements, rythme, identifiants des blocs).
create function my_ad_settings() returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (
    select auth.uid() as id,
           (not is_premium(auth.uid()) or cfg_bool('ads_show_to_premium', true)) as allowed
  )
  select case when me.id is null then jsonb_build_object('direct', false, 'admob', false) else jsonb_build_object(
    'direct', me.allowed and cfg_bool('ads_direct_enabled', false),
    'admob', me.allowed and cfg_bool('ads_admob_enabled', false),
    'non_personalized', cfg_bool('ads_admob_non_personalized', true),
    'community_every', greatest(cfg_int('ads_community_every', 6), 2),
    'explore_every', greatest(cfg_int('ads_explore_every', 8), 2),
    'banner_placements', coalesce((select value from app_config where key = 'ads_banner_placements'), '[]'::jsonb),
    'banner_unit_android', coalesce((select value #>> '{}' from app_config where key = 'admob_banner_unit_android'), ''),
    'interstitial_unit_android',
      coalesce((select value #>> '{}' from app_config where key = 'admob_interstitial_unit_android'), ''),
    'interstitial_every_swipes', greatest(cfg_int('ads_interstitial_every_swipes', 0), 0),
    'interstitial_min_minutes', greatest(cfg_int('ads_interstitial_min_minutes', 10), 1)) end
  from me;
$$;

revoke execute on function my_ad_settings() from public, anon;
grant execute on function my_ad_settings() to authenticated;
