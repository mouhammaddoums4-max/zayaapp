-- ZAYA — MISE À JOUR : migrations 0055 à 0059 (mises à jour instantanées, libellés des niveaux d'études,
-- floutage automatique des photos, communes de Conakry).
-- FICHIER GÉNÉRÉ depuis supabase/migrations/0055 à 0059 : ne pas le modifier à la main.
--
-- Utilisation : Supabase > SQL Editor > New query, coller TOUT le contenu, puis « Run ».
-- Une seule transaction : en cas d’erreur, rien n’est modifié et le message dit pourquoi.
-- Peut être collée plusieurs fois sans dommage : ce qui est déjà en place est sauté.
-- ORDRE : à passer AVANT les mises à jour 0060 à 0065 et 0066 à 0071 (elles s'appuient sur member_signals).
-- Après cette mise à jour : signaux instantanés (likes, matchs, messages, photos, Premium) ; libellés « Collège »,
-- « Baccalauréat », « Sans diplôme » corrects partout ; huit communes de Conakry ajoutées ; floutage automatique
-- prêt (il ne démarre qu'avec les secrets zaya_project_url et zaya_blur_token dans Vault, voir 0057).

begin;

-- Vérifications préalables.
do $$
begin
  if to_regclass('public.education_levels') is null or to_regproc('public.contains_link') is null then
    raise exception 'Il manque les migrations 0050 à 0052 (sécurité, liens, niveaux d''études) : appliquez-les d''abord.';
  end if;
end $$;

-- ═════════════════════════════ 0055_signaux_instantanes.sql
-- Sautée si la table member_signals existe déjà (migration appliquée plus tôt).
do $maj$
begin
  if to_regclass('public.member_signals') is not null then
    raise notice '0055 (signaux instantanés) : déjà appliquée, rien à faire.';
    return;
  end if;
  execute $sql$
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
$sql$;
end $maj$;

-- ═════════════════════════════ 0056_libelles_etudes_et_profils.sql
-- ZAYA — Niveaux d'études : libellés rétablis et recopiés dans les profils (suite de 0052).
--
-- Cause : la 0052 a été appliquée sur la préproduction depuis PowerShell 5.1, qui lit les fichiers dans l'encodage
-- Windows : les accents sont arrivés abîmés (« CollÃ¨ge », « BaccalaurÃ©at », « Sans diplÃ´me »). La 0058 répare
-- deux libellés ; cette migration rétablit les neuf, et recopie le bon libellé dans profiles.education_level,
-- que le déclencheur de 0052 avait rempli avec le texte abîmé (fiches des profils d'essai).
-- Sans effet sur une base saine. Les accents sont écrits en échappements Unicode, insensibles à l'encodage du fichier.

update education_levels l
set label_fr = v.label_fr, label_en = v.label_en
from (values
  ('none', U&'Sans dipl\00F4me', 'No diploma'),
  ('primary', 'Primaire (CEPE)', 'Primary school'),
  ('middle', U&'Coll\00E8ge (BEPC)', 'Middle school'),
  ('bac', U&'Baccalaur\00E9at', 'High school diploma'),
  ('vocational', 'Formation professionnelle', 'Vocational training'),
  ('bac2', 'Bac +2 (BTS, DUT)', 'Two-year degree'),
  ('licence', 'Licence (Bac +3)', 'Bachelor''s degree'),
  ('master', 'Master (Bac +5)', 'Master''s degree'),
  ('doctorate', 'Doctorat', 'Doctorate')
) as v (key, label_fr, label_en)
where l.key = v.key and (l.label_fr is distinct from v.label_fr or l.label_en is distinct from v.label_en);

-- Le déclencheur de 0052 recopie le libellé quand education_key est réécrit (même valeur).
update profiles p
set education_key = p.education_key
from education_levels l
where l.key = p.education_key and p.education_level is distinct from l.label_fr;

-- ═════════════════════════════ 0057_floutage_automatique.sql
-- Sautée si la table photo_blur_jobs existe déjà (migration appliquée plus tôt).
do $maj$
begin
  if to_regclass('public.photo_blur_jobs') is not null then
    raise notice '0057 (floutage automatique) : déjà appliquée, rien à faire.';
    return;
  end if;
  execute $sql$
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
$sql$;
end $maj$;

-- ═════════════════════════════ 0058_reparer_libelles_niveaux_etudes.sql
-- Répare les deux libellés français avec accents de la liste des niveaux d'études,
-- uniquement si leur valeur enregistrée contient un marqueur d'encodage abîmé.
update education_levels
set label_fr = case key
  when 'middle' then U&'Coll\00E8ge (BEPC)'
  when 'bac' then U&'Baccalaur\00E9at'
end
where key in ('middle', 'bac')
  and (
    position(U&'\FFFD' in label_fr) > 0
    or position(U&'\00C3' in label_fr) > 0
    or position('?' in label_fr) > 0
  );

-- ═════════════════════════════ 0059_communes_conakry_actualisees.sql
-- Ajoute les huit communes de Conakry absentes du référentiel initial.
-- Liste actualisée selon l'arrêté A/2026/872/MATD/CAB/SGG du 13 octobre 2026.
-- Le pays doit exister : sur une base vide, le seed crée la Guinée puis ses villes.
insert into cities (country_code, name)
select v.country_code, v.name
from countries c
join (values
  ('GN', U&'Conakry \2014 Gbessia'),
  ('GN', U&'Conakry \2014 Kagb\00E9len'),
  ('GN', U&'Conakry \2014 Lambanyi'),
  ('GN', U&'Conakry \2014 Man\00E9ah'),
  ('GN', U&'Conakry \2014 Sanoyah'),
  ('GN', U&'Conakry \2014 Sonfonia'),
  ('GN', U&'Conakry \2014 Tombolia'),
  ('GN', U&'Conakry \2014 Kassa')
) as v(country_code, name) on v.country_code = c.code
on conflict (country_code, name) do nothing;

commit;
