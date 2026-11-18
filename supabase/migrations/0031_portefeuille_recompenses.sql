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
