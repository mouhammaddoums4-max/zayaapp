-- ZAYA — Floutage automatique des photos (demande du propriétaire du 18/11/2026 : « toute modification ou mise à
-- jour doit s'effectuer automatiquement »).
--
-- Constat (18/11/2026, préproduction) : les 3 photos d'un membre vérifié n'avaient pas de version floutée. La
-- fabrication déclenchée par l'application juste après l'envoi (fonction Edge blur-photos) avait échoué une fois et
-- rien ne la relançait : un visiteur Gratuit ne voyait rien à la place des photos 2 et 3 (photo_access = blurred,
-- chemin flouté nul).
--
-- Correction (sans toucher à la modération, réglée par 0032) :
--   • photo_blur_jobs : échecs de fabrication par photo, réservé au serveur. Après un échec, nouvel essai 5 min plus
--     tard, puis 10, 15… ; au-delà de blur_max_attempts essais, la photo n'est plus relancée automatiquement (un
--     fichier abîmé ne fait pas tourner la fonction en boucle).
--   • blur_backlog(n, âge) : photos sans version floutée à fabriquer ; blur_job_failed(photo, erreur) : trace un
--     échec. Les deux sont réservées au serveur (service_role), appelées par la fonction Edge.
--   • blur_photos_tick() : chaque minute (pg_cron), s'il reste une photo sans version floutée depuis plus d'une
--     minute, appelle la fonction Edge blur-photos (pg_net), avec un jeton dédié lu dans le coffre de Supabase :
--     secrets « zaya_project_url » et « zaya_blur_token » (INSTALLATION_SUPABASE.md). Sans ces secrets, ou sans
--     pg_cron / pg_net (tests PGlite), elle ne fait rien.

create table photo_blur_jobs (
  photo_id uuid primary key references profile_photos (id) on delete cascade,
  attempts int not null default 0,
  last_error text,
  last_attempt_at timestamptz not null default now()
);
alter table photo_blur_jobs enable row level security; -- aucune règle : invisible pour les membres
revoke all on photo_blur_jobs from public, anon, authenticated;
grant select, insert, update, delete on photo_blur_jobs to service_role;

insert into app_config (key, value, description, is_public) values
  ('blur_max_attempts', '5',
   'Essais de fabrication automatique de la version floutée d''une photo avant abandon (relance : 5 min, 10 min, …)',
   false)
on conflict (key) do nothing;

-- Photos à flouter : sans version floutée, envoyées depuis au moins p_min_age_seconds (laisse à l'application le
-- temps de la demander elle-même), sans trop d'échecs, et pas en attente d'un nouvel essai.
create function blur_backlog(p_limit int, p_min_age_seconds int)
returns table (id uuid, user_id uuid, storage_path text)
language sql stable security definer set search_path = public as $$
  select ph.id, ph.user_id, ph.storage_path
  from profile_photos ph
  left join photo_blur_jobs j on j.photo_id = ph.id
  where ph.blur_path is null
    and ph.created_at <= now() - make_interval(secs => greatest(coalesce(p_min_age_seconds, 0), 0))
    and (j.photo_id is null
         or (j.attempts < cfg_int('blur_max_attempts', 5)
             and j.last_attempt_at <= now() - make_interval(mins => 5 * j.attempts)))
  order by coalesce(j.attempts, 0), ph.created_at, ph.id
  limit least(greatest(coalesce(p_limit, 1), 1), 20);
$$;

create function blur_job_failed(p_photo uuid, p_error text) returns void
language sql security definer set search_path = public as $$
  insert into photo_blur_jobs (photo_id, attempts, last_error, last_attempt_at)
  select p_photo, 1, left(coalesce(p_error, ''), 500), now()
  where exists (select 1 from profile_photos where id = p_photo)
  on conflict (photo_id) do update
    set attempts = photo_blur_jobs.attempts + 1, last_error = excluded.last_error, last_attempt_at = now();
$$;

-- Appel planifié. Les objets de pg_net et du coffre sont appelés par « execute » : la fonction se crée aussi sur une
-- base qui ne les a pas (PGlite), et n'y fait rien.
create function blur_photos_tick() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_token text;
begin
  if not exists (select 1 from blur_backlog(1, 60)) then return 0; end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                 where n.nspname = 'net' and p.proname = 'http_post')
     or to_regclass('vault.decrypted_secrets') is null then
    return 0;
  end if;
  execute $q$select (select decrypted_secret from vault.decrypted_secrets where name = 'zaya_project_url'),
                    (select decrypted_secret from vault.decrypted_secrets where name = 'zaya_blur_token')$q$
    into v_url, v_token;
  if coalesce(v_url, '') = '' or coalesce(v_token, '') = '' then return 0; end if;
  execute $q$select net.http_post(url := $1, body := '{}'::jsonb,
                                  headers := jsonb_build_object('Content-Type', 'application/json', 'x-zaya-cron', $2),
                                  timeout_milliseconds := 30000)$q$
    using rtrim(v_url, '/') || '/functions/v1/blur-photos', v_token;
  return 1;
end;
$$;

revoke execute on function blur_backlog(int, int) from public, anon, authenticated;
revoke execute on function blur_job_failed(uuid, text) from public, anon, authenticated;
revoke execute on function blur_photos_tick() from public, anon, authenticated;
grant execute on function blur_backlog(int, int) to service_role;
grant execute on function blur_job_failed(uuid, text) to service_role;

-- Tâche planifiée : seulement là où pg_cron et pg_net existent (Supabase). Reprogrammer sous le même nom remplace
-- la tâche existante : la migration peut être rejouée.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and exists (select 1 from pg_available_extensions where name = 'pg_net') then
    if exists (select 1 from pg_namespace where nspname = 'extensions') then
      execute 'create extension if not exists pg_net with schema extensions';
    else
      execute 'create extension if not exists pg_net';
    end if;
    execute 'create extension if not exists pg_cron';
    execute $q$select cron.schedule('zaya-floutage-automatique', '* * * * *', 'select public.blur_photos_tick()')$q$;
  end if;
end $$;
