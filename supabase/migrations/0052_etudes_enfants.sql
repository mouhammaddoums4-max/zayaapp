-- ZAYA — Profil : niveau d'études (liste administrable) et nombre d'enfants ; filtres Premium correspondants
-- (demande du propriétaire, 18/11/2026, suite de 0025).
--
-- • Niveau d'études : liste fermée tenue par l'administration (table education_levels), jamais écrite dans
--   l'application. Le membre choisit une clé (profiles.education_key) ; l'ancienne colonne texte education_level
--   reçoit automatiquement le libellé, si bien que la fiche profil (get_profile) l'affiche sans changement.
-- • Nombre d'enfants : colonne existante profiles.children_count (0 à 20), toujours visible sur la fiche.
-- • Filtres Premium (sens unique, comme 0025) : niveaux d'études acceptés ; nombre d'enfants au plus.
--   Une information non renseignée ne correspond à aucun choix. Sans Premium : ignorés, et non modifiables.

create table education_levels (
  key text primary key check (key ~ '^[a-z0-9_]+$'),
  label_fr text not null check (char_length(label_fr) between 1 and 80),
  label_en text not null check (char_length(label_en) between 1 and 80),
  position smallint not null default 0,
  active boolean not null default true
);
alter table education_levels enable row level security;
create policy education_levels_read on education_levels for select to anon, authenticated using (active);
create policy education_levels_admin on education_levels for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
grant select on education_levels to anon;
grant select, insert, update, delete on education_levels to authenticated;

-- Valeurs de départ (modifiables depuis l'administration) : parcours scolaire guinéen.
insert into education_levels (key, label_fr, label_en, position) values
  ('none', 'Sans diplôme', 'No diploma', 10),
  ('primary', 'Primaire (CEPE)', 'Primary school', 20),
  ('middle', 'Collège (BEPC)', 'Middle school', 30),
  ('bac', 'Baccalauréat', 'High school diploma', 40),
  ('vocational', 'Formation professionnelle', 'Vocational training', 50),
  ('bac2', 'Bac +2 (BTS, DUT)', 'Two-year degree', 60),
  ('licence', 'Licence (Bac +3)', 'Bachelor''s degree', 70),
  ('master', 'Master (Bac +5)', 'Master''s degree', 80),
  ('doctorate', 'Doctorat', 'Doctorate', 90);

alter table profiles add column education_key text references education_levels (key);

create function sync_education_label() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.education_key is not null then
    new.education_level := (select label_fr from education_levels where key = new.education_key);
  elsif tg_op = 'UPDATE' and old.education_key is not null then
    new.education_level := null;  -- niveau retiré par le membre
  end if;
  return new;
end;
$$;
revoke execute on function sync_education_label() from public, anon, authenticated;
create trigger profiles_education_label
  before insert or update of education_key on profiles
  for each row execute function sync_education_label();

-- Reprise des textes existants (profils d'essai) ; un texte non reconnu reste affiché tel quel, sans clé.
update profiles set education_key = case
    when education_level ilike 'doctorat%' then 'doctorate'
    when education_level ilike 'master%' then 'master'
    when education_level ilike 'licence%' then 'licence'
    when education_level ilike any (array['bts%', 'dut%', 'bac%+%2%']) then 'bac2'
    when education_level ilike 'bac%' then 'bac'
  end
  where education_level is not null and education_key is null;

-- Filtres Premium
alter table discovery_preferences
  add column education_keys text[] not null default '{}',
  add column children_max smallint check (children_max between 0 and 20);

-- Reprise du garde-fou de 0025 avec les deux nouveaux filtres.
create or replace function guard_advanced_filters() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_old discovery_preferences;  -- reste vide pour une insertion
begin
  if auth.uid() is null or is_premium(new.user_id) then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    v_old := old;
  end if;
  if (cardinality(new.languages) > 0 and new.languages is distinct from v_old.languages)
     or (cardinality(new.marriage_horizons) > 0 and new.marriage_horizons is distinct from v_old.marriage_horizons)
     or (cardinality(new.marital_statuses) > 0 and new.marital_statuses is distinct from v_old.marital_statuses)
     or (cardinality(new.education_keys) > 0 and new.education_keys is distinct from v_old.education_keys)
     or (new.children_max is not null and new.children_max is distinct from v_old.children_max) then
    raise exception 'PREMIUM_REQUIRED';
  end if;
  return new;
end;
$$;
revoke execute on function guard_advanced_filters() from public, anon, authenticated;

-- Reprise de discovery_feed (0025) avec les deux nouveaux filtres avancés ; le reste est inchangé.
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
      and (coalesce(cardinality(mp.education_keys), 0) = 0 or c.education_key = any (mp.education_keys))
      and (mp.children_max is null or c.children_count <= mp.children_max)
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
