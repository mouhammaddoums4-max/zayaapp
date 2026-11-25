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
