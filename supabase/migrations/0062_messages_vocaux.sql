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
