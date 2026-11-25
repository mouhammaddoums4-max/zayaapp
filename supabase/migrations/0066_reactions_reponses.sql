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
