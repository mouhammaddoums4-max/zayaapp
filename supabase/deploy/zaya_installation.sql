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
