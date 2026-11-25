-- Connexion par numéro + code à 4 chiffres (décision du propriétaire, 25/11/2026) : plus de SMS à chaque connexion.
--   • Le numéro est vérifié par SMS une seule fois, à l'inscription ; ensuite, numéro + code.
--   • Code oublié : nouvelle vérification par SMS (code valable 5 minutes, réglage Auth « sms_otp_exp » = 300),
--     puis choix d'un nouveau code. Le serveur exige une vérification SMS de moins de 5 minutes.
--   • Un code à 4 chiffres n'a que 10 000 possibilités : la protection repose sur le blocage côté serveur
--     (5 erreurs → 15 min), la limite par adresse IP et le secret (« poivre ») gardé dans le coffre Vault.
--   • Les codes ne sont jamais lisibles par l'application : schéma « private », non exposé par l'API.
-- Valeurs provisoires : documentation/DECISIONS_A_CONFIRMER.md (D16 à D19).

insert into app_config (key, value, description, is_public) values
  -- Désactivée tant que la fonction Edge « pin-login » et ses secrets ne sont pas déployés (sinon personne ne
  -- pourrait se connecter par code) : activer avec update app_config set value = 'true' … après le déploiement.
  ('pin_login_enabled', 'false', 'Connexion par numéro + code à 4 chiffres (activer après déploiement de pin-login)', true),
  ('pin_max_attempts', '5', 'Erreurs de code permises avant blocage du compte', false),
  ('pin_lock_minutes', '15', 'Durée du blocage après trop d''erreurs', false),
  ('pin_reset_window_seconds', '300', 'Délai maximal entre la vérification SMS et le nouveau code', false),
  ('pin_lookups_per_ip', '30', 'Vérifications de numéro par adresse IP et par 10 minutes', false),
  ('pin_attempts_per_ip', '30', 'Essais de code par adresse IP et par heure (tous comptes confondus)', false)
on conflict (key) do nothing;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.member_pins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  salt text not null,
  pin_hash text not null,
  must_change boolean not null default false,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

-- Journal des tentatives par adresse IP (limites) : clé hachée, purgée au fil de l'eau.
create table private.pin_rate (
  id bigint generated always as identity primary key,
  key text not null,
  created_at timestamptz not null default now()
);
create index pin_rate_key_idx on private.pin_rate (key, created_at);

-- ── Outils internes
create function private.pin_pepper() returns text
language plpgsql stable security definer set search_path = public as $$
declare v text;
begin
  select decrypted_secret into v from vault.decrypted_secrets where name = 'zaya_pin_pepper';
  if v is null or char_length(v) < 16 then raise exception 'PIN_NOT_CONFIGURED'; end if;
  return v;
end;
$$;

-- Empreinte salée, poivrée et répétée (SHA-256 du cœur de PostgreSQL, sans extension).
create function private.pin_digest(p_pin text, p_salt text) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  h bytea := sha256(convert_to(private.pin_pepper() || ':' || p_salt || ':' || p_pin, 'UTF8'));
  i int;
begin
  for i in 1..2000 loop
    h := sha256(h || convert_to(p_salt, 'UTF8'));
  end loop;
  return encode(h, 'hex');
end;
$$;

create function private.pin_valid_format(p_pin text) returns boolean
language sql immutable as $$ select coalesce(p_pin ~ '^[0-9]{4}$', false) $$;

-- Codes trop faciles à deviner, refusés quand le membre choisit lui-même son code.
create function private.pin_is_weak(p_pin text) returns boolean
language sql immutable as $$
  select p_pin ~ '^(.)\1{3}$'
      or p_pin in ('0123', '1234', '2345', '3456', '4567', '5678', '6789', '9876', '8765', '7654',
                   '6543', '5432', '4321', '3210', '1212', '2580', '1004', '2000', '1111')
$$;

create function private.pin_store(p_user uuid, p_pin text, p_must_change boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_salt text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into private.member_pins (user_id, salt, pin_hash, must_change, failed_attempts, locked_until, updated_at)
    values (p_user, v_salt, private.pin_digest(p_pin, v_salt), p_must_change, 0, null, now())
  on conflict (user_id) do update
    set salt = excluded.salt, pin_hash = excluded.pin_hash, must_change = excluded.must_change,
        failed_attempts = 0, locked_until = null, updated_at = now();
end;
$$;

-- Numéro saisi (« 627 84 30 30 », « +224627843030 ») → forme stockée par Supabase Auth (« 224627843030 »).
create function public.normalize_phone(p_phone text) returns text
language sql immutable as $$
  select case
    when d ~ '^[0-9]{9}$' then '224' || d
    when d ~ '^00[0-9]+$' then substr(d, 3)
    else d
  end
  from (select regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g') as d) x;
$$;

-- Limite par clé (adresse IP…) : vrai si la limite est dépassée ; sinon la tentative est comptée.
create function private.rate_exceeded(p_key text, p_limit int, p_window interval) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  delete from private.pin_rate where created_at < now() - interval '1 day';
  if (select count(*) from private.pin_rate where key = p_key and created_at > now() - p_window) >= p_limit then
    return true;
  end if;
  insert into private.pin_rate (key) values (p_key);
  return false;
end;
$$;

create function private.ip_key(p_ip text) returns text
language sql immutable as $$ select encode(sha256(convert_to('ip:' || coalesce(nullif(p_ip, ''), 'inconnue'), 'UTF8')), 'hex') $$;

-- ── État d'un numéro (avant connexion, appelable sans compte) : 'pin' (code défini), 'no_pin' (compte existant
-- sans code), 'new' (aucun compte). Choix du propriétaire : le parcours dépend de l'existence du numéro ; la
-- limite par adresse IP freine l'énumération des numéros.
create function public.pin_phone_status(p_phone text) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_phone text := normalize_phone(p_phone);
  v_user uuid;
begin
  if not cfg_bool('pin_login_enabled', false) then return 'disabled'; end if;
  if v_phone !~ '^[0-9]{8,15}$' then raise exception 'INVALID_PHONE'; end if;
  if private.rate_exceeded('lookup:' || private.ip_key(request_ip()), cfg_int('pin_lookups_per_ip', 30), interval '10 minutes') then
    return 'rate_limited';
  end if;
  select id into v_user from auth.users where phone = v_phone;
  if v_user is null then return 'new'; end if;
  return case when exists (select 1 from private.member_pins where user_id = v_user) then 'pin' else 'no_pin' end;
end;
$$;
revoke execute on function public.pin_phone_status(text) from public;
grant execute on function public.pin_phone_status(text) to anon, authenticated;

-- ── Vérification du code (appelée uniquement par la fonction Edge « pin-login », avec la clé de service).
create function public.pin_login_check(p_phone text, p_pin text, p_ip text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_phone text := normalize_phone(p_phone);
  v_user uuid;
  r private.member_pins;
  v_max int := cfg_int('pin_max_attempts', 5);
begin
  if not cfg_bool('pin_login_enabled', false) then return jsonb_build_object('status', 'disabled'); end if;
  if private.rate_exceeded('attempt:' || private.ip_key(p_ip), cfg_int('pin_attempts_per_ip', 30), interval '1 hour') then
    return jsonb_build_object('status', 'rate_limited');
  end if;
  select id into v_user from auth.users where phone = v_phone;
  if v_user is null then return jsonb_build_object('status', 'unknown'); end if;
  select * into r from private.member_pins where user_id = v_user for update;
  if not found then return jsonb_build_object('status', 'no_pin'); end if;
  if r.locked_until is not null and r.locked_until > now() then
    return jsonb_build_object('status', 'locked', 'until', r.locked_until);
  end if;
  if not private.pin_valid_format(p_pin) or private.pin_digest(p_pin, r.salt) <> r.pin_hash then
    if r.failed_attempts + 1 >= v_max then
      update private.member_pins
        set failed_attempts = 0, locked_until = now() + make_interval(mins => cfg_int('pin_lock_minutes', 15))
        where user_id = v_user;
      perform write_audit('pin_locked', 'auth.users', v_user::text, null, null, 'Trop d''erreurs de code');
      return jsonb_build_object('status', 'locked',
                                'until', now() + make_interval(mins => cfg_int('pin_lock_minutes', 15)));
    end if;
    update private.member_pins set failed_attempts = failed_attempts + 1 where user_id = v_user;
    return jsonb_build_object('status', 'wrong', 'remaining', v_max - r.failed_attempts - 1);
  end if;
  update private.member_pins set failed_attempts = 0, locked_until = null where user_id = v_user;
  return jsonb_build_object('status', 'ok', 'user_id', v_user, 'phone', v_phone, 'must_change', r.must_change);
end;
$$;
revoke execute on function public.pin_login_check(text, text, text) from public, anon, authenticated;

-- ── Fonctions du membre connecté
create function public.my_pin_status() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'has_pin', exists (select 1 from private.member_pins where user_id = auth.uid()),
    'must_change', coalesce((select must_change from private.member_pins where user_id = auth.uid()), false))
  where auth.uid() is not null;
$$;
revoke execute on function public.my_pin_status() from public, anon;
grant execute on function public.my_pin_status() to authenticated;

-- Premier code (après l'inscription vérifiée par SMS) : seulement si aucun code n'existe encore.
create function public.set_my_pin(p_pin text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if exists (select 1 from private.member_pins where user_id = auth.uid()) then raise exception 'PIN_ALREADY_SET'; end if;
  if not private.pin_valid_format(p_pin) then raise exception 'PIN_FORMAT'; end if;
  if private.pin_is_weak(p_pin) then raise exception 'PIN_TOO_WEAK'; end if;
  perform private.pin_store(auth.uid(), p_pin, false);
end;
$$;
revoke execute on function public.set_my_pin(text) from public, anon;
grant execute on function public.set_my_pin(text) to authenticated;

-- Changement : l'ancien code est exigé ; une erreur compte comme une tentative (même blocage).
create function public.change_my_pin(p_old text, p_new text) returns void
language plpgsql security definer set search_path = public as $$
declare r private.member_pins;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into r from private.member_pins where user_id = auth.uid() for update;
  if not found then raise exception 'NO_PIN'; end if;
  if r.locked_until is not null and r.locked_until > now() then raise exception 'PIN_LOCKED'; end if;
  if private.pin_digest(coalesce(p_old, ''), r.salt) <> r.pin_hash then
    if r.failed_attempts + 1 >= cfg_int('pin_max_attempts', 5) then
      update private.member_pins
        set failed_attempts = 0, locked_until = now() + make_interval(mins => cfg_int('pin_lock_minutes', 15))
        where user_id = auth.uid();
    else
      update private.member_pins set failed_attempts = failed_attempts + 1 where user_id = auth.uid();
    end if;
    raise exception 'PIN_WRONG';
  end if;
  if not private.pin_valid_format(p_new) then raise exception 'PIN_FORMAT'; end if;
  if private.pin_is_weak(p_new) or p_new = p_old then raise exception 'PIN_TOO_WEAK'; end if;
  perform private.pin_store(auth.uid(), p_new, false);
end;
$$;
revoke execute on function public.change_my_pin(text, text) from public, anon;
grant execute on function public.change_my_pin(text, text) to authenticated;

-- Code oublié : permis seulement juste après une vérification par SMS (jeton dont la méthode « otp » date de
-- moins de pin_reset_window_seconds). Une session ouverte par le code lui-même ne suffit pas.
create function public.reset_my_pin(p_new text) returns void
language plpgsql security definer set search_path = public as $$
declare v_recent boolean;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
    where a ->> 'method' = 'otp'
      and (a ->> 'timestamp')::bigint >= extract(epoch from now())::bigint - cfg_int('pin_reset_window_seconds', 300)
  ) into v_recent;
  if not v_recent then raise exception 'OTP_REQUIRED'; end if;
  if not private.pin_valid_format(p_new) then raise exception 'PIN_FORMAT'; end if;
  if private.pin_is_weak(p_new) then raise exception 'PIN_TOO_WEAK'; end if;
  perform private.pin_store(auth.uid(), p_new, false);
  perform write_audit('pin_reset', 'auth.users', auth.uid()::text, null, null, 'Code réinitialisé après SMS');
end;
$$;
revoke execute on function public.reset_my_pin(text) from public, anon;
grant execute on function public.reset_my_pin(text) to authenticated;

-- Code imposé par l'équipe (comptes existants, compte d'essai) : à changer à la première connexion.
create function public.admin_set_member_pin(p_user uuid, p_pin text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not private.pin_valid_format(p_pin) then raise exception 'PIN_FORMAT'; end if;
  perform private.pin_store(p_user, p_pin, true);
end;
$$;
revoke execute on function public.admin_set_member_pin(uuid, text) from public, anon, authenticated;
