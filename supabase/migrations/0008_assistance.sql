-- ZAYA — Assistance dans l'application (CARTE_ECRANS F12, cahier des charges §37 : « assistance et procédures
-- d'incident » avant l'ouverture) et langues de l'interface activables par l'administration (§22.15, §22.16).
--
-- Un membre connecté (même suspendu, pour pouvoir contester) écrit à l'assistance ; il ne lit que ses propres
-- demandes. Les problèmes de sécurité sont prioritaires. Aucune écriture directe : tout passe par des fonctions.

create type support_status as enum ('open', 'in_progress', 'answered', 'closed');

create table support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null
    check (category in ('account', 'verification', 'payment', 'safety', 'translation', 'bug', 'other')),
  message text not null check (char_length(message) between 10 and 2000),
  priority int not null default 2 check (priority between 1 and 3),   -- 1 = sécurité, traitée en premier
  status support_status not null default 'open',
  app_language text,                                                  -- langue de l'interface au moment de la demande
  reply text,
  replied_by uuid references auth.users (id) on delete set null,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index support_tickets_user on support_tickets (user_id, created_at desc);
create index support_tickets_queue on support_tickets (status, priority, created_at);

alter table support_tickets enable row level security;
create policy support_read on support_tickets for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator', 'support']::staff_role[]));
revoke all on support_tickets from anon, authenticated;
grant select on support_tickets to authenticated;

insert into app_config (key, value, description, is_public) values
  ('support_tickets_per_day', '5', 'Nombre maximal de demandes à l''assistance par membre et par 24 h', false),
  ('active_languages', '["fr", "en"]',
   'Langues de l''interface activées (codes ISO). Une langue n''est proposée que si l''application est entièrement traduite (§22.15)',
   true)
on conflict (key) do nothing;

create function create_support_ticket(p_category text, p_message text, p_language text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_text text := trim(coalesce(p_message, ''));
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if p_category is null
     or p_category not in ('account', 'verification', 'payment', 'safety', 'translation', 'bug', 'other') then
    raise exception 'INVALID_CATEGORY';
  end if;
  if char_length(v_text) < 10 then raise exception 'MESSAGE_TOO_SHORT'; end if;
  if (select count(*) from support_tickets
      where user_id = auth.uid() and created_at > now() - interval '24 hours') >= cfg_int('support_tickets_per_day', 5) then
    raise exception 'SUPPORT_RATE_LIMITED';
  end if;
  insert into support_tickets (user_id, category, message, priority, app_language)
  values (auth.uid(), p_category, left(v_text, 2000), case when p_category = 'safety' then 1 else 2 end,
          nullif(trim(coalesce(p_language, '')), ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- Réponse de l'équipe (console d'administration, lot A12) : tracée dans le journal d'audit.
create function admin_answer_support_ticket(p_ticket uuid, p_reply text, p_status support_status) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old support_tickets;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator', 'support']::staff_role[]) then
    raise exception 'FORBIDDEN';
  end if;
  if p_status = 'answered' and coalesce(trim(p_reply), '') = '' then raise exception 'REPLY_REQUIRED'; end if;
  select * into v_old from support_tickets where id = p_ticket for update;
  if not found then raise exception 'TICKET_NOT_FOUND'; end if;
  update support_tickets
    set status = p_status,
        reply = coalesce(nullif(trim(coalesce(p_reply, '')), ''), reply),
        replied_by = case when coalesce(trim(p_reply), '') = '' then replied_by else auth.uid() end,
        replied_at = case when coalesce(trim(p_reply), '') = '' then replied_at else now() end
    where id = p_ticket;
  perform write_audit('support.' || p_status::text, 'support_tickets', p_ticket::text,
                      jsonb_build_object('status', v_old.status), jsonb_build_object('status', p_status), null);
end;
$$;

-- Export des données (§22.9) : la version précédente est conservée telle quelle et complétée par les demandes
-- à l'assistance, sans recopier son contenu.
alter function export_my_data() rename to export_my_data_base;
create function export_my_data() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  return export_my_data_base() || jsonb_build_object(
    'support_requests', coalesce((
      select jsonb_agg(jsonb_build_object('category', t.category, 'message', t.message, 'status', t.status,
                                          'reply', t.reply, 'created_at', t.created_at) order by t.created_at)
      from support_tickets t where t.user_id = auth.uid()), '[]'::jsonb));
end;
$$;

revoke execute on all functions in schema public from public, anon;
revoke execute on function export_my_data_base() from authenticated;
grant execute on function create_support_ticket(text, text, text), admin_answer_support_ticket(uuid, text, support_status),
                          export_my_data()
  to authenticated;
