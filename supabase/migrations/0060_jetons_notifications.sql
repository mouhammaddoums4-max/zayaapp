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
