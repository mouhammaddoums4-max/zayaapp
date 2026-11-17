-- ZAYA — Swipes : quota par période, retour arrière, swipes supplémentaires crédités par le serveur.
--
-- Décisions du propriétaire (17/11/2026) : 50 swipes toutes les 8 heures pour un compte Gratuit, likes et passages
-- comptés ensemble ; retour arrière pour tous sur le dernier profil passé, sur plusieurs pour Premium.
-- Régie publicitaire §3–4 : quota contrôlé côté serveur, paramètres administrables, swipes supplémentaires accordés
-- après une publicité récompensée validée par le serveur (SSV), jamais sur un simple événement de l'application.
--
-- Période : elle commence au premier swipe et dure swipe_window_hours ; à son terme, le quota repart à zéro.
-- Un retour arrière ne rend pas le swipe consommé. Les anciennes clés free_daily_likes / premium_daily_likes ne
-- servent plus (my_like_quota renvoie désormais le quota de swipes).

insert into app_config (key, value, description, is_public) values
  ('swipe_quota_enabled', 'true', 'Quota de swipes actif (likes et passages comptés ensemble)', true),
  ('swipe_quota_free', '50', 'Swipes par période pour un compte Gratuit', true),
  ('swipe_quota_premium', '500', 'Plafond anti-abus des swipes par période pour un compte Premium', true),
  ('swipe_window_hours', '8', 'Durée d''une période de swipes, à partir du premier swipe', true),
  ('rewind_depth_free', '1', 'Nombre de profils passés que l''on peut faire revenir (Gratuit : le dernier)', true),
  ('rewind_depth_premium', '10', 'Nombre de profils passés que l''on peut faire revenir (Premium)', true),
  ('swipes_per_rewarded_ad', '10', 'Swipes supplémentaires accordés par publicité récompensée validée par le serveur', true)
on conflict (key) do nothing;

-- ───────────────────────────── Tables (lecture et écriture uniquement par les fonctions serveur)
create table swipe_events (              -- journal append-only des swipes : base du quota
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  target_id uuid not null references profiles (id) on delete cascade,
  action text not null check (action in ('like', 'pass')),
  extra boolean not null default false,  -- swipe pris sur les swipes supplémentaires
  created_at timestamptz not null default now()
);
create index swipe_events_user_idx on swipe_events (user_id, created_at desc);

create table swipe_periods (             -- période en cours de chaque membre
  user_id uuid primary key references profiles (id) on delete cascade,
  started_at timestamptz not null
);

create table swipe_credits (             -- swipes supplémentaires (append-only) : récompenses vérifiées, gestes commerciaux
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  amount int not null check (amount between 1 and 1000),
  source text not null,
  ref text not null unique,              -- identifiant de transaction (SSV…) : un même jeton ne crédite qu'une fois
  created_at timestamptz not null default now()
);

create trigger swipe_events_append_only before update or delete on swipe_events
  for each row execute function forbid_change();
create trigger swipe_credits_append_only before update or delete on swipe_credits
  for each row execute function forbid_change();

alter table swipe_events enable row level security;
alter table swipe_periods enable row level security;
alter table swipe_credits enable row level security;
revoke all on swipe_events, swipe_periods, swipe_credits from anon, authenticated;

-- ───────────────────────────── Quota
create function swipe_period_start(p_user uuid) returns timestamptz
language sql stable security definer set search_path = public as $$
  select started_at from swipe_periods
  where user_id = p_user and started_at > now() - make_interval(hours => cfg_int('swipe_window_hours', 8));
$$;

create function swipe_extra_balance(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select (coalesce((select sum(amount) from swipe_credits where user_id = p_user), 0)
          - (select count(*) from swipe_events where user_id = p_user and extra))::int;
$$;

create function swipe_limit(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select case when is_premium(p_user) then cfg_int('swipe_quota_premium', 500) else cfg_int('swipe_quota_free', 50) end;
$$;

-- Quota du membre connecté : resets_at est nul tant qu'aucune période n'est en cours.
create function my_swipe_quota() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_start timestamptz;
  v_limit int;
  v_used int := 0;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  v_start := swipe_period_start(v_me);
  v_limit := swipe_limit(v_me);
  if v_start is not null then
    select count(*) into v_used from swipe_events where user_id = v_me and not extra and created_at >= v_start;
  end if;
  return jsonb_build_object(
    'enabled', cfg_bool('swipe_quota_enabled', true),
    'limit', v_limit,
    'used', v_used,
    'remaining', greatest(v_limit - v_used, 0),
    'extra', greatest(swipe_extra_balance(v_me), 0),
    'window_hours', cfg_int('swipe_window_hours', 8),
    'resets_at', case when v_start is null then null
                      else v_start + make_interval(hours => cfg_int('swipe_window_hours', 8)) end);
end;
$$;

-- Compatibilité : l'application lit encore my_like_quota (mêmes clés limit / used / remaining / resets_at).
create or replace function my_like_quota() returns jsonb
language sql stable security definer set search_path = public as $$
  select my_swipe_quota();
$$;

-- Consomme un swipe (usage interne) : quota de la période, puis swipes supplémentaires. Verrou par membre pour que
-- deux swipes simultanés ne dépassent pas le quota.
create function consume_swipe(p_user uuid, p_target uuid, p_action text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_start timestamptz;
  v_used int;
  v_limit int;
  v_window interval := make_interval(hours => cfg_int('swipe_window_hours', 8));
begin
  perform pg_advisory_xact_lock(hashtext('swipe:' || p_user::text));
  if not cfg_bool('swipe_quota_enabled', true) then
    insert into swipe_events (user_id, target_id, action) values (p_user, p_target, p_action);
    return jsonb_build_object('ok', true);
  end if;
  v_start := swipe_period_start(p_user);
  if v_start is null then
    v_start := now();
    insert into swipe_periods (user_id, started_at) values (p_user, v_start)
      on conflict (user_id) do update set started_at = excluded.started_at;
  end if;
  v_limit := swipe_limit(p_user);
  select count(*) into v_used from swipe_events where user_id = p_user and not extra and created_at >= v_start;
  if v_used < v_limit then
    insert into swipe_events (user_id, target_id, action) values (p_user, p_target, p_action);
  elsif swipe_extra_balance(p_user) > 0 then
    insert into swipe_events (user_id, target_id, action, extra) values (p_user, p_target, p_action, true);
  else
    return jsonb_build_object('ok', false, 'limit', v_limit, 'resets_at', v_start + v_window);
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Swipes supplémentaires (usage serveur : validation SSV d'une publicité récompensée, geste commercial).
-- Renvoie false si cette référence a déjà été créditée : un même jeton ne crédite jamais deux fois.
create function grant_extra_swipes(p_user uuid, p_count int, p_source text, p_ref text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(trim(p_ref), '') = '' or coalesce(trim(p_source), '') = '' then raise exception 'REF_AND_SOURCE_REQUIRED'; end if;
  insert into swipe_credits (user_id, amount, source, ref) values (p_user, p_count, p_source, p_ref)
    on conflict (ref) do nothing;
  return found;
end;
$$;

-- ───────────────────────────── Like et passage : un swipe chacun (reprise de 0002 avec le nouveau quota)
create or replace function send_like(p_target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_swipe jsonb;
  v_match uuid;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if v_me = p_target then raise exception 'INVALID_TARGET'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active' and account_type = 'candidate') then
    raise exception 'PROFILE_NOT_ACTIVE';
  end if;
  if not is_discoverable(p_target) or blocked_between(v_me, p_target) then raise exception 'TARGET_UNAVAILABLE'; end if;
  if exists (select 1 from interests where from_user = v_me and to_user = p_target) then
    return jsonb_build_object('status', 'already_liked');
  end if;

  v_swipe := consume_swipe(v_me, p_target, 'like');
  if not (v_swipe ->> 'ok')::boolean then
    return jsonb_build_object('status', 'quota_reached', 'resets_at', v_swipe -> 'resets_at', 'limit', v_swipe -> 'limit');
  end if;

  insert into interests (from_user, to_user) values (v_me, p_target);
  delete from passes where from_user = v_me and to_user = p_target;

  -- Match uniquement si l'intérêt est réciproque
  if exists (select 1 from interests where from_user = p_target and to_user = v_me and status = 'pending') then
    update interests set status = 'accepted', responded_at = now()
      where (from_user = v_me and to_user = p_target) or (from_user = p_target and to_user = v_me);
    insert into matches (user_a, user_b) values (least(v_me, p_target), greatest(v_me, p_target))
      on conflict (user_a, user_b) do update set ended_at = null, ended_by = null
      returning id into v_match;
    return jsonb_build_object('status', 'matched', 'match_id', v_match);
  end if;
  return jsonb_build_object('status', 'liked', 'remaining', (my_swipe_quota() ->> 'remaining')::int);
end;
$$;

-- Passer un profil consomme un swipe ; quota atteint : SWIPE_QUOTA_REACHED (l'application affiche l'écran de limite).
create or replace function pass_profile(p_target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_swipe jsonb;
begin
  if auth.uid() is null or auth.uid() = p_target then raise exception 'INVALID_TARGET'; end if;
  v_swipe := consume_swipe(auth.uid(), p_target, 'pass');
  if not (v_swipe ->> 'ok')::boolean then raise exception 'SWIPE_QUOTA_REACHED'; end if;
  insert into passes (from_user, to_user) values (auth.uid(), p_target)
    on conflict (from_user, to_user) do update set created_at = now();
end;
$$;

-- ───────────────────────────── Retour arrière : faire revenir le dernier profil passé
-- Gratuit : seulement le dernier passage ; Premium : jusqu'aux rewind_depth_premium derniers. Le profil revient s'il
-- est toujours visible et sans blocage ; le swipe déjà consommé n'est pas rendu.
create function rewind_last_pass() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_depth int;
  v_target uuid;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  v_depth := case when is_premium(v_me) then cfg_int('rewind_depth_premium', 10) else cfg_int('rewind_depth_free', 1) end;
  select r.target_id into v_target
  from (select e.target_id, e.created_at from swipe_events e
        where e.user_id = v_me and e.action = 'pass'
        order by e.created_at desc, e.id desc limit greatest(v_depth, 0)) r
  where exists (select 1 from passes x where x.from_user = v_me and x.to_user = r.target_id)
    and is_discoverable(r.target_id) and not blocked_between(v_me, r.target_id)
  order by r.created_at desc limit 1;
  if v_target is null then return jsonb_build_object('status', 'nothing'); end if;

  delete from passes where from_user = v_me and to_user = v_target;
  return (
    select jsonb_build_object(
      'status', 'rewound', 'id', c.id, 'display_name', c.display_name, 'age', age_of(c.birth_date), 'city', ci.name,
      'country_code', c.country_code, 'bio', c.bio, 'marriage_horizon', c.marriage_horizon,
      'profession', coalesce(pr.label_fr, c.profession_other), 'languages', to_jsonb(c.languages),
      'interests', to_jsonb(c.interests), 'is_verified', true, 'is_premium', is_premium(c.id),
      'photo_path', (select ph.storage_path from profile_photos ph
                     where ph.user_id = c.id and ph.moderation = 'approved' and ph.visibility = 'public'
                     order by ph.position limit 1))
    from profiles c
    left join cities ci on ci.id = c.city_id
    left join professions pr on pr.id = c.profession_id
    where c.id = v_target);
end;
$$;

-- ───────────────────────────── Droits : seules les fonctions de l'API sont ouvertes aux membres
revoke execute on function swipe_period_start(uuid), swipe_extra_balance(uuid), swipe_limit(uuid),
                           consume_swipe(uuid, uuid, text), grant_extra_swipes(uuid, int, text, text)
  from public, anon, authenticated;
revoke execute on function my_swipe_quota(), rewind_last_pass() from public, anon;
grant execute on function my_swipe_quota(), rewind_last_pass() to authenticated;
