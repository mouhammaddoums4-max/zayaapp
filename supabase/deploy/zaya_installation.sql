-- ZAYA — installation complète de la base de données.
-- FICHIER GÉNÉRÉ AUTOMATIQUEMENT : ne pas le modifier à la main.
-- Source : supabase/migrations/*.sql puis supabase/seed/seed.sql.
-- Régénérer : cd supabase/tests && npm run build:install
--
-- Utilisation : Supabase > SQL Editor > New query, coller tout le contenu, puis « Run ».
-- Tout est appliqué en une seule transaction : en cas d’erreur, rien n’est modifié.

begin;

do $zaya$
begin
  if to_regclass('public.profiles') is not null then
    raise exception 'ZAYA semble déjà installé (la table public.profiles existe). Aucune modification n''a été faite.';
  end if;
end;
$zaya$;

-- ════════════════════════ 0001_schema.sql
-- ZAYA — Lot A : schéma de base (référentiels, profils, interactions, confiance, Premium, audit)
-- Référence : cahier des charges V6.4. Toutes les dates sont en UTC (= heure de Conakry).

-- ───────────────────────────── Types
create type account_type as enum ('candidate', 'counselor', 'family_rep');
create type profile_gender as enum ('femme', 'homme');
create type confession as enum ('muslim', 'christian', 'other', 'none', 'undisclosed');
create type confession_mode as enum ('mine_only', 'selected', 'all', 'no_filter');
create type marital_status as enum ('single', 'divorced', 'widowed', 'married', 'separated', 'other');
create type marriage_horizon as enum ('soon', 'few_months', 'medium_term', 'no_date');
create type profile_status as enum ('draft', 'active', 'paused', 'hidden', 'suspended', 'banned', 'deleted');
create type verification_status as enum ('not_requested', 'pending', 'more_info_required', 'approved', 'rejected', 'redo');
create type verification_level as enum ('phone', 'selfie', 'identity');
create type photo_visibility as enum ('public', 'blurred', 'private');
create type moderation_status as enum ('pending', 'approved', 'rejected');
create type interest_status as enum ('pending', 'accepted', 'declined', 'expired', 'cancelled');
create type report_priority as enum ('critical', 'high', 'normal', 'low');
create type report_status as enum ('open', 'in_review', 'resolved', 'dismissed');
create type sanction_kind as enum ('warning', 'restriction', 'suspension', 'ban');
create type staff_role as enum ('super_admin', 'admin', 'moderator', 'support', 'finance', 'ads', 'tech');
create type premium_source as enum ('purchase', 'admin_grant', 'partner');
create type premium_status as enum ('pending', 'active', 'cancelled', 'revoked'); -- « expiré » est calculé (ends_at <= now())
create type transaction_status as enum
  ('pending', 'processing', 'confirmed', 'failed', 'cancelled', 'refunded', 'partially_refunded', 'disputed');

-- ───────────────────────────── Référentiels administrables
create table countries (
  code text primary key,                 -- ISO 3166-1 alpha-2
  name_fr text not null,
  name_en text not null,
  phone_prefix text not null,
  enabled boolean not null default false -- pays ouvert à l'inscription
);

create table cities (
  id bigint generated always as identity primary key,
  country_code text not null references countries (code),
  name text not null,
  enabled boolean not null default true,
  unique (country_code, name)
);

create table ethnic_groups (             -- catalogue par pays, jamais codé en dur dans l'app (§23.2)
  id bigint generated always as identity primary key,
  country_code text not null references countries (code),
  label_fr text not null,
  label_en text,
  active boolean not null default true,
  catalog_version int not null default 1,
  unique (country_code, label_fr)
);

create table professions (
  id bigint generated always as identity primary key,
  category text not null,
  label_fr text not null unique,
  label_en text,
  active boolean not null default true
);

create table app_config (                -- paramètres configurables sans nouvelle version mobile
  key text primary key,
  value jsonb not null,
  description text,
  is_public boolean not null default false, -- lisible par l'application
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table legal_documents (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('tos', 'privacy', 'community')),
  version text not null,
  lang text not null default 'fr',
  content text not null,
  published_at timestamptz not null default now(),
  unique (kind, version, lang)
);

create table moderation_terms (          -- filtre de messagerie avant envoi (§24.3)
  id bigint generated always as identity primary key,
  term text not null,
  category text not null,
  severity int not null default 2 check (severity between 1 and 3), -- 3 = bloquant
  lang text not null default 'fr',
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (term, lang)
);

-- ───────────────────────────── Profils
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  account_type account_type not null default 'candidate',
  display_name text check (char_length(display_name) between 2 and 40),
  birth_date date,
  gender profile_gender,
  seeking_gender profile_gender,
  country_code text references countries (code),
  city_id bigint references cities (id),
  nationality_code text references countries (code),
  marital_status marital_status,
  children_count smallint check (children_count between 0 and 20),
  marriage_horizon marriage_horizon,
  profession_id bigint references professions (id),
  profession_other text check (char_length(profession_other) <= 60),
  education_level text,
  height_cm smallint check (height_cm between 120 and 230),
  languages text[] not null default '{}',
  interests text[] not null default '{}',
  bio text check (char_length(bio) <= 500),
  -- État (colonnes protégées : modifiables uniquement par fonctions serveur / staff)
  status profile_status not null default 'draft',
  is_phone_verified boolean not null default false,
  verification_status verification_status not null default 'not_requested',
  onboarding_step smallint not null default 0,
  -- Confidentialité (contrôlée par le membre, gratuite)
  incognito boolean not null default false,          -- visible seulement par les personnes déjà aimées
  discreet_browsing boolean not null default false,  -- n'apparaît pas dans la liste nominative des visiteurs
  show_online boolean not null default true,
  allow_profile_sharing boolean not null default false,
  last_active_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_discovery_idx on profiles (status, verification_status, gender, country_code);

-- Données sensibles : consentement explicite, propriétaire seul, jamais utilisées pour la publicité
create table profile_sensitive (
  user_id uuid primary key references profiles (id) on delete cascade,
  confession confession,
  show_confession boolean not null default false,
  ethnic_group_id bigint references ethnic_groups (id),
  ethnic_other text check (char_length(ethnic_other) <= 60),
  show_ethnic_group boolean not null default false,
  updated_at timestamptz not null default now()
);

create table discovery_preferences (
  user_id uuid primary key references profiles (id) on delete cascade,
  age_min smallint not null default 18 check (age_min >= 18),
  age_max smallint not null default 60 check (age_max <= 99),
  country_codes text[],                              -- null = pays de résidence
  confession_mode confession_mode not null default 'no_filter',
  confessions confession[] not null default '{}',
  personalization_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  check (age_min <= age_max)
);

create table consents (                  -- preuve de consentement, append-only (§22.14)
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  kind text not null check (kind in
    ('tos', 'privacy', 'community', 'religion_data', 'ethnicity_data', 'biometric', 'marketing', 'notifications', 'geolocation')),
  document_version text,
  granted boolean not null,
  created_at timestamptz not null default now()
);
create index consents_user_idx on consents (user_id, kind, created_at desc);

create table profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  storage_path text not null,            -- bucket privé profile-photos/<user_id>/<fichier>
  position smallint not null default 0,
  visibility photo_visibility not null default 'public',
  moderation moderation_status not null default 'pending',
  created_at timestamptz not null default now()
);
create index profile_photos_user_idx on profile_photos (user_id, position);

create table verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  level verification_level not null default 'selfie',
  status verification_status not null default 'pending',
  selfie_path text,                      -- bucket privé verification/, accès journalisé
  decided_by uuid,
  decided_at timestamptz,
  decision_reason text,
  created_at timestamptz not null default now()
);

-- ───────────────────────────── Interactions
create table interests (                 -- un intérêt unilatéral = demande, pas encore un Match (§32)
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references profiles (id) on delete cascade,
  to_user uuid not null references profiles (id) on delete cascade,
  status interest_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (from_user, to_user),
  check (from_user <> to_user)
);
create index interests_to_idx on interests (to_user, status);
create index interests_from_day_idx on interests (from_user, created_at);

create table passes (
  from_user uuid not null references profiles (id) on delete cascade,
  to_user uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_user, to_user)
);

create table matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references profiles (id) on delete cascade,
  user_b uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid,
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references matches (id) on delete cascade,
  sender_id uuid not null references profiles (id) on delete cascade,
  body text not null check (char_length(body) <= 2000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  unsent_at timestamptz,
  read_at timestamptz
);
create index messages_match_idx on messages (match_id, created_at);

create table message_hidden (            -- « Supprimer pour moi »
  message_id uuid not null references messages (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  primary key (message_id, user_id)
);

create table message_violations (        -- compteur de tentatives bloquées — sans le texte du message
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  category text not null,
  created_at timestamptz not null default now()
);

create table blocks (
  blocker uuid not null references profiles (id) on delete cascade,
  blocked uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references profiles (id) on delete cascade,
  reported_user uuid not null references profiles (id) on delete cascade,
  context text not null check (context in ('profile', 'conversation', 'photo')),
  reason text not null,
  details text check (char_length(details) <= 1000),
  match_id uuid references matches (id),
  priority report_priority not null default 'normal',
  status report_status not null default 'open',
  assigned_to uuid,
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index reports_queue_idx on reports (status, priority, created_at);

create table profile_views (
  id bigint generated always as identity primary key,
  viewer uuid not null references profiles (id) on delete cascade,
  viewed uuid not null references profiles (id) on delete cascade,
  discreet boolean not null default false,
  viewed_at timestamptz not null default now()
);
create index profile_views_viewed_idx on profile_views (viewed, viewed_at desc);

create table sanctions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  kind sanction_kind not null,
  reason text not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid not null,
  appeal_status text not null default 'none' check (appeal_status in ('none', 'requested', 'upheld', 'overturned')),
  created_at timestamptz not null default now()
);

create table account_deletion_requests ( -- suppression demandée depuis l'application (§22.9)
  user_id uuid primary key references profiles (id) on delete cascade,
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null,    -- délai de rétractation configurable
  previous_status profile_status not null
);

-- ───────────────────────────── Paiements & Premium (socle V6.4 — achats désactivés tant que non conformes)
create table transactions (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,        -- référence lisible
  user_id uuid not null references profiles (id),
  service text not null check (service in ('premium', 'boost', 'shop', 'event', 'counsel')),
  order_ref text,
  amount numeric(14, 2) not null check (amount > 0),
  currency text not null default 'GNF',
  method text not null,
  provider text not null,
  provider_ref text,
  status transaction_status not null default 'pending',
  fees numeric(14, 2) not null default 0,
  net_amount numeric(14, 2),
  failure_reason text,
  idempotency_key text not null unique,  -- empêche doubles débits / doubles activations
  created_at timestamptz not null default now(),
  confirmed_at timestamptz
);
create index transactions_user_idx on transactions (user_id, created_at desc);

create table transaction_events (
  id bigint generated always as identity primary key,
  transaction_id uuid not null references transactions (id),
  old_status transaction_status,
  new_status transaction_status not null,
  source text not null,                  -- webhook vérifié, rapprochement, action admin…
  actor uuid,
  created_at timestamptz not null default now()
);

create table premium_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  source premium_source not null,
  status premium_status not null default 'active',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  transaction_id uuid references transactions (id), -- null pour une attribution gratuite : aucune transaction fictive
  reason text,
  origin text,                           -- promotion, geste commercial, partenariat, compensation, compte de test…
  created_by uuid,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (source <> 'purchase' or transaction_id is not null),
  check (source <> 'admin_grant' or (reason is not null and origin is not null and created_by is not null))
);
create index premium_grants_user_idx on premium_grants (user_id, ends_at desc);

create table premium_events (            -- historique append-only (§40.4)
  id bigint generated always as identity primary key,
  grant_id uuid not null references premium_grants (id),
  user_id uuid not null,
  action text not null check (action in ('created', 'granted', 'extended', 'revoked', 'cancelled')),
  actor uuid,                            -- administrateur, ou null = processus système
  old_starts_at timestamptz,
  old_ends_at timestamptz,
  new_starts_at timestamptz,
  new_ends_at timestamptz,
  old_status premium_status,
  new_status premium_status,
  reason text,
  origin text,
  transaction_id uuid,
  created_at timestamptz not null default now()
);

-- ───────────────────────────── Administration
create table staff_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role staff_role not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table audit_log (                 -- append-only
  id bigint generated always as identity primary key,
  actor uuid,
  action text not null,
  entity text not null,
  entity_id text,
  old_value jsonb,
  new_value jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create table sms_log (                   -- suivi des coûts Nimba (pas de numéro en clair)
  id bigint generated always as identity primary key,
  phone_hash text not null,
  purpose text not null default 'otp',
  status text not null,
  cost_gnf numeric(10, 2) not null default 0,
  provider_ref text,
  created_at timestamptz not null default now()
);

-- ════════════════════════ 0002_fonctions.sql
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

-- ════════════════════════ 0003_rls.sql
-- ZAYA — Lot A : contrôle d'accès au niveau des lignes.
-- Principe : tout est fermé par défaut ; le rôle `anon` n'a accès qu'aux référentiels publics.
-- Les écritures métier (likes, matchs, messages, Premium…) passent par les fonctions de 0002.

alter table countries enable row level security;
alter table cities enable row level security;
alter table ethnic_groups enable row level security;
alter table professions enable row level security;
alter table app_config enable row level security;
alter table legal_documents enable row level security;
alter table moderation_terms enable row level security;
alter table profiles enable row level security;
alter table profile_sensitive enable row level security;
alter table discovery_preferences enable row level security;
alter table consents enable row level security;
alter table profile_photos enable row level security;
alter table verification_requests enable row level security;
alter table interests enable row level security;
alter table passes enable row level security;
alter table matches enable row level security;
alter table messages enable row level security;
alter table message_hidden enable row level security;
alter table message_violations enable row level security;
alter table blocks enable row level security;
alter table reports enable row level security;
alter table profile_views enable row level security;
alter table sanctions enable row level security;
alter table transactions enable row level security;
alter table transaction_events enable row level security;
alter table premium_grants enable row level security;
alter table premium_events enable row level security;
alter table staff_roles enable row level security;
alter table audit_log enable row level security;
alter table sms_log enable row level security;
alter table account_deletion_requests enable row level security;

-- ───────────────────────────── Référentiels (lecture publique, écriture staff)
create policy countries_read on countries for select to anon, authenticated using (true);
create policy cities_read on cities for select to anon, authenticated using (enabled);
create policy professions_read on professions for select to anon, authenticated using (active);
create policy legal_read on legal_documents for select to anon, authenticated using (true);
create policy ethnic_read on ethnic_groups for select to authenticated using (active);
create policy config_read on app_config for select to anon, authenticated using (is_public);

create policy countries_admin on countries for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy cities_admin on cities for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy ethnic_admin on ethnic_groups for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy professions_admin on professions for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy config_admin on app_config for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'tech']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'tech']::staff_role[]));
create policy legal_admin on legal_documents for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy terms_admin on moderation_terms for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

-- ───────────────────────────── Profil : le membre ne lit directement que SA ligne.
-- Les autres profils ne sont accessibles que via discovery_feed() / get_profile() qui n'exposent que les champs publics.
create policy profiles_select_own on profiles for select to authenticated
  using (id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator', 'support']::staff_role[]));
create policy profiles_insert_own on profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Données sensibles : propriétaire uniquement (pas même le staff en lecture directe)
create policy sensitive_own on profile_sensitive for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy prefs_own on discovery_preferences for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy consents_select_own on consents for select to authenticated using (user_id = auth.uid());
create policy consents_insert_own on consents for insert to authenticated with check (user_id = auth.uid());

create policy photos_select_own on profile_photos for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy photos_insert_own on profile_photos for insert to authenticated with check (user_id = auth.uid());
create policy photos_update_own on profile_photos for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy photos_delete_own on profile_photos for delete to authenticated using (user_id = auth.uid());

create policy verif_select on verification_requests for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

-- ───────────────────────────── Interactions (lecture seule ; écriture par fonctions)
-- Un membre voit les intérêts qu'il a envoyés. Les intérêts reçus passent par received_interests() (Premium).
create policy interests_select_sent on interests for select to authenticated using (from_user = auth.uid());
create policy passes_select_own on passes for select to authenticated using (from_user = auth.uid());
create policy matches_select_own on matches for select to authenticated using (auth.uid() in (user_a, user_b));

create policy messages_select_participant on messages for select to authenticated using (
  exists (select 1 from matches m where m.id = messages.match_id and auth.uid() in (m.user_a, m.user_b))
  and not exists (select 1 from message_hidden h where h.message_id = messages.id and h.user_id = auth.uid())
);
create policy hidden_select_own on message_hidden for select to authenticated using (user_id = auth.uid());

create policy blocks_select_own on blocks for select to authenticated using (blocker = auth.uid());

create policy reports_select on reports for select to authenticated
  using (reporter = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy reports_update_staff on reports for update to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

create policy sanctions_select on sanctions for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

create policy violations_staff on message_violations for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

-- ───────────────────────────── Paiements & Premium (lecture propriétaire / finance ; aucune écriture client)
create policy tx_select on transactions for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'finance']::staff_role[]));
create policy tx_events_select on transaction_events for select to authenticated using (
  auth_is_staff(array['super_admin', 'finance']::staff_role[])
  or exists (select 1 from transactions t where t.id = transaction_events.transaction_id and t.user_id = auth.uid())
);
create policy grants_select on premium_grants for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
create policy premium_events_select on premium_events for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));

-- ───────────────────────────── Administration
create policy staff_select on staff_roles for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin']::staff_role[]));
create policy staff_manage on staff_roles for all to authenticated
  using (auth_is_staff(array['super_admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin']::staff_role[]));
create policy audit_select on audit_log for select to authenticated
  using (auth_is_staff(array['super_admin', 'tech']::staff_role[]));
create policy sms_select on sms_log for select to authenticated
  using (auth_is_staff(array['super_admin', 'finance', 'tech']::staff_role[]));
create policy deletion_select on account_deletion_requests for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'support']::staff_role[]));
-- profile_views : aucune lecture directe (statistiques agrégées via my_profile_view_stats()).

-- ───────────────────────────── Privilèges
-- Supabase accorde par défaut tous les droits sur le schéma public aux rôles anon / authenticated :
-- on repart d'une base fermée, puis on n'ouvre que le nécessaire (RLS s'applique en plus).
grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon;
grant select on countries, cities, professions, legal_documents, app_config to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
-- Fonctions internes : appelées uniquement par les fonctions `security definer`, jamais par l'application.
revoke execute on function write_audit(text, text, text, jsonb, jsonb, text) from authenticated;
revoke execute on function cfg_int(text, int) from authenticated;
revoke execute on function cfg_bool(text, boolean) from authenticated;
revoke execute on function approved_photo_count(uuid) from authenticated;
revoke execute on function is_discoverable(uuid) from authenticated;
revoke execute on function message_violation_category(text) from authenticated;
revoke execute on function like_window_start() from authenticated;

-- ════════════════════════ 0004_storage.sql
-- ZAYA — Lot A : stockage des médias (buckets privés, URLs signées).
-- Convention de chemin : <bucket>/<user_id>/<fichier>

insert into storage.buckets (id, name, public) values
  ('profile-photos', 'profile-photos', false),
  ('verification', 'verification', false)
on conflict (id) do nothing;

-- Photos de profil : le propriétaire gère son dossier.
create policy photos_owner_all on storage.objects for all to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Les autres membres ne lisent qu'une photo approuvée ET publique d'un profil visible et non bloqué.
-- Les photos privées / floutées ne sont jamais servies en original (variante floutée serveur : lot B).
create policy photos_public_read on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and exists (
      select 1 from public.profile_photos ph
      where ph.storage_path = storage.objects.name
        and ph.moderation = 'approved' and ph.visibility = 'public'
        and not public.blocked_between(auth.uid(), ph.user_id)
    )
  );

-- Selfies de vérification : dépôt par le propriétaire, lecture réservée aux modérateurs.
create policy verification_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'verification' and (storage.foldername(name))[1] = auth.uid()::text);
create policy verification_staff_read on storage.objects for select to authenticated
  using (bucket_id = 'verification'
         and public.auth_is_staff(array['super_admin', 'admin', 'moderator']::public.staff_role[]));

-- ════════════════════════ 0005_realtime.sql
-- ZAYA — Lot A : diffusion temps réel des messages (les politiques RLS de `messages` s'appliquent aux abonnés).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

-- ════════════════════════ 0006_communaute.sql
-- ZAYA — Communauté, phase 1 (CDC V2.3 §2 et §4, V6.0 §26) : communautés thématiques, publications texte,
-- commentaires, réactions, enregistrements, masquage, signalement et modération.
-- L'application ne lit jamais directement les publications : tout passe par des fonctions serveur qui
-- appliquent les blocages, les contenus masqués ou retirés et les règles de publication.
-- Identité affichée : nom de profil, initiale et badge vérifié. Aucune photo, pour ne pas contourner
-- les règles de visibilité des photos du profil de rencontre.

create type post_kind as enum ('question', 'advice', 'experience');
create type content_status as enum ('published', 'deleted', 'removed');
create type community_notif_level as enum ('all', 'important', 'events', 'none');

create table communities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null,
  icon text not null default 'groups',
  position smallint not null default 0,
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  created_by uuid,
  created_at timestamptz not null default now()
);

create table community_members (
  community_id uuid not null references communities (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'moderator', 'admin')),
  notif_level community_notif_level not null default 'important',
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index community_members_user_idx on community_members (user_id);

create table posts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities (id),
  author_id uuid not null references profiles (id) on delete cascade,
  kind post_kind not null default 'question',
  body text not null check (char_length(body) between 1 and 2000),
  comments_enabled boolean not null default true,
  status content_status not null default 'published',
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  removed_by uuid,
  removal_reason text
);
create index posts_feed_idx on posts (community_id, status, created_at desc);
create index posts_author_idx on posts (author_id, created_at desc);

create table post_revisions (            -- historique des modifications (V6.0 §26.1), lecture : modération
  id bigint generated always as identity primary key,
  post_id uuid not null references posts (id) on delete cascade,
  previous_body text not null,
  edited_by uuid not null,
  edited_at timestamptz not null default now()
);

create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts (id) on delete cascade,
  author_id uuid not null references profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  status content_status not null default 'published',
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  removed_by uuid,
  removal_reason text
);
create index comments_post_idx on comments (post_id, created_at);
create index comments_author_idx on comments (author_id, created_at desc);

create table post_reactions (
  post_id uuid not null references posts (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table saved_posts (
  user_id uuid not null references profiles (id) on delete cascade,
  post_id uuid not null references posts (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table post_hidden (               -- « Masquer » : retiré de mon fil uniquement
  user_id uuid not null references profiles (id) on delete cascade,
  post_id uuid not null references posts (id) on delete cascade,
  primary key (user_id, post_id)
);

create table comment_hidden (
  user_id uuid not null references profiles (id) on delete cascade,
  comment_id uuid not null references comments (id) on delete cascade,
  primary key (user_id, comment_id)
);

-- Signalement des contenus communautaires
alter table reports add column post_id uuid references posts (id) on delete set null;
alter table reports add column comment_id uuid references comments (id) on delete set null;
alter table reports drop constraint reports_context_check;
alter table reports add constraint reports_context_check
  check (context in ('profile', 'conversation', 'photo', 'post', 'comment'));

-- Tentatives bloquées : on distingue la messagerie et la communauté (statistiques de modération)
alter table message_violations add column context text not null default 'message'
  check (context in ('message', 'post', 'comment'));

-- ───────────────────────────── Règles de contenu
-- Coordonnées : numéro de téléphone, e-mail, lien de messagerie externe. Les montants suivis d'une devise
-- (« 5 000 000 GNF », « 25 000 000 de francs ») ne sont pas des numéros. La détection n'est pas parfaite :
-- elle complète la modération humaine, elle ne la remplace pas (CDC §34.3).
create function contains_contact_details(p_body text) returns boolean
language sql immutable as $$
  select p_body ~* '[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}'
      or p_body ~* '(wa\.me|whatsapp\.com|t\.me|telegram\.me|m\.me)/'
      or regexp_replace(
           p_body,
           '\d([ .,-]?\d)*\s*(de\s+|d'')?(gnf|fg|francs?|fcfa|cfa|euros?|eur|usd|dollars?|€|\$)',
           ' ', 'gi')
         ~ '(\+|00)?\d([ .-]?\d){7,14}';
$$;

create function community_violation(p_body text) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(message_violation_category(p_body),
                  case when contains_contact_details(p_body) then 'contact_details' end);
$$;

create function report_priority_for(p_reason text) returns report_priority
language sql immutable as $$
  select case
    when p_reason in ('threat', 'blackmail', 'minor', 'exploitation', 'non_consensual_image') then 'critical'::report_priority
    when p_reason in ('scam', 'money_request', 'harassment', 'impersonation') then 'high'::report_priority
    when p_reason in ('spam', 'other') then 'low'::report_priority
    else 'normal'::report_priority end;
$$;

-- Contrôle commun : module ouvert, profil utilisable ; pour écrire, profil vérifié et aucune restriction en cours.
create function community_guard(p_write boolean) returns profiles
language plpgsql stable security definer set search_path = public as $$
declare
  v_me profiles;
begin
  if not cfg_bool('community_enabled', false) then raise exception 'COMMUNITY_DISABLED'; end if;
  select * into v_me from profiles where id = auth.uid();
  if not found or v_me.status in ('draft', 'suspended', 'banned', 'deleted') then
    raise exception 'PROFILE_NOT_ACTIVE';
  end if;
  if p_write then
    if exists (select 1 from sanctions s
               where s.user_id = v_me.id and s.kind in ('restriction', 'suspension', 'ban')
                 and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())) then
      raise exception 'ACCOUNT_RESTRICTED';
    end if;
    if cfg_bool('community_post_requires_verification', true) and v_me.verification_status <> 'approved' then
      raise exception 'VERIFICATION_REQUIRED';
    end if;
  end if;
  return v_me;
end;
$$;

-- Une publication est visible si elle est publiée, dans une communauté ouverte, d'un auteur dont le profil
-- n'est ni masqué ni sanctionné, sans blocage entre les deux membres et sans masquage par le lecteur.
create function post_visible(p posts, p_viewer uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p.status = 'published'
     and exists (select 1 from communities c where c.id = p.community_id and c.status = 'active')
     and (p.author_id = p_viewer
          or exists (select 1 from profiles a where a.id = p.author_id and a.status in ('active', 'paused')))
     and not blocked_between(p_viewer, p.author_id)
     and not exists (select 1 from post_hidden h where h.post_id = p.id and h.user_id = p_viewer);
$$;

create function comment_visible(x comments, p_viewer uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select x.status = 'published'
     and (x.author_id = p_viewer
          or exists (select 1 from profiles a where a.id = x.author_id and a.status in ('active', 'paused')))
     and not blocked_between(p_viewer, x.author_id)
     and not exists (select 1 from comment_hidden h where h.comment_id = x.id and h.user_id = p_viewer);
$$;

-- Requête commune du fil, du détail et des publications enregistrées (usage interne).
create function post_query(p_viewer uuid, p_post uuid, p_community uuid, p_joined_only boolean,
                           p_saved_only boolean, p_before timestamptz, p_limit int)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language sql stable security definer set search_path = public as $$
  select p.id, p.community_id, c.name, p.author_id, a.display_name, a.verification_status = 'approved',
         p.kind, p.body, p.comments_enabled, p.created_at, p.edited_at is not null,
         (select count(*)::int from post_reactions r where r.post_id = p.id),
         (select count(*)::int from comments x where x.post_id = p.id and comment_visible(x, p_viewer)),
         exists (select 1 from post_reactions r where r.post_id = p.id and r.user_id = p_viewer),
         exists (select 1 from saved_posts s where s.post_id = p.id and s.user_id = p_viewer),
         p.author_id = p_viewer
  from posts p
  join communities c on c.id = p.community_id
  join profiles a on a.id = p.author_id
  where (p_post is null or p.id = p_post)
    and (p_community is null or p.community_id = p_community)
    and (not p_joined_only
         or exists (select 1 from community_members m where m.community_id = p.community_id and m.user_id = p_viewer))
    and (not p_saved_only
         or exists (select 1 from saved_posts s2 where s2.post_id = p.id and s2.user_id = p_viewer))
    and (p_before is null or p.created_at < p_before)
    and post_visible(p, p_viewer)
  order by p.created_at desc
  limit least(greatest(p_limit, 1), 50);
$$;

-- ───────────────────────────── Communautés
create function list_communities()
returns table (community_id uuid, slug text, name text, description text, icon text,
               member_count int, joined boolean, notif_level community_notif_level)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
begin
  return query
    select c.id, c.slug, c.name, c.description, c.icon,
           (select count(*)::int from community_members m where m.community_id = c.id),
           m.user_id is not null, m.notif_level
    from communities c
    left join community_members m on m.community_id = c.id and m.user_id = v_me.id
    where c.status = 'active'
    order by c.position, c.name;
end;
$$;

create function join_community(p_community uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(false);
begin
  if not exists (select 1 from communities where id = p_community and status = 'active') then
    raise exception 'COMMUNITY_NOT_FOUND';
  end if;
  insert into community_members (community_id, user_id) values (p_community, v_me.id) on conflict do nothing;
end;
$$;

create function leave_community(p_community uuid) returns void
language sql security definer set search_path = public as $$
  delete from community_members where community_id = p_community and user_id = auth.uid();
$$;

create function set_community_notifications(p_community uuid, p_level community_notif_level) returns void
language plpgsql security definer set search_path = public as $$
begin
  update community_members set notif_level = p_level where community_id = p_community and user_id = auth.uid();
  if not found then raise exception 'NOT_A_MEMBER'; end if;
end;
$$;

-- ───────────────────────────── Lecture
-- Fil « Pour vous » : les communautés suivies ; si le membre n'en suit aucune, toutes les communautés.
create function community_feed(p_community uuid default null, p_before timestamptz default null, p_limit int default 20)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
  v_joined_only boolean;
begin
  v_joined_only := p_community is null and exists (select 1 from community_members m where m.user_id = v_me.id);
  return query select * from post_query(v_me.id, null, p_community, v_joined_only, false, p_before, p_limit);
end;
$$;

create function community_post(p_post uuid)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
begin
  return query select * from post_query(v_me.id, p_post, null, false, false, null, 1);
  if not found then raise exception 'POST_NOT_FOUND'; end if;
end;
$$;

create function saved_community_posts(p_before timestamptz default null, p_limit int default 20)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
begin
  return query select * from post_query(v_me.id, null, null, false, true, p_before, p_limit);
end;
$$;

create function post_comments(p_post uuid)
returns table (comment_id uuid, author_id uuid, author_name text, author_verified boolean, body text,
               created_at timestamptz, edited boolean, is_mine boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
  v_post posts;
begin
  select * into v_post from posts p where p.id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  return query
    select x.id, x.author_id, a.display_name, a.verification_status = 'approved', x.body, x.created_at,
           x.edited_at is not null, x.author_id = v_me.id
    from comments x
    join profiles a on a.id = x.author_id
    where x.post_id = p_post and comment_visible(x, v_me.id)
    order by x.created_at;
end;
$$;

-- ───────────────────────────── Publications
create function create_post(p_community uuid, p_kind post_kind, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
  v_id uuid;
begin
  if not exists (select 1 from communities where id = p_community and status = 'active') then
    raise exception 'COMMUNITY_NOT_FOUND';
  end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_POST'; end if;
  if (select count(*) from posts where author_id = v_me.id and created_at > now() - interval '1 day')
     >= cfg_int('community_posts_per_day', 5) then
    raise exception 'RATE_LIMITED';
  end if;
  -- Filtre avant publication : un contenu non conforme n'est jamais enregistré ni diffusé.
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'post');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  -- Publier dans une communauté revient à la suivre.
  insert into community_members (community_id, user_id) values (p_community, v_me.id) on conflict do nothing;
  insert into posts (community_id, author_id, kind, body) values (p_community, v_me.id, p_kind, v_body)
    returning id into v_id;
  return jsonb_build_object('status', 'published', 'id', v_id);
end;
$$;

create function edit_post(p_post uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_post posts;
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
begin
  select * into v_post from posts where id = p_post and author_id = v_me.id and status = 'published' for update;
  if not found then raise exception 'POST_NOT_FOUND'; end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_POST'; end if;
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'post');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  if v_body <> v_post.body then
    insert into post_revisions (post_id, previous_body, edited_by) values (p_post, v_post.body, v_me.id);
    update posts set body = v_body, edited_at = now() where id = p_post;
  end if;
  return jsonb_build_object('status', 'published', 'id', p_post);
end;
$$;

-- Suppression par l'auteur : retirée pour tous ; conservée un temps limité pour la modération (V6.0 §26.1).
create function delete_post(p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update posts set status = 'deleted', deleted_at = now()
    where id = p_post and author_id = auth.uid() and status = 'published';
  if not found then raise exception 'POST_NOT_FOUND'; end if;
end;
$$;

create function set_post_comments(p_post uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  update posts set comments_enabled = p_enabled
    where id = p_post and author_id = auth.uid() and status = 'published';
  if not found then raise exception 'POST_NOT_FOUND'; end if;
end;
$$;

create function react_to_post(p_post uuid, p_on boolean) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(false);
  v_post posts;
begin
  select * into v_post from posts where id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  if p_on then
    insert into post_reactions (post_id, user_id) values (p_post, v_me.id) on conflict do nothing;
  else
    delete from post_reactions where post_id = p_post and user_id = v_me.id;
  end if;
  return (select count(*)::int from post_reactions where post_id = p_post);
end;
$$;

create function save_post(p_post uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(false);
  v_post posts;
begin
  if not p_on then
    delete from saved_posts where post_id = p_post and user_id = v_me.id;
    return;
  end if;
  select * into v_post from posts where id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  insert into saved_posts (user_id, post_id) values (v_me.id, p_post) on conflict do nothing;
end;
$$;

create function hide_post(p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from posts where id = p_post) then raise exception 'POST_NOT_FOUND'; end if;
  insert into post_hidden (user_id, post_id) values (auth.uid(), p_post) on conflict do nothing;
end;
$$;

-- ───────────────────────────── Commentaires
create function add_comment(p_post uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_post posts;
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
  v_id uuid;
begin
  select * into v_post from posts where id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  if not v_post.comments_enabled then raise exception 'COMMENTS_DISABLED'; end if;
  if v_body = '' or char_length(v_body) > 1000 then raise exception 'INVALID_COMMENT'; end if;
  if (select count(*) from comments where author_id = v_me.id and created_at > now() - interval '1 hour')
     >= cfg_int('community_comments_per_hour', 20) then
    raise exception 'RATE_LIMITED';
  end if;
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'comment');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  insert into comments (post_id, author_id, body) values (p_post, v_me.id, v_body) returning id into v_id;
  return jsonb_build_object('status', 'published', 'id', v_id);
end;
$$;

create function edit_comment(p_comment uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
begin
  if not exists (select 1 from comments where id = p_comment and author_id = v_me.id and status = 'published') then
    raise exception 'COMMENT_NOT_FOUND';
  end if;
  if v_body = '' or char_length(v_body) > 1000 then raise exception 'INVALID_COMMENT'; end if;
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'comment');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  update comments set body = v_body, edited_at = now() where id = p_comment;
  return jsonb_build_object('status', 'published', 'id', p_comment);
end;
$$;

create function delete_comment(p_comment uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update comments set status = 'deleted', deleted_at = now()
    where id = p_comment and author_id = auth.uid() and status = 'published';
  if not found then raise exception 'COMMENT_NOT_FOUND'; end if;
end;
$$;

-- ───────────────────────────── Signalement : le contenu signalé disparaît aussitôt pour la personne qui signale
create function report_post(p_post uuid, p_reason text, p_details text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_post posts;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_post from posts where id = p_post;
  if not found or v_post.author_id = auth.uid() then raise exception 'INVALID_TARGET'; end if;
  insert into reports (reporter, reported_user, context, reason, details, post_id, priority)
    values (auth.uid(), v_post.author_id, 'post', p_reason, p_details, p_post, report_priority_for(p_reason))
    returning id into v_id;
  insert into post_hidden (user_id, post_id) values (auth.uid(), p_post) on conflict do nothing;
  return v_id;
end;
$$;

create function report_comment(p_comment uuid, p_reason text, p_details text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_comment comments;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_comment from comments where id = p_comment;
  if not found or v_comment.author_id = auth.uid() then raise exception 'INVALID_TARGET'; end if;
  insert into reports (reporter, reported_user, context, reason, details, post_id, comment_id, priority)
    values (auth.uid(), v_comment.author_id, 'comment', p_reason, p_details, v_comment.post_id, p_comment,
            report_priority_for(p_reason))
    returning id into v_id;
  insert into comment_hidden (user_id, comment_id) values (auth.uid(), p_comment) on conflict do nothing;
  return v_id;
end;
$$;

-- ───────────────────────────── Modération (retirer, restaurer), tracée dans le journal d'audit
create function admin_moderate_post(p_post uuid, p_action text, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_post posts;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_post from posts where id = p_post for update;
  if not found then raise exception 'POST_NOT_FOUND'; end if;
  if p_action = 'remove' and v_post.status = 'published' then
    update posts set status = 'removed', removed_by = auth.uid(), removal_reason = p_reason where id = p_post;
  elsif p_action = 'restore' and v_post.status = 'removed' then
    update posts set status = 'published', removed_by = null, removal_reason = null where id = p_post;
  else
    raise exception 'INVALID_ACTION';
  end if;
  perform write_audit('post.' || p_action, 'posts', p_post::text,
                      jsonb_build_object('status', v_post.status),
                      jsonb_build_object('status', case when p_action = 'remove' then 'removed' else 'published' end),
                      p_reason);
end;
$$;

create function admin_moderate_comment(p_comment uuid, p_action text, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_comment comments;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_comment from comments where id = p_comment for update;
  if not found then raise exception 'COMMENT_NOT_FOUND'; end if;
  if p_action = 'remove' and v_comment.status = 'published' then
    update comments set status = 'removed', removed_by = auth.uid(), removal_reason = p_reason where id = p_comment;
  elsif p_action = 'restore' and v_comment.status = 'removed' then
    update comments set status = 'published', removed_by = null, removal_reason = null where id = p_comment;
  else
    raise exception 'INVALID_ACTION';
  end if;
  perform write_audit('comment.' || p_action, 'comments', p_comment::text,
                      jsonb_build_object('status', v_comment.status),
                      jsonb_build_object('status', case when p_action = 'remove' then 'removed' else 'published' end),
                      p_reason);
end;
$$;

-- ───────────────────────────── Accès
alter table communities enable row level security;
alter table community_members enable row level security;
alter table posts enable row level security;
alter table post_revisions enable row level security;
alter table comments enable row level security;
alter table post_reactions enable row level security;
alter table saved_posts enable row level security;
alter table post_hidden enable row level security;
alter table comment_hidden enable row level security;

create policy communities_read on communities for select to authenticated
  using (status = 'active' or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy communities_admin on communities for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy members_own on community_members for select to authenticated using (user_id = auth.uid());
create policy saved_own on saved_posts for select to authenticated using (user_id = auth.uid());
create policy post_hidden_own on post_hidden for select to authenticated using (user_id = auth.uid());
create policy comment_hidden_own on comment_hidden for select to authenticated using (user_id = auth.uid());
-- Publications, commentaires, réactions, historique : lecture directe réservée à la modération.
create policy posts_staff on posts for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy comments_staff on comments for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy reactions_staff on post_reactions for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy revisions_staff on post_revisions for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

revoke all on communities, community_members, posts, post_revisions, comments, post_reactions,
              saved_posts, post_hidden, comment_hidden from anon;
grant select on communities, community_members, posts, post_revisions, comments, post_reactions,
                saved_posts, post_hidden, comment_hidden to authenticated;

-- Fonctions : aucune pour anon ; seules les fonctions de l'API sont ouvertes aux membres connectés.
revoke execute on all functions in schema public from public, anon;
revoke execute on function contains_contact_details(text), community_violation(text), report_priority_for(text),
                           community_guard(boolean), post_visible(posts, uuid), comment_visible(comments, uuid),
                           post_query(uuid, uuid, uuid, boolean, boolean, timestamptz, int)
  from authenticated;
grant execute on function list_communities(), join_community(uuid), leave_community(uuid),
                          set_community_notifications(uuid, community_notif_level),
                          community_feed(uuid, timestamptz, int), community_post(uuid),
                          saved_community_posts(timestamptz, int), post_comments(uuid),
                          create_post(uuid, post_kind, text), edit_post(uuid, text), delete_post(uuid),
                          set_post_comments(uuid, boolean), react_to_post(uuid, boolean), save_post(uuid, boolean),
                          hide_post(uuid), add_comment(uuid, text), edit_comment(uuid, text), delete_comment(uuid),
                          report_post(uuid, text, text), report_comment(uuid, text, text),
                          admin_moderate_post(uuid, text, text), admin_moderate_comment(uuid, text, text)
  to authenticated;

-- ───────────────────────────── Export des données : ajout des contenus communautaires du membre (§22.9)
create or replace function export_my_data() returns jsonb
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
    'community_posts', coalesce((
      select jsonb_agg(jsonb_build_object('community', c.name, 'kind', p.kind, 'body', p.body, 'status', p.status,
                                          'created_at', p.created_at, 'edited_at', p.edited_at) order by p.created_at)
      from posts p join communities c on c.id = p.community_id where p.author_id = v_me), '[]'::jsonb),
    'community_comments', coalesce((
      select jsonb_agg(jsonb_build_object('body', x.body, 'status', x.status, 'created_at', x.created_at)
                       order by x.created_at)
      from comments x where x.author_id = v_me), '[]'::jsonb),
    'communities_followed', coalesce((
      select jsonb_agg(c.name order by c.position)
      from community_members m join communities c on c.id = m.community_id where m.user_id = v_me), '[]'::jsonb),
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

-- ════════════════════════ 0007_photos_lecture.sql
-- ZAYA — Correction : un membre ne pouvait pas afficher les photos des autres membres (« Object not found »).
-- La règle de lecture du stockage (0004, photos_public_read) interrogeait public.profile_photos avec les droits
-- du membre connecté ; or la RLS de profile_photos ne lui montre que ses propres lignes, donc la condition
-- était toujours fausse pour la photo d'un autre. La vérification passe désormais par une fonction
-- `security definer`, avec exactement les mêmes conditions : photo approuvée, publique, et aucun blocage
-- entre les deux membres. Les photos privées ou floutées ne sont toujours jamais servies en original.

create function photo_is_viewable(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profile_photos ph
    where ph.storage_path = p_path
      and ph.moderation = 'approved' and ph.visibility = 'public'
      and not blocked_between(auth.uid(), ph.user_id)
  );
$$;
revoke execute on function photo_is_viewable(text) from public, anon;
grant execute on function photo_is_viewable(text) to authenticated;

drop policy photos_public_read on storage.objects;
create policy photos_public_read on storage.objects for select to authenticated
  using (bucket_id = 'profile-photos' and public.photo_is_viewable(name));

-- ════════════════════════ 0008_assistance.sql
-- ZAYA — Assistance dans l'application (CARTE_ECRANS F12, cahier des charges §37 : « assistance et procédures
-- d'incident » avant l'ouverture) et langues de l'interface activables par l'administration (§22.15, §22.16).
--
-- Un membre connecté (même suspendu, pour pouvoir contester) écrit à l'assistance ; il ne lit que ses propres
-- demandes. Les problèmes de sécurité sont prioritaires. Aucune écriture directe : tout passe par des fonctions.

create type support_status as enum ('open', 'in_progress', 'answered', 'closed');

create table support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null
    check (category in ('account', 'verification', 'payment', 'safety', 'translation', 'bug', 'other')),
  message text not null check (char_length(message) between 10 and 2000),
  priority int not null default 2 check (priority between 1 and 3),   -- 1 = sécurité, traitée en premier
  status support_status not null default 'open',
  app_language text,                                                  -- langue de l'interface au moment de la demande
  reply text,
  replied_by uuid references auth.users (id) on delete set null,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index support_tickets_user on support_tickets (user_id, created_at desc);
create index support_tickets_queue on support_tickets (status, priority, created_at);

alter table support_tickets enable row level security;
create policy support_read on support_tickets for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator', 'support']::staff_role[]));
revoke all on support_tickets from anon, authenticated;
grant select on support_tickets to authenticated;

insert into app_config (key, value, description, is_public) values
  ('support_tickets_per_day', '5', 'Nombre maximal de demandes à l''assistance par membre et par 24 h', false),
  ('active_languages', '["fr", "en"]',
   'Langues de l''interface activées (codes ISO). Une langue n''est proposée que si l''application est entièrement traduite (§22.15)',
   true)
on conflict (key) do nothing;

create function create_support_ticket(p_category text, p_message text, p_language text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_text text := trim(coalesce(p_message, ''));
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_category is null
     or p_category not in ('account', 'verification', 'payment', 'safety', 'translation', 'bug', 'other') then
    raise exception 'INVALID_CATEGORY';
  end if;
  if char_length(v_text) < 10 then raise exception 'MESSAGE_TOO_SHORT'; end if;
  if (select count(*) from support_tickets
      where user_id = auth.uid() and created_at > now() - interval '24 hours') >= cfg_int('support_tickets_per_day', 5) then
    raise exception 'SUPPORT_RATE_LIMITED';
  end if;
  insert into support_tickets (user_id, category, message, priority, app_language)
  values (auth.uid(), p_category, left(v_text, 2000), case when p_category = 'safety' then 1 else 2 end,
          nullif(trim(coalesce(p_language, '')), ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- Réponse de l'équipe (console d'administration, lot A12) : tracée dans le journal d'audit.
create function admin_answer_support_ticket(p_ticket uuid, p_reply text, p_status support_status) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old support_tickets;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator', 'support']::staff_role[]) then
    raise exception 'FORBIDDEN';
  end if;
  if p_status = 'answered' and coalesce(trim(p_reply), '') = '' then raise exception 'REPLY_REQUIRED'; end if;
  select * into v_old from support_tickets where id = p_ticket for update;
  if not found then raise exception 'TICKET_NOT_FOUND'; end if;
  update support_tickets
    set status = p_status,
        reply = coalesce(nullif(trim(coalesce(p_reply, '')), ''), reply),
        replied_by = case when coalesce(trim(p_reply), '') = '' then replied_by else auth.uid() end,
        replied_at = case when coalesce(trim(p_reply), '') = '' then replied_at else now() end
    where id = p_ticket;
  perform write_audit('support.' || p_status::text, 'support_tickets', p_ticket::text,
                      jsonb_build_object('status', v_old.status), jsonb_build_object('status', p_status), null);
end;
$$;

-- Export des données (§22.9) : la version précédente est conservée telle quelle et complétée par les demandes
-- à l'assistance, sans recopier son contenu.
alter function export_my_data() rename to export_my_data_base;
create function export_my_data() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  return export_my_data_base() || jsonb_build_object(
    'support_requests', coalesce((
      select jsonb_agg(jsonb_build_object('category', t.category, 'message', t.message, 'status', t.status,
                                          'reply', t.reply, 'created_at', t.created_at) order by t.created_at)
      from support_tickets t where t.user_id = auth.uid()), '[]'::jsonb));
end;
$$;

revoke execute on all functions in schema public from public, anon;
revoke execute on function export_my_data_base() from authenticated;
grant execute on function create_support_ticket(text, text, text), admin_answer_support_ticket(uuid, text, support_status),
                          export_my_data()
  to authenticated;

-- ════════════════════════ 0009_photos_floutees.sql
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

-- ════════════════════════ 0010_matchs_termines.sql
-- ZAYA — Matchs terminés (CARTE_ECRANS E01 « liste des matchs terminés, avec une explication », §7.1 ;
-- cahier des charges §32).
--
-- Après un dématch, plus aucun nouveau message n'est possible (send_message → MATCH_ENDED) et le match quitte
-- la liste des conversations des deux côtés. Cette liste sert à relire l'historique, qui reste lisible par les
-- deux personnes (RLS messages_select_participant), et à signaler la personne si besoin.
-- Le lien est retiré : ni photo ni accès au profil, seulement le nom affiché, masqué si le compte est fermé.
-- Un blocage efface toute trace dans cette liste : le dématch n'est pas un blocage, mais le blocage l'emporte.

create function my_ended_matches()
returns table (match_id uuid, user_id uuid, display_name text, matched_at timestamptz, ended_at timestamptz,
               ended_by_me boolean, account_closed boolean)
language sql stable security definer set search_path = public as $$
  select m.id,
         p.id,
         case when p.status in ('deleted', 'banned') then null else p.display_name end,
         m.created_at,
         m.ended_at,
         coalesce(m.ended_by = auth.uid(), false),
         p.status in ('deleted', 'banned')
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b)
    and m.ended_at is not null
    and not blocked_between(auth.uid(), p.id)
  order by m.ended_at desc
  limit 100;
$$;

revoke execute on function my_ended_matches() from public, anon;
grant execute on function my_ended_matches() to authenticated;

-- ════════════════════════ 0011_otp_renvoi.sql
-- ZAYA — Délai avant de pouvoir redemander un code de connexion (cahier des charges §9, CARTE_ECRANS A03).
-- Réglable sans nouvelle version de l'application : l'écran affiche un compte à rebours, puis « Renvoyer le code ».
-- Le serveur d'authentification garde ses propres limites (fréquence et nombre d'envois) : ce réglage ne les remplace pas.

insert into app_config (key, value, description, is_public) values
  ('otp_resend_seconds', '60', 'Secondes avant de pouvoir redemander un code de connexion (compte à rebours)', true)
on conflict (key) do nothing;

-- ════════════════════════ 0012_filtre_ville.sql
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

-- ════════════════════════ 0014_mises_a_jour_et_avis.sql
-- ZAYA — Mises à jour de l'application et demande d'avis sur le store.
-- Tout est réglable sans nouvelle version : l'application lit ces clés publiques au lancement.
--   • latest_app_version : au-dessus de la version installée → proposition de mise à jour (une fois par version).
--   • min_app_version : au-dessus de la version installée → mise à jour obligatoire (écran bloquant), par exemple
--     après une correction de sécurité.
--   • app_update_url : lien de la mise à jour ; vide = fiche Google Play de l'application.
--   • rating_* : la fenêtre d'avis de Google Play n'est proposée que de temps en temps, jamais aux nouveaux membres.

insert into app_config (key, value, description, is_public) values
  ('latest_app_version', '"0.1.0"', 'Dernière version publiée de l''application (proposition de mise à jour)', true),
  ('min_app_version', '"0.1.0"', 'Version minimale acceptée : en dessous, la mise à jour est obligatoire', true),
  ('app_update_url', '""', 'Lien de la mise à jour ; vide = fiche Google Play de l''application', true),
  ('rating_prompt_enabled', 'true', 'Proposer de temps en temps de noter l''application sur le store', true),
  ('rating_min_days', '7', 'Jours depuis la première ouverture avant la première demande d''avis', true),
  ('rating_min_sessions', '5', 'Nombre d''ouvertures de l''application avant la première demande d''avis', true),
  ('rating_interval_days', '90', 'Jours minimum entre deux demandes d''avis', true)
on conflict (key) do nothing;

-- ════════════════════════ 0015_regie_publicitaire.sql
-- ZAYA — Régie publicitaire : annonceurs directs, campagnes, emplacements, statistiques, réglages AdMob.
-- Références : cahier « Régie publicitaire » v1 (§2, §9, §11 à §13) ; CDC V6.4 §22.13 et §18 (« paiements et publicités
-- désactivés tant que leur conformité n'est pas vérifiée »).
--
-- Règles :
--   • Tout est désactivé par défaut (ads_direct_enabled, ads_admob_enabled = false) jusqu'à validation.
--   • Jamais de publicité dans les conversations : seuls les emplacements listés ici existent.
--   • Aucun ciblage à partir de données sensibles : les campagnes ne visent qu'un emplacement, jamais une personne.
--   • Les membres ne lisent les campagnes que par sponsored_ads() ; aucune lecture directe des tables.
--   • Un clic n'est compté qu'après un affichage réel au même membre ; aucune récompense n'est liée à un clic.
--   • Démarrage et arrêt automatiques selon les dates (statut effectif calculé).
-- Les tables du cahier « ad_impressions » et « ad_clicks » sont réunies dans ad_events (colonne kind).

create type ad_campaign_status as enum
  ('draft', 'pending_review', 'scheduled', 'active', 'suspended', 'ended', 'archived');

create table advertisers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  logo_path text,                                   -- bucket public « ad-media »
  contact_name text check (char_length(contact_name) <= 120),
  contact_phone text check (char_length(contact_phone) <= 40),
  contact_email text check (char_length(contact_email) <= 160),
  notes text check (char_length(notes) <= 2000),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  advertiser_id uuid not null references advertisers (id) on delete restrict,
  name text not null check (char_length(name) between 2 and 120),
  status ad_campaign_status not null default 'draft',
  placements text[] not null default '{}'
    check (placements <@ array['community_feed', 'explore', 'profile']::text[]),
  headline text not null check (char_length(headline) between 2 and 90),
  body text check (char_length(body) <= 280),
  cta_label text check (char_length(cta_label) <= 30),
  destination_url text check (destination_url ~ '^https://[^\s]+$'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  max_impressions_per_user_per_day int not null default 3 check (max_impressions_per_user_per_day between 1 and 50),
  budget_gnf numeric(14, 0) check (budget_gnf >= 0),
  amount_paid_gnf numeric(14, 0) not null default 0 check (amount_paid_gnf >= 0),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'partial', 'paid')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index ad_campaigns_live on ad_campaigns (status, starts_at, ends_at);

create table ad_creatives (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references ad_campaigns (id) on delete cascade,
  media_type text not null check (media_type in ('image', 'video')),
  storage_path text not null,                       -- JPG, PNG, WebP ou MP4 dans « ad-media »
  aspect text not null default 'landscape' check (aspect in ('square', 'landscape', 'portrait')),
  created_at timestamptz not null default now()
);

create table ad_events (
  id bigint generated always as identity primary key,
  campaign_id uuid not null references ad_campaigns (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  kind text not null check (kind in ('impression', 'click')),
  placement text not null,
  created_at timestamptz not null default now()
);
create index ad_events_stats on ad_events (campaign_id, kind, created_at);
create index ad_events_user_day on ad_events (user_id, campaign_id, kind, created_at);

alter table advertisers enable row level security;
alter table ad_campaigns enable row level security;
alter table ad_creatives enable row level security;
alter table ad_events enable row level security;
create policy advertisers_staff on advertisers for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]));
create policy campaigns_staff on ad_campaigns for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]));
create policy creatives_staff on ad_creatives for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]));
create policy ad_events_staff on ad_events for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]));
revoke all on advertisers, ad_campaigns, ad_creatives, ad_events from anon, authenticated;
grant select on advertisers, ad_campaigns, ad_creatives, ad_events to authenticated;

-- Médias publicitaires : contenus publics par nature ; dépôt réservé à l'équipe publicité.
insert into storage.buckets (id, name, public) values ('ad-media', 'ad-media', true) on conflict (id) do nothing;
create policy ad_media_staff_write on storage.objects for all to authenticated
  using (bucket_id = 'ad-media' and public.auth_is_staff(array['super_admin', 'admin', 'ads']::public.staff_role[]))
  with check (bucket_id = 'ad-media' and public.auth_is_staff(array['super_admin', 'admin', 'ads']::public.staff_role[]));

insert into app_config (key, value, description, is_public) values
  ('ads_direct_enabled', 'false', 'Campagnes directes (annonceurs) diffusées dans l''application', true),
  ('ads_admob_enabled', 'false', 'Publicités Google AdMob (après validation du compte éditeur et des politiques)', true),
  ('ads_show_to_premium', 'true', 'Les comptes Premium voient aussi les publicités (régie v1 §1)', true),
  ('ads_community_every', '6', 'Une carte « Sponsorisé » toutes les N publications de la Communauté', true),
  ('admob_banner_unit_android', '""', 'Identifiant du bloc d''annonces bannière AdMob (Android)', true),
  ('admob_rewarded_unit_android', '""', 'Identifiant du bloc d''annonces récompensées AdMob (Android)', true)
on conflict (key) do nothing;

-- Statut effectif : une campagne programmée ou active démarre et s'arrête seule selon ses dates.
create function ad_effective_status(p_status ad_campaign_status, p_starts timestamptz, p_ends timestamptz)
returns ad_campaign_status language sql stable as $$
  select case
    when p_status in ('scheduled', 'active') and now() < p_starts then 'scheduled'::ad_campaign_status
    when p_status in ('scheduled', 'active') and now() >= p_ends then 'ended'::ad_campaign_status
    when p_status in ('scheduled', 'active') then 'active'::ad_campaign_status
    else p_status end;
$$;

-- Campagnes à afficher pour un emplacement, dans la limite d'affichages par membre et par jour.
create function sponsored_ads(p_placement text, p_limit int default 3)
returns table (campaign_id uuid, advertiser_name text, logo_path text, headline text, body text, cta_label text,
               destination_url text, media_type text, media_path text, aspect text)
language sql stable security definer set search_path = public as $$
  select c.id, a.name, a.logo_path, c.headline, c.body, c.cta_label, c.destination_url,
         cr.media_type, cr.storage_path, cr.aspect
  from ad_campaigns c
  join advertisers a on a.id = c.advertiser_id
  left join lateral (select * from ad_creatives x where x.campaign_id = c.id order by x.created_at limit 1) cr on true
  where auth.uid() is not null
    and coalesce((select value = 'true'::jsonb from app_config where key = 'ads_direct_enabled'), false)
    and (not is_premium(auth.uid())
         or coalesce((select value <> 'false'::jsonb from app_config where key = 'ads_show_to_premium'), true))
    and p_placement = any (c.placements)
    and ad_effective_status(c.status, c.starts_at, c.ends_at) = 'active'
    and (select count(*) from ad_events e
         where e.user_id = auth.uid() and e.campaign_id = c.id and e.kind = 'impression'
           and e.created_at >= date_trunc('day', now())) < c.max_impressions_per_user_per_day
  order by random()
  limit greatest(1, least(coalesce(p_limit, 3), 10));
$$;

-- Affichage ou clic réel. Les affichages au-delà du plafond et les clics sans affichage préalable sont ignorés.
create function record_ad_event(p_campaign uuid, p_kind text, p_placement text) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_c ad_campaigns;
  v_today timestamptz := date_trunc('day', now());
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_kind not in ('impression', 'click') then raise exception 'INVALID_EVENT'; end if;
  select * into v_c from ad_campaigns where id = p_campaign;
  if not found or not (p_placement = any (v_c.placements))
     or ad_effective_status(v_c.status, v_c.starts_at, v_c.ends_at) <> 'active' then
    return false;
  end if;
  if p_kind = 'impression' and (select count(*) from ad_events where user_id = auth.uid() and campaign_id = p_campaign
                                and kind = 'impression' and created_at >= v_today) >= v_c.max_impressions_per_user_per_day then
    return false;
  end if;
  if p_kind = 'click' and (
       not exists (select 1 from ad_events where user_id = auth.uid() and campaign_id = p_campaign
                   and kind = 'impression' and created_at >= v_today)
       or exists (select 1 from ad_events where user_id = auth.uid() and campaign_id = p_campaign
                  and kind = 'click' and created_at >= v_today)) then
    return false;
  end if;
  insert into ad_events (campaign_id, user_id, kind, placement) values (p_campaign, auth.uid(), p_kind, p_placement);
  return true;
end;
$$;

-- Statistiques par campagne (administration) : affichages, clics, taux de clic, revenus directs saisis.
create view ad_campaign_stats with (security_invoker = true) as
  select c.id as campaign_id, c.name, a.name as advertiser, ad_effective_status(c.status, c.starts_at, c.ends_at) as status,
         c.starts_at, c.ends_at, c.budget_gnf, c.amount_paid_gnf, c.payment_status,
         count(*) filter (where e.kind = 'impression') as impressions,
         count(*) filter (where e.kind = 'click') as clicks,
         round(100.0 * count(*) filter (where e.kind = 'click')
               / nullif(count(*) filter (where e.kind = 'impression'), 0), 2) as ctr_percent
  from ad_campaigns c join advertisers a on a.id = c.advertiser_id
  left join ad_events e on e.campaign_id = c.id
  group by c.id, a.name;
grant select on ad_campaign_stats to authenticated;

-- ───────────── Administration (console web) : réservé à l'équipe publicité, tracé dans le journal d'audit.
create function admin_save_advertiser(p_id uuid, p_name text, p_logo_path text, p_contact_name text,
                                      p_contact_phone text, p_contact_email text, p_notes text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_id is null then
    insert into advertisers (name, logo_path, contact_name, contact_phone, contact_email, notes, created_by)
    values (p_name, p_logo_path, p_contact_name, p_contact_phone, p_contact_email, p_notes, auth.uid())
    returning id into v_id;
  else
    update advertisers set name = p_name, logo_path = p_logo_path, contact_name = p_contact_name,
           contact_phone = p_contact_phone, contact_email = p_contact_email, notes = p_notes
    where id = p_id returning id into v_id;
    if v_id is null then raise exception 'ADVERTISER_NOT_FOUND'; end if;
  end if;
  perform write_audit('ads.advertiser_saved', 'advertisers', v_id::text, null, jsonb_build_object('name', p_name), null);
  return v_id;
end;
$$;

-- Création ou modification d'une campagne (champs en JSON). Une campagne enregistrée repart en brouillon,
-- sauf si elle était archivée (refusé) : la publication passe par admin_set_campaign_status.
create function admin_save_campaign(p_id uuid, p_data jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_id is null then
    insert into ad_campaigns (advertiser_id, name, placements, headline, body, cta_label, destination_url, starts_at,
                              ends_at, max_impressions_per_user_per_day, budget_gnf, amount_paid_gnf, payment_status,
                              created_by)
    values ((p_data ->> 'advertiser_id')::uuid, p_data ->> 'name',
            coalesce(array(select jsonb_array_elements_text(p_data -> 'placements')), '{}'),
            p_data ->> 'headline', p_data ->> 'body', p_data ->> 'cta_label', p_data ->> 'destination_url',
            (p_data ->> 'starts_at')::timestamptz, (p_data ->> 'ends_at')::timestamptz,
            coalesce((p_data ->> 'max_impressions_per_user_per_day')::int, 3), (p_data ->> 'budget_gnf')::numeric,
            coalesce((p_data ->> 'amount_paid_gnf')::numeric, 0), coalesce(p_data ->> 'payment_status', 'pending'),
            auth.uid())
    returning id into v_id;
  else
    if (select status from ad_campaigns where id = p_id) = 'archived' then raise exception 'CAMPAIGN_ARCHIVED'; end if;
    update ad_campaigns set
      name = coalesce(p_data ->> 'name', name),
      placements = coalesce(array(select jsonb_array_elements_text(p_data -> 'placements')), placements),
      headline = coalesce(p_data ->> 'headline', headline), body = coalesce(p_data ->> 'body', body),
      cta_label = coalesce(p_data ->> 'cta_label', cta_label),
      destination_url = coalesce(p_data ->> 'destination_url', destination_url),
      starts_at = coalesce((p_data ->> 'starts_at')::timestamptz, starts_at),
      ends_at = coalesce((p_data ->> 'ends_at')::timestamptz, ends_at),
      max_impressions_per_user_per_day = coalesce((p_data ->> 'max_impressions_per_user_per_day')::int,
                                                  max_impressions_per_user_per_day),
      budget_gnf = coalesce((p_data ->> 'budget_gnf')::numeric, budget_gnf),
      amount_paid_gnf = coalesce((p_data ->> 'amount_paid_gnf')::numeric, amount_paid_gnf),
      payment_status = coalesce(p_data ->> 'payment_status', payment_status),
      status = 'draft', updated_at = now()
    where id = p_id returning id into v_id;
    if v_id is null then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  end if;
  perform write_audit('ads.campaign_saved', 'ad_campaigns', v_id::text, null, p_data, null);
  return v_id;
end;
$$;

create function admin_add_ad_creative(p_campaign uuid, p_media_type text, p_storage_path text, p_aspect text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  insert into ad_creatives (campaign_id, media_type, storage_path, aspect)
  values (p_campaign, p_media_type, p_storage_path, coalesce(p_aspect, 'landscape')) returning id into v_id;
  perform write_audit('ads.creative_added', 'ad_creatives', v_id::text, null,
                      jsonb_build_object('campaign', p_campaign, 'path', p_storage_path), null);
  return v_id;
end;
$$;

-- Valider, programmer, suspendre, reprendre, archiver : motif obligatoire pour suspendre ou archiver.
create function admin_set_campaign_status(p_campaign uuid, p_status ad_campaign_status, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_old ad_campaigns;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_status in ('suspended', 'archived') and coalesce(trim(p_reason), '') = '' then
    raise exception 'REASON_REQUIRED';
  end if;
  select * into v_old from ad_campaigns where id = p_campaign for update;
  if not found then raise exception 'CAMPAIGN_NOT_FOUND'; end if;
  update ad_campaigns set status = p_status, updated_at = now() where id = p_campaign;
  perform write_audit('ads.campaign_' || p_status::text, 'ad_campaigns', p_campaign::text,
                      jsonb_build_object('status', v_old.status), jsonb_build_object('status', p_status), p_reason);
end;
$$;

revoke execute on all functions in schema public from public, anon;
grant execute on function sponsored_ads(text, int), record_ad_event(uuid, text, text),
                          ad_effective_status(ad_campaign_status, timestamptz, timestamptz),
                          admin_save_advertiser(uuid, text, text, text, text, text, text),
                          admin_save_campaign(uuid, jsonb), admin_add_ad_creative(uuid, text, text, text),
                          admin_set_campaign_status(uuid, ad_campaign_status, text)
  to authenticated;

-- ════════════════════════ 0016_swipes_retour.sql
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

-- ════════════════════════ 0019_aide_administrable.sql
-- ZAYA — Aide administrable : les questions fréquentes ne sont plus écrites dans l'application (consigne du propriétaire
-- « pas de données en dur »). L'équipe (support, admin) les ajoute, modifie, ordonne et désactive ; l'application les lit
-- dans la langue de l'interface, avec repli en français.

create table help_articles (
  id bigint generated always as identity primary key,
  section text not null check (char_length(section) between 2 and 80),
  lang text not null default 'fr' check (lang ~ '^[a-z]{2,3}$'),
  question text not null check (char_length(question) between 5 and 200),
  answer text not null check (char_length(answer) between 5 and 2000),
  position int not null default 0,
  active boolean not null default true,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);
create index help_articles_lang on help_articles (lang, active, position);

alter table help_articles enable row level security;
create policy help_read on help_articles for select to anon, authenticated using (active);
create policy help_staff on help_articles for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'support']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'support']::staff_role[]));
grant select on help_articles to anon, authenticated;
grant insert, update, delete on help_articles to authenticated;

insert into help_articles (section, lang, question, answer, position) values
  ('Compte et profil', 'fr', 'Pourquoi mon profil n’apparaît-il pas dans Découvrir ?',
   'Un profil n’est proposé aux autres membres qu’une fois vérifié par l’équipe ZAYA : il faut le nombre minimum de photos demandé et un selfie de contrôle (Profil → Vérification du profil). Un profil en pause ou masqué n’est pas proposé non plus.', 10),
  ('Compte et profil', 'fr', 'Mon numéro de téléphone est-il visible ?',
   'Non. Il sert uniquement à vous connecter et à sécuriser votre compte. Il n’apparaît jamais sur votre profil ni dans vos conversations.', 20),
  ('Compte et profil', 'fr', 'Puis-je modifier ma date de naissance ou mon genre ?',
   'Non : ils sont fixés à l’inscription pour protéger les membres contre les faux profils. En cas d’erreur, écrivez à l’assistance.', 30),
  ('Rencontres et messages', 'fr', 'Comment se crée un match ?',
   'Un match se crée seulement lorsque deux personnes s’aiment mutuellement. La conversation s’ouvre alors pour vous deux.', 40),
  ('Rencontres et messages', 'fr', 'Pourquoi mon message a-t-il été refusé ?',
   'Avant l’envoi, ZAYA bloque les messages contraires à la charte, par exemple une demande d’argent ou des insultes. Les numéros de téléphone sont masqués pour vous protéger. Reformulez votre message.', 50),
  ('Rencontres et messages', 'fr', 'Que se passe-t-il quand un match prend fin ?',
   'La conversation se ferme pour les deux personnes. Le match apparaît ensuite dans « Matchs terminés », dans l’onglet Messages.', 60),
  ('Sécurité', 'fr', 'Comment signaler ou bloquer quelqu’un ?',
   'Depuis son profil ou la conversation, ouvrez le menu ⋯ puis choisissez « Signaler » ou « Bloquer ». La personne n’est pas prévenue. Après un blocage, vous ne vous voyez plus.', 70),
  ('Sécurité', 'fr', 'Quelqu’un me demande de l’argent : que faire ?',
   'Ne transférez jamais d’argent à une personne que vous n’avez pas rencontrée, et ne communiquez jamais un code reçu par SMS. Signalez la personne : notre équipe examine chaque signalement.', 80),
  ('Abonnement et compte', 'fr', 'Que puis-je faire gratuitement ?',
   'Créer votre profil, découvrir des profils, aimer dans la limite prévue, obtenir des matchs et discuter avec eux restent gratuits. Premium ajoute des avantages, sans jamais fermer une conversation après un match.', 90),
  ('Abonnement et compte', 'fr', 'Comment supprimer mon compte ?',
   'Réglages → Gérer mon compte. Votre profil est masqué immédiatement et vous pouvez annuler pendant le délai indiqué. Vous pouvez aussi simplement mettre votre profil en pause.', 100),
  ('Account and profile', 'en', 'Why doesn’t my profile appear in Discover?',
   'A profile is only shown to other members once the ZAYA team has verified it: you need the minimum number of photos and a check selfie (Profile → Profile verification). A paused or hidden profile is not shown either.', 10),
  ('Account and profile', 'en', 'Is my phone number visible?',
   'No. It is only used to sign you in and secure your account. It never appears on your profile or in your conversations.', 20),
  ('Account and profile', 'en', 'Can I change my date of birth or gender?',
   'No: they are set when you sign up, to protect members from fake profiles. If there is a mistake, write to support.', 30),
  ('Matches and messages', 'en', 'How is a match made?',
   'A match is only made when two people like each other. The conversation then opens for both of you.', 40),
  ('Matches and messages', 'en', 'Why was my message refused?',
   'Before sending, ZAYA blocks messages that break the rules, such as a request for money or insults. Phone numbers are hidden to protect you. Rephrase your message.', 50),
  ('Matches and messages', 'en', 'What happens when a match ends?',
   'The conversation closes for both people. The match then appears in “Ended matches”, in the Messages tab.', 60),
  ('Safety', 'en', 'How do I report or block someone?',
   'From their profile or the conversation, open the ⋯ menu and choose “Report” or “Block”. The person is not notified. After blocking, you no longer see each other.', 70),
  ('Safety', 'en', 'Someone is asking me for money: what should I do?',
   'Never send money to someone you have not met, and never share a code received by SMS. Report the person: our team reviews every report.', 80),
  ('Subscription and account', 'en', 'What can I do for free?',
   'Creating your profile, discovering profiles, liking within the limit, getting matches and chatting with them are free. Premium adds benefits, but never closes a conversation after a match.', 90),
  ('Subscription and account', 'en', 'How do I delete my account?',
   'Settings → Manage my account. Your profile is hidden immediately and you can cancel during the period shown. You can also simply pause your profile.', 100);

-- ════════════════════════ 0022_formules_premium.sql
-- ZAYA — Formules et avantages Premium administrables (CDC §22.16 : « avantages et prix Premium hebdomadaire, mensuel
-- et trimestriel » ; consigne « pas de données en dur »).
--   • Noms proposés le 17/11/2026 à la demande du propriétaire : Étincelle (7 jours), Flamme (30 jours),
--     Alliance (90 jours), en écho à la flamme du logo ZAYA et à l'alliance du mariage. Modifiables par l'équipe.
--   • Prix : non décidés (décision C7) → price_gnf reste vide ; l'achat reste fermé (payments_enabled = false).
--   • Avantages : liste descriptive affichée dans l'application ; les règles réelles restent appliquées par le serveur.

create table premium_plans (
  code text primary key check (code ~ '^[a-z_]{2,30}$'),
  name_fr text not null check (char_length(name_fr) between 2 and 40),
  name_en text not null check (char_length(name_en) between 2 and 40),
  tagline_fr text check (char_length(tagline_fr) <= 120),
  tagline_en text check (char_length(tagline_en) <= 120),
  duration_days int not null check (duration_days between 1 and 366),
  price_gnf numeric(12, 0) check (price_gnf >= 0),     -- vide tant que le prix n'est pas décidé (C7)
  position int not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table premium_features (
  code text primary key check (code ~ '^[a-z_]{2,40}$'),
  label_fr text not null check (char_length(label_fr) between 2 and 120),
  label_en text not null check (char_length(label_en) between 2 and 120),
  in_free boolean not null default false,
  in_premium boolean not null default true,
  position int not null default 0,
  active boolean not null default true
);

alter table premium_plans enable row level security;
alter table premium_features enable row level security;
create policy plans_read on premium_plans for select to anon, authenticated using (active);
create policy features_read on premium_features for select to anon, authenticated using (active);
create policy plans_staff on premium_plans for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
create policy features_staff on premium_features for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
grant select on premium_plans, premium_features to anon, authenticated;
grant insert, update, delete on premium_plans, premium_features to authenticated;

insert into premium_plans (code, name_fr, name_en, tagline_fr, tagline_en, duration_days, position) values
  ('week', 'Étincelle', 'Spark', 'Une semaine pour aller plus loin', 'One week to go further', 7, 1),
  ('month', 'Flamme', 'Flame', 'Un mois pour prendre le temps de bien choisir', 'One month to take your time', 30, 2),
  ('quarter', 'Alliance', 'Alliance', 'Trois mois pour construire sereinement', 'Three months to build with peace of mind',
   90, 3)
on conflict (code) do nothing;

insert into premium_features (code, label_fr, label_en, in_free, in_premium, position) values
  ('profile', 'Créer et gérer son profil', 'Create and manage your profile', true, true, 10),
  ('discover', 'Découvrir tous les profils, Gratuit et Premium', 'Discover all profiles, Free and Premium', true, true, 20),
  ('swipes', 'Swipes à chaque période', 'Swipes every period', true, true, 30),
  ('matches', 'Matchs réciproques et messagerie', 'Mutual matches and messaging', true, true, 40),
  ('safety', 'Bloquer, signaler, masquer son profil', 'Block, report, hide your profile', true, true, 50),
  ('data', 'Exporter et supprimer ses données', 'Export and delete your data', true, true, 60),
  ('who_liked', 'Voir qui a aimé votre profil', 'See who liked your profile', false, true, 70),
  ('more_swipes', 'Davantage de swipes', 'More swipes', false, true, 80),
  ('filters', 'Filtres de recherche avancés', 'Advanced search filters', false, true, 90),
  ('photos', 'Photos des profils sans floutage', 'Profile photos without blur', false, true, 100)
on conflict (code) do nothing;

-- ════════════════════════ 0023_photos_et_invitation.sql
-- ZAYA — Photos du profil : 6 au plus (demande du propriétaire du 17/11/2026), limite réglable et appliquée par le
-- serveur ; lien d'invitation administrable (consigne « pas de données en dur »).
--   • max_profile_photos : au-delà, l'ajout est refusé (MAX_PHOTOS), même par un appel direct.
--   • min_profile_photos (déjà public) reste le minimum demandé pour la vérification.
--   • invite_url : lien partagé par « Inviter » (fiche Google Play tant qu'aucun autre lien n'est défini).
-- La suppression et l'ordre des photos par leur propriétaire sont déjà permis par la RLS (photos_update_own,
-- photos_delete_own) ; photos_guard garde la modération, le chemin et la version floutée hors de sa portée.

insert into app_config (key, value, description, is_public) values
  ('max_profile_photos', '6', 'Nombre maximal de photos par profil', true),
  ('invite_url', '"https://play.google.com/store/apps/details?id=com.zaya.app.zaya"',
   'Lien partagé par le bouton « Inviter » du profil', true)
on conflict (key) do nothing;

create function photos_max_guard() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not zaya_internal()
     and (select count(*) from profile_photos where user_id = new.user_id) >= cfg_int('max_profile_photos', 6) then
    raise exception 'MAX_PHOTOS';
  end if;
  return new;
end;
$$;
create trigger photos_max_guard_trg before insert on profile_photos
  for each row execute function photos_max_guard();
revoke execute on function photos_max_guard() from public, anon, authenticated;

-- ════════════════════════ 0024_likes_envoyes.sql
-- ZAYA — Likes : liste des likes envoyés ; compteur des likes reçus aligné sur la liste (demande du 17/11/2026).
--
-- Le compteur des likes reçus comptait aussi les likes de membres qui ne sont pas visibles (profil non vérifié, en
-- pause, suspendu…), que la liste nominative (Premium) n'affiche pas : le membre voyait « 1 like » et une liste vide.
-- Le compteur suit désormais exactement la même règle que la liste. Jamais de like inventé ni caché au compteur
-- d'un profil visible.

create or replace function received_interests_count() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from interests i
  where i.to_user = auth.uid() and i.status = 'pending'
    and is_discoverable(i.from_user) and not blocked_between(i.from_user, i.to_user);
$$;

-- Profils que j'ai aimés et qui n'ont pas encore répondu (gratuit pour tous). Un match ou une réponse les retire de
-- la liste, de même qu'un profil devenu invisible (pause, suspension) ou un blocage.
create function my_sent_interests()
returns table (interest_id uuid, user_id uuid, display_name text, age int, city text, photo_path text,
               created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select i.id, p.id, p.display_name, age_of(p.birth_date), ci.name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         i.created_at
  from interests i
  join profiles p on p.id = i.to_user
  left join cities ci on ci.id = p.city_id
  where i.from_user = auth.uid() and i.status = 'pending'
    and is_discoverable(p.id) and not blocked_between(i.from_user, i.to_user)
  order by i.created_at desc;
$$;
revoke execute on function my_sent_interests() from public, anon;
grant execute on function my_sent_interests() to authenticated;

-- ════════════════════════ 0025_filtres_avances.sql
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

-- ════════════════════════ 0026_compat_quota_likes.sql
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

-- ════════════════════════ 0031_portefeuille_recompenses.sql
-- ZAYA — Portefeuille et récompenses publicitaires (cahier « Régie publicitaire » v1 §3, §8, §10, §11, §13).
--
-- Règles :
--   • Une récompense n'est créditée qu'après la vérification côté serveur d'AdMob (SSV) : la fonction Edge
--     « admob-ssv » vérifie la signature de Google, puis appelle credit_rewarded_ad() avec la clé de service. Aucun
--     événement de l'application ne peut créditer quoi que ce soit.
--   • Chaque identifiant de transaction AdMob n'est crédité qu'une fois (contrainte d'unicité) ; limites quotidiennes
--     appliquées par le serveur ; tout est historisé, y compris les refus (limite atteinte, récompense désactivée).
--   • Les crédits publicitaires (swipes, boosts personnels) et les pièces achetées sont deux catégories séparées,
--     jamais mélangées, jamais transférables ni convertibles en argent. Le portefeuille est en ajout seul.
--   • Les swipes gagnés passent par grant_extra_swipes() (0016) : une seule source pour le quota de swipes.
--   • reward_configurations est la référence administrable (régie §10). Pour extra_swipes, le montant initial reprend
--     app_config.swipes_per_rewarded_ad.

create table reward_configurations (
  code text primary key check (code in ('extra_swipes', 'boost_credit')),
  enabled boolean not null default false,
  amount int not null check (amount between 1 and 1000),
  daily_limit int not null default 3 check (daily_limit between 0 and 50),
  label_fr text not null check (char_length(label_fr) between 2 and 80),
  label_en text not null check (char_length(label_en) between 2 and 80),
  updated_at timestamptz not null default now()
);

insert into reward_configurations (code, enabled, amount, daily_limit, label_fr, label_en) values
  ('extra_swipes', true, coalesce((select (value #>> '{}')::int from app_config where key = 'swipes_per_rewarded_ad'), 10),
   3, 'Swipes supplémentaires', 'Extra swipes'),
  ('boost_credit', false, 1, 1, 'Crédit de boost pour votre profil', 'Boost credit for your profile')
on conflict (code) do nothing;

create table ad_reward_transactions (
  id bigint generated always as identity primary key,
  transaction_id text not null unique check (char_length(transaction_id) between 1 and 200),
  user_id uuid not null references auth.users (id) on delete cascade,
  reward_code text not null references reward_configurations (code),
  reward_amount int not null default 0,
  status text not null check (status in ('credited', 'limit_reached', 'disabled')),
  ad_network text,
  ad_unit text,
  created_at timestamptz not null default now()
);
create index ad_rewards_user_day on ad_reward_transactions (user_id, reward_code, created_at);
create trigger ad_reward_transactions_append_only before update or delete on ad_reward_transactions
  for each row execute function forbid_change();

create table wallet_transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null check (category in ('ad_credit', 'coins')),
  asset text not null check ((category = 'ad_credit' and asset in ('swipes', 'boost'))
                             or (category = 'coins' and asset = 'coins')),
  amount int not null check (amount <> 0),
  reason text not null check (char_length(reason) between 2 and 120),
  ref text,
  created_at timestamptz not null default now(),
  unique (category, ref)
);
create index wallet_user on wallet_transactions (user_id, created_at desc);
create trigger wallet_transactions_append_only before update or delete on wallet_transactions
  for each row execute function forbid_change();

alter table reward_configurations enable row level security;
alter table ad_reward_transactions enable row level security;
alter table wallet_transactions enable row level security;
create policy rewards_read on reward_configurations for select to authenticated using (true);
create policy rewards_staff on reward_configurations for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]));
create policy ad_rewards_read on ad_reward_transactions for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'ads']::staff_role[]));
create policy wallet_read on wallet_transactions for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
revoke all on reward_configurations, ad_reward_transactions, wallet_transactions from anon, authenticated;
grant select on reward_configurations, ad_reward_transactions, wallet_transactions to authenticated;
grant update on reward_configurations to authenticated;   -- la RLS le réserve à l'équipe

-- Crédit après vérification SSV (appelé uniquement par la fonction Edge « admob-ssv », avec la clé de service).
create function credit_rewarded_ad(p_transaction text, p_user uuid, p_reward text, p_ad_network text, p_ad_unit text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_cfg reward_configurations;
  v_today int;
begin
  if coalesce(trim(p_transaction), '') = '' then raise exception 'TRANSACTION_REQUIRED'; end if;
  if exists (select 1 from ad_reward_transactions where transaction_id = p_transaction) then
    return jsonb_build_object('status', 'duplicate');
  end if;
  select * into v_cfg from reward_configurations where code = p_reward;
  if not found then raise exception 'UNKNOWN_REWARD'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'UNKNOWN_USER'; end if;

  if not v_cfg.enabled then
    insert into ad_reward_transactions (transaction_id, user_id, reward_code, status, ad_network, ad_unit)
    values (p_transaction, p_user, p_reward, 'disabled', p_ad_network, p_ad_unit);
    return jsonb_build_object('status', 'disabled');
  end if;

  select count(*) into v_today from ad_reward_transactions
  where user_id = p_user and reward_code = p_reward and status = 'credited'
    and created_at >= date_trunc('day', now());
  if v_today >= v_cfg.daily_limit then
    insert into ad_reward_transactions (transaction_id, user_id, reward_code, status, ad_network, ad_unit)
    values (p_transaction, p_user, p_reward, 'limit_reached', p_ad_network, p_ad_unit);
    return jsonb_build_object('status', 'limit_reached');
  end if;

  if p_reward = 'extra_swipes' then
    perform grant_extra_swipes(p_user, v_cfg.amount, 'rewarded_ad', p_transaction);
    insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (p_user, 'ad_credit', 'swipes', v_cfg.amount, 'Publicité récompensée', p_transaction);
  else
    insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (p_user, 'ad_credit', 'boost', v_cfg.amount, 'Publicité récompensée', p_transaction);
  end if;
  insert into ad_reward_transactions (transaction_id, user_id, reward_code, reward_amount, status, ad_network, ad_unit)
  values (p_transaction, p_user, p_reward, v_cfg.amount, 'credited', p_ad_network, p_ad_unit);
  return jsonb_build_object('status', 'credited', 'amount', v_cfg.amount);
end;
$$;

-- Ce qu'une publicité récompensée rapporterait maintenant au membre (affiché AVANT le visionnage, régie §2.1).
create function my_reward_offer(p_reward text) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when c.code is null or auth.uid() is null then jsonb_build_object('available', false)
    else jsonb_build_object(
      'available', c.enabled
                   and coalesce((select value = 'true'::jsonb from app_config where key = 'ads_admob_enabled'), false)
                   and (select count(*) from ad_reward_transactions t
                        where t.user_id = auth.uid() and t.reward_code = c.code and t.status = 'credited'
                          and t.created_at >= date_trunc('day', now())) < c.daily_limit,
      'amount', c.amount,
      'label_fr', c.label_fr, 'label_en', c.label_en,
      'remaining_today', greatest(0, c.daily_limit - (select count(*) from ad_reward_transactions t
                        where t.user_id = auth.uid() and t.reward_code = c.code and t.status = 'credited'
                          and t.created_at >= date_trunc('day', now()))::int))
    end
  from (select 1) one left join reward_configurations c on c.code = p_reward;
$$;

-- Portefeuille : trois catégories séparées (régie §8), soldes calculés par le serveur.
create function my_wallet() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ad_credits', jsonb_build_object(
      'swipes', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'ad_credit' and asset = 'swipes'), 0),
      'boosts', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'ad_credit' and asset = 'boost'), 0)),
    'coins', coalesce((select sum(amount) from wallet_transactions where user_id = auth.uid() and category = 'coins'), 0),
    'premium', jsonb_build_object('active', is_premium(auth.uid()),
      'ends_at', (select max(g.ends_at) from premium_grants g where g.user_id = auth.uid() and g.status = 'active')),
    'history', coalesce((select jsonb_agg(jsonb_build_object('category', w.category, 'asset', w.asset,
                                'amount', w.amount, 'reason', w.reason, 'created_at', w.created_at)
                                order by w.created_at desc)
                         from (select * from wallet_transactions where user_id = auth.uid()
                               order by created_at desc limit 50) w), '[]'::jsonb))
  where auth.uid() is not null;
$$;

revoke execute on all functions in schema public from public, anon;
revoke execute on function credit_rewarded_ad(text, uuid, text, text, text) from authenticated;
grant execute on function credit_rewarded_ad(text, uuid, text, text, text) to service_role;
grant execute on function my_reward_offer(text), my_wallet() to authenticated;

-- ════════════════════════ 0032_photos_publication_automatique.sql
-- ZAYA — Photos publiées automatiquement, modérées ensuite (demande du propriétaire du 18/11/2026 : « toute
-- modification ou mise à jour doit s'effectuer automatiquement »).
--
-- Constat : une photo ajoutée restait « en attente » (photos_guard) jusqu'à une validation de l'équipe ; sans console
-- de modération, elle n'était jamais montrée aux autres membres. Le cahier des charges admet les deux modes :
-- « contrôle des contenus avant publication ou modération rapide après publication ».
--   • app_config.photo_auto_publish = true : une nouvelle photo est approuvée dès l'envoi, donc visible aussitôt
--     (dans le respect de sa visibilité et du floutage) ; l'équipe peut la refuser ensuite, et les membres peuvent la
--     signaler. false : retour à la validation préalable.
--   • Les photos déjà en attente sont publiées par cette migration.
--   • admin_moderate_photo : refus ou rétablissement par l'équipe, motif obligatoire pour un refus, tracé.

insert into app_config (key, value, description, is_public) values
  ('photo_auto_publish', 'true',
   'Photos visibles dès l''envoi puis modérées ensuite (true) ; false = visibles après validation de l''équipe', false)
on conflict (key) do nothing;

-- S'exécute après photos_guard (ordre alphabétique des déclencheurs BEFORE : « photos_guard » < « photos_zz… »).
create function photos_auto_publish() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if cfg_bool('photo_auto_publish', true) then
    new.moderation := 'approved';
  end if;
  return new;
end;
$$;
create trigger photos_zz_auto_publish_trg before insert on profile_photos
  for each row execute function photos_auto_publish();

do $$
begin
  if cfg_bool('photo_auto_publish', true) then
    perform set_config('zaya.internal', '1', true);
    update profile_photos set moderation = 'approved' where moderation = 'pending';
    perform set_config('zaya.internal', '0', true);
  end if;
end $$;

create function admin_moderate_photo(p_photo uuid, p_status moderation_status, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_old profile_photos;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_status = 'rejected' and coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_old from profile_photos where id = p_photo for update;
  if not found then raise exception 'PHOTO_NOT_FOUND'; end if;
  perform set_config('zaya.internal', '1', true);
  update profile_photos set moderation = p_status where id = p_photo;
  perform set_config('zaya.internal', '0', true);
  perform write_audit('photo.' || p_status::text, 'profile_photos', p_photo::text,
                      jsonb_build_object('moderation', v_old.moderation), jsonb_build_object('moderation', p_status),
                      p_reason);
end;
$$;

revoke execute on function photos_auto_publish() from public, anon, authenticated;
revoke execute on function admin_moderate_photo(uuid, moderation_status, text) from public, anon;
grant execute on function admin_moderate_photo(uuid, moderation_status, text) to authenticated;

-- ════════════════════════ 0033_boite_mystere.sql
-- ZAYA — Boîte mystère de bienvenue (idée du propriétaire du 18/11/2026) : une boîte gratuite pour les premiers
-- inscrits, avec une récompense tirée au sort. Tout se décide côté serveur (demande explicite : « pour ne pas cliquer
-- deux fois ») :
--   • une seule ouverture par membre, garantie par la clé primaire de mystery_box_openings ; un second appel, même
--     simultané, renvoie le lot déjà obtenu sans nouveau tirage ;
--   • tirage pondéré par le serveur parmi les lots actifs et en stock, stock décompté dans la même transaction ;
--   • récompenses personnelles, non transférables, jamais convertibles en argent (régie v1 §3, §6.1) ;
--   • lots et probabilités réelles visibles AVANT l'ouverture (mystery_box_status) ; rien n'est présenté comme garanti ;
--   • gratuite : aucun achat ni publicité n'est demandé. Le cahier « Régie » exige une validation juridique de tout
--     mécanisme aléatoire avant la mise en production : activée pour la préproduction, à confirmer avant l'ouverture
--     au public (DECISIONS_A_CONFIRMER.md).
-- Tout est réglable : lots, montants, poids, stock, nombre de premiers inscrits concernés, activation.

alter type premium_source add value if not exists 'promotion';

-- Le portefeuille (0031) reçoit une troisième catégorie : les bonus offerts (boîte mystère), séparés des crédits
-- publicitaires et des pièces achetées.
alter table wallet_transactions drop constraint if exists wallet_transactions_category_check;
alter table wallet_transactions drop constraint if exists wallet_transactions_check;       -- nom donné par Postgres (0031)
alter table wallet_transactions drop constraint if exists wallet_transactions_asset_check;
alter table wallet_transactions add constraint wallet_transactions_category_check
  check (category in ('ad_credit', 'coins', 'bonus'));
alter table wallet_transactions add constraint wallet_transactions_asset_check
  check ((category in ('ad_credit', 'bonus') and asset in ('swipes', 'boost', 'premium_days'))
         or (category = 'coins' and asset = 'coins'));

create table mystery_box_prizes (
  code text primary key check (code ~ '^[a-z0-9_]{2,40}$'),
  label_fr text not null check (char_length(label_fr) between 2 and 80),
  label_en text not null check (char_length(label_en) between 2 and 80),
  kind text not null check (kind in ('extra_swipes', 'boost_credit', 'premium_days')),
  amount int not null check (amount between 1 and 1000),
  weight int not null check (weight >= 0),       -- probabilité = poids / somme des poids des lots disponibles
  stock int check (stock >= 0),                   -- vide = illimité
  active boolean not null default true,
  position int not null default 0
);

create table mystery_box_openings (
  user_id uuid primary key,                       -- une seule ouverture par membre (pas de clé étrangère : l'historique
  prize_code text not null,                       -- reste après une suppression de compte, sans autre donnée)
  kind text not null,
  amount int not null,
  opened_at timestamptz not null default now()
);
create trigger mystery_box_openings_append_only before update or delete on mystery_box_openings
  for each row execute function forbid_change();

alter table mystery_box_prizes enable row level security;
alter table mystery_box_openings enable row level security;
create policy prizes_staff on mystery_box_prizes for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy openings_read on mystery_box_openings for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin']::staff_role[]));
revoke all on mystery_box_prizes, mystery_box_openings from anon, authenticated;
grant select, insert, update, delete on mystery_box_prizes to authenticated;   -- la RLS le réserve à l'équipe
grant select on mystery_box_openings to authenticated;

insert into app_config (key, value, description, is_public) values
  ('mystery_box_enabled', 'true', 'Boîte mystère de bienvenue (validation juridique à faire avant le public)', true),
  ('mystery_box_first_members', '1000', 'Nombre de premiers inscrits qui reçoivent une boîte mystère', true)
on conflict (key) do nothing;

insert into mystery_box_prizes (code, label_fr, label_en, kind, amount, weight, stock, position) values
  ('swipes_20', '20 swipes supplémentaires', '20 extra swipes', 'extra_swipes', 20, 65, null, 1),
  ('swipes_50', '50 swipes supplémentaires', '50 extra swipes', 'extra_swipes', 50, 30, null, 2),
  ('premium_7', '7 jours de Premium Étincelle', '7 days of Premium Spark', 'premium_days', 7, 5, 50, 3)
on conflict (code) do nothing;

-- Le membre fait-il partie des premiers inscrits ? (profils actifs, par date de création)
create function mystery_box_eligible(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles me where me.id = p_user and me.status = 'active' and me.account_type = 'candidate')
     and (select count(*) from profiles p
          where p.account_type = 'candidate' and p.created_at <= (select created_at from profiles where id = p_user))
         <= cfg_int('mystery_box_first_members', 1000);
$$;

-- Lots disponibles et probabilités réelles (en pourcentage), à afficher avant l'ouverture.
create function mystery_box_prizes_available() returns jsonb
language sql stable security definer set search_path = public as $$
  with available as (
    select * from mystery_box_prizes where active and weight > 0 and (stock is null or stock > 0)
  ), total as (select sum(weight)::numeric as w from available)
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', a.code, 'label_fr', a.label_fr, 'label_en', a.label_en, 'kind', a.kind, 'amount', a.amount,
           'probability_percent', round(100 * a.weight / nullif(t.w, 0), 1)) order by a.position), '[]'::jsonb)
  from available a cross join total t;
$$;

create function mystery_box_status() returns jsonb
language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then jsonb_build_object('available', false) else jsonb_build_object(
    'enabled', cfg_bool('mystery_box_enabled', false),
    'eligible', mystery_box_eligible(auth.uid()),
    'opened', exists (select 1 from mystery_box_openings where user_id = auth.uid()),
    'prize', (select jsonb_build_object('code', o.prize_code, 'kind', o.kind, 'amount', o.amount,
                                        'label_fr', p.label_fr, 'label_en', p.label_en, 'opened_at', o.opened_at)
              from mystery_box_openings o left join mystery_box_prizes p on p.code = o.prize_code
              where o.user_id = auth.uid()),
    'prizes', mystery_box_prizes_available(),
    'first_members', cfg_int('mystery_box_first_members', 1000)) end;
$$;

-- Ouverture : tirage, stock et crédit dans une seule transaction ; second appel = même lot, sans nouveau tirage.
create function open_mystery_box() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_total int;
  v_pick numeric;
  v_prize mystery_box_prizes;
  v_grant uuid;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if exists (select 1 from mystery_box_openings where user_id = v_me) then
    return mystery_box_status() || jsonb_build_object('status', 'already_opened');
  end if;
  if not cfg_bool('mystery_box_enabled', false) then raise exception 'MYSTERY_BOX_DISABLED'; end if;
  if not mystery_box_eligible(v_me) then raise exception 'MYSTERY_BOX_NOT_ELIGIBLE'; end if;

  -- Verrou des lots : deux ouvertures simultanées ne peuvent pas épuiser deux fois le même stock.
  perform 1 from mystery_box_prizes where active for update;
  select sum(weight) into v_total from mystery_box_prizes where active and weight > 0 and (stock is null or stock > 0);
  if coalesce(v_total, 0) = 0 then raise exception 'MYSTERY_BOX_EMPTY'; end if;
  v_pick := random() * v_total;
  select * into v_prize from (
    select p.*, sum(weight) over (order by position, code) as cumul
    from mystery_box_prizes p where active and weight > 0 and (stock is null or stock > 0)
  ) x where x.cumul > v_pick order by x.cumul limit 1;

  begin
    insert into mystery_box_openings (user_id, prize_code, kind, amount) values (v_me, v_prize.code, v_prize.kind, v_prize.amount);
  exception when unique_violation then
    return mystery_box_status() || jsonb_build_object('status', 'already_opened');
  end;
  update mystery_box_prizes set stock = stock - 1 where code = v_prize.code and stock is not null;

  if v_prize.kind = 'extra_swipes' then
    perform grant_extra_swipes(v_me, v_prize.amount, 'mystery_box', 'mystery_box:' || v_me);
    insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (v_me, 'bonus', 'swipes', v_prize.amount, 'Boîte mystère de bienvenue', 'mystery_box:' || v_me);
  elsif v_prize.kind = 'boost_credit' then
    insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (v_me, 'bonus', 'boost', v_prize.amount, 'Boîte mystère de bienvenue', 'mystery_box:' || v_me);
  else
    insert into premium_grants (user_id, source, status, starts_at, ends_at, reason, origin)
    values (v_me, 'promotion', 'active', now(), now() + make_interval(days => v_prize.amount),
            'Boîte mystère de bienvenue', 'mystery_box')
    returning id into v_grant;
    insert into premium_events (grant_id, user_id, action, new_starts_at, new_ends_at, new_status, reason, origin)
    values (v_grant, v_me, 'granted', now(), now() + make_interval(days => v_prize.amount), 'active',
            'Boîte mystère de bienvenue', 'mystery_box');
    insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (v_me, 'bonus', 'premium_days', v_prize.amount, 'Boîte mystère de bienvenue', 'mystery_box:' || v_me);
  end if;
  perform write_audit('mystery_box.opened', 'mystery_box_openings', v_me::text, null,
                      jsonb_build_object('prize', v_prize.code, 'amount', v_prize.amount), null);
  return mystery_box_status() || jsonb_build_object('status', 'opened');
end;
$$;

-- Portefeuille (0031) : les bonus offerts apparaissent dans leur propre catégorie.
create or replace function my_wallet() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ad_credits', jsonb_build_object(
      'swipes', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'ad_credit' and asset = 'swipes'), 0),
      'boosts', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'ad_credit' and asset = 'boost'), 0)),
    'bonus', jsonb_build_object(
      'swipes', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'bonus' and asset = 'swipes'), 0),
      'boosts', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'bonus' and asset = 'boost'), 0),
      'premium_days', coalesce((select sum(amount) from wallet_transactions
                          where user_id = auth.uid() and category = 'bonus' and asset = 'premium_days'), 0)),
    'coins', coalesce((select sum(amount) from wallet_transactions where user_id = auth.uid() and category = 'coins'), 0),
    'premium', jsonb_build_object('active', is_premium(auth.uid()),
      'ends_at', (select max(g.ends_at) from premium_grants g where g.user_id = auth.uid() and g.status = 'active')),
    'history', coalesce((select jsonb_agg(jsonb_build_object('category', w.category, 'asset', w.asset,
                                'amount', w.amount, 'reason', w.reason, 'created_at', w.created_at)
                                order by w.created_at desc)
                         from (select * from wallet_transactions where user_id = auth.uid()
                               order by created_at desc limit 50) w), '[]'::jsonb))
  where auth.uid() is not null;
$$;

revoke execute on all functions in schema public from public, anon;
revoke execute on function mystery_box_eligible(uuid), mystery_box_prizes_available() from authenticated;
grant execute on function mystery_box_status(), open_mystery_box(), my_wallet() to authenticated;

-- ════════════════════════ 0034_publicites_google.sql
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

-- ════════════════════════ 0035_boutique_cadeaux_compliments.sql
-- 0035 : boutique de cadeaux virtuels et de compliments (régie v1 §6 et §7).
-- • Catalogue administrable : noms, emoji ou image, prix en pièces ACHETÉES. Aucun prix n'est fixé ici : un article
--   sans prix reste visible mais ne peut pas être envoyé (décision C7, prix fixés par l'administration).
-- • Les pièces viennent uniquement d'achats (wallet_transactions, catégorie « coins ») : jamais des crédits
--   publicitaires ni des cadeaux ZAYA (régie §6.1 et §7). Tant que les paiements sont fermés, le solde reste à 0.
-- • Pas de texte libre : un cadeau est un article du catalogue, un compliment un texte écrit par l'équipe.
-- • Historique en ajout seul : envoi et débit sont deux lignes indissociables, jamais modifiées ni effacées.

insert into app_config (key, value, description, is_public) values
  ('shop_enabled', 'true', 'Boutique de cadeaux et de compliments visible dans l''application', true),
  ('shop_sends_per_day', '20', 'Cadeaux et compliments envoyés au plus par membre et par jour (anti-abus)', true)
on conflict (key) do nothing;

create table public.shop_items (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]{2,40}$'),
  kind text not null check (kind in ('gift', 'compliment')),
  name_fr text not null check (char_length(name_fr) between 2 and 60),
  name_en text not null default '' check (char_length(name_en) <= 60),
  emoji text check (emoji is null or char_length(emoji) <= 16),
  image_path text,                                     -- image ou animation (bucket shop-media), facultative
  message_fr text check (message_fr is null or char_length(message_fr) <= 160),  -- texte d'un compliment
  message_en text check (message_en is null or char_length(message_en) <= 160),
  price_coins int check (price_coins is null or price_coins > 0),
  rarity text not null default 'common' check (rarity in ('common', 'rare', 'legendary')),
  position int not null default 100,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind <> 'compliment' or message_fr is not null)
);

create table public.shop_sends (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.shop_items (id),
  from_user uuid not null references public.profiles (id) on delete cascade,
  to_user uuid not null references public.profiles (id) on delete cascade,
  price_coins int not null check (price_coins > 0),    -- prix au moment de l'envoi
  created_at timestamptz not null default now(),
  check (from_user <> to_user)
);
create index shop_sends_to_idx on public.shop_sends (to_user, created_at desc);
create index shop_sends_from_idx on public.shop_sends (from_user, created_at desc);
create trigger shop_sends_append_only before update or delete on public.shop_sends
  for each row execute function forbid_change();

alter table public.shop_items enable row level security;
alter table public.shop_sends enable row level security;
create policy shop_items_read on public.shop_items for select to authenticated
  using (active or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
create policy shop_sends_read on public.shop_sends for select to authenticated
  using (from_user = auth.uid() or to_user = auth.uid()
         or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
revoke all on public.shop_items, public.shop_sends from anon, authenticated;
grant select on public.shop_items, public.shop_sends to authenticated;

-- Médias de la boutique : publics par nature, déposés par l'équipe uniquement.
insert into storage.buckets (id, name, public) values ('shop-media', 'shop-media', true) on conflict (id) do nothing;
create policy shop_media_staff_write on storage.objects for all to authenticated
  using (bucket_id = 'shop-media' and public.auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (bucket_id = 'shop-media' and public.auth_is_staff(array['super_admin', 'admin']::staff_role[]));

-- Catalogue de départ, SANS prix : l'équipe fixe les prix et peut tout modifier ou désactiver.
insert into public.shop_items (code, kind, name_fr, name_en, emoji, message_fr, message_en, rarity, position) values
  ('rose', 'gift', 'Rose', 'Rose', '🌹', null, null, 'common', 10),
  ('the_menthe', 'gift', 'Thé à la menthe', 'Mint tea', '🍵', null, null, 'common', 20),
  ('bouquet', 'gift', 'Bouquet de fleurs', 'Bouquet', '💐', null, null, 'common', 30),
  ('parfum', 'gift', 'Parfum', 'Perfume', '🧴', null, null, 'rare', 40),
  ('bague', 'gift', 'Bague', 'Ring', '💍', null, null, 'legendary', 50),
  ('sourire', 'compliment', 'Ton sourire', 'Your smile', '😊',
   'Ton sourire donne envie de mieux te connaître.', 'Your smile makes me want to know you better.', 'common', 110),
  ('valeurs', 'compliment', 'Tes valeurs', 'Your values', '🤝',
   'J''apprécie les valeurs que tu partages sur ton profil.', 'I appreciate the values you share on your profile.', 'common', 120),
  ('serieux', 'compliment', 'Ton sérieux', 'Your sincerity', '✨',
   'Ton profil montre une personne sérieuse et sincère.', 'Your profile shows a serious and sincere person.', 'common', 130)
on conflict (code) do nothing;

-- Catalogue visible par le membre : prix tels que fixés par l'équipe (null : pas encore en vente).
create function public.shop_catalog() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', cfg_bool('shop_enabled', false),
    'coins', coalesce((select sum(amount) from wallet_transactions
                       where user_id = auth.uid() and category = 'coins'), 0),
    'payments_open', cfg_bool('payments_enabled', false),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'code', i.code, 'kind', i.kind, 'name_fr', i.name_fr, 'name_en', i.name_en, 'emoji', i.emoji,
        'image_path', i.image_path, 'message_fr', i.message_fr, 'message_en', i.message_en,
        'price_coins', i.price_coins, 'rarity', i.rarity) order by i.position, i.name_fr)
      from shop_items i where i.active), '[]'::jsonb))
  where auth.uid() is not null;
$$;

-- Envoi : solde suffisant en pièces achetées, destinataire actif et non bloqué, limite quotidienne ; débit et envoi
-- dans la même transaction, sous verrou du portefeuille de l'expéditeur (deux appuis ne débitent jamais deux fois
-- au-delà du solde).
create function public.send_shop_item(p_item uuid, p_to uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_item shop_items;
  v_balance int;
  v_send uuid;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not cfg_bool('shop_enabled', false) then raise exception 'FEATURE_DISABLED'; end if;
  select * into v_item from shop_items where id = p_item and active;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  if v_item.price_coins is null then raise exception 'PRICE_NOT_SET'; end if;
  if p_to is null or p_to = v_me then raise exception 'INVALID_TARGET'; end if;
  if not exists (select 1 from profiles where id = p_to and status = 'active') or blocked_between(v_me, p_to) then
    raise exception 'TARGET_UNAVAILABLE';
  end if;
  if (select count(*) from shop_sends where from_user = v_me and created_at >= now() - interval '24 hours')
     >= cfg_int('shop_sends_per_day', 20) then
    raise exception 'DAILY_LIMIT';
  end if;

  perform pg_advisory_xact_lock(hashtext('wallet:' || v_me::text));
  select coalesce(sum(amount), 0) into v_balance from wallet_transactions where user_id = v_me and category = 'coins';
  if v_balance < v_item.price_coins then raise exception 'INSUFFICIENT_COINS'; end if;

  insert into shop_sends (item_id, from_user, to_user, price_coins)
    values (v_item.id, v_me, p_to, v_item.price_coins) returning id into v_send;
  insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (v_me, 'coins', 'coins', -v_item.price_coins,
            case v_item.kind when 'gift' then 'Cadeau envoyé : ' else 'Compliment envoyé : ' end || v_item.name_fr,
            'shop:' || v_send);
  return jsonb_build_object('status', 'sent', 'send_id', v_send, 'coins', v_balance - v_item.price_coins);
end;
$$;

-- Cadeaux et compliments reçus (ou envoyés), avec le prénom affiché de l'autre membre.
create function public.my_shop_history(p_direction text default 'received', p_limit int default 50) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by (x ->> 'created_at') desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', s.id, 'created_at', s.created_at, 'kind', i.kind, 'code', i.code, 'name_fr', i.name_fr,
      'name_en', i.name_en, 'emoji', i.emoji, 'image_path', i.image_path, 'message_fr', i.message_fr,
      'message_en', i.message_en,
      'other_id', case when p_direction = 'sent' then s.to_user else s.from_user end,
      'other_name', p.display_name) as x
    from shop_sends s
    join shop_items i on i.id = s.item_id
    join profiles p on p.id = case when p_direction = 'sent' then s.to_user else s.from_user end
    where auth.uid() is not null
      and case when p_direction = 'sent' then s.from_user else s.to_user end = auth.uid()
      and not blocked_between(s.from_user, s.to_user)
    order by s.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 200))
  ) h;
$$;

-- Administration (régie §6.2) : créer, modifier, désactiver un article et fixer son prix. Tracé.
create function public.admin_save_shop_item(p_id uuid, p_item jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_old jsonb;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_id is null then
    insert into shop_items (code, kind, name_fr, name_en, emoji, image_path, message_fr, message_en, price_coins,
                            rarity, position, active)
    values (p_item ->> 'code', p_item ->> 'kind', p_item ->> 'name_fr', coalesce(p_item ->> 'name_en', ''),
            p_item ->> 'emoji', p_item ->> 'image_path', p_item ->> 'message_fr', p_item ->> 'message_en',
            (p_item ->> 'price_coins')::int, coalesce(p_item ->> 'rarity', 'common'),
            coalesce((p_item ->> 'position')::int, 100), coalesce((p_item ->> 'active')::boolean, true))
    returning id into v_id;
  else
    select to_jsonb(i) into v_old from shop_items i where id = p_id;
    if v_old is null then raise exception 'ITEM_NOT_FOUND'; end if;
    update shop_items set
      name_fr = coalesce(p_item ->> 'name_fr', name_fr),
      name_en = coalesce(p_item ->> 'name_en', name_en),
      emoji = case when p_item ? 'emoji' then p_item ->> 'emoji' else emoji end,
      image_path = case when p_item ? 'image_path' then p_item ->> 'image_path' else image_path end,
      message_fr = case when p_item ? 'message_fr' then p_item ->> 'message_fr' else message_fr end,
      message_en = case when p_item ? 'message_en' then p_item ->> 'message_en' else message_en end,
      price_coins = case when p_item ? 'price_coins' then (p_item ->> 'price_coins')::int else price_coins end,
      rarity = coalesce(p_item ->> 'rarity', rarity),
      position = coalesce((p_item ->> 'position')::int, position),
      active = coalesce((p_item ->> 'active')::boolean, active),
      updated_at = now()
    where id = p_id;
    v_id := p_id;
  end if;
  perform write_audit('shop_item.saved', 'shop_items', v_id::text, v_old,
                      (select to_jsonb(i) from shop_items i where id = v_id), null);
  return v_id;
end;
$$;

revoke execute on function public.shop_catalog(), public.send_shop_item(uuid, uuid),
  public.my_shop_history(text, int), public.admin_save_shop_item(uuid, jsonb) from public, anon;
grant execute on function public.shop_catalog(), public.send_shop_item(uuid, uuid),
  public.my_shop_history(text, int), public.admin_save_shop_item(uuid, jsonb) to authenticated;

-- ════════════════════════ 0036_prix_boutique_par_defaut.sql
-- 0036 : prix par défaut de la boutique, demandés par le propriétaire le 25/11/2026 (décision C21).
-- Prix en pièces, provisoires et modifiables à tout moment par l'équipe (admin_save_shop_item). Un prix déjà fixé
-- par l'équipe n'est jamais écrasé. La valeur d'une pièce en GNF sera fixée avec l'ouverture des paiements (C7, C8).

update public.shop_items as i set price_coins = d.price, updated_at = now()
from (values
  ('rose', 10),
  ('the_menthe', 15),
  ('bouquet', 30),
  ('parfum', 60),
  ('bague', 150),
  ('sourire', 5),
  ('valeurs', 5),
  ('serieux', 5)
) as d (code, price)
where i.code = d.code and i.price_coins is null;

-- ════════════════════════ 0040_conversations_actives.sql
-- ZAYA — Messagerie : conversations actives limitées et demande de re-match (décisions du propriétaire, 18/11/2026).
--
-- Conversation active : un match en cours dans lequel au moins un message a été échangé. Pour écrire le PREMIER
-- message d'un match, le membre doit avoir une place libre (max_active_conversations : 5 en Gratuit, réglable ;
-- davantage pour Premium). Un match sans message reste dans « Nouveaux matchs » ; terminer une conversation libère
-- une place. Répondre dans une conversation déjà ouverte n'est jamais bloqué.
--
-- Demande de re-match : après la fin d'un match, l'un des deux peut proposer de reprendre la conversation. L'autre
-- accepte (le match reprend) ou refuse ; une seule demande par match, jamais en cas de blocage, et pas de nouvelle
-- demande après un refus (protection contre l'insistance).

insert into app_config (key, value, description, is_public) values
  ('max_active_conversations', '5', 'Conversations actives à la fois pour un compte Gratuit', true),
  ('max_active_conversations_premium', '10',
   'Conversations actives à la fois pour un compte Premium (valeur provisoire, à confirmer)', true)
on conflict (key) do nothing;

-- ───────────────────────────── Conversations actives
create function active_conversations_count(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from matches m
  where p_user in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
    and exists (select 1 from messages x where x.match_id = m.id);
$$;

create function active_conversations_limit(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select case when is_premium(p_user) then cfg_int('max_active_conversations_premium', 10)
              else cfg_int('max_active_conversations', 5) end;
$$;

-- Places de conversation du membre connecté (affichage « 3/5 »).
create function my_conversation_slots() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  return jsonb_build_object('active', active_conversations_count(auth.uid()),
                            'limit', active_conversations_limit(auth.uid()));
end;
$$;

-- Premier message d'un match : place libre exigée (usage interne, aussi pour les messages avec média).
create function conversation_slot_available(p_user uuid, p_match uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from messages x where x.match_id = p_match)
      or active_conversations_count(p_user) < active_conversations_limit(p_user);
$$;

-- Reprise de send_message (0002) avec la vérification de place ; le reste est inchangé.
create or replace function send_message(p_match uuid, p_body text) returns jsonb
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

  -- Premier message : une place de conversation doit être libre.
  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object('status', 'active_limit',
                              'active', active_conversations_count(v_me), 'limit', active_conversations_limit(v_me));
  end if;

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

-- ───────────────────────────── Demande de re-match
create table rematch_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references matches (id) on delete cascade,  -- une seule demande par match
  requester uuid not null references profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);
alter table rematch_requests enable row level security;
revoke all on rematch_requests from anon, authenticated;

create function request_rematch(p_match uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match matches;
  v_other uuid;
  v_req rematch_requests;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_match from matches where id = p_match and v_me in (user_a, user_b);
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.ended_at is null then return jsonb_build_object('status', 'active'); end if;
  v_other := case when v_match.user_a = v_me then v_match.user_b else v_match.user_a end;
  if blocked_between(v_me, v_other)
     or not exists (select 1 from profiles where id = v_other and status in ('active', 'paused')) then
    raise exception 'REMATCH_UNAVAILABLE';
  end if;
  select * into v_req from rematch_requests where match_id = p_match;
  if found then
    -- L'autre avait déjà demandé : la demande croisée vaut accord.
    if v_req.status = 'pending' and v_req.requester = v_other then
      update rematch_requests set status = 'accepted', responded_at = now() where id = v_req.id;
      update matches set ended_at = null, ended_by = null where id = p_match;
      return jsonb_build_object('status', 'rematched');
    end if;
    return jsonb_build_object('status', v_req.status, 'mine', v_req.requester = v_me);
  end if;
  insert into rematch_requests (match_id, requester) values (p_match, v_me);
  return jsonb_build_object('status', 'pending', 'mine', true);
end;
$$;

create function respond_rematch(p_match uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_req rematch_requests;
  v_match matches;
begin
  select r.* into v_req from rematch_requests r join matches m on m.id = r.match_id
  where r.match_id = p_match and r.status = 'pending' and r.requester <> v_me and v_me in (m.user_a, m.user_b)
  for update of r;
  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;
  select * into v_match from matches where id = p_match;
  if blocked_between(v_match.user_a, v_match.user_b) then raise exception 'REMATCH_UNAVAILABLE'; end if;
  update rematch_requests set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
    where id = v_req.id;
  if p_accept then update matches set ended_at = null, ended_by = null where id = p_match; end if;
  return jsonb_build_object('status', case when p_accept then 'rematched' else 'declined' end);
end;
$$;

-- Demandes reçues en attente (pour les afficher dans Messages).
create function my_rematch_requests()
returns table (match_id uuid, user_id uuid, display_name text, photo_path text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.match_id, p.id, p.display_name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         r.created_at
  from rematch_requests r
  join matches m on m.id = r.match_id
  join profiles p on p.id = r.requester
  where r.status = 'pending' and r.requester <> auth.uid() and auth.uid() in (m.user_a, m.user_b)
    and not blocked_between(m.user_a, m.user_b)
  order by r.created_at desc;
$$;

-- État de la demande pour un match terminé, vu par le membre (aucune / envoyée / reçue / refusée).
create function rematch_state(p_match uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when r.id is null then 'none'
    when r.status = 'pending' and r.requester = auth.uid() then 'sent'
    when r.status = 'pending' then 'received'
    else r.status end
  from matches m left join rematch_requests r on r.match_id = m.id
  where m.id = p_match and auth.uid() in (m.user_a, m.user_b);
$$;

revoke execute on function active_conversations_count(uuid), active_conversations_limit(uuid),
                           conversation_slot_available(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function my_conversation_slots(), request_rematch(uuid), respond_rematch(uuid, boolean),
                           my_rematch_requests(), rematch_state(uuid)
  from public, anon;
grant execute on function my_conversation_slots(), request_rematch(uuid), respond_rematch(uuid, boolean),
                          my_rematch_requests(), rematch_state(uuid)
  to authenticated;

-- ════════════════════════ 0050_durcissement_securite.sql
-- ZAYA — Durcissement de la sécurité (demande du propriétaire, 18/11/2026).
--
-- Audit en lecture seule de la base de préproduction (18/11/2026) :
--   • toutes les tables du schéma public ont la RLS activée ; anon n'a aucun droit sur les tables ;
--   • toutes les fonctions security definer fixent leur search_path ; aucune vue ne contourne la RLS ;
--   • les fonctions d'administration vérifient le rôle (auth_is_staff → FORBIDDEN) ; la Communauté passe par
--     community_guard ; les buckets de photos et de vérification sont privés (selfies lisibles par la modération
--     seulement), seul ad-media (visuels publicitaires) est public ;
--   • une seule fonction privilégiée restait exécutable par anon : guard_advanced_filters (0025), une fonction de
--     déclencheur, sans risque réel (elle ne s'appelle pas directement), fermée ici par principe.
-- Les autres mesures de cette demande sont dans 0051 (liens et limite de fréquence dans la messagerie) et dans
-- l'application Android (anti-capture, pas de sauvegarde des données, pas de trafic non chiffré).

revoke execute on function guard_advanced_filters() from public, anon, authenticated;

-- ════════════════════════ 0051_liens_messages.sql
-- ZAYA — Messagerie : liens interdits et limite de fréquence (demande du propriétaire, 18/11/2026).
--
-- • « Interdiction d'envoi de lien par message » : un message (envoi ou modification) qui contient un lien n'est ni
--   stocké ni transmis ; la tentative est comptée dans message_violations (catégorie « link », sans le texte), comme
--   les autres contenus bloqués (§24.3). CDC : liens suspects et escroqueries (§177, §830, §1443).
-- • Anti-spam (CDC §1191 « limites de fréquence ») : au plus `message_rate_per_minute` messages par minute et par
--   membre (réglable dans app_config) ; au-delà, refus MESSAGE_RATE_LIMITED.
--
-- Détection des liens : adresse avec protocole (https://, http://, intent://…), « www. », domaine avec une extension
-- courante (.com, .net, .org…), raccourcisseurs (bit.ly…), domaine suivi d'un chemin (exemple.gn/page), écritures
-- détournées « site point com ». Les extensions de deux lettres seules (.ma, .me, .ne…) ne comptent que suivies
-- d'un chemin, pour ne pas bloquer une phrase sans espace après le point (« ok.Ma sœur… »). Une adresse e-mail n'est
-- pas un lien (elle reste régie par les règles existantes). La détection complète la modération humaine, elle ne la
-- remplace pas : une écriture très détournée peut passer.

insert into app_config (key, value, description, is_public) values
  ('message_rate_per_minute', '20', 'Messages au plus par minute et par membre (anti-spam)', false)
on conflict (key) do nothing;

create index if not exists messages_sender_recent_idx on messages (sender_id, created_at desc);

create function contains_link(p_body text) returns boolean
language sql immutable set search_path = public as $$
  select p_body ~* '[a-z][a-z0-9+.-]{1,15}://'
      or p_body ~* '(^|[^a-z0-9@._-])www\s*\.'
      or p_body ~* '(^|[^a-z0-9@._-])[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|net|org|info|biz|app|dev|link|site|online|shop|store|xyz|top|live|click|io)\M'
      -- « site . com » : espace avant le point (une fin de phrase « C'est bon. Top ! » n'est pas un lien)
      or p_body ~* '(^|[^a-z0-9@._-])[a-z0-9-]+\s+\.\s*(com|net|org)\M'
      or p_body ~* '(^|[^a-z0-9@._-])(bit\.ly|goo\.gl|tinyurl|t\.co|cutt\.ly|rb\.gy|is\.gd|ow\.ly|shorturl\.at|wa\.me|t\.me|m\.me)\M'
      or p_body ~* '(^|[^a-z0-9@._-])[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}/\S'
      or p_body ~* '\m(point|dot)\s*(com|net|org)\M';
$$;
revoke execute on function contains_link(text) from public, anon, authenticated;

-- Reprise de send_message (0040, limite des conversations actives comprise) : limite de fréquence et liens.
create or replace function send_message(p_match uuid, p_body text) returns jsonb
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

  -- Anti-spam : nombre de messages envoyés par ce membre dans la dernière minute.
  if (select count(*) from messages where sender_id = v_me and created_at > now() - interval '1 minute')
     >= cfg_int('message_rate_per_minute', 20) then
    raise exception 'MESSAGE_RATE_LIMITED';
  end if;

  -- Premier message : une place de conversation doit être libre.
  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object('status', 'active_limit',
                              'active', active_conversations_count(v_me), 'limit', active_conversations_limit(v_me));
  end if;

  -- Filtre avant transmission : un message non conforme n'est ni stocké ni transmis (§24.3)
  v_category := message_violation_category(v_body);
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;

  insert into messages (match_id, sender_id, body) values (p_match, v_me, v_body) returning id into v_id;
  return jsonb_build_object('status', 'sent', 'id', v_id);
end;
$$;

-- Reprise de edit_message (0002) : un lien ne peut pas entrer par une modification.
create or replace function edit_message(p_message uuid, p_body text) returns jsonb
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
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (auth.uid(), v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  update messages set body = v_body, edited_at = now() where id = p_message;
  return jsonb_build_object('status', 'edited');
end;
$$;

-- ════════════════════════ 0052_etudes_enfants.sql
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

-- ════════════════════════ 0055_signaux_instantanes.sql
-- ZAYA — Mises à jour instantanées (demande du propriétaire, 18/11/2026 : « toutes les informations doivent être
-- mises à jour instantanément, photos et autres »).
--
-- Principe : un « signal » court est déposé pour le membre concerné à chaque événement qui change ce qu'il voit
-- (like reçu, match, message, photo modérée ou floutée, Premium, vérification, visite). L'application s'abonne en
-- temps réel (Supabase Realtime) à ses propres signaux et rafraîchit aussitôt les données concernées.
-- Un signal ne contient que sa nature : jamais l'identité de l'auteur (l'identité des likes reçus reste réservée à
-- Premium, CDC §4.3). Lisible par son seul destinataire ; aucune écriture possible par l'application.
-- Les signaux de plus d'un jour sont effacés au fil de l'eau (la table reste petite).

create table member_signals (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  kind text not null check (kind in ('like', 'match', 'message', 'photo', 'premium', 'profile', 'visit', 'wallet')),
  created_at timestamptz not null default now()
);
create index member_signals_user_idx on member_signals (user_id, created_at desc);
alter table member_signals enable row level security;
create policy member_signals_own on member_signals for select to authenticated using (user_id = auth.uid());
revoke all on member_signals from anon;
revoke insert, update, delete on member_signals from authenticated;
grant select on member_signals to authenticated;

-- Dépôt d'un signal (fonctions serveur seulement) ; efface au passage les anciens signaux du membre.
create function signal_member(p_user uuid, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user is null then return; end if;
  delete from member_signals where user_id = p_user and created_at < now() - interval '1 day';
  insert into member_signals (user_id, kind) values (p_user, p_kind);
end;
$$;
revoke execute on function signal_member(uuid, text) from public, anon, authenticated;

create function signals_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  case tg_table_name
    when 'interests' then
      perform signal_member(new.to_user, 'like');
    when 'matches' then
      perform signal_member(new.user_a, 'match');
      perform signal_member(new.user_b, 'match');
    when 'messages' then
      perform signal_member(
        (select case when m.user_a = new.sender_id then m.user_b else m.user_a end from matches m where m.id = new.match_id),
        'message');
    when 'profile_photos' then
      perform signal_member(coalesce(new.user_id, old.user_id), 'photo');
    when 'premium_grants' then
      perform signal_member(new.user_id, 'premium');
    when 'profiles' then
      perform signal_member(new.id, 'profile');
    when 'profile_views' then
      perform signal_member(new.viewed, 'visit');
  end case;
  return null;
end;
$$;
revoke execute on function signals_after_change() from public, anon, authenticated;

create trigger interests_signal after insert on interests
  for each row execute function signals_after_change();
create trigger matches_signal after insert on matches
  for each row execute function signals_after_change();
create trigger messages_signal after insert on messages
  for each row execute function signals_after_change();
-- Photo ajoutée, retirée, modérée, floutée par le serveur ou changée de visibilité.
create trigger profile_photos_signal after insert or delete or update of moderation, blur_path, visibility, position
  on profile_photos for each row execute function signals_after_change();
create trigger premium_grants_signal after insert or update on premium_grants
  for each row execute function signals_after_change();
-- Seulement ce que le membre ne fait pas lui-même : vérification et statut du compte (décisions de l'équipe).
create trigger profiles_signal after update of verification_status, status on profiles
  for each row when (old.verification_status is distinct from new.verification_status or old.status is distinct from new.status)
  execute function signals_after_change();
create trigger profile_views_signal after insert on profile_views
  for each row execute function signals_after_change();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.member_signals;
  end if;
end;
$$;

-- ════════════════════════ 0056_libelles_etudes_et_profils.sql
-- ZAYA — Niveaux d'études : libellés rétablis et recopiés dans les profils (suite de 0052).
--
-- Cause : la 0052 a été appliquée sur la préproduction depuis PowerShell 5.1, qui lit les fichiers dans l'encodage
-- Windows : les accents sont arrivés abîmés (« CollÃ¨ge », « BaccalaurÃ©at », « Sans diplÃ´me »). La 0058 répare
-- deux libellés ; cette migration rétablit les neuf, et recopie le bon libellé dans profiles.education_level,
-- que le déclencheur de 0052 avait rempli avec le texte abîmé (fiches des profils d'essai).
-- Sans effet sur une base saine. Les accents sont écrits en échappements Unicode, insensibles à l'encodage du fichier.

update education_levels l
set label_fr = v.label_fr, label_en = v.label_en
from (values
  ('none', U&'Sans dipl\00F4me', 'No diploma'),
  ('primary', 'Primaire (CEPE)', 'Primary school'),
  ('middle', U&'Coll\00E8ge (BEPC)', 'Middle school'),
  ('bac', U&'Baccalaur\00E9at', 'High school diploma'),
  ('vocational', 'Formation professionnelle', 'Vocational training'),
  ('bac2', 'Bac +2 (BTS, DUT)', 'Two-year degree'),
  ('licence', 'Licence (Bac +3)', 'Bachelor''s degree'),
  ('master', 'Master (Bac +5)', 'Master''s degree'),
  ('doctorate', 'Doctorat', 'Doctorate')
) as v (key, label_fr, label_en)
where l.key = v.key and (l.label_fr is distinct from v.label_fr or l.label_en is distinct from v.label_en);

-- Le déclencheur de 0052 recopie le libellé quand education_key est réécrit (même valeur).
update profiles p
set education_key = p.education_key
from education_levels l
where l.key = p.education_key and p.education_level is distinct from l.label_fr;

-- ════════════════════════ 0057_floutage_automatique.sql
-- ZAYA — Floutage automatique des photos (demande du propriétaire du 18/11/2026 : « toute modification ou mise à
-- jour doit s'effectuer automatiquement »).
--
-- Constat (18/11/2026, préproduction) : les 3 photos d'un membre vérifié n'avaient pas de version floutée. La
-- fabrication déclenchée par l'application juste après l'envoi (fonction Edge blur-photos) avait échoué une fois et
-- rien ne la relançait : un visiteur Gratuit ne voyait rien à la place des photos 2 et 3 (photo_access = blurred,
-- chemin flouté nul).
--
-- Correction (sans toucher à la modération, réglée par 0032) :
--   • photo_blur_jobs : échecs de fabrication par photo, réservé au serveur. Après un échec, nouvel essai 5 min plus
--     tard, puis 10, 15… ; au-delà de blur_max_attempts essais, la photo n'est plus relancée automatiquement (un
--     fichier abîmé ne fait pas tourner la fonction en boucle).
--   • blur_backlog(n, âge) : photos sans version floutée à fabriquer ; blur_job_failed(photo, erreur) : trace un
--     échec. Les deux sont réservées au serveur (service_role), appelées par la fonction Edge.
--   • blur_photos_tick() : chaque minute (pg_cron), s'il reste une photo sans version floutée depuis plus d'une
--     minute, appelle la fonction Edge blur-photos (pg_net), avec un jeton dédié lu dans le coffre de Supabase :
--     secrets « zaya_project_url » et « zaya_blur_token » (INSTALLATION_SUPABASE.md). Sans ces secrets, ou sans
--     pg_cron / pg_net (tests PGlite), elle ne fait rien.

create table photo_blur_jobs (
  photo_id uuid primary key references profile_photos (id) on delete cascade,
  attempts int not null default 0,
  last_error text,
  last_attempt_at timestamptz not null default now()
);
alter table photo_blur_jobs enable row level security; -- aucune règle : invisible pour les membres
revoke all on photo_blur_jobs from public, anon, authenticated;
grant select, insert, update, delete on photo_blur_jobs to service_role;

insert into app_config (key, value, description, is_public) values
  ('blur_max_attempts', '5',
   'Essais de fabrication automatique de la version floutée d''une photo avant abandon (relance : 5 min, 10 min, …)',
   false)
on conflict (key) do nothing;

-- Photos à flouter : sans version floutée, envoyées depuis au moins p_min_age_seconds (laisse à l'application le
-- temps de la demander elle-même), sans trop d'échecs, et pas en attente d'un nouvel essai.
create function blur_backlog(p_limit int, p_min_age_seconds int)
returns table (id uuid, user_id uuid, storage_path text)
language sql stable security definer set search_path = public as $$
  select ph.id, ph.user_id, ph.storage_path
  from profile_photos ph
  left join photo_blur_jobs j on j.photo_id = ph.id
  where ph.blur_path is null
    and ph.created_at <= now() - make_interval(secs => greatest(coalesce(p_min_age_seconds, 0), 0))
    and (j.photo_id is null
         or (j.attempts < cfg_int('blur_max_attempts', 5)
             and j.last_attempt_at <= now() - make_interval(mins => 5 * j.attempts)))
  order by coalesce(j.attempts, 0), ph.created_at, ph.id
  limit least(greatest(coalesce(p_limit, 1), 1), 20);
$$;

create function blur_job_failed(p_photo uuid, p_error text) returns void
language sql security definer set search_path = public as $$
  insert into photo_blur_jobs (photo_id, attempts, last_error, last_attempt_at)
  select p_photo, 1, left(coalesce(p_error, ''), 500), now()
  where exists (select 1 from profile_photos where id = p_photo)
  on conflict (photo_id) do update
    set attempts = photo_blur_jobs.attempts + 1, last_error = excluded.last_error, last_attempt_at = now();
$$;

-- Appel planifié. Les objets de pg_net et du coffre sont appelés par « execute » : la fonction se crée aussi sur une
-- base qui ne les a pas (PGlite), et n'y fait rien.
create function blur_photos_tick() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_token text;
begin
  if not exists (select 1 from blur_backlog(1, 60)) then return 0; end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'net' and p.proname = 'http_post')
     or to_regclass('vault.decrypted_secrets') is null then
    return 0;
  end if;
  execute $q$select (select decrypted_secret from vault.decrypted_secrets where name = 'zaya_project_url'),
                    (select decrypted_secret from vault.decrypted_secrets where name = 'zaya_blur_token')$q$
    into v_url, v_token;
  if coalesce(v_url, '') = '' or coalesce(v_token, '') = '' then return 0; end if;
  execute $q$select net.http_post(url := $1, body := '{}'::jsonb,
                                  headers := jsonb_build_object('Content-Type', 'application/json', 'x-zaya-cron', $2),
                                  timeout_milliseconds := 30000)$q$
    using rtrim(v_url, '/') || '/functions/v1/blur-photos', v_token;
  return 1;
end;
$$;

revoke execute on function blur_backlog(int, int) from public, anon, authenticated;
revoke execute on function blur_job_failed(uuid, text) from public, anon, authenticated;
revoke execute on function blur_photos_tick() from public, anon, authenticated;
grant execute on function blur_backlog(int, int) to service_role;
grant execute on function blur_job_failed(uuid, text) to service_role;

-- Tâche planifiée : seulement là où pg_cron et pg_net existent (Supabase). Reprogrammer sous le même nom remplace
-- la tâche existante : la migration peut être rejouée.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and exists (select 1 from pg_available_extensions where name = 'pg_net') then
    if exists (select 1 from pg_namespace where nspname = 'extensions') then
      execute 'create extension if not exists pg_net with schema extensions';
    else
      execute 'create extension if not exists pg_net';
    end if;
    execute 'create extension if not exists pg_cron';
    execute $q$select cron.schedule('zaya-floutage-automatique', '* * * * *', 'select public.blur_photos_tick()')$q$;
  end if;
end $$;

-- ════════════════════════ 0058_reparer_libelles_niveaux_etudes.sql
-- Répare les deux libellés français avec accents de la liste des niveaux d'études,
-- uniquement si leur valeur enregistrée contient un marqueur d'encodage abîmé.
update education_levels
set label_fr = case key
  when 'middle' then U&'Coll\00E8ge (BEPC)'
  when 'bac' then U&'Baccalaur\00E9at'
end
where key in ('middle', 'bac')
  and (
    position(U&'\FFFD' in label_fr) > 0
    or position(U&'\00C3' in label_fr) > 0
    or position('?' in label_fr) > 0
  );

-- ════════════════════════ 0059_communes_conakry_actualisees.sql
-- Ajoute les huit communes de Conakry absentes du référentiel initial.
-- Liste actualisée selon l'arrêté A/2026/872/MATD/CAB/SGG du 13 octobre 2026.
-- Le pays doit exister : sur une base vide, le seed crée la Guinée puis ses villes.
insert into cities (country_code, name)
select v.country_code, v.name
from countries c
join (values
  ('GN', U&'Conakry \2014 Gbessia'),
  ('GN', U&'Conakry \2014 Kagb\00E9len'),
  ('GN', U&'Conakry \2014 Lambanyi'),
  ('GN', U&'Conakry \2014 Man\00E9ah'),
  ('GN', U&'Conakry \2014 Sanoyah'),
  ('GN', U&'Conakry \2014 Sonfonia'),
  ('GN', U&'Conakry \2014 Tombolia'),
  ('GN', U&'Conakry \2014 Kassa')
) as v(country_code, name) on v.country_code = c.code
on conflict (country_code, name) do nothing;

-- ════════════════════════ 0060_jetons_notifications.sql
-- Jetons FCM des appareils membres. Les jetons restent invisibles aux clients ; seul le serveur les lit pour
-- distribuer les notifications. Un membre ne peut enregistrer ou retirer que le jeton de sa session.

create table member_push_tokens (
  token text primary key check (char_length(token) between 32 and 4096),
  user_id uuid not null references profiles (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);
create index member_push_tokens_user_idx on member_push_tokens (user_id);
alter table member_push_tokens enable row level security;
revoke all on member_push_tokens from anon, authenticated;

create function register_push_token(p_token text, p_platform text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_token is null or char_length(p_token) < 32 or char_length(p_token) > 4096 then
    raise exception 'INVALID_PUSH_TOKEN';
  end if;
  if p_platform is null or p_platform not in ('android', 'ios') then raise exception 'INVALID_PUSH_PLATFORM'; end if;
  insert into member_push_tokens (token, user_id, platform)
  values (p_token, auth.uid(), p_platform)
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;
revoke execute on function register_push_token(text, text) from public, anon;
grant execute on function register_push_token(text, text) to authenticated;

create function unregister_push_token(p_token text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  delete from member_push_tokens where token = p_token and user_id = auth.uid();
end;
$$;
revoke execute on function unregister_push_token(text) from public, anon;
grant execute on function unregister_push_token(text) to authenticated;

-- ════════════════════════ 0061_webhook_notifications.sql
-- Relie les signaux serveur au distributeur FCM sans stocker le secret dans Git.
-- Les valeurs zaya_project_url et zaya_push_webhook_secret sont créées dans Vault
-- pour chaque environnement avant d'appliquer cette migration.

do $$
begin
  -- Absente de l'émulateur de test : l'extension n'est créée que si l'environnement la propose.
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end;
$$;

create or replace function public.dispatch_member_signal_webhook()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  webhook_secret text;
begin
  select decrypted_secret into project_url
  from vault.decrypted_secrets
  where name = 'zaya_project_url';

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'zaya_push_webhook_secret';

  -- Une panne de configuration des notifications ne doit pas bloquer les messages.
  if project_url is null or webhook_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/push-dispatch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-webhook-secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', tg_op,
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', null
    )
  );

  return new;
end;
$$;

revoke execute on function public.dispatch_member_signal_webhook() from public, anon, authenticated;

create trigger member_signals_push_webhook
  after insert on public.member_signals
  for each row execute function public.dispatch_member_signal_webhook();

-- ════════════════════════ 0062_messages_vocaux.sql
-- Notes vocales privées dans une conversation active.
-- Contrôles serveur : match actif, blocage, limite d'envoi, durée et poids du fichier.

insert into public.app_config (key, value, description, is_public) values
  ('voice_messages_enabled', 'true', 'Autoriser les notes vocales dans les conversations', true),
  ('voice_message_max_duration_seconds', '60', 'Durée maximale d’une note vocale', true),
  ('voice_message_max_size_bytes', '1048576', 'Poids maximal d’une note vocale (1 Mio)', true)
on conflict (key) do nothing;

alter table public.messages
  add column message_kind text not null default 'text',
  add column media_path text,
  add column media_duration_seconds int,
  add constraint messages_kind_check check (message_kind in ('text', 'voice')),
  add constraint messages_voice_payload_check check (
    (message_kind = 'text' and media_path is null and media_duration_seconds is null)
    or
    (message_kind = 'voice' and media_path is not null and media_duration_seconds between 1 and 60)
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-voice', 'chat-voice', false, 1048576, array['audio/mp4'])
on conflict (id) do update set
  public = false,
  file_size_limit = 1048576,
  allowed_mime_types = array['audio/mp4'];

create function public.can_upload_chat_voice() returns boolean
language sql stable security definer set search_path = public as $$
  select (
    select count(*) from storage.objects o
    where o.bucket_id = 'chat-voice'
      and o.owner_id = auth.uid()::text
      and o.created_at > now() - interval '1 minute'
  ) < cfg_int('message_rate_per_minute', 20);
$$;
revoke execute on function public.can_upload_chat_voice() from public, anon;
grant execute on function public.can_upload_chat_voice() to authenticated;

create policy chat_voice_upload_match_member on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-voice'
    and cardinality(storage.foldername(name)) = 2
    and (storage.foldername(name))[2] = auth.uid()::text
    and exists (
      select 1 from public.matches m
      where m.id::text = (storage.foldername(name))[1]
        and auth.uid() in (m.user_a, m.user_b)
        and m.ended_at is null
        and not public.blocked_between(m.user_a, m.user_b)
    )
    and public.can_upload_chat_voice()
  );

create policy chat_voice_read_visible_message on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-voice'
    and exists (
      select 1
      from public.messages msg
      join public.matches m on m.id = msg.match_id
      where msg.media_path = storage.objects.name
        and msg.message_kind = 'voice'
        and msg.unsent_at is null
        and auth.uid() in (m.user_a, m.user_b)
        and not public.blocked_between(m.user_a, m.user_b)
        and not exists (
          select 1 from public.message_hidden h
          where h.message_id = msg.id and h.user_id = auth.uid()
        )
    )
  );

create policy chat_voice_delete_owner on storage.objects
  for delete to authenticated
  using (bucket_id = 'chat-voice' and (storage.foldername(name))[2] = auth.uid()::text);

create function public.send_voice_message(
  p_match uuid,
  p_storage_path text,
  p_duration_seconds int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match matches;
  v_size bigint;
  v_max_size int := least(cfg_int('voice_message_max_size_bytes', 1048576), 1048576);
  v_max_duration int := least(cfg_int('voice_message_max_duration_seconds', 60), 60);
  v_message uuid;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not cfg_bool('voice_messages_enabled', false) then raise exception 'VOICE_MESSAGES_DISABLED'; end if;
  if p_duration_seconds is null or p_duration_seconds < 1 or p_duration_seconds > v_max_duration then
    raise exception 'INVALID_VOICE_DURATION';
  end if;

  select * into v_match from matches where id = p_match and v_me in (user_a, user_b);
  if not found or v_match.ended_at is not null then raise exception 'MATCH_ENDED'; end if;
  if blocked_between(v_match.user_a, v_match.user_b) then raise exception 'MATCH_ENDED'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active') then
    raise exception 'PROFILE_NOT_ACTIVE';
  end if;
  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object(
      'status', 'active_limit',
      'active', active_conversations_count(v_me),
      'limit', active_conversations_limit(v_me)
    );
  end if;
  if (
    select count(*) from messages
    where sender_id = v_me and created_at > now() - interval '1 minute'
  ) >= cfg_int('message_rate_per_minute', 20) then
    raise exception 'MESSAGE_RATE_LIMITED';
  end if;
  if p_storage_path is null
    or p_storage_path not like p_match::text || '/' || v_me::text || '/%.m4a'
  then raise exception 'INVALID_VOICE_PATH'; end if;

  select coalesce((metadata->>'size')::bigint, 0) into v_size
  from storage.objects
  where bucket_id = 'chat-voice'
    and name = p_storage_path
    and owner_id = v_me::text
    and metadata->>'mimetype' = 'audio/mp4';
  if not found or v_size < 1 or v_size > v_max_size then raise exception 'INVALID_VOICE_FILE'; end if;

  insert into messages (
    match_id, sender_id, body, message_kind, media_path, media_duration_seconds
  ) values (
    p_match, v_me, 'Note vocale', 'voice', p_storage_path, p_duration_seconds
  ) returning id into v_message;

  return jsonb_build_object('status', 'sent', 'id', v_message);
end;
$$;

revoke execute on function public.send_voice_message(uuid, text, int) from public, anon;
grant execute on function public.send_voice_message(uuid, text, int) to authenticated;

-- ════════════════════════ 0063_statuts_reception_messages.sql
-- Accusés de réception et de lecture indépendants.
-- « Reçu » signifie que l'application du destinataire a confirmé sa connexion ; « Lu » reste read_at.

alter table public.messages add column delivered_at timestamptz;
alter table public.member_signals add column entity_id uuid;
create index messages_pending_delivery_idx on public.messages (match_id, created_at)
  where delivered_at is null and read_at is null and unsent_at is null;

create function public.signal_message_member(p_user uuid, p_message uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user is null then return; end if;
  delete from member_signals where user_id = p_user and created_at < now() - interval '1 day';
  insert into member_signals (user_id, kind, entity_id)
    values (p_user, 'message', p_message);
end;
$$;
revoke execute on function public.signal_message_member(uuid, uuid) from public, anon, authenticated;

create or replace function public.signals_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  case tg_table_name
    when 'interests' then
      perform signal_member(new.to_user, 'like');
    when 'matches' then
      perform signal_member(new.user_a, 'match');
      perform signal_member(new.user_b, 'match');
    when 'messages' then
      perform signal_message_member(
        (select case when m.user_a = new.sender_id then m.user_b else m.user_a end
         from matches m where m.id = new.match_id),
        new.id);
    when 'profile_photos' then
      perform signal_member(coalesce(new.user_id, old.user_id), 'photo');
    when 'premium_grants' then
      perform signal_member(new.user_id, 'premium');
    when 'profiles' then
      perform signal_member(new.id, 'profile');
    when 'profile_views' then
      perform signal_member(new.viewed, 'visit');
  end case;
  return null;
end;
$$;
revoke execute on function public.signals_after_change() from public, anon, authenticated;

create function public.mark_message_received(p_message uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  update messages msg
  set delivered_at = coalesce(msg.delivered_at, now())
  from matches m
  where msg.id = p_message
    and msg.match_id = m.id
    and auth.uid() in (m.user_a, m.user_b)
    and msg.sender_id <> auth.uid()
    and msg.read_at is null
    and msg.unsent_at is null
    and not blocked_between(m.user_a, m.user_b);
  return found;
end;
$$;
revoke execute on function public.mark_message_received(uuid) from public, anon;
grant execute on function public.mark_message_received(uuid) to authenticated;

create function public.mark_pending_messages_received() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_count int;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  update messages msg
  set delivered_at = now()
  from matches m
  where msg.match_id = m.id
    and auth.uid() in (m.user_a, m.user_b)
    and msg.sender_id <> auth.uid()
    and msg.delivered_at is null
    and msg.read_at is null
    and msg.unsent_at is null
    and not blocked_between(m.user_a, m.user_b);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke execute on function public.mark_pending_messages_received() from public, anon;
grant execute on function public.mark_pending_messages_received() to authenticated;

-- ════════════════════════ 0064_stickers_animes.sql
-- Animations prédéfinies et emojis animés, sans transfert de GIF arbitraire.
-- Le catalogue est borné côté serveur pour n'accepter que des animations ZAYA connues.

insert into public.app_config (key, value, description, is_public) values
  ('animated_stickers_enabled', 'true', 'Autoriser les animations prédéfinies dans les conversations', true)
on conflict (key) do nothing;

alter table public.messages add column sticker_id text;
alter table public.messages drop constraint messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (message_kind in ('text', 'voice', 'sticker'));
alter table public.messages drop constraint messages_voice_payload_check;
alter table public.messages add constraint messages_media_payload_check check (
  (message_kind = 'text' and media_path is null and media_duration_seconds is null and sticker_id is null)
  or
  (message_kind = 'voice' and media_path is not null and media_duration_seconds between 1 and 60 and sticker_id is null)
  or
  (message_kind = 'sticker' and media_path is null and media_duration_seconds is null and sticker_id in (
    'heart_bounce', 'laugh_shake', 'kiss_pulse', 'hug_squeeze',
    'party_spin', 'prayer_bounce', 'rose_sway', 'fire_flicker'
  ))
);

create function public.send_animated_sticker(p_match uuid, p_sticker_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match matches;
  v_message uuid;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not cfg_bool('animated_stickers_enabled', false) then raise exception 'STICKERS_DISABLED'; end if;
  if p_sticker_id not in (
    'heart_bounce', 'laugh_shake', 'kiss_pulse', 'hug_squeeze',
    'party_spin', 'prayer_bounce', 'rose_sway', 'fire_flicker'
  ) then raise exception 'INVALID_ANIMATED_STICKER'; end if;

  select * into v_match from matches where id = p_match and v_me in (user_a, user_b);
  if not found or v_match.ended_at is not null then raise exception 'MATCH_ENDED'; end if;
  if blocked_between(v_match.user_a, v_match.user_b) then raise exception 'MATCH_ENDED'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active') then
    raise exception 'PROFILE_NOT_ACTIVE';
  end if;
  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object(
      'status', 'active_limit',
      'active', active_conversations_count(v_me),
      'limit', active_conversations_limit(v_me)
    );
  end if;
  if (
    select count(*) from messages
    where sender_id = v_me and created_at > now() - interval '1 minute'
  ) >= cfg_int('message_rate_per_minute', 20) then
    raise exception 'MESSAGE_RATE_LIMITED';
  end if;

  insert into messages (match_id, sender_id, body, message_kind, sticker_id)
  values (p_match, v_me, 'Animation', 'sticker', p_sticker_id)
  returning id into v_message;

  return jsonb_build_object('status', 'sent', 'id', v_message);
end;
$$;

revoke execute on function public.send_animated_sticker(uuid, text) from public, anon;
grant execute on function public.send_animated_sticker(uuid, text) to authenticated;

create or replace function public.my_matches()
returns table (match_id uuid, user_id uuid, display_name text, photo_path text, is_verified boolean,
               last_message text, last_at timestamptz, unread int, matched_at timestamptz)
language sql stable security definer set search_path = public as $$
  select m.id, p.id, p.display_name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         p.verification_status = 'approved',
         lm.last_message, lm.created_at,
         (select count(*)::int from messages u
           where u.match_id = m.id and u.sender_id <> auth.uid() and u.read_at is null and u.unsent_at is null
             and not exists (select 1 from message_hidden h where h.message_id = u.id and h.user_id = auth.uid())),
         m.created_at
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  left join lateral (
    select case
      when x.unsent_at is not null then null
      when x.message_kind = 'voice' then 'Note vocale'
      when x.message_kind = 'sticker' then 'GIF animé'
      else x.body
    end as last_message, x.created_at
    from messages x
    where x.match_id = m.id
      and not exists (select 1 from message_hidden h where h.message_id = x.id and h.user_id = auth.uid())
    order by x.created_at desc limit 1
  ) lm on true
  where auth.uid() in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
  order by coalesce(lm.created_at, m.created_at) desc;
$$;

-- ════════════════════════ 0065_badge_messages.sql
-- Nombre de conversations contenant des messages non lus, utilisable par l'app et le répartiteur FCM.
create function public.unread_message_count(p_user uuid) returns int
language plpgsql stable security definer set search_path = public as $$
declare
  v_count int;
begin
  if p_user is null then raise exception 'USER_REQUIRED'; end if;
  if auth.uid() is not null and auth.uid() <> p_user then raise exception 'NOT_ALLOWED'; end if;
  if auth.uid() is null and coalesce(auth.role(), '') <> 'service_role' then raise exception 'NOT_ALLOWED'; end if;

  select count(*)::int into v_count
  from messages msg
  join matches m on m.id = msg.match_id
  where p_user in (m.user_a, m.user_b)
    and msg.sender_id <> p_user
    and msg.read_at is null
    and msg.unsent_at is null
    and not blocked_between(m.user_a, m.user_b)
    and not exists (
      select 1 from message_hidden hidden
      where hidden.message_id = msg.id and hidden.user_id = p_user
    );
  return coalesce(v_count, 0);
end;
$$;

revoke execute on function public.unread_message_count(uuid) from public, anon;
grant execute on function public.unread_message_count(uuid) to authenticated, service_role;

-- ════════════════════════ 0066_reactions_reponses.sql
-- Messagerie : réactions (emoji) et réponse à un message. Règles vérifiées côté serveur.

-- ── Réponse à un message
alter table public.messages add column reply_to_id uuid references public.messages (id) on delete set null;
create index messages_reply_to_idx on public.messages (reply_to_id) where reply_to_id is not null;

drop function public.send_message(uuid, text);
create function public.send_message(p_match uuid, p_body text, p_reply_to uuid default null) returns jsonb
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
  -- La citation doit appartenir à la même conversation.
  if p_reply_to is not null
     and not exists (select 1 from messages where id = p_reply_to and match_id = p_match) then
    raise exception 'INVALID_REPLY';
  end if;

  if (select count(*) from messages where sender_id = v_me and created_at > now() - interval '1 minute')
     >= cfg_int('message_rate_per_minute', 20) then
    raise exception 'MESSAGE_RATE_LIMITED';
  end if;

  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object('status', 'active_limit',
                              'active', active_conversations_count(v_me), 'limit', active_conversations_limit(v_me));
  end if;

  v_category := message_violation_category(v_body);
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;

  insert into messages (match_id, sender_id, body, reply_to_id)
    values (p_match, v_me, v_body, p_reply_to) returning id into v_id;
  return jsonb_build_object('status', 'sent', 'id', v_id);
end;
$$;
revoke execute on function public.send_message(uuid, text, uuid) from public, anon;
grant execute on function public.send_message(uuid, text, uuid) to authenticated;

-- ── Réactions : une seule par membre et par message, liste d'emojis fermée.
create table public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null check (emoji in ('❤️', '😂', '😮', '😢', '🙏', '👍')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
create index message_reactions_match_idx on public.message_reactions (match_id);
alter table public.message_reactions enable row level security;
grant select on public.message_reactions to authenticated;
create policy reactions_select_participant on public.message_reactions for select to authenticated using (
  exists (select 1 from matches m where m.id = message_reactions.match_id and auth.uid() in (m.user_a, m.user_b))
);

-- p_emoji null : retire ma réaction. Même emoji déjà posé : la retire (bascule).
create function public.react_to_message(p_message uuid, p_emoji text) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_msg messages;
  v_match matches;
  v_current text;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_msg from messages where id = p_message;
  if not found or v_msg.unsent_at is not null then raise exception 'MESSAGE_NOT_FOUND'; end if;
  select * into v_match from matches where id = v_msg.match_id and v_me in (user_a, user_b);
  if not found then raise exception 'MESSAGE_NOT_FOUND'; end if;
  if v_match.ended_at is not null or blocked_between(v_match.user_a, v_match.user_b) then
    raise exception 'MATCH_ENDED';
  end if;
  select emoji into v_current from message_reactions where message_id = p_message and user_id = v_me;
  if p_emoji is null or p_emoji = v_current then
    delete from message_reactions where message_id = p_message and user_id = v_me;
    return 'removed';
  end if;
  if p_emoji not in ('❤️', '😂', '😮', '😢', '🙏', '👍') then raise exception 'INVALID_REACTION'; end if;
  insert into message_reactions (message_id, match_id, user_id, emoji)
    values (p_message, v_msg.match_id, v_me, p_emoji)
  on conflict (message_id, user_id) do update set emoji = excluded.emoji, created_at = now();
  return 'set';
end;
$$;
revoke execute on function public.react_to_message(uuid, text) from public, anon;
grant execute on function public.react_to_message(uuid, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end;
$$;

-- ════════════════════════ 0067_socle_zaya2.sql
-- ZAYA 2.0 — Lot 0 : socle de sécurité (interrupteurs, registre de crédits, anti-arnaque, confiance, doublons de photos).
-- Valeurs chiffrées provisoires : voir documentation/DECISIONS_A_CONFIRMER.md (D1 à D8). Tout est lu dans app_config.

-- ── Interrupteurs d'urgence : chaque fonctionnalité se coupe côté serveur, même pour une ancienne version de l'app.
insert into app_config (key, value, description, is_public) values
  ('feature_match_of_day_enabled', 'true', 'Zaya Match du jour', true),
  ('feature_pulse_enabled', 'true', 'Zaya Pulse', true),
  ('feature_invitation_enabled', 'true', 'Zaya Invitation (parrainage)', true),
  ('feature_surprise_enabled', 'true', 'Zaya Surprise quotidienne', true),
  ('feature_challenge_enabled', 'true', 'Zaya Challenge', true),
  ('feature_questions_enabled', 'true', 'Zaya Questions', true),
  ('max_unanswered_messages', '8', 'Messages consécutifs permis sans réponse de l''autre personne', false),
  ('trust_min_for_recommendations', '30', 'Score de confiance minimal pour être recommandé (Match du jour, Pulse)', false),
  ('photo_hash_max_distance', '6', 'Distance de Hamming maximale entre deux empreintes de photos pour les juger identiques', false)
on conflict (key) do nothing;

create function public.feature_enabled(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select cfg_bool('feature_' || p_name || '_enabled', false);
$$;
revoke execute on function public.feature_enabled(text) from public, anon;
grant execute on function public.feature_enabled(text) to authenticated;

-- ── Registre de crédits en ajout seul. Le client ne peut ni écrire ni modifier : seul le serveur crédite.
-- Chaque ligne est aussi inscrite au portefeuille existant (wallet_transactions, catégorie « bonus », 0033) :
-- le membre voit ses gains dans « Mon portefeuille ». Pas de pièces ni de compliments gagnés : les pièces
-- achetées et les crédits gagnés restent séparés (régie §6-7).
create table public.reward_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  source text not null check (source in ('surprise', 'challenge', 'referral', 'admin', 'reversal')),
  asset text not null check (asset in ('swipes', 'boost')),
  amount int not null check (amount <> 0),
  idempotency_key text not null unique,
  reason text not null check (char_length(reason) between 2 and 160),
  reverses bigint references public.reward_ledger (id),
  created_at timestamptz not null default now()
);
create index reward_ledger_user_idx on public.reward_ledger (user_id, created_at desc);
create trigger reward_ledger_append_only before update or delete on public.reward_ledger
  for each row execute function forbid_change();
alter table public.reward_ledger enable row level security;
create policy ledger_read on public.reward_ledger for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
revoke all on public.reward_ledger from anon, authenticated;
grant select on public.reward_ledger to authenticated;

-- Crédit idempotent : la même clé ne crédite jamais deux fois (retourne faux au second appel).
create function public.grant_reward(p_user uuid, p_source text, p_asset text, p_amount int, p_key text, p_reason text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  if p_amount is null or p_amount <= 0 then return false; end if;
  insert into reward_ledger (user_id, source, asset, amount, idempotency_key, reason)
    values (p_user, p_source, p_asset, p_amount, p_key, p_reason)
  on conflict (idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then return false; end if;
  if p_asset = 'swipes' then
    perform grant_extra_swipes(p_user, p_amount, 'zaya2_' || p_source, p_key);
  end if;
  insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (p_user, 'bonus', p_asset, p_amount, left(p_reason, 120), p_key);
  return true;
end;
$$;
revoke execute on function public.grant_reward(uuid, text, text, int, text, text) from public, anon, authenticated;

-- Annulation par l'équipe : nouvelle ligne négative, jamais d'effacement. Les swipes déjà utilisés ne sont pas repris.
create function public.admin_reverse_reward(p_entry bigint, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_row reward_ledger;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_row from reward_ledger where id = p_entry and amount > 0;
  if not found then raise exception 'ENTRY_NOT_FOUND'; end if;
  insert into reward_ledger (user_id, source, asset, amount, idempotency_key, reason, reverses)
    values (v_row.user_id, 'reversal', v_row.asset, -v_row.amount, 'reverse:' || p_entry, left(p_reason, 160), p_entry);
  insert into wallet_transactions (user_id, category, asset, amount, reason, ref)
    values (v_row.user_id, 'bonus', v_row.asset, -v_row.amount, left('Annulation : ' || p_reason, 120), 'reverse:' || p_entry);
  perform write_audit('reward_reversed', 'reward_ledger', p_entry::text, null, null, p_reason);
exception when unique_violation then
  raise exception 'ALREADY_REVERSED';
end;
$$;
revoke execute on function public.admin_reverse_reward(bigint, text) from public, anon;
grant execute on function public.admin_reverse_reward(bigint, text) to authenticated;

-- ── Anti-arnaque en messagerie : avertissement aux deux personnes, événement gardé pour la modération.
create function public.scam_category(p_body text) returns text
language sql immutable as $$
  select case
    when p_body ~* '(orange\s*money|mtn\s*(money|momo)|mobile\s*money|\mmomo\M|western\s*union|moneygram|paypal|moov\s*money)' then 'mobile_money'
    when p_body ~* '(\miban\M|\mrib\M|num[ée]ro\s+de\s+compte|compte\s+bancaire|bank\s+account|carte\s+bancaire|code\s+(pin|secret))' then 'bank_details'
    when p_body ~* '(carte\s+cadeau|gift\s*card|bitcoin|crypto|investissement|investir)' then 'investment'
    when p_body ~* '(envoie|envoyer|envoi|transf[èe]re|transf[ée]rer|donne|donner|pr[êe]te|pr[êe]ter|besoin|send|lend)\s.{0,40}\m(argent|sous|fric|cfa|gnf|fcfa|francs?|dollars?|euros?|money|cash)\M' then 'money_request'
    when p_body ~* '\margent\M.{0,30}(urgent|svp|stp|s''il)' then 'money_request'
    else null
  end;
$$;

alter table public.messages add column scam_category text;
create table public.scam_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  message_id uuid references public.messages (id) on delete set null,
  category text not null,
  created_at timestamptz not null default now()
);
create index scam_events_user_idx on public.scam_events (user_id, created_at desc);
alter table public.scam_events enable row level security;
create policy scam_events_staff on public.scam_events for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
revoke all on public.scam_events from anon, authenticated;
grant select on public.scam_events to authenticated;

-- ── Score de confiance interne : jamais exposé aux membres, utilisé pour l'éligibilité aux recommandations.
create function public.trust_score(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select greatest(0, least(100,
      40
    + least(20, (extract(epoch from now() - p.created_at) / 86400)::int / 5)
    + case when p.verification_status = 'approved' then 25 else 0 end
    - least(40, 10 * (select count(distinct r.reporter)::int from reports r
                       where r.reported_user = p.id and r.created_at > now() - interval '90 days'))
    - least(30, 5 * (select count(*)::int from message_violations v where v.user_id = p.id))
    - least(30, 6 * (select count(*)::int from scam_events s where s.user_id = p.id))
    - case when exists (select 1 from sanctions s where s.user_id = p.id
                          and s.kind in ('restriction', 'suspension', 'ban')
                          and (s.ends_at is null or s.ends_at > now())) then 40 else 0 end))::int
  from profiles p where p.id = p_user;
$$;
revoke execute on function public.trust_score(uuid) from public, anon, authenticated;

-- ── Empreintes de photos : détecte une même image utilisée par deux comptes (alimentée par la fonction Edge).
create table public.photo_hashes (
  photo_id uuid primary key references public.profile_photos (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  phash bigint not null,
  created_at timestamptz not null default now()
);
create index photo_hashes_user_idx on public.photo_hashes (user_id);
create table public.photo_duplicate_flags (
  id bigint generated always as identity primary key,
  photo_id uuid not null references public.profile_photos (id) on delete cascade,
  duplicate_of uuid not null references public.profile_photos (id) on delete cascade,
  distance int not null,
  status text not null default 'open' check (status in ('open', 'dismissed', 'confirmed')),
  created_at timestamptz not null default now(),
  unique (photo_id, duplicate_of)
);
alter table public.photo_hashes enable row level security;
alter table public.photo_duplicate_flags enable row level security;
create policy photo_flags_staff on public.photo_duplicate_flags for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
revoke all on public.photo_hashes, public.photo_duplicate_flags from anon, authenticated;
grant select on public.photo_duplicate_flags to authenticated;

create function public.register_photo_hash(p_photo uuid, p_hash bigint) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_user uuid;
  v_found int := 0;
  r record;
begin
  select user_id into v_user from profile_photos where id = p_photo;
  if not found then raise exception 'PHOTO_NOT_FOUND'; end if;
  insert into photo_hashes (photo_id, user_id, phash) values (p_photo, v_user, p_hash)
    on conflict (photo_id) do update set phash = excluded.phash;
  for r in
    select h.photo_id, bit_count((h.phash # p_hash)::bit(64))::int as distance
    from photo_hashes h
    where h.user_id <> v_user and h.photo_id <> p_photo
      and bit_count((h.phash # p_hash)::bit(64)) <= cfg_int('photo_hash_max_distance', 6)
  loop
    insert into photo_duplicate_flags (photo_id, duplicate_of, distance) values (p_photo, r.photo_id, r.distance)
      on conflict do nothing;
    v_found := v_found + 1;
  end loop;
  return v_found;
end;
$$;
revoke execute on function public.register_photo_hash(uuid, bigint) from public, anon, authenticated;

-- ── Messagerie : avertissement anti-arnaque + limite de messages sans réponse (reprise de 0066).
create or replace function public.send_message(p_match uuid, p_body text, p_reply_to uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match matches;
  v_other uuid;
  v_category text;
  v_scam text;
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
  if p_reply_to is not null
     and not exists (select 1 from messages where id = p_reply_to and match_id = p_match) then
    raise exception 'INVALID_REPLY';
  end if;

  if (select count(*) from messages where sender_id = v_me and created_at > now() - interval '1 minute')
     >= cfg_int('message_rate_per_minute', 20) then
    raise exception 'MESSAGE_RATE_LIMITED';
  end if;

  -- Trop de messages à une personne qui ne répond pas : frein contre le harcèlement et l'envoi de masse.
  if (select count(*) from messages m
       where m.match_id = p_match and m.sender_id = v_me and m.unsent_at is null
         and m.created_at > coalesce((select max(o.created_at) from messages o
                                       where o.match_id = p_match and o.sender_id <> v_me), '-infinity'))
     >= cfg_int('max_unanswered_messages', 8) then
    raise exception 'UNANSWERED_LIMIT';
  end if;

  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object('status', 'active_limit',
                              'active', active_conversations_count(v_me), 'limit', active_conversations_limit(v_me));
  end if;

  v_category := message_violation_category(v_body);
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;

  -- Demande d'argent, Mobile Money, coordonnées bancaires : le message passe, mais les deux personnes sont avertis.
  v_scam := scam_category(v_body);
  insert into messages (match_id, sender_id, body, reply_to_id, scam_category)
    values (p_match, v_me, v_body, p_reply_to, v_scam) returning id into v_id;
  if v_scam is not null then
    insert into scam_events (user_id, match_id, message_id, category) values (v_me, p_match, v_id, v_scam);
  end if;
  return jsonb_build_object('status', 'sent', 'id', v_id, 'warning', v_scam);
end;
$$;

-- Une modification ne peut pas non plus introduire une demande d'argent sans avertissement.
create or replace function public.edit_message(p_message uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_msg messages;
  v_category text;
  v_scam text;
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
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (auth.uid(), v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  v_scam := scam_category(v_body);
  update messages set body = v_body, edited_at = now(), scam_category = v_scam where id = p_message;
  if v_scam is not null then
    insert into scam_events (user_id, match_id, message_id, category) values (auth.uid(), v_msg.match_id, p_message, v_scam);
  end if;
  return jsonb_build_object('status', 'edited', 'warning', v_scam);
end;
$$;

-- ════════════════════════ 0068_lot1_match_pulse_invitation.sql
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

-- ════════════════════════ 0069_lot2_questions_surprise_challenge.sql
-- ZAYA 2.0 — Lot 2 : Questions (visibilité par réponse), Surprise quotidienne, Challenge.
-- Les montants de récompense sont à 0 tant que le propriétaire ne les fixe pas (documentation/DECISIONS_A_CONFIRMER.md, D9 à D12).

insert into app_config (key, value, description, is_public) values
  ('challenge_daily_reward_cap', '3', 'Défis récompensés par membre et par jour', false),
  ('challenge_weekly_reward_cap', '10', 'Défis récompensés par membre et par semaine', false),
  ('challenge_device_daily_cap', '6', 'Défis récompensés par jour et par appareil (tous comptes confondus)', false)
on conflict (key) do nothing;

-- ── Questions pour mieux se connaître
create table public.marriage_questions (
  id bigint generated always as identity primary key,
  code text not null unique,
  topic text not null check (topic in ('marriage', 'family', 'children', 'living', 'goals', 'communication')),
  text_fr text not null,
  text_en text not null,
  sensitive boolean not null default false,
  position int not null default 0,
  active boolean not null default true
);
create table public.question_answers (
  user_id uuid not null references public.profiles (id) on delete cascade,
  question_id bigint not null references public.marriage_questions (id) on delete cascade,
  answer text not null check (char_length(answer) between 1 and 500),
  visibility text not null default 'me' check (visibility in ('me', 'matches', 'verified')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, question_id)
);
create index question_answers_day_idx on public.question_answers (user_id, created_at desc);
alter table public.marriage_questions enable row level security;
alter table public.question_answers enable row level security;
create policy questions_read on public.marriage_questions for select to authenticated using (active);
create policy answers_own on public.question_answers for select to authenticated using (user_id = auth.uid());
revoke all on public.marriage_questions, public.question_answers from anon, authenticated;
grant select on public.marriage_questions, public.question_answers to authenticated;

insert into public.marriage_questions (code, topic, text_fr, text_en, sensitive, position) values
  ('marriage_success', 'marriage', 'Pour vous, qu''est-ce qui fait un mariage réussi ?', 'In your view, what makes a marriage successful?', false, 1),
  ('family_place', 'family', 'Quelle place souhaitez-vous donner à vos familles dans votre couple ?', 'What place do you want your families to have in your couple?', true, 2),
  ('children_plan', 'children', 'Souhaitez-vous des enfants ? Combien, et à quel moment ?', 'Do you want children? How many, and when?', true, 3),
  ('living_place', 'living', 'Où aimeriez-vous vivre après le mariage ?', 'Where would you like to live after marriage?', false, 4),
  ('life_goals', 'goals', 'Quels sont vos principaux objectifs de vie pour les cinq prochaines années ?', 'What are your main life goals for the next five years?', false, 5),
  ('communication', 'communication', 'Comment aimez-vous que l''on vous parle quand quelque chose ne va pas ?', 'How do you like to be spoken to when something is wrong?', false, 6),
  ('disagreement', 'communication', 'Comment gérez-vous un désaccord avec la personne que vous aimez ?', 'How do you handle a disagreement with someone you love?', false, 7),
  ('daily_life', 'living', 'À quoi ressemble, pour vous, une journée ordinaire heureuse à deux ?', 'What does an ordinary happy day together look like for you?', false, 8)
on conflict (code) do nothing;

create function public.marriage_questions_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not feature_enabled('questions') then jsonb_build_object('status', 'disabled')
    else jsonb_build_object('status', 'ready', 'questions',
      coalesce((select jsonb_agg(jsonb_build_object(
          'id', q.id, 'topic', q.topic, 'text_fr', q.text_fr, 'text_en', q.text_en, 'sensitive', q.sensitive,
          'answer', a.answer, 'visibility', a.visibility) order by q.position)
        from marriage_questions q
        left join question_answers a on a.question_id = q.id and a.user_id = auth.uid()
        where q.active), '[]'::jsonb)) end;
$$;
revoke execute on function public.marriage_questions_list() from public, anon;
grant execute on function public.marriage_questions_list() to authenticated;

-- Réponse : privée par défaut (« moi seul »). Le texte passe par le même filtre que la messagerie.
create function public.answer_question(p_question bigint, p_answer text, p_visibility text default 'me') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_text text := trim(p_answer);
  v_category text;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('questions') then raise exception 'FEATURE_DISABLED'; end if;
  if p_visibility not in ('me', 'matches', 'verified') then raise exception 'INVALID_VISIBILITY'; end if;
  if v_text is null or v_text = '' or char_length(v_text) > 500 then raise exception 'INVALID_ANSWER'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active') then raise exception 'PROFILE_NOT_ACTIVE'; end if;
  if not exists (select 1 from marriage_questions where id = p_question and active) then raise exception 'QUESTION_NOT_FOUND'; end if;
  v_category := message_violation_category(v_text);
  if v_category is null and contains_link(v_text) then v_category := 'link'; end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  insert into question_answers (user_id, question_id, answer, visibility) values (v_me, p_question, v_text, p_visibility)
    on conflict (user_id, question_id) do update
      set answer = excluded.answer, visibility = excluded.visibility, updated_at = now();
  return jsonb_build_object('status', 'saved');
end;
$$;
revoke execute on function public.answer_question(bigint, text, text) from public, anon;
grant execute on function public.answer_question(bigint, text, text) to authenticated;

create function public.delete_answer(p_question bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  delete from question_answers where user_id = auth.uid() and question_id = p_question;
end;
$$;
revoke execute on function public.delete_answer(bigint) from public, anon;
grant execute on function public.delete_answer(bigint) to authenticated;

-- Réponses d'un membre que je consulte : la visibilité choisie par la personne est appliquée ici, côté serveur.
create function public.answers_of(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_matched boolean;
  v_verified boolean;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('questions') then return '[]'::jsonb; end if;
  if v_me <> p_user and blocked_between(v_me, p_user) then return '[]'::jsonb; end if;
  v_matched := exists (select 1 from matches where user_a = least(v_me, p_user) and user_b = greatest(v_me, p_user)
                        and ended_at is null);
  v_verified := exists (select 1 from profiles where id = v_me and status = 'active' and verification_status = 'approved');
  return coalesce((
    select jsonb_agg(jsonb_build_object('question_id', q.id, 'text_fr', q.text_fr, 'text_en', q.text_en,
                                        'answer', a.answer, 'visibility', a.visibility) order by q.position)
    from question_answers a
    join marriage_questions q on q.id = a.question_id and q.active
    join profiles t on t.id = a.user_id and t.status = 'active'
    where a.user_id = p_user
      and (v_me = p_user
           or (a.visibility = 'matches' and v_matched)
           or (a.visibility = 'verified' and v_verified))), '[]'::jsonb);
end;
$$;
revoke execute on function public.answers_of(uuid) from public, anon;
grant execute on function public.answers_of(uuid) to authenticated;

-- ── Surprise quotidienne : tirage serveur, une par jour (clé primaire), probabilités publiques.
create table public.surprise_prizes (
  code text primary key,
  kind text not null check (kind in ('question', 'swipes')),
  label_fr text not null,
  label_en text not null,
  weight int not null default 0 check (weight >= 0),
  amount int not null default 0 check (amount >= 0),
  active boolean not null default true
);
insert into public.surprise_prizes (code, kind, label_fr, label_en, weight, amount, active) values
  ('question', 'question', 'Une question pour mieux vous connaître', 'A question to know yourself better', 100, 0, true),
  ('swipes', 'swipes', 'Des swipes offerts', 'Free swipes', 0, 0, false)
on conflict (code) do nothing;
alter table public.surprise_prizes enable row level security;
create policy prizes_read on public.surprise_prizes for select to authenticated using (true);
create policy prizes_staff on public.surprise_prizes for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
revoke all on public.surprise_prizes from anon, authenticated;
grant select on public.surprise_prizes to authenticated;
grant update on public.surprise_prizes to authenticated;

create table public.daily_surprises (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  prize_code text not null references public.surprise_prizes (code),
  amount int not null default 0,
  question_id bigint references public.marriage_questions (id),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.daily_surprises enable row level security;
revoke all on public.daily_surprises from anon, authenticated;

-- Probabilités réelles affichées avant l'ouverture : pas de promesse ambiguë.
create function public.surprise_odds() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', p.code, 'label_fr', p.label_fr, 'label_en', p.label_en, 'amount', p.amount,
           'percent', round(100.0 * p.weight / nullif(t.total, 0), 1)) order by p.code), '[]'::jsonb)
  from surprise_prizes p, (select sum(weight) as total from surprise_prizes where active and weight > 0) t
  where p.active and p.weight > 0;
$$;
revoke execute on function public.surprise_odds() from public, anon;
grant execute on function public.surprise_odds() to authenticated;

create function public.open_daily_surprise() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_day date := (now() at time zone 'utc')::date;
  v_total int;
  v_pick int;
  v_bytes bytea;
  v_prize surprise_prizes;
  v_question bigint;
  v_row daily_surprises;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('surprise') then return jsonb_build_object('status', 'disabled'); end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active' and verification_status = 'approved') then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select * into v_row from daily_surprises where user_id = v_me and day = v_day;
  if not found then
    select coalesce(sum(weight), 0) into v_total from surprise_prizes where active and weight > 0;
    if v_total = 0 then return jsonb_build_object('status', 'unavailable'); end if;
    -- Aléa du générateur sûr de PostgreSQL (UUID v4), réduit à un entier : ni le client ni l'heure n'y changent rien.
    v_bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    v_pick := (((get_byte(v_bytes, 0)::bigint << 24) + (get_byte(v_bytes, 1)::bigint << 16)
              + (get_byte(v_bytes, 2)::bigint << 8) + get_byte(v_bytes, 3)) % v_total)::int;
    select * into v_prize from (
      select p.*, sum(p.weight) over (order by p.code) as cum from surprise_prizes p where p.active and p.weight > 0
    ) x where x.cum > v_pick order by x.cum limit 1;
    if v_prize.kind = 'question' then
      select q.id into v_question from marriage_questions q
        where q.active and not exists (select 1 from question_answers a where a.question_id = q.id and a.user_id = v_me)
        order by random() limit 1;
    end if;
    insert into daily_surprises (user_id, day, prize_code, amount, question_id)
      values (v_me, v_day, v_prize.code, v_prize.amount, v_question)
      on conflict (user_id, day) do nothing;
    select * into v_row from daily_surprises where user_id = v_me and day = v_day;
    if v_prize.kind = 'swipes' and v_prize.amount > 0 and v_row.prize_code = v_prize.code then
      perform grant_reward(v_me, 'surprise', 'swipes', v_prize.amount, 'surprise:' || v_me || ':' || v_day, 'Surprise du jour');
    end if;
    return jsonb_build_object('status', 'opened', 'prize', v_row.prize_code, 'amount', v_row.amount,
                              'question_id', v_row.question_id);
  end if;
  return jsonb_build_object('status', 'already_opened', 'prize', v_row.prize_code, 'amount', v_row.amount,
                            'question_id', v_row.question_id);
end;
$$;
revoke execute on function public.open_daily_surprise() from public, anon;
grant execute on function public.open_daily_surprise() to authenticated;

-- ── Challenge : chaque défi est validé par le serveur à partir d'événements réels.
create table public.challenges (
  code text primary key,
  kind text not null check (kind in ('complete_profile', 'answer_questions', 'view_profiles')),
  title_fr text not null,
  title_en text not null,
  target int not null default 1 check (target >= 1),
  once boolean not null default false,
  reward_amount int not null default 0 check (reward_amount >= 0),
  position int not null default 0,
  active boolean not null default true
);
insert into public.challenges (code, kind, title_fr, title_en, target, once, reward_amount, position) values
  ('complete_profile', 'complete_profile', 'Complétez votre profil', 'Complete your profile', 1, true, 0, 1),
  ('answer_question', 'answer_questions', 'Répondez à une question', 'Answer a question', 1, false, 0, 2),
  ('discover_profiles', 'view_profiles', 'Découvrez 5 profils', 'Discover 5 profiles', 5, false, 0, 3)
on conflict (code) do nothing;
create table public.challenge_claims (
  user_id uuid not null references public.profiles (id) on delete cascade,
  challenge_code text not null references public.challenges (code),
  day date not null,
  reward_amount int not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, challenge_code, day)
);
alter table public.challenges enable row level security;
alter table public.challenge_claims enable row level security;
create policy challenges_read on public.challenges for select to authenticated using (active);
create policy challenge_claims_own on public.challenge_claims for select to authenticated using (user_id = auth.uid());
create policy challenges_staff on public.challenges for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
revoke all on public.challenges, public.challenge_claims from anon, authenticated;
grant select on public.challenges, public.challenge_claims to authenticated;
grant update on public.challenges to authenticated;

create function public.challenge_progress(p_user uuid, p_code text) returns int
language plpgsql stable security definer set search_path = public as $$
declare c challenges;
begin
  select * into c from challenges where code = p_code;
  if not found then return 0; end if;
  if c.kind = 'complete_profile' then
    return case when exists (
      select 1 from profiles p
      where p.id = p_user and char_length(coalesce(p.bio, '')) >= 20 and p.marriage_horizon is not null
        and p.profession_id is not null and approved_photo_count(p.id) >= cfg_int('min_profile_photos', 3)) then 1 else 0 end;
  elsif c.kind = 'answer_questions' then
    return (select count(*)::int from question_answers where user_id = p_user
             and created_at >= (now() at time zone 'utc')::date);
  else
    return (select count(distinct viewed)::int from profile_views
             where viewer = p_user and viewed <> p_user and viewed_at >= (now() at time zone 'utc')::date);
  end if;
end;
$$;
revoke execute on function public.challenge_progress(uuid, text) from public, anon, authenticated;

create function public.my_challenges() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('challenge') then return jsonb_build_object('status', 'disabled'); end if;
  return jsonb_build_object('status', 'ready', 'challenges', coalesce((
    select jsonb_agg(jsonb_build_object(
        'code', c.code, 'title_fr', c.title_fr, 'title_en', c.title_en, 'target', c.target,
        'progress', least(c.target, challenge_progress(v_me, c.code)), 'reward', c.reward_amount,
        'claimed', exists (select 1 from challenge_claims k where k.user_id = v_me and k.challenge_code = c.code
                            and k.day = case when c.once then date '2000-01-01' else (now() at time zone 'utc')::date end))
      order by c.position)
    from challenges c where c.active), '[]'::jsonb));
end;
$$;
revoke execute on function public.my_challenges() from public, anon;
grant execute on function public.my_challenges() to authenticated;

create function public.claim_challenge(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  c challenges;
  v_day date;
  v_today date := (now() at time zone 'utc')::date;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('challenge') then raise exception 'FEATURE_DISABLED'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active' and verification_status = 'approved') then
    raise exception 'NOT_ELIGIBLE';
  end if;
  select * into c from challenges where code = p_code and active;
  if not found then raise exception 'CHALLENGE_NOT_FOUND'; end if;
  if challenge_progress(v_me, p_code) < c.target then raise exception 'NOT_COMPLETED'; end if;
  v_day := case when c.once then date '2000-01-01' else v_today end;
  if exists (select 1 from challenge_claims where user_id = v_me and challenge_code = p_code and day = v_day) then
    raise exception 'ALREADY_CLAIMED';
  end if;
  -- Plafonds par membre (jour, semaine) et par appareil : un défi récompensé de plus est refusé, pas crédité.
  if c.reward_amount > 0 then
    if (select count(*) from challenge_claims where user_id = v_me and reward_amount > 0 and created_at >= date_trunc('day', now()))
         >= cfg_int('challenge_daily_reward_cap', 3)
       or (select count(*) from challenge_claims where user_id = v_me and reward_amount > 0 and created_at >= date_trunc('week', now()))
         >= cfg_int('challenge_weekly_reward_cap', 10) then
      raise exception 'REWARD_CAP_REACHED';
    end if;
    if (select count(*) from challenge_claims k
         where k.reward_amount > 0 and k.created_at >= date_trunc('day', now())
           and k.user_id in (select d2.user_id from member_devices d1 join member_devices d2 on d1.device_hash = d2.device_hash
                              where d1.user_id = v_me))
       >= cfg_int('challenge_device_daily_cap', 6) then
      raise exception 'DEVICE_LIMIT';
    end if;
  end if;
  insert into challenge_claims (user_id, challenge_code, day, reward_amount) values (v_me, p_code, v_day, c.reward_amount);
  perform grant_reward(v_me, 'challenge', 'swipes', c.reward_amount, 'challenge:' || p_code || ':' || v_me || ':' || v_day, 'Défi : ' || c.title_fr);
  return jsonb_build_object('status', 'claimed', 'reward', c.reward_amount);
end;
$$;
revoke execute on function public.claim_challenge(text) from public, anon;
grant execute on function public.claim_challenge(text) to authenticated;

-- ════════════════════════ 0070_fleur_conversations_en_ligne.sql
-- Demandes du propriétaire (25/11/2026) : Fleur Premium réellement envoyée, suppression de plusieurs conversations
-- (pour moi), point vert « en ligne » visible par les matchs. Règles vérifiées côté serveur.
-- Valeurs provisoires à confirmer : documentation/DECISIONS_A_CONFIRMER.md (D13 à D15).

insert into app_config (key, value, description, is_public) values
  ('flowers_enabled', 'true', 'Fleur Premium : marquer un profil d''une fleur', true),
  ('flowers_per_day', '3', 'Fleurs par membre Premium et par jour (valeur provisoire)', true),
  ('online_window_minutes', '5', 'Un membre est « en ligne » s''il a été actif depuis ce nombre de minutes', false)
on conflict (key) do nothing;

-- ── Fleur Premium : un « J'aime » mis en avant, dont l'expéditeur choisit de se faire connaître.
alter table public.interests add column is_flower boolean not null default false;
alter table public.interests add column flower_at timestamptz;
create index interests_flower_idx on public.interests (to_user, flower_at desc) where is_flower;

create function public.send_flower(p_target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_result jsonb;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not cfg_bool('flowers_enabled', false) then raise exception 'FEATURE_DISABLED'; end if;
  if not is_premium(v_me) then raise exception 'PREMIUM_REQUIRED'; end if;
  if exists (select 1 from interests where from_user = v_me and to_user = p_target and is_flower) then
    return jsonb_build_object('status', 'already_sent');
  end if;
  if (select count(*) from interests
       where from_user = v_me and is_flower and flower_at >= date_trunc('day', now()))
     >= cfg_int('flowers_per_day', 3) then
    raise exception 'FLOWER_LIMIT';
  end if;
  -- Même chemin qu'un « J'aime » : profil disponible, blocage, quota et match réciproque sont vérifiés par send_like.
  v_result := send_like(p_target);
  if v_result ->> 'status' not in ('liked', 'matched', 'already_liked') then
    return v_result;
  end if;
  update interests set is_flower = true, flower_at = now() where from_user = v_me and to_user = p_target;
  return v_result || jsonb_build_object('flower', true);
end;
$$;
revoke execute on function public.send_flower(uuid) from public, anon;
grant execute on function public.send_flower(uuid) to authenticated;

-- Fleurs reçues : l'expéditeur s'est fait connaître en l'envoyant, elles sont donc visibles même sans Premium.
create function public.received_flowers()
returns table (interest_id uuid, user_id uuid, display_name text, age int, city text, photo_path text, sent_at timestamptz)
language sql stable security definer set search_path = public as $$
  select i.id, p.id, p.display_name, age_of(p.birth_date), ci.name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         i.flower_at
  from interests i
  join profiles p on p.id = i.from_user
  left join cities ci on ci.id = p.city_id
  where i.to_user = auth.uid() and i.is_flower and i.status = 'pending'
    and is_discoverable(p.id) and not blocked_between(i.from_user, i.to_user)
  order by i.flower_at desc;
$$;
revoke execute on function public.received_flowers() from public, anon;
grant execute on function public.received_flowers() to authenticated;

-- ── Supprimer des conversations (pour moi) : l'historique disparaît de mon côté, le match reste.
-- Si l'autre personne écrit à nouveau, la conversation revient avec les seuls nouveaux messages.
create table public.conversation_hidden (
  user_id uuid not null references public.profiles (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (user_id, match_id)
);
alter table public.conversation_hidden enable row level security;
create policy conversation_hidden_own on public.conversation_hidden for select to authenticated
  using (user_id = auth.uid());
revoke all on public.conversation_hidden from anon, authenticated;
grant select on public.conversation_hidden to authenticated;

create function public.hide_conversations(p_matches uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match uuid;
  v_count int := 0;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_matches is null or cardinality(p_matches) = 0 then return 0; end if;
  if cardinality(p_matches) > 200 then raise exception 'TOO_MANY_CONVERSATIONS'; end if;
  for v_match in select m.id from matches m where m.id = any (p_matches) and v_me in (m.user_a, m.user_b) loop
    insert into message_hidden (message_id, user_id)
      select x.id, v_me from messages x where x.match_id = v_match
      on conflict do nothing;
    insert into conversation_hidden (user_id, match_id) values (v_me, v_match)
      on conflict (user_id, match_id) do update set hidden_at = now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke execute on function public.hide_conversations(uuid[]) from public, anon;
grant execute on function public.hide_conversations(uuid[]) to authenticated;

-- Reprise de my_matches (0064) : une conversation supprimée n'apparaît plus tant qu'aucun nouveau message n'arrive.
create or replace function public.my_matches()
returns table (match_id uuid, user_id uuid, display_name text, photo_path text, is_verified boolean,
               last_message text, last_at timestamptz, unread int, matched_at timestamptz)
language sql stable security definer set search_path = public as $$
  select m.id, p.id, p.display_name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         p.verification_status = 'approved',
         lm.last_message, lm.created_at,
         (select count(*)::int from messages u
           where u.match_id = m.id and u.sender_id <> auth.uid() and u.read_at is null and u.unsent_at is null
             and not exists (select 1 from message_hidden h where h.message_id = u.id and h.user_id = auth.uid())),
         m.created_at
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  left join lateral (
    select case
      when x.unsent_at is not null then null
      when x.message_kind = 'voice' then 'Note vocale'
      when x.message_kind = 'sticker' then 'GIF animé'
      else x.body
    end as last_message, x.created_at
    from messages x
    where x.match_id = m.id
      and not exists (select 1 from message_hidden h where h.message_id = x.id and h.user_id = auth.uid())
    order by x.created_at desc limit 1
  ) lm on true
  where auth.uid() in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
    and not exists (select 1 from conversation_hidden ch
                    where ch.user_id = auth.uid() and ch.match_id = m.id and lm.created_at is null)
  order by coalesce(lm.created_at, m.created_at) desc;
$$;

-- ── En ligne : seulement pour mes matchs, si la personne l'autorise (show_online) et si je l'autorise moi aussi.
create function public.my_online_matches() returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
    and p.status = 'active' and p.show_online
    and p.last_active_at > now() - make_interval(mins => cfg_int('online_window_minutes', 5))
    and exists (select 1 from profiles me where me.id = auth.uid() and me.show_online);
$$;
revoke execute on function public.my_online_matches() from public, anon;
grant execute on function public.my_online_matches() to authenticated;

-- ════════════════════════ 0071_connexion_par_code.sql
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

-- ════════════════════════ seed.sql
-- ZAYA — données de référence (aucune donnée personnelle). Valeurs provisoires : voir DECISIONS_A_CONFIRMER.md

insert into countries (code, name_fr, name_en, phone_prefix, enabled) values
  ('GN', 'Guinée', 'Guinea', '+224', true),
  ('SN', 'Sénégal', 'Senegal', '+221', false),
  ('CI', 'Côte d''Ivoire', 'Côte d''Ivoire', '+225', false),
  ('ML', 'Mali', 'Mali', '+223', false),
  ('SL', 'Sierra Leone', 'Sierra Leone', '+232', false),
  ('LR', 'Libéria', 'Liberia', '+231', false),
  ('GW', 'Guinée-Bissau', 'Guinea-Bissau', '+245', false),
  ('GM', 'Gambie', 'Gambia', '+220', false),
  ('FR', 'France', 'France', '+33', false)
on conflict (code) do nothing;

insert into cities (country_code, name) values
  ('GN', 'Conakry — Kaloum'), ('GN', 'Conakry — Dixinn'), ('GN', 'Conakry — Matam'),
  ('GN', 'Conakry — Ratoma'), ('GN', 'Conakry — Matoto'),
  ('GN', 'Coyah'), ('GN', 'Dubréka'), ('GN', 'Kindia'), ('GN', 'Boké'), ('GN', 'Kamsar'),
  ('GN', 'Labé'), ('GN', 'Mamou'), ('GN', 'Kankan'), ('GN', 'Siguiri'), ('GN', 'Faranah'),
  ('GN', 'N''Zérékoré'), ('GN', 'Kissidougou'), ('GN', 'Guéckédou')
on conflict do nothing;

-- Catalogue culturel Guinée : liste non exhaustive, à relire localement (§23.2)
insert into ethnic_groups (country_code, label_fr) values
  ('GN', 'Peul'), ('GN', 'Malinké'), ('GN', 'Soussou'), ('GN', 'Kissi'), ('GN', 'Guerzé / Kpèlè'), ('GN', 'Baga')
on conflict do nothing;

insert into professions (category, label_fr) values
  ('administration', 'Administration publique'), ('agriculture', 'Agriculture / élevage'),
  ('commerce', 'Commerce'), ('artisanat', 'Artisanat'), ('batiment', 'Bâtiment / BTP'),
  ('transport', 'Transport / logistique'), ('sante', 'Santé'), ('education', 'Éducation / enseignement'),
  ('informatique', 'Informatique / télécoms'), ('finance', 'Banque / finance'), ('securite', 'Sécurité'),
  ('industrie', 'Industrie / mines'), ('services', 'Services'), ('etudiant', 'Étudiant(e)'),
  ('sans_emploi', 'Sans emploi'), ('retraite', 'Retraité(e)'), ('domestique', 'Travail domestique / ménager')
on conflict do nothing;

insert into app_config (key, value, description, is_public) values
  ('free_daily_likes', '20', 'Quota quotidien de likes gratuits', true),
  ('premium_daily_likes', '200', 'Plafond anti-abus des likes Premium', true),
  ('likes_reset_hour_utc', '0', 'Heure (UTC = Conakry) de renouvellement du quota', true),
  ('min_profile_photos', '3', 'Nombre minimal de photos approuvées', true),
  ('message_edit_window_minutes', '15', 'Durée pour modifier ou annuler un message', true),
  ('payments_enabled', 'false', 'Achats désactivés tant que la conformité n''est pas validée', true),
  ('support_whatsapp', '""', 'Numéro WhatsApp officiel du support (vide = bouton masqué)', true),
  ('account_deletion_delay_days', '30', 'Délai de rétractation avant suppression définitive du compte', true),
  ('community_enabled', 'true', 'Communauté ouverte (à confirmer avant ouverture publique : modération opérationnelle)', true),
  ('community_post_requires_verification', 'true', 'Profil vérifié exigé pour publier et commenter', true),
  ('community_posts_per_day', '5', 'Nombre maximal de publications par membre et par 24 h', true),
  ('community_comments_per_hour', '20', 'Nombre maximal de commentaires par membre et par heure', true),
  ('sms_monthly_budget_gnf', '0', 'Plafond mensuel de dépenses SMS (0 = envoi bloqué)', false),
  ('sms_unit_cost_gnf', '0', 'Coût unitaire d''un SMS, à confirmer avec Nimba', false)
on conflict (key) do nothing;

insert into legal_documents (kind, version, lang, content) values
  ('tos', 'v0-draft', 'fr', 'Brouillon — conditions d''utilisation à faire valider par un professionnel compétent.'),
  ('privacy', 'v0-draft', 'fr', 'Brouillon — politique de confidentialité à faire valider.'),
  ('community', 'v0-draft', 'fr', 'Brouillon — règles communautaires : respect, pas de nudité, pas de harcèlement, pas de demande d''argent.')
on conflict do nothing;

-- Liste minimale de démonstration : à compléter et à relire par l'équipe de modération avant lancement
insert into moderation_terms (term, category, severity) values
  ('envoie-moi de l''argent', 'money_request', 3),
  ('envoie moi de l''argent', 'money_request', 3),
  ('ton code otp', 'credential_request', 3),
  ('ton mot de passe', 'credential_request', 3),
  ('ton code orange money', 'credential_request', 3),
  ('photo nue', 'sexual_content', 3),
  ('je vais te tuer', 'threat', 3)
on conflict do nothing;

-- Communautés thématiques de départ (CDC V2.3 §2.3), ouvertes progressivement selon la capacité de modération
insert into communities (slug, name, description, icon, position) values
  ('preparation-mariage', 'Préparation au mariage',
   'Les questions à se poser, les étapes, les sujets à aborder avant de s’engager.', 'favorite', 1),
  ('vie-de-couple', 'Communication et vie de couple',
   'Écoute, désaccords, respect : partager ce qui aide à construire une relation solide.', 'forum', 2),
  ('conseils-experiences', 'Conseils et expériences',
   'Rencontres, premiers rendez-vous, précautions : apprendre de l’expérience des autres.', 'lightbulb', 3),
  ('famille-parentalite', 'Famille et parentalité',
   'Présenter son projet à sa famille, fonder un foyer, accueillir des enfants.', 'family', 4),
  ('developpement-personnel', 'Éducation et développement personnel',
   'Études, travail, projets : grandir pour soi et pour le couple.', 'school', 5),
  ('evenements-locaux', 'Événements et activités locales',
   'Ateliers, conférences et rencontres encadrées près de chez vous.', 'event', 6),
  ('questions-reponses', 'Questions et réponses',
   'Une question sur ZAYA, la sécurité ou la vie à deux ? Posez-la ici.', 'help', 7),
  ('langues-regions', 'Communautés linguistiques et régionales',
   'Échanger dans sa langue et autour de sa région.', 'translate', 8)
on conflict (slug) do nothing;

commit;
