-- ZAYA — MISE À JOUR : migrations 0066 à 0071 (réactions et réponses, ZAYA+, fleur, conversations, en ligne, connexion par code).
-- FICHIER GÉNÉRÉ par supabase/deploy/build_mise_a_jour.mjs : ne pas le modifier à la main.
--
-- Utilisation : Supabase > SQL Editor > New query, coller TOUT le contenu, puis « Run ».
-- Une seule transaction : en cas d’erreur, rien n’est modifié. Chaque migration déjà présente est ignorée
-- (voir les notes « déjà présente » dans les résultats) : le fichier peut être rejoué sans risque.

begin;

do $zaya$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'sticker_id') then raise exception 'Il manque la mise à jour 0060 à 0065 (notes vocales, animations) : collez-la d''abord.'; end if;
end $zaya$;

-- ═════════════════════════════ 0066_reactions_reponses.sql
do $zaya$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'reply_to_id') then
    raise notice '0066_reactions_reponses : déjà présente, ignorée';
  else
    execute $m0066$
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
$m0066$;
    raise notice '0066_reactions_reponses : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0067_socle_zaya2.sql
do $zaya$
begin
  if to_regclass('public.reward_ledger') is not null then
    raise notice '0067_socle_zaya2 : déjà présente, ignorée';
  else
    execute $m0067$
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
$m0067$;
    raise notice '0067_socle_zaya2 : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0068_lot1_match_pulse_invitation.sql
do $zaya$
begin
  if to_regclass('public.daily_matches') is not null then
    raise notice '0068_lot1_match_pulse_invitation : déjà présente, ignorée';
  else
    execute $m0068$
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
$m0068$;
    raise notice '0068_lot1_match_pulse_invitation : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0069_lot2_questions_surprise_challenge.sql
do $zaya$
begin
  if to_regclass('public.marriage_questions') is not null then
    raise notice '0069_lot2_questions_surprise_challenge : déjà présente, ignorée';
  else
    execute $m0069$
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
$m0069$;
    raise notice '0069_lot2_questions_surprise_challenge : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0070_fleur_conversations_en_ligne.sql
do $zaya$
begin
  if to_regclass('public.conversation_hidden') is not null then
    raise notice '0070_fleur_conversations_en_ligne : déjà présente, ignorée';
  else
    execute $m0070$
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
$m0070$;
    raise notice '0070_fleur_conversations_en_ligne : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0071_connexion_par_code.sql
do $zaya$
begin
  if to_regclass('private.member_pins') is not null then
    raise notice '0071_connexion_par_code : déjà présente, ignorée';
  else
    execute $m0071$
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
$m0071$;
    raise notice '0071_connexion_par_code : appliquée';
  end if;
end $zaya$;

-- Secret « poivre » des codes de connexion, créé dans le coffre Vault s'il n'existe pas (valeur aléatoire,
-- jamais écrite dans Git ni affichée).
do $zaya$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'zaya_pin_pepper') then
    perform vault.create_secret(replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
                                'zaya_pin_pepper');
  end if;
end $zaya$;

commit;
