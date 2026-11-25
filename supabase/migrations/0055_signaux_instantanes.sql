-- ZAYA — Mises à jour instantanées (demande du propriétaire, 18/11/2026 : « toutes les informations doivent être
-- mises à jour instantanément, photos et autres »).
--
-- Principe : un « signal » court est déposé pour le membre concerné à chaque événement qui change ce qu'il voit
-- (like reçu, match, message, photo modérée ou floutée, Premium, vérification, visite). L'application s'abonne en
-- temps réel (Supabase Realtime) à ses propres signaux et rafraîchit aussitôt les données concernées.
-- Un signal ne contient que sa nature : jamais l'identité de l'auteur (l'identité des likes reçus reste réservée à
-- Premium, CDC §4.3). Lisible par son seul destinataire ; aucune écriture possible par l'application.
-- Les signaux de plus d'un jour sont effacés au fil de l'eau (la table reste petite).

create table member_signals (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  kind text not null check (kind in ('like', 'match', 'message', 'photo', 'premium', 'profile', 'visit', 'wallet')),
  created_at timestamptz not null default now()
);
create index member_signals_user_idx on member_signals (user_id, created_at desc);
alter table member_signals enable row level security;
create policy member_signals_own on member_signals for select to authenticated using (user_id = auth.uid());
revoke all on member_signals from anon;
revoke insert, update, delete on member_signals from authenticated;
grant select on member_signals to authenticated;

-- Dépôt d'un signal (fonctions serveur seulement) ; efface au passage les anciens signaux du membre.
create function signal_member(p_user uuid, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user is null then return; end if;
  delete from member_signals where user_id = p_user and created_at < now() - interval '1 day';
  insert into member_signals (user_id, kind) values (p_user, p_kind);
end;
$$;
revoke execute on function signal_member(uuid, text) from public, anon, authenticated;

create function signals_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  case tg_table_name
    when 'interests' then
      perform signal_member(new.to_user, 'like');
    when 'matches' then
      perform signal_member(new.user_a, 'match');
      perform signal_member(new.user_b, 'match');
    when 'messages' then
      perform signal_member(
        (select case when m.user_a = new.sender_id then m.user_b else m.user_a end from matches m where m.id = new.match_id),
        'message');
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
revoke execute on function signals_after_change() from public, anon, authenticated;

create trigger interests_signal after insert on interests
  for each row execute function signals_after_change();
create trigger matches_signal after insert on matches
  for each row execute function signals_after_change();
create trigger messages_signal after insert on messages
  for each row execute function signals_after_change();
-- Photo ajoutée, retirée, modérée, floutée par le serveur ou changée de visibilité.
create trigger profile_photos_signal after insert or delete or update of moderation, blur_path, visibility, position
  on profile_photos for each row execute function signals_after_change();
create trigger premium_grants_signal after insert or update on premium_grants
  for each row execute function signals_after_change();
-- Seulement ce que le membre ne fait pas lui-même : vérification et statut du compte (décisions de l'équipe).
create trigger profiles_signal after update of verification_status, status on profiles
  for each row when (old.verification_status is distinct from new.verification_status or old.status is distinct from new.status)
  execute function signals_after_change();
create trigger profile_views_signal after insert on profile_views
  for each row execute function signals_after_change();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.member_signals;
  end if;
end;
$$;
