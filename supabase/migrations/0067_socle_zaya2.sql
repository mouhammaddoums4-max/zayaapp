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
