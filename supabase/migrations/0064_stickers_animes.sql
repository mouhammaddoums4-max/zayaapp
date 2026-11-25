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
