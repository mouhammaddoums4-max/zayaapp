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
