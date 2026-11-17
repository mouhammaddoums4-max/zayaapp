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
