-- ZAYA — Lot B : floutage des photos côté serveur (addendum V6.4 §2.2, §3 et §9 ; décision C12).
--
-- Accès d'un visiteur à une photo, dans l'ordre de priorité de l'addendum (§2.2) :
--   1. le propriétaire voit toujours ses originaux ;
--   2. photo non approuvée, photo privée, ou blocage entre les deux membres : aucun accès ;
--   3. photo « floutée » par son propriétaire : version floutée pour tous, Premium compris
--      (le forfait ne contourne jamais un choix du propriétaire) ;
--   4. photo publique : nette pour un visiteur Premium, ou si elle fait partie des N premières photos
--      publiques du profil (N = app_config free_clear_photos, 1 par défaut : la photo principale) ;
--      sinon floutée pour un visiteur Gratuit.
--
-- La version floutée est fabriquée côté serveur (fonction Edge blur-photos) dans le bucket privé
-- profile-photos-blur. L'original n'est jamais servi à un visiteur qui n'y a pas droit : la règle de stockage
-- du bucket profile-photos refuse le fichier, même par une adresse directe.

alter table profile_photos add column blur_path text; -- chemin dans le bucket profile-photos-blur (serveur uniquement)

insert into storage.buckets (id, name, public) values ('profile-photos-blur', 'profile-photos-blur', false)
on conflict (id) do nothing;

insert into app_config (key, value, description, is_public) values
  ('free_clear_photos', '1',
   'Photos publiques affichées nettes à un visiteur Gratuit, dans l''ordre du profil (minimum 1 : la photo principale reste nette dans Découvrir) ; les suivantes sont floutées',
   true)
on conflict (key) do nothing;

-- ───────────────────────────── Règle d'accès (usage interne : appelée par les fonctions et règles de stockage)
create function photo_access(p_photo profile_photos, p_viewer uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when p_viewer = p_photo.user_id then 'original'
    when p_viewer is null or p_photo.moderation <> 'approved' or p_photo.visibility = 'private'
         or blocked_between(p_viewer, p_photo.user_id) then 'none'
    when p_photo.visibility = 'blurred' then 'blurred'
    when is_premium(p_viewer) then 'original'
    when (select count(*) from profile_photos o
          where o.user_id = p_photo.user_id and o.moderation = 'approved' and o.visibility = 'public'
            and (o.position, o.created_at, o.id) < (p_photo.position, p_photo.created_at, p_photo.id))
         < greatest(cfg_int('free_clear_photos', 1), 1) then 'original'
    else 'blurred'
  end;
$$;
revoke execute on function photo_access(profile_photos, uuid) from public, anon, authenticated;

-- Fichier original : servi seulement si le visiteur a droit à la photo nette.
create or replace function photo_is_viewable(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profile_photos ph
    where ph.storage_path = p_path and photo_access(ph, auth.uid()) = 'original'
  );
$$;

-- Version floutée : servie à quiconque a droit à la photo, nette ou floutée.
create function blur_is_viewable(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profile_photos ph
    where ph.blur_path = p_path and photo_access(ph, auth.uid()) in ('original', 'blurred')
  );
$$;
revoke execute on function blur_is_viewable(text) from public, anon;
grant execute on function blur_is_viewable(text) to authenticated;

-- Bucket des versions floutées : lecture seule pour les membres ; seul le serveur y écrit.
create policy photos_blur_read on storage.objects for select to authenticated
  using (bucket_id = 'profile-photos-blur' and public.blur_is_viewable(name));

-- ───────────────────────────── Le chemin flouté n'est jamais modifiable par un membre
create or replace function photos_guard() returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and not zaya_internal() then
    if tg_op = 'INSERT' then
      new.moderation := 'pending';
      new.blur_path := null;
    else
      new.moderation := old.moderation;
      new.user_id := old.user_id;
      new.storage_path := old.storage_path;
      new.blur_path := old.blur_path;
    end if;
  end if;
  return new;
end;
$$;

-- ───────────────────────────── Profil consulté : chaque photo indique l'accès du visiteur
-- access = original (chemin net), blurred (chemin flouté, null tant que la version floutée n'est pas prête)
-- ou none (ni l'un ni l'autre). Le reste de la fonction est inchangé (0002).
create or replace function get_profile(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_p profiles;
  v_s profile_sensitive;
  v_is_self boolean;
  v_matched boolean;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_p from profiles where id = p_id;
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  v_is_self := v_me = p_id;
  v_matched := exists (select 1 from matches m
    where m.user_a = least(v_me, p_id) and m.user_b = greatest(v_me, p_id) and m.ended_at is null);
  if not v_is_self then
    if blocked_between(v_me, p_id) then raise exception 'PROFILE_NOT_FOUND'; end if;
    if not (v_matched and v_p.status in ('active', 'paused')) and not is_discoverable(p_id) then
      raise exception 'PROFILE_NOT_FOUND';
    end if;
  end if;
  select * into v_s from profile_sensitive where user_id = p_id;

  return jsonb_build_object(
    'id', v_p.id,
    'display_name', v_p.display_name,
    'age', age_of(v_p.birth_date),
    'gender', v_p.gender,
    'city', (select name from cities where id = v_p.city_id),
    'country_code', v_p.country_code,
    'bio', v_p.bio,
    'marital_status', v_p.marital_status,
    'children_count', v_p.children_count,
    'marriage_horizon', v_p.marriage_horizon,
    'profession', coalesce((select label_fr from professions where id = v_p.profession_id), v_p.profession_other),
    'education_level', v_p.education_level,
    'height_cm', v_p.height_cm,
    'languages', to_jsonb(v_p.languages),
    'interests', to_jsonb(v_p.interests),
    'is_verified', v_p.verification_status = 'approved',
    'is_phone_verified', v_p.is_phone_verified,
    'is_premium', is_premium(p_id),
    -- Données sensibles : uniquement si le membre a choisi de les afficher
    'confession', case when v_is_self or coalesce(v_s.show_confession, false) then v_s.confession end,
    'ethnic_group', case when v_is_self or coalesce(v_s.show_ethnic_group, false)
                      then coalesce((select label_fr from ethnic_groups where id = v_s.ethnic_group_id), v_s.ethnic_other) end,
    'matched', v_matched,
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', ph.id,
               'visibility', ph.visibility,
               'access', a.access,
               -- Le chemin de l'original n'est envoyé qu'au visiteur qui a droit à la photo nette.
               'path', case when a.access = 'original' then ph.storage_path end,
               'blur_path', case when a.access = 'blurred' then ph.blur_path end)
             order by ph.position)
      from profile_photos ph
      cross join lateral (select photo_access(ph, v_me) as access) a
      where ph.user_id = p_id and (v_is_self or ph.moderation = 'approved')), '[]'::jsonb)
  );
end;
$$;
