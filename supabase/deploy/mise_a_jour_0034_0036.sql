-- ZAYA — MISE À JOUR : migrations 0034 à 0036 (publicités, boutique de cadeaux et de compliments, prix par défaut).
-- FICHIER GÉNÉRÉ depuis supabase/migrations/0034 à 0036 : ne pas le modifier à la main.
--
-- Utilisation : Supabase > SQL Editor > New query, coller TOUT le contenu, puis « Run ».
-- Une seule transaction : en cas d’erreur, rien n’est modifié et le message dit pourquoi.
-- Après cette mise à jour : réglages publicitaires (my_ad_settings, tout reste éteint par défaut), boutique
-- (Réglages > Boutique, « Offrir un cadeau » sur une fiche) avec les prix par défaut.
-- Indépendante des mises à jour 0055 à 0071 : peut être passée avant ou après elles.

begin;

-- Vérifications préalables.
do $$
begin
  if to_regclass('public.shop_items') is not null or to_regproc('public.my_ad_settings') is not null then
    raise exception 'Cette mise à jour est déjà appliquée (boutique ou réglages publicitaires présents) : rien à faire.';
  end if;
  if to_regclass('public.wallet_transactions') is null or to_regclass('public.mystery_box_prizes') is null then
    raise exception 'Il manque les migrations 0031 à 0033 (portefeuille, boîte mystère) : appliquez-les d''abord.';
  end if;
end $$;

-- ═════════════════════════════ 0034_publicites_google.sql
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

-- ═════════════════════════════ 0035_boutique_cadeaux_compliments.sql
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

-- ═════════════════════════════ 0036_prix_boutique_par_defaut.sql
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

commit;
