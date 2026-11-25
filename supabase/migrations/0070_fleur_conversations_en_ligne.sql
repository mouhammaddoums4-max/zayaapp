-- Demandes du propriétaire (25/11/2026) : Fleur Premium réellement envoyée, suppression de plusieurs conversations
-- (pour moi), point vert « en ligne » visible par les matchs. Règles vérifiées côté serveur.
-- Valeurs provisoires à confirmer : documentation/DECISIONS_A_CONFIRMER.md (D13 à D15).

insert into app_config (key, value, description, is_public) values
  ('flowers_enabled', 'true', 'Fleur Premium : marquer un profil d''une fleur', true),
  ('flowers_per_day', '3', 'Fleurs par membre Premium et par jour (valeur provisoire)', true),
  ('online_window_minutes', '5', 'Un membre est « en ligne » s''il a été actif depuis ce nombre de minutes', false)
on conflict (key) do nothing;

-- ── Fleur Premium : un « J'aime » mis en avant, dont l'expéditeur choisit de se faire connaître.
alter table public.interests add column is_flower boolean not null default false;
alter table public.interests add column flower_at timestamptz;
create index interests_flower_idx on public.interests (to_user, flower_at desc) where is_flower;

create function public.send_flower(p_target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_result jsonb;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not cfg_bool('flowers_enabled', false) then raise exception 'FEATURE_DISABLED'; end if;
  if not is_premium(v_me) then raise exception 'PREMIUM_REQUIRED'; end if;
  if exists (select 1 from interests where from_user = v_me and to_user = p_target and is_flower) then
    return jsonb_build_object('status', 'already_sent');
  end if;
  if (select count(*) from interests
       where from_user = v_me and is_flower and flower_at >= date_trunc('day', now()))
     >= cfg_int('flowers_per_day', 3) then
    raise exception 'FLOWER_LIMIT';
  end if;
  -- Même chemin qu'un « J'aime » : profil disponible, blocage, quota et match réciproque sont vérifiés par send_like.
  v_result := send_like(p_target);
  if v_result ->> 'status' not in ('liked', 'matched', 'already_liked') then
    return v_result;
  end if;
  update interests set is_flower = true, flower_at = now() where from_user = v_me and to_user = p_target;
  return v_result || jsonb_build_object('flower', true);
end;
$$;
revoke execute on function public.send_flower(uuid) from public, anon;
grant execute on function public.send_flower(uuid) to authenticated;

-- Fleurs reçues : l'expéditeur s'est fait connaître en l'envoyant, elles sont donc visibles même sans Premium.
create function public.received_flowers()
returns table (interest_id uuid, user_id uuid, display_name text, age int, city text, photo_path text, sent_at timestamptz)
language sql stable security definer set search_path = public as $$
  select i.id, p.id, p.display_name, age_of(p.birth_date), ci.name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         i.flower_at
  from interests i
  join profiles p on p.id = i.from_user
  left join cities ci on ci.id = p.city_id
  where i.to_user = auth.uid() and i.is_flower and i.status = 'pending'
    and is_discoverable(p.id) and not blocked_between(i.from_user, i.to_user)
  order by i.flower_at desc;
$$;
revoke execute on function public.received_flowers() from public, anon;
grant execute on function public.received_flowers() to authenticated;

-- ── Supprimer des conversations (pour moi) : l'historique disparaît de mon côté, le match reste.
-- Si l'autre personne écrit à nouveau, la conversation revient avec les seuls nouveaux messages.
create table public.conversation_hidden (
  user_id uuid not null references public.profiles (id) on delete cascade,
  match_id uuid not null references public.matches (id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (user_id, match_id)
);
alter table public.conversation_hidden enable row level security;
create policy conversation_hidden_own on public.conversation_hidden for select to authenticated
  using (user_id = auth.uid());
revoke all on public.conversation_hidden from anon, authenticated;
grant select on public.conversation_hidden to authenticated;

create function public.hide_conversations(p_matches uuid[]) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_match uuid;
  v_count int := 0;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_matches is null or cardinality(p_matches) = 0 then return 0; end if;
  if cardinality(p_matches) > 200 then raise exception 'TOO_MANY_CONVERSATIONS'; end if;
  for v_match in select m.id from matches m where m.id = any (p_matches) and v_me in (m.user_a, m.user_b) loop
    insert into message_hidden (message_id, user_id)
      select x.id, v_me from messages x where x.match_id = v_match
      on conflict do nothing;
    insert into conversation_hidden (user_id, match_id) values (v_me, v_match)
      on conflict (user_id, match_id) do update set hidden_at = now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke execute on function public.hide_conversations(uuid[]) from public, anon;
grant execute on function public.hide_conversations(uuid[]) to authenticated;

-- Reprise de my_matches (0064) : une conversation supprimée n'apparaît plus tant qu'aucun nouveau message n'arrive.
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
    and not exists (select 1 from conversation_hidden ch
                    where ch.user_id = auth.uid() and ch.match_id = m.id and lm.created_at is null)
  order by coalesce(lm.created_at, m.created_at) desc;
$$;

-- ── En ligne : seulement pour mes matchs, si la personne l'autorise (show_online) et si je l'autorise moi aussi.
create function public.my_online_matches() returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b) and m.ended_at is null
    and not blocked_between(m.user_a, m.user_b)
    and p.status = 'active' and p.show_online
    and p.last_active_at > now() - make_interval(mins => cfg_int('online_window_minutes', 5))
    and exists (select 1 from profiles me where me.id = auth.uid() and me.show_online);
$$;
revoke execute on function public.my_online_matches() from public, anon;
grant execute on function public.my_online_matches() to authenticated;
