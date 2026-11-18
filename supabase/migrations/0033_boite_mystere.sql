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
