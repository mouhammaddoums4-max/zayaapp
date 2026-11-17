-- ZAYA — Compatibilité de my_like_quota avec les versions de l'application antérieures à la 0016.
--
-- Ces versions lisent resets_at comme une date toujours présente. Depuis la 0016, my_swipe_quota renvoie
-- resets_at = null tant qu'aucune période n'est commencée (avant le premier swipe). my_like_quota, utilisée par
-- l'application, renvoie donc la fin qu'aurait une période commencée maintenant. my_swipe_quota est inchangée.

create or replace function my_like_quota() returns jsonb
language sql stable security definer set search_path = public as $$
  select q || jsonb_build_object('resets_at',
                                 coalesce(nullif(q -> 'resets_at', 'null'::jsonb),
                                          to_jsonb(now() + make_interval(hours => cfg_int('swipe_window_hours', 8)))))
  from (select my_swipe_quota() as q) s;
$$;
