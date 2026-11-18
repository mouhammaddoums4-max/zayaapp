-- ZAYA — Messagerie : conversations actives limitées et demande de re-match (décisions du propriétaire, 18/11/2026).
--
-- Conversation active : un match en cours dans lequel au moins un message a été échangé. Pour écrire le PREMIER
-- message d'un match, le membre doit avoir une place libre (max_active_conversations : 5 en Gratuit, réglable ;
-- davantage pour Premium). Un match sans message reste dans « Nouveaux matchs » ; terminer une conversation libère
-- une place. Répondre dans une conversation déjà ouverte n'est jamais bloqué.
--
-- Demande de re-match : après la fin d'un match, l'un des deux peut proposer de reprendre la conversation. L'autre
-- accepte (le match reprend) ou refuse ; une seule demande par match, jamais en cas de blocage, et pas de nouvelle
-- demande après un refus (protection contre l'insistance).

insert into app_config (key, value, description, is_public) values
  ('max_active_conversations', '5', 'Conversations actives à la fois pour un compte Gratuit', true),
  ('max_active_conversations_premium', '10',
   'Conversations actives à la fois pour un compte Premium (valeur provisoire, à confirmer)', true)
on conflict (key) do nothing;

-- ───────────────────────────── Conversations actives
create function active_conversations_count(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from matches m
  where p_user in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
    and exists (select 1 from messages x where x.match_id = m.id);
$$;

create function active_conversations_limit(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select case when is_premium(p_user) then cfg_int('max_active_conversations_premium', 10)
              else cfg_int('max_active_conversations', 5) end;
$$;

-- Places de conversation du membre connecté (affichage « 3/5 »).
create function my_conversation_slots() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  return jsonb_build_object('active', active_conversations_count(auth.uid()),
                            'limit', active_conversations_limit(auth.uid()));
end;
$$;

-- Premier message d'un match : place libre exigée (usage interne, aussi pour les messages avec média).
create function conversation_slot_available(p_user uuid, p_match uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from messages x where x.match_id = p_match)
      or active_conversations_count(p_user) < active_conversations_limit(p_user);
$$;

-- Reprise de send_message (0002) avec la vérification de place ; le reste est inchangé.
create or replace function send_message(p_match uuid, p_body text) returns jsonb
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

  -- Premier message : une place de conversation doit être libre.
  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object('status', 'active_limit',
                              'active', active_conversations_count(v_me), 'limit', active_conversations_limit(v_me));
  end if;

  -- Filtre avant transmission : un message non conforme n'est ni stocké ni transmis (§24.3)
  v_category := message_violation_category(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;

  insert into messages (match_id, sender_id, body) values (p_match, v_me, v_body) returning id into v_id;
  return jsonb_build_object('status', 'sent', 'id', v_id);
end;
$$;

-- ───────────────────────────── Demande de re-match
create table rematch_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references matches (id) on delete cascade,  -- une seule demande par match
  requester uuid not null references profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);
alter table rematch_requests enable row level security;
revoke all on rematch_requests from anon, authenticated;

create function request_rematch(p_match uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match matches;
  v_other uuid;
  v_req rematch_requests;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_match from matches where id = p_match and v_me in (user_a, user_b);
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  if v_match.ended_at is null then return jsonb_build_object('status', 'active'); end if;
  v_other := case when v_match.user_a = v_me then v_match.user_b else v_match.user_a end;
  if blocked_between(v_me, v_other)
     or not exists (select 1 from profiles where id = v_other and status in ('active', 'paused')) then
    raise exception 'REMATCH_UNAVAILABLE';
  end if;
  select * into v_req from rematch_requests where match_id = p_match;
  if found then
    -- L'autre avait déjà demandé : la demande croisée vaut accord.
    if v_req.status = 'pending' and v_req.requester = v_other then
      update rematch_requests set status = 'accepted', responded_at = now() where id = v_req.id;
      update matches set ended_at = null, ended_by = null where id = p_match;
      return jsonb_build_object('status', 'rematched');
    end if;
    return jsonb_build_object('status', v_req.status, 'mine', v_req.requester = v_me);
  end if;
  insert into rematch_requests (match_id, requester) values (p_match, v_me);
  return jsonb_build_object('status', 'pending', 'mine', true);
end;
$$;

create function respond_rematch(p_match uuid, p_accept boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_req rematch_requests;
  v_match matches;
begin
  select r.* into v_req from rematch_requests r join matches m on m.id = r.match_id
  where r.match_id = p_match and r.status = 'pending' and r.requester <> v_me and v_me in (m.user_a, m.user_b)
  for update of r;
  if not found then raise exception 'REQUEST_NOT_FOUND'; end if;
  select * into v_match from matches where id = p_match;
  if blocked_between(v_match.user_a, v_match.user_b) then raise exception 'REMATCH_UNAVAILABLE'; end if;
  update rematch_requests set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now()
    where id = v_req.id;
  if p_accept then update matches set ended_at = null, ended_by = null where id = p_match; end if;
  return jsonb_build_object('status', case when p_accept then 'rematched' else 'declined' end);
end;
$$;

-- Demandes reçues en attente (pour les afficher dans Messages).
create function my_rematch_requests()
returns table (match_id uuid, user_id uuid, display_name text, photo_path text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.match_id, p.id, p.display_name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         r.created_at
  from rematch_requests r
  join matches m on m.id = r.match_id
  join profiles p on p.id = r.requester
  where r.status = 'pending' and r.requester <> auth.uid() and auth.uid() in (m.user_a, m.user_b)
    and not blocked_between(m.user_a, m.user_b)
  order by r.created_at desc;
$$;

-- État de la demande pour un match terminé, vu par le membre (aucune / envoyée / reçue / refusée).
create function rematch_state(p_match uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when r.id is null then 'none'
    when r.status = 'pending' and r.requester = auth.uid() then 'sent'
    when r.status = 'pending' then 'received'
    else r.status end
  from matches m left join rematch_requests r on r.match_id = m.id
  where m.id = p_match and auth.uid() in (m.user_a, m.user_b);
$$;

revoke execute on function active_conversations_count(uuid), active_conversations_limit(uuid),
                           conversation_slot_available(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function my_conversation_slots(), request_rematch(uuid), respond_rematch(uuid, boolean),
                           my_rematch_requests(), rematch_state(uuid)
  from public, anon;
grant execute on function my_conversation_slots(), request_rematch(uuid), respond_rematch(uuid, boolean),
                          my_rematch_requests(), rematch_state(uuid)
  to authenticated;
