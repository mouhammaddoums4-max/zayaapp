-- ZAYA — Découvrir : filtres avancés réservés à Premium (demande du propriétaire, 17/11/2026).
--
-- CDC §5.1 : « filtres de base » pour le forfait Gratuit ; §5.2 : « filtres de recherche avancés » pour Premium.
-- Répartition choisie par le propriétaire :
--   • Gratuit (inchangé) : âge, ville ou commune (0012), préférence confessionnelle.
--   • Premium : langues parlées, projet de mariage, situation matrimoniale.
-- Ces trois informations sont demandées à l'inscription et toujours visibles sur la fiche : filtrer dessus ne révèle
-- rien de caché. L'ethnie n'est jamais un filtre (donnée sensible, CDC §23.4). Les études et le nombre d'enfants ne
-- sont pas encore demandés aux membres : pas de filtre tant qu'ils ne le sont pas (il exclurait tout le monde).
--
-- Filtres à sens unique, comme la ville : ils restreignent ce que je vois, sans me cacher aux autres.
-- Contrôle côté serveur, à deux niveaux :
--   1. discovery_feed n'applique les filtres avancés que si le membre est Premium au moment de la recherche :
--      un Premium expiré garde ses réglages (retrouvés s'il se réabonne) mais ils n'ont plus d'effet ;
--   2. un membre Gratuit ne peut pas les définir ni les modifier (il peut seulement les vider).

alter table discovery_preferences
  add column languages text[] not null default '{}',
  add column marriage_horizons marriage_horizon[] not null default '{}',
  add column marital_statuses marital_status[] not null default '{}';

create function guard_advanced_filters() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_old discovery_preferences;  -- reste vide pour une insertion
begin
  -- Service et administration (pas de membre connecté) : pas de contrôle.
  if auth.uid() is null or is_premium(new.user_id) then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    v_old := old;
  end if;
  if (cardinality(new.languages) > 0 and new.languages is distinct from v_old.languages)
     or (cardinality(new.marriage_horizons) > 0 and new.marriage_horizons is distinct from v_old.marriage_horizons)
     or (cardinality(new.marital_statuses) > 0 and new.marital_statuses is distinct from v_old.marital_statuses) then
    raise exception 'PREMIUM_REQUIRED';
  end if;
  return new;
end;
$$;

create trigger discovery_preferences_advanced_filters
  before insert or update on discovery_preferences
  for each row execute function guard_advanced_filters();

-- Reprise de discovery_feed (0012, filtre par ville compris) avec les filtres avancés ; le reste est inchangé.
create or replace function discovery_feed(p_limit int default 20)
returns table (
  id uuid, display_name text, age int, city text, country_code text, bio text,
  marriage_horizon marriage_horizon, profession text, languages text[], interests text[],
  is_verified boolean, is_premium boolean, photo_path text
)
language sql stable security definer set search_path = public as $$
  with me as (
    select p.*, s.confession as my_confession, age_of(p.birth_date) as my_age, is_premium(p.id) as my_premium
    from profiles p left join profile_sensitive s on s.user_id = p.id
    where p.id = auth.uid() and p.status = 'active' and p.account_type = 'candidate'
  )
  select c.id, c.display_name, age_of(c.birth_date), ci.name, c.country_code, c.bio,
         c.marriage_horizon, coalesce(pr.label_fr, c.profession_other), c.languages, c.interests,
         true, is_premium(c.id),
         (select ph.storage_path from profile_photos ph
           where ph.user_id = c.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1)
  from me
  join profiles c on c.id <> me.id
  left join discovery_preferences mp on mp.user_id = me.id
  left join discovery_preferences cp on cp.user_id = c.id
  left join profile_sensitive cs on cs.user_id = c.id
  left join cities ci on ci.id = c.city_id
  left join professions pr on pr.id = c.profession_id
  where is_discoverable(c.id)
    -- Filtres réciproques (§31.2) : genre recherché, âge, pays, confession
    and c.gender = me.seeking_gender and c.seeking_gender = me.gender
    and age_of(c.birth_date) between coalesce(mp.age_min, 18) and coalesce(mp.age_max, 99)
    and me.my_age between coalesce(cp.age_min, 18) and coalesce(cp.age_max, 99)
    and c.country_code = any (coalesce(mp.country_codes, array[me.country_code]))
    and me.country_code = any (coalesce(cp.country_codes, array[c.country_code]))
    and confession_ok(mp.confession_mode, mp.confessions, me.my_confession, cs.confession)
    and confession_ok(cp.confession_mode, cp.confessions, cs.confession, me.my_confession)
    -- Ville ou commune choisie par le membre (sens unique ; liste vide = toutes)
    and (coalesce(cardinality(mp.city_ids), 0) = 0 or c.city_id = any (mp.city_ids))
    -- Filtres avancés (sens unique ; liste vide = tous) : seulement pour un membre Premium.
    -- Une information non renseignée ne correspond à aucun choix.
    and (not me.my_premium or (
          (coalesce(cardinality(mp.languages), 0) = 0 or c.languages && mp.languages)
      and (coalesce(cardinality(mp.marriage_horizons), 0) = 0 or c.marriage_horizon = any (mp.marriage_horizons))
      and (coalesce(cardinality(mp.marital_statuses), 0) = 0 or c.marital_status = any (mp.marital_statuses))
    ))
    -- Sécurité et historique
    and not blocked_between(me.id, c.id)
    and not exists (select 1 from interests i where i.from_user = me.id and i.to_user = c.id)
    and not exists (select 1 from passes x where x.from_user = me.id and x.to_user = c.id)
    and not exists (select 1 from matches m where m.user_a = least(me.id, c.id) and m.user_b = greatest(me.id, c.id))
    -- Incognito : visible uniquement par les personnes déjà aimées
    and (not c.incognito or exists (select 1 from interests i where i.from_user = c.id and i.to_user = me.id))
  order by c.last_active_at desc
  limit least(greatest(p_limit, 1), 50);
$$;
