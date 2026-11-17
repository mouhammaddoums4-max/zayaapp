-- ZAYA — Communauté, phase 1 (CDC V2.3 §2 et §4, V6.0 §26) : communautés thématiques, publications texte,
-- commentaires, réactions, enregistrements, masquage, signalement et modération.
-- L'application ne lit jamais directement les publications : tout passe par des fonctions serveur qui
-- appliquent les blocages, les contenus masqués ou retirés et les règles de publication.
-- Identité affichée : nom de profil, initiale et badge vérifié. Aucune photo, pour ne pas contourner
-- les règles de visibilité des photos du profil de rencontre.

create type post_kind as enum ('question', 'advice', 'experience');
create type content_status as enum ('published', 'deleted', 'removed');
create type community_notif_level as enum ('all', 'important', 'events', 'none');

create table communities (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null,
  icon text not null default 'groups',
  position smallint not null default 0,
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  created_by uuid,
  created_at timestamptz not null default now()
);

create table community_members (
  community_id uuid not null references communities (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'moderator', 'admin')),
  notif_level community_notif_level not null default 'important',
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index community_members_user_idx on community_members (user_id);

create table posts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities (id),
  author_id uuid not null references profiles (id) on delete cascade,
  kind post_kind not null default 'question',
  body text not null check (char_length(body) between 1 and 2000),
  comments_enabled boolean not null default true,
  status content_status not null default 'published',
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  removed_by uuid,
  removal_reason text
);
create index posts_feed_idx on posts (community_id, status, created_at desc);
create index posts_author_idx on posts (author_id, created_at desc);

create table post_revisions (            -- historique des modifications (V6.0 §26.1), lecture : modération
  id bigint generated always as identity primary key,
  post_id uuid not null references posts (id) on delete cascade,
  previous_body text not null,
  edited_by uuid not null,
  edited_at timestamptz not null default now()
);

create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts (id) on delete cascade,
  author_id uuid not null references profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  status content_status not null default 'published',
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  removed_by uuid,
  removal_reason text
);
create index comments_post_idx on comments (post_id, created_at);
create index comments_author_idx on comments (author_id, created_at desc);

create table post_reactions (
  post_id uuid not null references posts (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table saved_posts (
  user_id uuid not null references profiles (id) on delete cascade,
  post_id uuid not null references posts (id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table post_hidden (               -- « Masquer » : retiré de mon fil uniquement
  user_id uuid not null references profiles (id) on delete cascade,
  post_id uuid not null references posts (id) on delete cascade,
  primary key (user_id, post_id)
);

create table comment_hidden (
  user_id uuid not null references profiles (id) on delete cascade,
  comment_id uuid not null references comments (id) on delete cascade,
  primary key (user_id, comment_id)
);

-- Signalement des contenus communautaires
alter table reports add column post_id uuid references posts (id) on delete set null;
alter table reports add column comment_id uuid references comments (id) on delete set null;
alter table reports drop constraint reports_context_check;
alter table reports add constraint reports_context_check
  check (context in ('profile', 'conversation', 'photo', 'post', 'comment'));

-- Tentatives bloquées : on distingue la messagerie et la communauté (statistiques de modération)
alter table message_violations add column context text not null default 'message'
  check (context in ('message', 'post', 'comment'));

-- ───────────────────────────── Règles de contenu
-- Coordonnées : numéro de téléphone, e-mail, lien de messagerie externe. Les montants suivis d'une devise
-- (« 5 000 000 GNF », « 25 000 000 de francs ») ne sont pas des numéros. La détection n'est pas parfaite :
-- elle complète la modération humaine, elle ne la remplace pas (CDC §34.3).
create function contains_contact_details(p_body text) returns boolean
language sql immutable as $$
  select p_body ~* '[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}'
      or p_body ~* '(wa\.me|whatsapp\.com|t\.me|telegram\.me|m\.me)/'
      or regexp_replace(
           p_body,
           '\d([ .,-]?\d)*\s*(de\s+|d'')?(gnf|fg|francs?|fcfa|cfa|euros?|eur|usd|dollars?|€|\$)',
           ' ', 'gi')
         ~ '(\+|00)?\d([ .-]?\d){7,14}';
$$;

create function community_violation(p_body text) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(message_violation_category(p_body),
                  case when contains_contact_details(p_body) then 'contact_details' end);
$$;

create function report_priority_for(p_reason text) returns report_priority
language sql immutable as $$
  select case
    when p_reason in ('threat', 'blackmail', 'minor', 'exploitation', 'non_consensual_image') then 'critical'::report_priority
    when p_reason in ('scam', 'money_request', 'harassment', 'impersonation') then 'high'::report_priority
    when p_reason in ('spam', 'other') then 'low'::report_priority
    else 'normal'::report_priority end;
$$;

-- Contrôle commun : module ouvert, profil utilisable ; pour écrire, profil vérifié et aucune restriction en cours.
create function community_guard(p_write boolean) returns profiles
language plpgsql stable security definer set search_path = public as $$
declare
  v_me profiles;
begin
  if not cfg_bool('community_enabled', false) then raise exception 'COMMUNITY_DISABLED'; end if;
  select * into v_me from profiles where id = auth.uid();
  if not found or v_me.status in ('draft', 'suspended', 'banned', 'deleted') then
    raise exception 'PROFILE_NOT_ACTIVE';
  end if;
  if p_write then
    if exists (select 1 from sanctions s
               where s.user_id = v_me.id and s.kind in ('restriction', 'suspension', 'ban')
                 and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())) then
      raise exception 'ACCOUNT_RESTRICTED';
    end if;
    if cfg_bool('community_post_requires_verification', true) and v_me.verification_status <> 'approved' then
      raise exception 'VERIFICATION_REQUIRED';
    end if;
  end if;
  return v_me;
end;
$$;

-- Une publication est visible si elle est publiée, dans une communauté ouverte, d'un auteur dont le profil
-- n'est ni masqué ni sanctionné, sans blocage entre les deux membres et sans masquage par le lecteur.
create function post_visible(p posts, p_viewer uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p.status = 'published'
     and exists (select 1 from communities c where c.id = p.community_id and c.status = 'active')
     and (p.author_id = p_viewer
          or exists (select 1 from profiles a where a.id = p.author_id and a.status in ('active', 'paused')))
     and not blocked_between(p_viewer, p.author_id)
     and not exists (select 1 from post_hidden h where h.post_id = p.id and h.user_id = p_viewer);
$$;

create function comment_visible(x comments, p_viewer uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select x.status = 'published'
     and (x.author_id = p_viewer
          or exists (select 1 from profiles a where a.id = x.author_id and a.status in ('active', 'paused')))
     and not blocked_between(p_viewer, x.author_id)
     and not exists (select 1 from comment_hidden h where h.comment_id = x.id and h.user_id = p_viewer);
$$;

-- Requête commune du fil, du détail et des publications enregistrées (usage interne).
create function post_query(p_viewer uuid, p_post uuid, p_community uuid, p_joined_only boolean,
                           p_saved_only boolean, p_before timestamptz, p_limit int)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language sql stable security definer set search_path = public as $$
  select p.id, p.community_id, c.name, p.author_id, a.display_name, a.verification_status = 'approved',
         p.kind, p.body, p.comments_enabled, p.created_at, p.edited_at is not null,
         (select count(*)::int from post_reactions r where r.post_id = p.id),
         (select count(*)::int from comments x where x.post_id = p.id and comment_visible(x, p_viewer)),
         exists (select 1 from post_reactions r where r.post_id = p.id and r.user_id = p_viewer),
         exists (select 1 from saved_posts s where s.post_id = p.id and s.user_id = p_viewer),
         p.author_id = p_viewer
  from posts p
  join communities c on c.id = p.community_id
  join profiles a on a.id = p.author_id
  where (p_post is null or p.id = p_post)
    and (p_community is null or p.community_id = p_community)
    and (not p_joined_only
         or exists (select 1 from community_members m where m.community_id = p.community_id and m.user_id = p_viewer))
    and (not p_saved_only
         or exists (select 1 from saved_posts s2 where s2.post_id = p.id and s2.user_id = p_viewer))
    and (p_before is null or p.created_at < p_before)
    and post_visible(p, p_viewer)
  order by p.created_at desc
  limit least(greatest(p_limit, 1), 50);
$$;

-- ───────────────────────────── Communautés
create function list_communities()
returns table (community_id uuid, slug text, name text, description text, icon text,
               member_count int, joined boolean, notif_level community_notif_level)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
begin
  return query
    select c.id, c.slug, c.name, c.description, c.icon,
           (select count(*)::int from community_members m where m.community_id = c.id),
           m.user_id is not null, m.notif_level
    from communities c
    left join community_members m on m.community_id = c.id and m.user_id = v_me.id
    where c.status = 'active'
    order by c.position, c.name;
end;
$$;

create function join_community(p_community uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(false);
begin
  if not exists (select 1 from communities where id = p_community and status = 'active') then
    raise exception 'COMMUNITY_NOT_FOUND';
  end if;
  insert into community_members (community_id, user_id) values (p_community, v_me.id) on conflict do nothing;
end;
$$;

create function leave_community(p_community uuid) returns void
language sql security definer set search_path = public as $$
  delete from community_members where community_id = p_community and user_id = auth.uid();
$$;

create function set_community_notifications(p_community uuid, p_level community_notif_level) returns void
language plpgsql security definer set search_path = public as $$
begin
  update community_members set notif_level = p_level where community_id = p_community and user_id = auth.uid();
  if not found then raise exception 'NOT_A_MEMBER'; end if;
end;
$$;

-- ───────────────────────────── Lecture
-- Fil « Pour vous » : les communautés suivies ; si le membre n'en suit aucune, toutes les communautés.
create function community_feed(p_community uuid default null, p_before timestamptz default null, p_limit int default 20)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
  v_joined_only boolean;
begin
  v_joined_only := p_community is null and exists (select 1 from community_members m where m.user_id = v_me.id);
  return query select * from post_query(v_me.id, null, p_community, v_joined_only, false, p_before, p_limit);
end;
$$;

create function community_post(p_post uuid)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
begin
  return query select * from post_query(v_me.id, p_post, null, false, false, null, 1);
  if not found then raise exception 'POST_NOT_FOUND'; end if;
end;
$$;

create function saved_community_posts(p_before timestamptz default null, p_limit int default 20)
returns table (
  post_id uuid, community_id uuid, community_name text, author_id uuid, author_name text, author_verified boolean,
  kind post_kind, body text, comments_enabled boolean, created_at timestamptz, edited boolean,
  reaction_count int, comment_count int, reacted boolean, saved boolean, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
begin
  return query select * from post_query(v_me.id, null, null, false, true, p_before, p_limit);
end;
$$;

create function post_comments(p_post uuid)
returns table (comment_id uuid, author_id uuid, author_name text, author_verified boolean, body text,
               created_at timestamptz, edited boolean, is_mine boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_me profiles := community_guard(false);
  v_post posts;
begin
  select * into v_post from posts p where p.id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  return query
    select x.id, x.author_id, a.display_name, a.verification_status = 'approved', x.body, x.created_at,
           x.edited_at is not null, x.author_id = v_me.id
    from comments x
    join profiles a on a.id = x.author_id
    where x.post_id = p_post and comment_visible(x, v_me.id)
    order by x.created_at;
end;
$$;

-- ───────────────────────────── Publications
create function create_post(p_community uuid, p_kind post_kind, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
  v_id uuid;
begin
  if not exists (select 1 from communities where id = p_community and status = 'active') then
    raise exception 'COMMUNITY_NOT_FOUND';
  end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_POST'; end if;
  if (select count(*) from posts where author_id = v_me.id and created_at > now() - interval '1 day')
     >= cfg_int('community_posts_per_day', 5) then
    raise exception 'RATE_LIMITED';
  end if;
  -- Filtre avant publication : un contenu non conforme n'est jamais enregistré ni diffusé.
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'post');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  -- Publier dans une communauté revient à la suivre.
  insert into community_members (community_id, user_id) values (p_community, v_me.id) on conflict do nothing;
  insert into posts (community_id, author_id, kind, body) values (p_community, v_me.id, p_kind, v_body)
    returning id into v_id;
  return jsonb_build_object('status', 'published', 'id', v_id);
end;
$$;

create function edit_post(p_post uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_post posts;
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
begin
  select * into v_post from posts where id = p_post and author_id = v_me.id and status = 'published' for update;
  if not found then raise exception 'POST_NOT_FOUND'; end if;
  if v_body = '' or char_length(v_body) > 2000 then raise exception 'INVALID_POST'; end if;
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'post');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  if v_body <> v_post.body then
    insert into post_revisions (post_id, previous_body, edited_by) values (p_post, v_post.body, v_me.id);
    update posts set body = v_body, edited_at = now() where id = p_post;
  end if;
  return jsonb_build_object('status', 'published', 'id', p_post);
end;
$$;

-- Suppression par l'auteur : retirée pour tous ; conservée un temps limité pour la modération (V6.0 §26.1).
create function delete_post(p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update posts set status = 'deleted', deleted_at = now()
    where id = p_post and author_id = auth.uid() and status = 'published';
  if not found then raise exception 'POST_NOT_FOUND'; end if;
end;
$$;

create function set_post_comments(p_post uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  update posts set comments_enabled = p_enabled
    where id = p_post and author_id = auth.uid() and status = 'published';
  if not found then raise exception 'POST_NOT_FOUND'; end if;
end;
$$;

create function react_to_post(p_post uuid, p_on boolean) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(false);
  v_post posts;
begin
  select * into v_post from posts where id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  if p_on then
    insert into post_reactions (post_id, user_id) values (p_post, v_me.id) on conflict do nothing;
  else
    delete from post_reactions where post_id = p_post and user_id = v_me.id;
  end if;
  return (select count(*)::int from post_reactions where post_id = p_post);
end;
$$;

create function save_post(p_post uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(false);
  v_post posts;
begin
  if not p_on then
    delete from saved_posts where post_id = p_post and user_id = v_me.id;
    return;
  end if;
  select * into v_post from posts where id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  insert into saved_posts (user_id, post_id) values (v_me.id, p_post) on conflict do nothing;
end;
$$;

create function hide_post(p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not exists (select 1 from posts where id = p_post) then raise exception 'POST_NOT_FOUND'; end if;
  insert into post_hidden (user_id, post_id) values (auth.uid(), p_post) on conflict do nothing;
end;
$$;

-- ───────────────────────────── Commentaires
create function add_comment(p_post uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_post posts;
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
  v_id uuid;
begin
  select * into v_post from posts where id = p_post;
  if not found or not post_visible(v_post, v_me.id) then raise exception 'POST_NOT_FOUND'; end if;
  if not v_post.comments_enabled then raise exception 'COMMENTS_DISABLED'; end if;
  if v_body = '' or char_length(v_body) > 1000 then raise exception 'INVALID_COMMENT'; end if;
  if (select count(*) from comments where author_id = v_me.id and created_at > now() - interval '1 hour')
     >= cfg_int('community_comments_per_hour', 20) then
    raise exception 'RATE_LIMITED';
  end if;
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'comment');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  insert into comments (post_id, author_id, body) values (p_post, v_me.id, v_body) returning id into v_id;
  return jsonb_build_object('status', 'published', 'id', v_id);
end;
$$;

create function edit_comment(p_comment uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me profiles := community_guard(true);
  v_body text := trim(coalesce(p_body, ''));
  v_category text;
begin
  if not exists (select 1 from comments where id = p_comment and author_id = v_me.id and status = 'published') then
    raise exception 'COMMENT_NOT_FOUND';
  end if;
  if v_body = '' or char_length(v_body) > 1000 then raise exception 'INVALID_COMMENT'; end if;
  v_category := community_violation(v_body);
  if v_category is not null then
    insert into message_violations (user_id, category, context) values (v_me.id, v_category, 'comment');
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  update comments set body = v_body, edited_at = now() where id = p_comment;
  return jsonb_build_object('status', 'published', 'id', p_comment);
end;
$$;

create function delete_comment(p_comment uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update comments set status = 'deleted', deleted_at = now()
    where id = p_comment and author_id = auth.uid() and status = 'published';
  if not found then raise exception 'COMMENT_NOT_FOUND'; end if;
end;
$$;

-- ───────────────────────────── Signalement : le contenu signalé disparaît aussitôt pour la personne qui signale
create function report_post(p_post uuid, p_reason text, p_details text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_post posts;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_post from posts where id = p_post;
  if not found or v_post.author_id = auth.uid() then raise exception 'INVALID_TARGET'; end if;
  insert into reports (reporter, reported_user, context, reason, details, post_id, priority)
    values (auth.uid(), v_post.author_id, 'post', p_reason, p_details, p_post, report_priority_for(p_reason))
    returning id into v_id;
  insert into post_hidden (user_id, post_id) values (auth.uid(), p_post) on conflict do nothing;
  return v_id;
end;
$$;

create function report_comment(p_comment uuid, p_reason text, p_details text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_comment comments;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select * into v_comment from comments where id = p_comment;
  if not found or v_comment.author_id = auth.uid() then raise exception 'INVALID_TARGET'; end if;
  insert into reports (reporter, reported_user, context, reason, details, post_id, comment_id, priority)
    values (auth.uid(), v_comment.author_id, 'comment', p_reason, p_details, v_comment.post_id, p_comment,
            report_priority_for(p_reason))
    returning id into v_id;
  insert into comment_hidden (user_id, comment_id) values (auth.uid(), p_comment) on conflict do nothing;
  return v_id;
end;
$$;

-- ───────────────────────────── Modération (retirer, restaurer), tracée dans le journal d'audit
create function admin_moderate_post(p_post uuid, p_action text, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_post posts;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_post from posts where id = p_post for update;
  if not found then raise exception 'POST_NOT_FOUND'; end if;
  if p_action = 'remove' and v_post.status = 'published' then
    update posts set status = 'removed', removed_by = auth.uid(), removal_reason = p_reason where id = p_post;
  elsif p_action = 'restore' and v_post.status = 'removed' then
    update posts set status = 'published', removed_by = null, removal_reason = null where id = p_post;
  else
    raise exception 'INVALID_ACTION';
  end if;
  perform write_audit('post.' || p_action, 'posts', p_post::text,
                      jsonb_build_object('status', v_post.status),
                      jsonb_build_object('status', case when p_action = 'remove' then 'removed' else 'published' end),
                      p_reason);
end;
$$;

create function admin_moderate_comment(p_comment uuid, p_action text, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_comment comments;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_comment from comments where id = p_comment for update;
  if not found then raise exception 'COMMENT_NOT_FOUND'; end if;
  if p_action = 'remove' and v_comment.status = 'published' then
    update comments set status = 'removed', removed_by = auth.uid(), removal_reason = p_reason where id = p_comment;
  elsif p_action = 'restore' and v_comment.status = 'removed' then
    update comments set status = 'published', removed_by = null, removal_reason = null where id = p_comment;
  else
    raise exception 'INVALID_ACTION';
  end if;
  perform write_audit('comment.' || p_action, 'comments', p_comment::text,
                      jsonb_build_object('status', v_comment.status),
                      jsonb_build_object('status', case when p_action = 'remove' then 'removed' else 'published' end),
                      p_reason);
end;
$$;

-- ───────────────────────────── Accès
alter table communities enable row level security;
alter table community_members enable row level security;
alter table posts enable row level security;
alter table post_revisions enable row level security;
alter table comments enable row level security;
alter table post_reactions enable row level security;
alter table saved_posts enable row level security;
alter table post_hidden enable row level security;
alter table comment_hidden enable row level security;

create policy communities_read on communities for select to authenticated
  using (status = 'active' or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy communities_admin on communities for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy members_own on community_members for select to authenticated using (user_id = auth.uid());
create policy saved_own on saved_posts for select to authenticated using (user_id = auth.uid());
create policy post_hidden_own on post_hidden for select to authenticated using (user_id = auth.uid());
create policy comment_hidden_own on comment_hidden for select to authenticated using (user_id = auth.uid());
-- Publications, commentaires, réactions, historique : lecture directe réservée à la modération.
create policy posts_staff on posts for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy comments_staff on comments for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy reactions_staff on post_reactions for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy revisions_staff on post_revisions for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

revoke all on communities, community_members, posts, post_revisions, comments, post_reactions,
              saved_posts, post_hidden, comment_hidden from anon;
grant select on communities, community_members, posts, post_revisions, comments, post_reactions,
                saved_posts, post_hidden, comment_hidden to authenticated;

-- Fonctions : aucune pour anon ; seules les fonctions de l'API sont ouvertes aux membres connectés.
revoke execute on all functions in schema public from public, anon;
revoke execute on function contains_contact_details(text), community_violation(text), report_priority_for(text),
                           community_guard(boolean), post_visible(posts, uuid), comment_visible(comments, uuid),
                           post_query(uuid, uuid, uuid, boolean, boolean, timestamptz, int)
  from authenticated;
grant execute on function list_communities(), join_community(uuid), leave_community(uuid),
                          set_community_notifications(uuid, community_notif_level),
                          community_feed(uuid, timestamptz, int), community_post(uuid),
                          saved_community_posts(timestamptz, int), post_comments(uuid),
                          create_post(uuid, post_kind, text), edit_post(uuid, text), delete_post(uuid),
                          set_post_comments(uuid, boolean), react_to_post(uuid, boolean), save_post(uuid, boolean),
                          hide_post(uuid), add_comment(uuid, text), edit_comment(uuid, text), delete_comment(uuid),
                          report_post(uuid, text, text), report_comment(uuid, text, text),
                          admin_moderate_post(uuid, text, text), admin_moderate_comment(uuid, text, text)
  to authenticated;

-- ───────────────────────────── Export des données : ajout des contenus communautaires du membre (§22.9)
create or replace function export_my_data() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) from profiles p where p.id = v_me),
    'sensitive', (select to_jsonb(s) - 'user_id' from profile_sensitive s where s.user_id = v_me),
    'discovery_preferences', (select to_jsonb(d) - 'user_id' from discovery_preferences d where d.user_id = v_me),
    'consents', coalesce((
      select jsonb_agg(jsonb_build_object('kind', c.kind, 'granted', c.granted,
                                          'document_version', c.document_version, 'created_at', c.created_at) order by c.id)
      from consents c where c.user_id = v_me), '[]'::jsonb),
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object('visibility', ph.visibility, 'moderation', ph.moderation,
                                          'created_at', ph.created_at) order by ph.position)
      from profile_photos ph where ph.user_id = v_me), '[]'::jsonb),
    'likes_sent', coalesce((
      select jsonb_agg(jsonb_build_object('status', i.status, 'created_at', i.created_at) order by i.created_at)
      from interests i where i.from_user = v_me), '[]'::jsonb),
    'matches', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', m.created_at, 'ended_at', m.ended_at) order by m.created_at)
      from matches m where v_me in (m.user_a, m.user_b)), '[]'::jsonb),
    'messages_sent', coalesce((
      select jsonb_agg(jsonb_build_object('body', x.body, 'created_at', x.created_at) order by x.created_at)
      from messages x where x.sender_id = v_me and x.unsent_at is null), '[]'::jsonb),
    'community_posts', coalesce((
      select jsonb_agg(jsonb_build_object('community', c.name, 'kind', p.kind, 'body', p.body, 'status', p.status,
                                          'created_at', p.created_at, 'edited_at', p.edited_at) order by p.created_at)
      from posts p join communities c on c.id = p.community_id where p.author_id = v_me), '[]'::jsonb),
    'community_comments', coalesce((
      select jsonb_agg(jsonb_build_object('body', x.body, 'status', x.status, 'created_at', x.created_at)
                       order by x.created_at)
      from comments x where x.author_id = v_me), '[]'::jsonb),
    'communities_followed', coalesce((
      select jsonb_agg(c.name order by c.position)
      from community_members m join communities c on c.id = m.community_id where m.user_id = v_me), '[]'::jsonb),
    'reports_made', coalesce((
      select jsonb_agg(jsonb_build_object('context', r.context, 'reason', r.reason, 'status', r.status,
                                          'created_at', r.created_at) order by r.created_at)
      from reports r where r.reporter = v_me), '[]'::jsonb),
    'premium', coalesce((
      select jsonb_agg(jsonb_build_object('source', g.source, 'status', g.status,
                                          'starts_at', g.starts_at, 'ends_at', g.ends_at) order by g.starts_at)
      from premium_grants g where g.user_id = v_me), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object('reference', t.reference, 'service', t.service, 'amount', t.amount,
                                          'currency', t.currency, 'method', t.method, 'status', t.status,
                                          'created_at', t.created_at) order by t.created_at)
      from transactions t where t.user_id = v_me), '[]'::jsonb)
  );
end;
$$;
