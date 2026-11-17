-- ZAYA — Lot A : diffusion temps réel des messages (les politiques RLS de `messages` s'appliquent aux abonnés).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
