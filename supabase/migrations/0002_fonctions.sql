-- ZAYA — Lot A : règles métier côté serveur.
-- Toutes les fonctions exposées sont `security definer` et vérifient auth.uid() elles-mêmes.

-- ───────────────────────────── Utilitaires
create function zaya_internal() returns boolean
language sql stable as $$
  select coalesce(current_setting('zaya.internal', true), '') = '1';
$$;

create function cfg_int(p_key text, p_default int) returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::int from app_config where key = p_key), p_default);
$$;

create function cfg_bool(p_key text, p_default boolean) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::boolean from app_config where key = p_key), p_default);
$$;

create function auth_is_staff(p_roles staff_role[] default null) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from staff_roles s
    where s.user_id = auth.uid() and (p_roles is null or s.role = any (p_roles))
  );
$$;

create function is_premium(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from premium_grants g
    where g.user_id = p_user and g.status = 'active' and g.starts_at <= now() and g.ends_at > now()
  );
$$;

-- Un membre ne peut interroger que les blocages qui le concernent (pas ceux entre deux autres personnes).
create function blocked_between(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from blocks b
    where ((b.blocker = p_a and b.blocked = p_b) or (b.blocker = p_b and b.blocked = p_a))
      and (auth.uid() is null or auth.uid() in (p_a, p_b))
  );
$$;

create function age_of(p_birth date) returns int
language sql stable as $$
  select extract(year from age(current_date, p_birth))::int;
$$;

create function approved_photo_count(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from profile_photos where user_id = p_user and moderation = 'approved';
$$;

create function is_discoverable(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p
    where p.id = p_user and p.account_type = 'candidate' and p.status = 'active'
      and p.verification_status = 'approved'
      and approved_photo_count(p.id) >= cfg_int('min_profile_photos', 3)
  );
$$;

create function write_audit(p_action text, p_entity text, p_entity_id text, p_old jsonb, p_new jsonb, p_reason text)
returns void language sql security definer set search_path = public as $$
  insert into audit_log (actor, action, entity, entity_id, old_value, new_value, reason)
  values (auth.uid(), p_action, p_entity, p_entity_id, p_old, p_new, p_reason);
$$;
revoke execute on function write_audit(text, text, text, jsonb, jsonb, text) from public;

-- ───────────────────────────── Triggers de protection
create function forbid_change() returns trigger language plpgsql as $$
begin
  raise exception 'APPEND_ONLY: % ne peut pas être modifié ni supprimé', tg_table_name;
end;
$$;
create trigger audit_log_append_only before update or delete on audit_log for each row execute function forbid_change();
create trigger premium_events_append_only before update or delete on premium_events for each row execute function forbid_change();
create trigger transaction_events_append_only before update or delete on transaction_events for each row execute function forbid_change();

create function profiles_guard() returns trigger language plpgsql as $$
begin
  if new.birth_date is not null and new.birth_date > (current_date - interval '18 years')::date then
    raise exception 'AGE_MINIMUM_18';
  end if;
  if tg_op = 'INSERT' then
    if auth.uid() is not null and not zaya_internal() then
      new.status := 'draft';
      new.is_phone_verified := false;
      new.verification_status := 'not_requested';
      new.account_type := 'candidate';
    end if;
    return new;
  end if;
  new.updated_at := now();
  if auth.uid() is not null and not zaya_internal() then
    -- Colonnes protégées : seules les fonctions serveur peuvent les changer
    new.is_phone_verified := old.is_phone_verified;
    new.verification_status := old.verification_status;
    new.account_type := old.account_type;
    new.created_at := old.created_at;
    -- Après l'inscription, date de naissance et genre ne se modifient plus librement
    -- (contrôle d'âge, cohérence du matching) : passer par l'assistance.
    if old.status <> 'draft' then
      new.birth_date := old.birth_date;
      new.gender := old.gender;
      new.seeking_gender := old.seeking_gender;
    end if;
    if new.status <> old.status
       and not (old.status in ('active', 'paused', 'hidden') and new.status in ('active', 'paused', 'hidden')) then
      raise exception 'STATUS_CHANGE_NOT_ALLOWED';
    end if;
  end if;
  return new;
end;
$$;
create trigger profiles_guard_trg before insert or update on profiles for each row execute function profiles_guard();

-- Sous le minimum de photos approuvées : le badge est retiré et le profil sort de la découverte (§22.8)
create function photos_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid := coalesce(old.user_id, new.user_id);
begin
  if approved_photo_count(v_user) < cfg_int('min_profile_photos', 3) then
    perform set_config('zaya.internal', '1', true);
    update profiles set verification_status = 'redo' where id = v_user and verification_status = 'approved';
    perform set_config('zaya.internal', '0', true);
  end if;
  return null;
end;
$$;
create trigger photos_after_change_trg after delete or update of moderation on profile_photos
  for each row execute function photos_after_change();

-- Un membre ne peut pas approuver ses propres photos
create function photos_guard() returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and not zaya_internal() then
    if tg_op = 'INSERT' then
      new.moderation := 'pending';
    else
      new.moderation := old.moderation;
      new.user_id := old.user_id;
      new.storage_path := old.storage_path;
    end if;
  end if;
  return new;
end;
$$;
create trigger photos_guard_trg before insert or update on profile_photos for each row execute function photos_guard();

-- ───────────────────────────── Onboarding & vérification
create function complete_onboarding() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles;
  v_missing text[] := '{}';
  v_kind text;
begin
  select * into v_me from profiles where id = auth.uid();
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  if v_me.status <> 'draft' then return jsonb_build_object('status', v_me.status); end if;

  if v_me.display_name is null then v_missing := v_missing || 'display_name'; end if;
  if v_me.birth_date is null then v_missing := v_missing || 'birth_date'; end if;
  if v_me.gender is null then v_missing := v_missing || 'gender'; end if;
  if v_me.seeking_gender is null then v_missing := v_missing || 'seeking_gender'; end if;
  if v_me.country_code is null then v_missing := v_missing || 'country_code'; end if;
  if v_me.city_id is null then v_missing := v_missing || 'city_id'; end if;
  foreach v_kind in array array['tos', 'privacy', 'community'] loop
    if not coalesce((select c.granted from consents c where c.user_id = v_me.id and c.kind = v_kind
                     order by c.created_at desc, c.id desc limit 1), false) then
      v_missing := v_missing || ('consent_' || v_kind);
    end if;
  end loop;
  if not exists (select 1 from auth.users u where u.id = v_me.id and u.phone_confirmed_at is not null) then
    v_missing := v_missing || 'phone_verification';
  end if;
  if array_length(v_missing, 1) > 0 then
    return jsonb_build_object('status', 'incomplete', 'missing', to_jsonb(v_missing));
  end if;

  perform set_config('zaya.internal', '1', true);
  update profiles set status = 'active', is_phone_verified = true where id = v_me.id;
  perform set_config('zaya.internal', '0', true);
  insert into discovery_preferences (user_id) values (v_me.id) on conflict do nothing;
  return jsonb_build_object('status', 'active');
end;
$$;

create function request_verification(p_selfie_path text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_min int := cfg_int('min_profile_photos', 3);
  v_count int;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not coalesce((select c.granted from consents c where c.user_id = auth.uid() and c.kind = 'biometric'
                   order by c.created_at desc, c.id desc limit 1), false) then
    raise exception 'BIOMETRIC_CONSENT_REQUIRED';
  end if;
  select count(*) into v_count from profile_photos where user_id = auth.uid() and moderation <> 'rejected';
  if v_count < v_min then
    return jsonb_build_object('status', 'not_enough_photos', 'required', v_min, 'current', v_count);
  end if;
  if exists (select 1 from verification_requests where user_id = auth.uid() and status = 'pending') then
    return jsonb_build_object('status', 'pending');
  end if;
  insert into verification_requests (user_id, selfie_path) values (auth.uid(), p_selfie_path) returning id into v_id;
  perform set_config('zaya.internal', '1', true);
  update profiles set verification_status = 'pending' where id = auth.uid();
  perform set_config('zaya.internal', '0', true);
  return jsonb_build_object('status', 'pending', 'request_id', v_id);
end;
$$;

create function admin_decide_verification(p_request uuid, p_status verification_status, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_req verification_requests;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_status not in ('approved', 'rejected', 'more_info_required', 'redo') then raise exception 'INVALID_STATUS'; end if;
  if p_status <> 'approved' and coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_req from verification_requests where id = p_request for update;
  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;

  update verification_requests
    set status = p_status, decided_by = auth.uid(), decided_at = now(), decision_reason = p_reason
    where id = p_request;
  perform set_config('zaya.internal', '1', true);
  if p_status = 'approved' then
    update profile_photos set moderation = 'approved' where user_id = v_req.user_id and moderation = 'pending';
  end if;
  update profiles set verification_status = p_status where id = v_req.user_id;
  perform set_config('zaya.internal', '0', true);
  perform write_audit('verification.' || p_status::text, 'verification_requests', p_request::text,
                      jsonb_build_object('status', v_req.status), jsonb_build_object('status', p_status), p_reason);
end;
$$;

-- ───────────────────────────── Découverte
create function confession_ok(p_mode confession_mode, p_selected confession[], p_mine confession, p_theirs confession)
returns boolean language sql immutable as $$
  select case
    when p_mode is null or p_mode in ('no_filter', 'all') then true
    -- Règle expliquée à l'utilisateur : un profil sans confession déclarée n'est pas classé arbitrairement, il reste proposé.
    when p_theirs is null or p_theirs = 'undisclosed' then true
    when p_mode = 'mine_only' then p_mine is null or p_mine = 'undisclosed' or p_theirs = p_mine
    when p_mode = 'selected' then coalesce(array_length(p_selected, 1), 0) = 0 or p_theirs = any (p_selected)
    else true
  end;
$$;

create function discovery_feed(p_limit int default 20)
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

-- ───────────────────────────── Likes, matchs
create function like_window_start() returns timestamptz
language sql stable security definer set search_path = public as $$
  select date_trunc('day', now() - make_interval(hours => cfg_int('likes_reset_hour_utc', 0)))
         + make_interval(hours => cfg_int('likes_reset_hour_utc', 0));
$$;

create function my_like_quota() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_limit int;
  v_used int;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  v_limit := case when is_premium(auth.uid()) then cfg_int('premium_daily_likes', 200) else cfg_int('free_daily_likes', 20) end;
  select count(*) into v_used from interests where from_user = auth.uid() and created_at >= like_window_start();
  return jsonb_build_object('limit', v_limit, 'used', v_used, 'remaining', greatest(v_limit - v_used, 0),
                            'resets_at', like_window_start() + interval '1 day');
end;
$$;

create function send_like(p_target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_quota jsonb;
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

  v_quota := my_like_quota();
  if (v_quota ->> 'remaining')::int <= 0 then
    return jsonb_build_object('status', 'quota_reached', 'resets_at', v_quota -> 'resets_at', 'limit', v_quota -> 'limit');
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
  return jsonb_build_object('status', 'liked', 'remaining', (v_quota ->> 'remaining')::int - 1);
end;
$$;

create function pass_profile(p_target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or auth.uid() = p_target then raise exception 'INVALID_TARGET'; end if;
  insert into passes (from_user, to_user) values (auth.uid(), p_target)
    on conflict (from_user, to_user) do update set created_at = now();
end;
$$;

create function received_interests_count() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from interests i
  where i.to_user = auth.uid() and i.status = 'pending' and not blocked_between(i.from_user, i.to_user);
$$;

-- Liste nominative des intérêts reçus : avantage Premium (V3.0 §4.3). Le compteur reste gratuit.
create function received_interests()
returns table (interest_id uuid, user_id uuid, display_name text, age int, city text, photo_path text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_premium(auth.uid()) then raise exception 'PREMIUM_REQUIRED'; end if;
  return query
    select i.id, p.id, p.display_name, age_of(p.birth_date), ci.name,
           (select ph.storage_path from profile_photos ph
             where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
             order by ph.position limit 1),
           i.created_at
    from interests i
    join profiles p on p.id = i.from_user
    left join cities ci on ci.id = p.city_id
    where i.to_user = auth.uid() and i.status = 'pending'
      and is_discoverable(p.id) and not blocked_between(i.from_user, i.to_user)
    order by i.created_at desc;
end;
$$;

create function unmatch(p_match uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update matches set ended_at = now(), ended_by = auth.uid()
    where id = p_match and ended_at is null and auth.uid() in (user_a, user_b);
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
end;
$$;

create function block_user(p_target uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null or v_me = p_target then raise exception 'INVALID_TARGET'; end if;
  insert into blocks (blocker, blocked) values (v_me, p_target) on conflict do nothing;
  update matches set ended_at = now(), ended_by = v_me
    where user_a = least(v_me, p_target) and user_b = greatest(v_me, p_target) and ended_at is null;
  update interests set status = 'cancelled', responded_at = now()
    where status = 'pending'
      and ((from_user = v_me and to_user = p_target) or (from_user = p_target and to_user = v_me));
end;
$$;

create function unblock_user(p_target uuid) returns void
language sql security definer set search_path = public as $$
  delete from blocks where blocker = auth.uid() and blocked = p_target;
$$;

create function report_user(p_target uuid, p_context text, p_reason text, p_details text default null, p_match uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_priority report_priority;
begin
  if auth.uid() is null or auth.uid() = p_target then raise exception 'INVALID_TARGET'; end if;
  v_priority := case
    when p_reason in ('threat', 'blackmail', 'minor', 'exploitation', 'non_consensual_image') then 'critical'
    when p_reason in ('scam', 'money_request', 'harassment', 'impersonation') then 'high'
    when p_reason in ('spam', 'other') then 'low'
    else 'normal' end;
  insert into reports (reporter, reported_user, context, reason, details, match_id, priority)
    values (auth.uid(), p_target, p_context, p_reason, p_details, p_match, v_priority)
    returning id into v_id;
  return v_id;
end;
$$;

-- ───────────────────────────── Messagerie
create function message_violation_category(p_body text) returns text
language sql stable security definer set search_path = public as $$
  select t.category from moderation_terms t
  where t.active and t.severity = 3
    and position(lower(t.term) in lower(regexp_replace(p_body, '\s+', ' ', 'g'))) > 0
  order by t.id limit 1;
$$;

create function send_message(p_match uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match matches;
  v_other uuid;
  v_category text;
  v_id uuid;
  v_body text := trim(p_body);
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_MESSAGE'; end if;
  select * into v_match from matches where id = p_match and v_me in (user_a, user_b);
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.ended_at is not null then raise exception 'MATCH_ENDED'; end if;
  v_other := case when v_match.user_a = v_me then v_match.user_b else v_match.user_a end;
  if blocked_between(v_me, v_other) then raise exception 'MATCH_ENDED'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active') then raise exception 'PROFILE_NOT_ACTIVE'; end if;

  -- Filtre avant transmission : un message non conforme n'est ni stocké ni transmis (§24.3)
  v_category := message_violation_category(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;

  insert into messages (match_id, sender_id, body) values (p_match, v_me, v_body) returning id into v_id;
  return jsonb_build_object('status', 'sent', 'id', v_id);
end;
$$;

create function edit_message(p_message uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_msg messages;
  v_category text;
  v_body text := trim(p_body);
begin
  select * into v_msg from messages where id = p_message and sender_id = auth.uid();
  if not found then raise exception 'MESSAGE_NOT_FOUND'; end if;
  if v_msg.unsent_at is not null then raise exception 'MESSAGE_UNSENT'; end if;
  if v_msg.created_at < now() - make_interval(mins => cfg_int('message_edit_window_minutes', 15)) then
    raise exception 'EDIT_WINDOW_EXPIRED';
  end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_MESSAGE'; end if;
  v_category := message_violation_category(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category) values (auth.uid(), v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  update messages set body = v_body, edited_at = now() where id = p_message;
  return jsonb_build_object('status', 'edited');
end;
$$;

create function unsend_message(p_message uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update messages set body = '', unsent_at = now()
    where id = p_message and sender_id = auth.uid() and unsent_at is null
      and created_at >= now() - make_interval(mins => cfg_int('message_edit_window_minutes', 15));
  if not found then raise exception 'UNSEND_NOT_ALLOWED'; end if;
end;
$$;

create function hide_message(p_message uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from messages m join matches x on x.id = m.match_id
    where m.id = p_message and auth.uid() in (x.user_a, x.user_b)
  ) then raise exception 'MESSAGE_NOT_FOUND'; end if;
  insert into message_hidden (message_id, user_id) values (p_message, auth.uid()) on conflict do nothing;
end;
$$;

create function mark_conversation_read(p_match uuid) returns void
language sql security definer set search_path = public as $$
  update messages m set read_at = now()
  from matches x
  where x.id = m.match_id and m.match_id = p_match and auth.uid() in (x.user_a, x.user_b)
    and m.sender_id <> auth.uid() and m.read_at is null;
$$;

create function my_matches()
returns table (match_id uuid, user_id uuid, display_name text, photo_path text, is_verified boolean,
               last_message text, last_at timestamptz, unread int, matched_at timestamptz)
language sql stable security definer set search_path = public as $$
  select m.id, p.id, p.display_name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         p.verification_status = 'approved',
         lm.body, lm.created_at,
         (select count(*)::int from messages u
           where u.match_id = m.id and u.sender_id <> auth.uid() and u.read_at is null and u.unsent_at is null),
         m.created_at
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  left join lateral (
    select case when x.unsent_at is not null then null else x.body end as body, x.created_at
    from messages x
    where x.match_id = m.id
      and not exists (select 1 from message_hidden h where h.message_id = x.id and h.user_id = auth.uid())
    order by x.created_at desc limit 1
  ) lm on true
  where auth.uid() in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
  order by coalesce(lm.created_at, m.created_at) desc;
$$;

-- ───────────────────────────── Consultation d'un profil
create function get_profile(p_id uuid) returns jsonb
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
               -- Le chemin n'est jamais envoyé pour une photo privée ou floutée (variante floutée serveur : lot B)
               'path', case when v_is_self or ph.visibility = 'public' then ph.storage_path end)
             order by ph.position)
      from profile_photos ph
      where ph.user_id = p_id and (v_is_self or ph.moderation = 'approved')), '[]'::jsonb)
  );
end;
$$;

create function record_profile_view(p_target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or auth.uid() = p_target or blocked_between(auth.uid(), p_target) then return; end if;
  insert into profile_views (viewer, viewed, discreet)
    select auth.uid(), p_target, p.discreet_browsing from profiles p where p.id = auth.uid();
end;
$$;

create function my_profile_view_stats() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'views_7d', count(*) filter (where viewed_at >= now() - interval '7 days'),
    'unique_7d', count(distinct viewer) filter (where viewed_at >= now() - interval '7 days'),
    'views_30d', count(*),
    'unique_30d', count(distinct viewer))
  from profile_views where viewed = auth.uid() and viewed_at >= now() - interval '30 days';
$$;

-- ───────────────────────────── Premium : gestion administrative (V6.4 §40.3)
create function admin_grant_premium(p_user uuid, p_starts timestamptz, p_ends timestamptz, p_reason text, p_origin text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' or coalesce(trim(p_origin), '') = '' then raise exception 'REASON_AND_ORIGIN_REQUIRED'; end if;
  if p_ends <= p_starts then raise exception 'INVALID_PERIOD'; end if;
  insert into premium_grants (user_id, source, status, starts_at, ends_at, reason, origin, created_by)
    values (p_user, 'admin_grant', 'active', p_starts, p_ends, p_reason, p_origin, auth.uid())
    returning id into v_id;
  insert into premium_events (grant_id, user_id, action, actor, new_starts_at, new_ends_at, new_status, reason, origin)
    values (v_id, p_user, 'granted', auth.uid(), p_starts, p_ends, 'active', p_reason, p_origin);
  perform write_audit('premium.grant', 'premium_grants', v_id::text, null,
                      jsonb_build_object('starts_at', p_starts, 'ends_at', p_ends, 'origin', p_origin), p_reason);
  return v_id;
end;
$$;

-- Règle de prolongation : encore actif → on ajoute à la date de fin ; expiré → on repart de maintenant.
create function admin_extend_premium(p_grant uuid, p_days int, p_reason text) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare
  v_g premium_grants;
  v_new_ends timestamptz;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_days <= 0 or coalesce(trim(p_reason), '') = '' then raise exception 'INVALID_EXTENSION'; end if;
  select * into v_g from premium_grants where id = p_grant for update;
  if not found or v_g.status <> 'active' then raise exception 'GRANT_NOT_ACTIVE'; end if;
  v_new_ends := greatest(v_g.ends_at, now()) + make_interval(days => p_days);
  update premium_grants set ends_at = v_new_ends where id = p_grant;
  insert into premium_events (grant_id, user_id, action, actor, old_starts_at, old_ends_at, new_starts_at, new_ends_at,
                              old_status, new_status, reason, origin)
    values (p_grant, v_g.user_id, 'extended', auth.uid(), v_g.starts_at, v_g.ends_at, v_g.starts_at, v_new_ends,
            v_g.status, v_g.status,
            p_reason || case when v_g.ends_at > now() then ' [règle : ajout à la date de fin]' else ' [règle : reprise à la date du jour]' end,
            v_g.origin);
  perform write_audit('premium.extend', 'premium_grants', p_grant::text,
                      jsonb_build_object('ends_at', v_g.ends_at), jsonb_build_object('ends_at', v_new_ends), p_reason);
  return v_new_ends;
end;
$$;

create function admin_revoke_premium(p_grant uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_g premium_grants;
begin
  if not auth_is_staff(array['super_admin', 'admin']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_g from premium_grants where id = p_grant for update;
  if not found or v_g.status <> 'active' then raise exception 'GRANT_NOT_ACTIVE'; end if;
  update premium_grants set status = 'revoked', revoked_at = now() where id = p_grant;
  insert into premium_events (grant_id, user_id, action, actor, old_starts_at, old_ends_at, new_starts_at, new_ends_at,
                              old_status, new_status, reason, origin)
    values (p_grant, v_g.user_id, 'revoked', auth.uid(), v_g.starts_at, v_g.ends_at, v_g.starts_at, v_g.ends_at,
            v_g.status, 'revoked', p_reason, v_g.origin);
  perform write_audit('premium.revoke', 'premium_grants', p_grant::text,
                      jsonb_build_object('status', v_g.status), jsonb_build_object('status', 'revoked'), p_reason);
end;
$$;

-- ───────────────────────────── Compte : activité, préférences, blocages, suppression, export (§22.9)
create function touch_last_active() returns void
language sql security definer set search_path = public as $$
  update profiles set last_active_at = now() where id = auth.uid();
$$;

create function my_blocked_users()
returns table (user_id uuid, display_name text, blocked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select b.blocked, p.display_name, b.created_at
  from blocks b join profiles p on p.id = b.blocked
  where b.blocker = auth.uid()
  order by b.created_at desc;
$$;

-- Demande de suppression : le profil sort immédiatement de la découverte. La purge effective intervient
-- à l'échéance (tâche planifiée — lot administration). La demande est annulable pendant le délai.
create function request_account_deletion() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles;
  v_when timestamptz;
begin
  select * into v_me from profiles where id = auth.uid();
  if not found then raise exception 'PROFILE_NOT_FOUND'; end if;
  select scheduled_for into v_when from account_deletion_requests where user_id = v_me.id;
  if found then return jsonb_build_object('status', 'scheduled', 'scheduled_for', v_when); end if;

  v_when := now() + make_interval(days => cfg_int('account_deletion_delay_days', 30));
  insert into account_deletion_requests (user_id, scheduled_for, previous_status)
    values (v_me.id, v_when, v_me.status);
  perform set_config('zaya.internal', '1', true);
  update profiles set status = 'hidden' where id = v_me.id and status in ('active', 'paused');
  perform set_config('zaya.internal', '0', true);
  return jsonb_build_object('status', 'scheduled', 'scheduled_for', v_when);
end;
$$;

create function cancel_account_deletion() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_req account_deletion_requests;
begin
  delete from account_deletion_requests where user_id = auth.uid() returning * into v_req;
  if not found then raise exception 'NO_DELETION_REQUEST'; end if;
  if v_req.previous_status in ('active', 'paused') then
    perform set_config('zaya.internal', '1', true);
    update profiles set status = v_req.previous_status where id = auth.uid() and status = 'hidden';
    perform set_config('zaya.internal', '0', true);
  end if;
end;
$$;

-- Export des données personnelles du membre connecté (JSON).
-- Ne contient jamais l'identité d'autres membres ni les messages reçus.
create function export_my_data() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) from profiles p where p.id = v_me),
    'sensitive', (select to_jsonb(s) - 'user_id' from profile_sensitive s where s.user_id = v_me),
    'discovery_preferences', (select to_jsonb(d) - 'user_id' from discovery_preferences d where d.user_id = v_me),
    'consents', coalesce((
      select jsonb_agg(jsonb_build_object('kind', c.kind, 'granted', c.granted,
                                          'document_version', c.document_version, 'created_at', c.created_at) order by c.id)
      from consents c where c.user_id = v_me), '[]'::jsonb),
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object('visibility', ph.visibility, 'moderation', ph.moderation,
                                          'created_at', ph.created_at) order by ph.position)
      from profile_photos ph where ph.user_id = v_me), '[]'::jsonb),
    'likes_sent', coalesce((
      select jsonb_agg(jsonb_build_object('status', i.status, 'created_at', i.created_at) order by i.created_at)
      from interests i where i.from_user = v_me), '[]'::jsonb),
    'matches', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', m.created_at, 'ended_at', m.ended_at) order by m.created_at)
      from matches m where v_me in (m.user_a, m.user_b)), '[]'::jsonb),
    'messages_sent', coalesce((
      select jsonb_agg(jsonb_build_object('body', x.body, 'created_at', x.created_at) order by x.created_at)
      from messages x where x.sender_id = v_me and x.unsent_at is null), '[]'::jsonb),
    'reports_made', coalesce((
      select jsonb_agg(jsonb_build_object('context', r.context, 'reason', r.reason, 'status', r.status,
                                          'created_at', r.created_at) order by r.created_at)
      from reports r where r.reporter = v_me), '[]'::jsonb),
    'premium', coalesce((
      select jsonb_agg(jsonb_build_object('source', g.source, 'status', g.status,
                                          'starts_at', g.starts_at, 'ends_at', g.ends_at) order by g.starts_at)
      from premium_grants g where g.user_id = v_me), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object('reference', t.reference, 'service', t.service, 'amount', t.amount,
                                          'currency', t.currency, 'method', t.method, 'status', t.status,
                                          'created_at', t.created_at) order by t.created_at)
      from transactions t where t.user_id = v_me), '[]'::jsonb)
  );
end;
$$;
