-- ZAYA — Messagerie : liens interdits et limite de fréquence (demande du propriétaire, 18/11/2026).
--
-- • « Interdiction d'envoi de lien par message » : un message (envoi ou modification) qui contient un lien n'est ni
--   stocké ni transmis ; la tentative est comptée dans message_violations (catégorie « link », sans le texte), comme
--   les autres contenus bloqués (§24.3). CDC : liens suspects et escroqueries (§177, §830, §1443).
-- • Anti-spam (CDC §1191 « limites de fréquence ») : au plus `message_rate_per_minute` messages par minute et par
--   membre (réglable dans app_config) ; au-delà, refus MESSAGE_RATE_LIMITED.
--
-- Détection des liens : adresse avec protocole (https://, http://, intent://…), « www. », domaine avec une extension
-- courante (.com, .net, .org…), raccourcisseurs (bit.ly…), domaine suivi d'un chemin (exemple.gn/page), écritures
-- détournées « site point com ». Les extensions de deux lettres seules (.ma, .me, .ne…) ne comptent que suivies
-- d'un chemin, pour ne pas bloquer une phrase sans espace après le point (« ok.Ma sœur… »). Une adresse e-mail n'est
-- pas un lien (elle reste régie par les règles existantes). La détection complète la modération humaine, elle ne la
-- remplace pas : une écriture très détournée peut passer.

insert into app_config (key, value, description, is_public) values
  ('message_rate_per_minute', '20', 'Messages au plus par minute et par membre (anti-spam)', false)
on conflict (key) do nothing;

create index if not exists messages_sender_recent_idx on messages (sender_id, created_at desc);

create function contains_link(p_body text) returns boolean
language sql immutable set search_path = public as $$
  select p_body ~* '[a-z][a-z0-9+.-]{1,15}://'
      or p_body ~* '(^|[^a-z0-9@._-])www\s*\.'
      or p_body ~* '(^|[^a-z0-9@._-])[a-z0-9-]+(\.[a-z0-9-]+)*\.(com|net|org|info|biz|app|dev|link|site|online|shop|store|xyz|top|live|click|io)\M'
      -- « site . com » : espace avant le point (une fin de phrase « C'est bon. Top ! » n'est pas un lien)
      or p_body ~* '(^|[^a-z0-9@._-])[a-z0-9-]+\s+\.\s*(com|net|org)\M'
      or p_body ~* '(^|[^a-z0-9@._-])(bit\.ly|goo\.gl|tinyurl|t\.co|cutt\.ly|rb\.gy|is\.gd|ow\.ly|shorturl\.at|wa\.me|t\.me|m\.me)\M'
      or p_body ~* '(^|[^a-z0-9@._-])[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}/\S'
      or p_body ~* '\m(point|dot)\s*(com|net|org)\M';
$$;
revoke execute on function contains_link(text) from public, anon, authenticated;

-- Reprise de send_message (0040, limite des conversations actives comprise) : limite de fréquence et liens.
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

  -- Anti-spam : nombre de messages envoyés par ce membre dans la dernière minute.
  if (select count(*) from messages where sender_id = v_me and created_at > now() - interval '1 minute')
     >= cfg_int('message_rate_per_minute', 20) then
    raise exception 'MESSAGE_RATE_LIMITED';
  end if;

  -- Premier message : une place de conversation doit être libre.
  if not conversation_slot_available(v_me, p_match) then
    return jsonb_build_object('status', 'active_limit',
                              'active', active_conversations_count(v_me), 'limit', active_conversations_limit(v_me));
  end if;

  -- Filtre avant transmission : un message non conforme n'est ni stocké ni transmis (§24.3)
  v_category := message_violation_category(v_body);
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;

  insert into messages (match_id, sender_id, body) values (p_match, v_me, v_body) returning id into v_id;
  return jsonb_build_object('status', 'sent', 'id', v_id);
end;
$$;

-- Reprise de edit_message (0002) : un lien ne peut pas entrer par une modification.
create or replace function edit_message(p_message uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_msg messages;
  v_category text;
  v_body text := trim(p_body);
begin
  select * into v_msg from messages where id = p_message and sender_id = auth.uid();
  if not found then raise exception 'MESSAGE_NOT_FOUND'; end if;
  if v_msg.unsent_at is not null then raise exception 'MESSAGE_UNSENT'; end if;
  if v_msg.created_at < now() - make_interval(mins => cfg_int('message_edit_window_minutes', 15)) then
    raise exception 'EDIT_WINDOW_EXPIRED';
  end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_MESSAGE'; end if;
  v_category := message_violation_category(v_body);
  if v_category is null and contains_link(v_body) then
    v_category := 'link';
  end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (auth.uid(), v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  update messages set body = v_body, edited_at = now() where id = p_message;
  return jsonb_build_object('status', 'edited');
end;
$$;
