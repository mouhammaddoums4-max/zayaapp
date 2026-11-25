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
