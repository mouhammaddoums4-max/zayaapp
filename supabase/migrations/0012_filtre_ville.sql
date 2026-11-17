-- ZAYA — Découvrir : filtre par ville ou commune (demande du propriétaire, 17/11/2026).
--
-- Le membre peut limiter les profils proposés à une ou plusieurs villes ou communes du référentiel `cities`
-- (les communes de Conakry y sont des entrées distinctes). Liste vide = toutes les villes.
-- Filtre à sens unique : il restreint ce que je vois, sans me cacher aux personnes des autres villes.
-- Les filtres réciproques du §31.2 (genre, âge, pays, confession) sont inchangés.

alter table discovery_preferences add column city_ids bigint[] not null default '{}';

-- Reprise de discovery_feed (0002) avec la condition de ville ; le reste est inchangé.
create or replace function discovery_feed(p_limit int default 20)
returns table (
  id uuid, display_name text, age int, city text, country_code text, bio text,
  marriage_horizon marriage_horizon, profession text, languages text[], interests text[],
  is_verified boolean, is_premium boolean, photo_path text
)
language sql stable security definer set search_path = public as $$
  with me as (
    select p.*, s.confession as my_confession, age_of(p.birth_date) as my_age
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
