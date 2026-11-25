-- ZAYA — MISE À JOUR : migrations 0060 à 0065 (notifications push, notes vocales, accusés de réception, animations, badge).
-- FICHIER GÉNÉRÉ par supabase/deploy/build_mise_a_jour.mjs : ne pas le modifier à la main.
--
-- Utilisation : Supabase > SQL Editor > New query, coller TOUT le contenu, puis « Run ».
-- Une seule transaction : en cas d’erreur, rien n’est modifié. Chaque migration déjà présente est ignorée
-- (voir les notes « déjà présente » dans les résultats) : le fichier peut être rejoué sans risque.

begin;

do $zaya$
begin
  if to_regclass('public.member_signals') is null then raise exception 'Il manque la mise à jour 0055 à 0059 : collez-la d''abord.'; end if;
end $zaya$;

-- ═════════════════════════════ 0060_jetons_notifications.sql
do $zaya$
begin
  if to_regclass('public.member_push_tokens') is not null then
    raise notice '0060_jetons_notifications : déjà présente, ignorée';
  else
    execute $m0060$
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
$m0060$;
    raise notice '0060_jetons_notifications : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0061_webhook_notifications.sql
do $zaya$
begin
  if exists (select 1 from pg_trigger where tgname = 'member_signals_push_webhook') then
    raise notice '0061_webhook_notifications : déjà présente, ignorée';
  else
    execute $m0061$
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
$m0061$;
    raise notice '0061_webhook_notifications : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0062_messages_vocaux.sql
do $zaya$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'message_kind') then
    raise notice '0062_messages_vocaux : déjà présente, ignorée';
  else
    execute $m0062$
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
$m0062$;
    raise notice '0062_messages_vocaux : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0063_statuts_reception_messages.sql
do $zaya$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'delivered_at') then
    raise notice '0063_statuts_reception_messages : déjà présente, ignorée';
  else
    execute $m0063$
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
$m0063$;
    raise notice '0063_statuts_reception_messages : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0064_stickers_animes.sql
do $zaya$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'sticker_id') then
    raise notice '0064_stickers_animes : déjà présente, ignorée';
  else
    execute $m0064$
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
$m0064$;
    raise notice '0064_stickers_animes : appliquée';
  end if;
end $zaya$;

-- ═════════════════════════════ 0065_badge_messages.sql
do $zaya$
begin
  if exists (select 1 from pg_proc where proname = 'unread_message_count') then
    raise notice '0065_badge_messages : déjà présente, ignorée';
  else
    execute $m0065$
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
$m0065$;
    raise notice '0065_badge_messages : appliquée';
  end if;
end $zaya$;

commit;
