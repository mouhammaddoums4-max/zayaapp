-- ZAYA 2.0 — Lot 1 : Match du jour, Pulse (avec accord), Invitation (anti-fraude).
-- Tout est calculé côté serveur. Aucun montant de récompense n'est inventé : 0 tant que le propriétaire ne le fixe pas.

insert into app_config (key, value, description, is_public) values
  ('pulse_min_group', '20', 'Taille minimale d''un groupe pour afficher une statistique agrégée dans Pulse', false),
  ('pulse_new_member_days', '14', 'Un nouveau membre apparaît dans Pulse pendant ce nombre de jours', false),
  ('referral_reward_swipes', '0', 'Swipes offerts au parrain par filleul valide (0 = aucune récompense tant que non décidé)', false),
  ('referral_min_days', '7', 'Jours d''activité du filleul avant récompense', false),
  ('referral_monthly_cap', '10', 'Récompenses de parrainage maximales par parrain et par mois ; au-delà : revue manuelle', false),
  ('referral_link_base', '""', 'Domaine officiel des liens d''invitation (vide = seul le code est partagé)', true)
on conflict (key) do nothing;

-- ── Match du jour : une suggestion par membre et par jour, choisie par le serveur parmi le fil autorisé.
create table public.daily_matches (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  candidate_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.daily_matches enable row level security;
revoke all on public.daily_matches from anon, authenticated;

create function public.my_daily_match() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_day date := (now() at time zone 'utc')::date;
  v_cand uuid;
  v_row record;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('match_of_day') then return jsonb_build_object('status', 'disabled'); end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active' and account_type = 'candidate') then
    return jsonb_build_object('status', 'none');
  end if;

  select candidate_id into v_cand from daily_matches where user_id = v_me and day = v_day;
  if v_cand is not null then
    -- Déjà aimée, passée ou devenue un match : la suggestion du jour est traitée.
    if exists (select 1 from interests where from_user = v_me and to_user = v_cand)
       or exists (select 1 from passes where from_user = v_me and to_user = v_cand)
       or exists (select 1 from matches where user_a = least(v_me, v_cand) and user_b = greatest(v_me, v_cand)) then
      return jsonb_build_object('status', 'done');
    end if;
    -- Redevenue inéligible (bloquée, suspendue, non vérifiée…) : jamais présentée.
    if blocked_between(v_me, v_cand) or not is_discoverable(v_cand) then
      return jsonb_build_object('status', 'none');
    end if;
  else
    select f.id into v_cand
    from discovery_feed(50) f
    join profiles c on c.id = f.id
    join profiles m on m.id = v_me
    where trust_score(f.id) >= cfg_int('trust_min_for_recommendations', 30)
    order by (select count(*) from unnest(f.interests) i where i = any (m.interests)) * 2
             + case when f.marriage_horizon is not distinct from m.marriage_horizon then 3 else 0 end
             + trust_score(f.id) / 20 desc, f.id
    limit 1;
    if v_cand is null then return jsonb_build_object('status', 'none'); end if;
    insert into daily_matches (user_id, day, candidate_id) values (v_me, v_day, v_cand)
      on conflict (user_id, day) do nothing;
    select candidate_id into v_cand from daily_matches where user_id = v_me and day = v_day;
  end if;

  select c.id, c.display_name, age_of(c.birth_date) as age, ci.name as city, c.bio,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = c.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1) as photo_path,
         (select count(*)::int from unnest(c.interests) i where i = any (m.interests)) as shared
    into v_row
  from profiles c join profiles m on m.id = v_me left join cities ci on ci.id = c.city_id
  where c.id = v_cand;
  return jsonb_build_object('status', 'ready', 'profile', jsonb_build_object(
    'id', v_row.id, 'display_name', v_row.display_name, 'age', v_row.age, 'city', v_row.city,
    'bio', v_row.bio, 'photo_path', v_row.photo_path, 'shared_interests', v_row.shared, 'is_verified', true));
end;
$$;
revoke execute on function public.my_daily_match() from public, anon;
grant execute on function public.my_daily_match() to authenticated;

-- ── Pulse : désactivé par défaut, le membre doit l'accepter explicitement.
create table public.pulse_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  opted_in boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.pulse_settings enable row level security;
create policy pulse_settings_own on public.pulse_settings for select to authenticated using (user_id = auth.uid());
revoke all on public.pulse_settings from anon, authenticated;
grant select on public.pulse_settings to authenticated;

create function public.set_pulse_optin(p_on boolean) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('pulse') then raise exception 'FEATURE_DISABLED'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and status = 'active') then raise exception 'PROFILE_NOT_ACTIVE'; end if;
  insert into pulse_settings (user_id, opted_in) values (auth.uid(), coalesce(p_on, false))
    on conflict (user_id) do update set opted_in = excluded.opted_in, updated_at = now();
  insert into consents (user_id, kind, granted) values (auth.uid(), 'marketing', false) on conflict do nothing;
  return coalesce(p_on, false);
end;
$$;
revoke execute on function public.set_pulse_optin(boolean) from public, anon;
grant execute on function public.set_pulse_optin(boolean) to authenticated;

create function public.pulse_feed() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_country text;
  v_items jsonb;
  v_stats jsonb;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('pulse') then return jsonb_build_object('status', 'disabled'); end if;
  select country_code into v_country from profiles where id = v_me and status = 'active';
  if not found then return jsonb_build_object('status', 'none'); end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', 'new_member', 'user_id', p.id, 'display_name', p.display_name, 'age', age_of(p.birth_date),
           'city', ci.name, 'joined_at', p.created_at,
           'photo_path', (select ph.storage_path from profile_photos ph
                           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
                           order by ph.position limit 1)) order by p.created_at desc), '[]'::jsonb)
    into v_items
  from (select p.* from profiles p
        join pulse_settings s on s.user_id = p.id and s.opted_in
        where p.id <> v_me and p.country_code = v_country and not p.incognito
          and p.created_at > now() - make_interval(days => cfg_int('pulse_new_member_days', 14))
          and is_discoverable(p.id) and not blocked_between(v_me, p.id)
          and trust_score(p.id) >= cfg_int('trust_min_for_recommendations', 30)
        order by p.created_at desc limit 20) p
  left join cities ci on ci.id = p.city_id;

  -- Statistiques réelles, par ville, seulement si le groupe est assez grand pour ne désigner personne.
  select coalesce(jsonb_agg(jsonb_build_object('city', g.city, 'members', g.n, 'active_this_week', g.active)), '[]'::jsonb)
    into v_stats
  from (select ci.name as city, count(*)::int as n,
               count(*) filter (where p.last_active_at > now() - interval '7 days')::int as active
        from profiles p join cities ci on ci.id = p.city_id
        where p.country_code = v_country and p.status = 'active' and p.account_type = 'candidate'
        group by ci.name
        having count(*) >= cfg_int('pulse_min_group', 20)) g;

  return jsonb_build_object('status', 'ready',
    'opted_in', coalesce((select opted_in from pulse_settings where user_id = v_me), false),
    'items', v_items, 'stats', v_stats);
end;
$$;
revoke execute on function public.pulse_feed() from public, anon;
grant execute on function public.pulse_feed() to authenticated;

-- ── Invitation (parrainage)
create table public.referral_codes (
  code text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index referral_codes_active_idx on public.referral_codes (user_id) where revoked_at is null;
create table public.member_devices (
  user_id uuid not null references public.profiles (id) on delete cascade,
  device_hash text not null check (char_length(device_hash) between 16 and 128),
  ip text,
  first_seen timestamptz not null default now(),
  primary key (user_id, device_hash)
);
create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer uuid not null references public.profiles (id) on delete cascade,
  referee uuid not null unique references public.profiles (id) on delete cascade,
  code text not null,
  status text not null default 'pending' check (status in ('pending', 'rewarded', 'rejected', 'review', 'cancelled')),
  reject_reason text,
  reward_amount int not null default 0,
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  check (referrer <> referee)
);
create index referrals_referrer_idx on public.referrals (referrer, created_at desc);
alter table public.referral_codes enable row level security;
alter table public.member_devices enable row level security;
alter table public.referrals enable row level security;
create policy referrals_own on public.referrals for select to authenticated
  using (referrer = auth.uid() or auth_is_staff(array['super_admin', 'admin']::staff_role[]));
revoke all on public.referral_codes, public.member_devices, public.referrals from anon, authenticated;
grant select on public.referrals to authenticated;

create function public.request_ip() returns text
language plpgsql stable as $$
declare h text;
begin
  h := current_setting('request.headers', true);
  if h is null or h = '' then return null; end if;
  return nullif(trim(split_part(h::json ->> 'x-forwarded-for', ',', 1)), '');
exception when others then
  return null;
end;
$$;

create function public.register_device(p_hash text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_hash is null or char_length(p_hash) not between 16 and 128 then raise exception 'INVALID_DEVICE'; end if;
  insert into member_devices (user_id, device_hash, ip) values (auth.uid(), p_hash, request_ip())
    on conflict (user_id, device_hash) do update set ip = coalesce(excluded.ip, member_devices.ip);
end;
$$;
revoke execute on function public.register_device(text) from public, anon;
grant execute on function public.register_device(text) to authenticated;

-- Code aléatoire non devinable (10 caractères, 40 bits issus du générateur sûr de PostgreSQL), révocable.
create function public.my_referral_code() returns text
language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('invitation') then raise exception 'FEATURE_DISABLED'; end if;
  select code into v_code from referral_codes where user_id = auth.uid() and revoked_at is null;
  if v_code is not null then return v_code; end if;
  if not exists (select 1 from profiles where id = auth.uid() and status = 'active') then raise exception 'PROFILE_NOT_ACTIVE'; end if;
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    begin
      insert into referral_codes (code, user_id) values (v_code, auth.uid());
      return v_code;
    exception when unique_violation then
      select code into v_code from referral_codes where user_id = auth.uid() and revoked_at is null;
      if v_code is not null then return v_code; end if;
    end;
  end loop;
end;
$$;
revoke execute on function public.my_referral_code() from public, anon;
grant execute on function public.my_referral_code() to authenticated;

create function public.revoke_my_referral_code() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  update referral_codes set revoked_at = now() where user_id = auth.uid() and revoked_at is null;
end;
$$;
revoke execute on function public.revoke_my_referral_code() from public, anon;
grant execute on function public.revoke_my_referral_code() to authenticated;

-- Utilisation d'un code à l'inscription. Une fraude évidente est enregistrée comme « rejected » (sans récompense).
create function public.redeem_referral(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_ref uuid;
  v_reason text;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('invitation') then raise exception 'FEATURE_DISABLED'; end if;
  if not exists (select 1 from profiles where id = v_me) then raise exception 'PROFILE_NOT_FOUND'; end if;
  if exists (select 1 from referrals where referee = v_me) then raise exception 'ALREADY_REFERRED'; end if;
  select user_id into v_ref from referral_codes where code = upper(trim(p_code)) and revoked_at is null;
  if v_ref is null then raise exception 'INVALID_CODE'; end if;

  if v_ref = v_me then
    raise exception 'SELF_REFERRAL';
  end if;
  if exists (select 1 from member_devices a join member_devices b on a.device_hash = b.device_hash
              where a.user_id = v_ref and b.user_id = v_me) then
    v_reason := 'same_device';
  elsif exists (select 1 from member_devices a join member_devices b on a.ip = b.ip and a.ip is not null
                 where a.user_id = v_ref and b.user_id = v_me) then
    v_reason := 'same_ip';
  end if;
  insert into referrals (referrer, referee, code, status, reject_reason, settled_at)
    values (v_ref, v_me, upper(trim(p_code)), case when v_reason is null then 'pending' else 'rejected' end, v_reason,
            case when v_reason is null then null else now() end);
  if v_reason is not null then
    perform write_audit('referral_fraud_suspected', 'referrals', v_me::text, null, jsonb_build_object('reason', v_reason), v_reason);
  end if;
  return jsonb_build_object('status', case when v_reason is null then 'pending' else 'rejected' end);
end;
$$;
revoke execute on function public.redeem_referral(text) from public, anon;
grant execute on function public.redeem_referral(text) to authenticated;

-- Règlement des parrainages d'un parrain : atomique, idempotent (clé de crédit = identifiant du parrainage).
create function public.settle_referrals(p_referrer uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  r referrals;
  v_amount int := cfg_int('referral_reward_swipes', 0);
  v_days int := cfg_int('referral_min_days', 7);
  v_cap int := cfg_int('referral_monthly_cap', 10);
  v_month_count int;
begin
  for r in select * from referrals where referrer = p_referrer and status in ('pending', 'rewarded') order by created_at loop
    -- Filleul banni ou supprimé : parrainage annulé, récompense reprise par une ligne négative.
    if exists (select 1 from profiles where id = r.referee and status in ('banned', 'deleted')) then
      if r.status = 'rewarded' and r.reward_amount > 0 then
        insert into reward_ledger (user_id, source, asset, amount, idempotency_key, reason, reverses)
          select r.referrer, 'reversal', 'swipes', -r.reward_amount, 'referral-cancel:' || r.id, 'Parrainage annulé (filleul banni)', l.id
          from reward_ledger l where l.idempotency_key = 'referral:' || r.id
        on conflict (idempotency_key) do nothing;
        insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
          values (r.referrer, 'bonus', 'swipes', -r.reward_amount, 'Parrainage annulé (filleul banni)', 'referral-cancel:' || r.id)
        on conflict (category, ref) do nothing;
      end if;
      update referrals set status = 'cancelled', settled_at = now(), reject_reason = 'referee_banned' where id = r.id;
      continue;
    end if;
    continue when r.status <> 'pending';
    continue when not exists (
      select 1 from profiles f join profiles p on p.id = r.referrer
      where f.id = r.referee and f.status = 'active' and f.verification_status = 'approved'
        and p.status = 'active' and p.verification_status = 'approved'
        and f.created_at <= now() - make_interval(days => v_days)
        and f.last_active_at >= now() - make_interval(days => v_days));
    select count(*) into v_month_count from referrals
      where referrer = r.referrer and status = 'rewarded' and settled_at >= date_trunc('month', now());
    if v_month_count >= v_cap then
      update referrals set status = 'review', settled_at = now() where id = r.id;
      continue;
    end if;
    perform grant_reward(r.referrer, 'referral', 'swipes', v_amount, 'referral:' || r.id, 'Parrainage validé');
    update referrals set status = 'rewarded', reward_amount = v_amount, settled_at = now() where id = r.id;
  end loop;
end;
$$;
revoke execute on function public.settle_referrals(uuid) from public, anon, authenticated;

create function public.my_referral_summary() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('invitation') then return jsonb_build_object('status', 'disabled'); end if;
  perform settle_referrals(v_me);
  return jsonb_build_object('status', 'ready',
    'code', (select code from referral_codes where user_id = v_me and revoked_at is null),
    'invited', (select count(*)::int from referrals where referrer = v_me),
    'pending', (select count(*)::int from referrals where referrer = v_me and status = 'pending'),
    'rewarded', (select count(*)::int from referrals where referrer = v_me and status = 'rewarded'),
    'reward_swipes', cfg_int('referral_reward_swipes', 0),
    'min_days', cfg_int('referral_min_days', 7));
end;
$$;
revoke execute on function public.my_referral_summary() from public, anon;
grant execute on function public.my_referral_summary() to authenticated;
