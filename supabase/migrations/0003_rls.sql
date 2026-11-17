-- ZAYA — Lot A : contrôle d'accès au niveau des lignes.
-- Principe : tout est fermé par défaut ; le rôle `anon` n'a accès qu'aux référentiels publics.
-- Les écritures métier (likes, matchs, messages, Premium…) passent par les fonctions de 0002.

alter table countries enable row level security;
alter table cities enable row level security;
alter table ethnic_groups enable row level security;
alter table professions enable row level security;
alter table app_config enable row level security;
alter table legal_documents enable row level security;
alter table moderation_terms enable row level security;
alter table profiles enable row level security;
alter table profile_sensitive enable row level security;
alter table discovery_preferences enable row level security;
alter table consents enable row level security;
alter table profile_photos enable row level security;
alter table verification_requests enable row level security;
alter table interests enable row level security;
alter table passes enable row level security;
alter table matches enable row level security;
alter table messages enable row level security;
alter table message_hidden enable row level security;
alter table message_violations enable row level security;
alter table blocks enable row level security;
alter table reports enable row level security;
alter table profile_views enable row level security;
alter table sanctions enable row level security;
alter table transactions enable row level security;
alter table transaction_events enable row level security;
alter table premium_grants enable row level security;
alter table premium_events enable row level security;
alter table staff_roles enable row level security;
alter table audit_log enable row level security;
alter table sms_log enable row level security;
alter table account_deletion_requests enable row level security;

-- ───────────────────────────── Référentiels (lecture publique, écriture staff)
create policy countries_read on countries for select to anon, authenticated using (true);
create policy cities_read on cities for select to anon, authenticated using (enabled);
create policy professions_read on professions for select to anon, authenticated using (active);
create policy legal_read on legal_documents for select to anon, authenticated using (true);
create policy ethnic_read on ethnic_groups for select to authenticated using (active);
create policy config_read on app_config for select to anon, authenticated using (is_public);

create policy countries_admin on countries for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy cities_admin on cities for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy ethnic_admin on ethnic_groups for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy professions_admin on professions for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy config_admin on app_config for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'tech']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'tech']::staff_role[]));
create policy legal_admin on legal_documents for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
create policy terms_admin on moderation_terms for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

-- ───────────────────────────── Profil : le membre ne lit directement que SA ligne.
-- Les autres profils ne sont accessibles que via discovery_feed() / get_profile() qui n'exposent que les champs publics.
create policy profiles_select_own on profiles for select to authenticated
  using (id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator', 'support']::staff_role[]));
create policy profiles_insert_own on profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Données sensibles : propriétaire uniquement (pas même le staff en lecture directe)
create policy sensitive_own on profile_sensitive for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy prefs_own on discovery_preferences for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy consents_select_own on consents for select to authenticated using (user_id = auth.uid());
create policy consents_insert_own on consents for insert to authenticated with check (user_id = auth.uid());

create policy photos_select_own on profile_photos for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy photos_insert_own on profile_photos for insert to authenticated with check (user_id = auth.uid());
create policy photos_update_own on profile_photos for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy photos_delete_own on profile_photos for delete to authenticated using (user_id = auth.uid());

create policy verif_select on verification_requests for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

-- ───────────────────────────── Interactions (lecture seule ; écriture par fonctions)
-- Un membre voit les intérêts qu'il a envoyés. Les intérêts reçus passent par received_interests() (Premium).
create policy interests_select_sent on interests for select to authenticated using (from_user = auth.uid());
create policy passes_select_own on passes for select to authenticated using (from_user = auth.uid());
create policy matches_select_own on matches for select to authenticated using (auth.uid() in (user_a, user_b));

create policy messages_select_participant on messages for select to authenticated using (
  exists (select 1 from matches m where m.id = messages.match_id and auth.uid() in (m.user_a, m.user_b))
  and not exists (select 1 from message_hidden h where h.message_id = messages.id and h.user_id = auth.uid())
);
create policy hidden_select_own on message_hidden for select to authenticated using (user_id = auth.uid());

create policy blocks_select_own on blocks for select to authenticated using (blocker = auth.uid());

create policy reports_select on reports for select to authenticated
  using (reporter = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));
create policy reports_update_staff on reports for update to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

create policy sanctions_select on sanctions for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

create policy violations_staff on message_violations for select to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]));

-- ───────────────────────────── Paiements & Premium (lecture propriétaire / finance ; aucune écriture client)
create policy tx_select on transactions for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'finance']::staff_role[]));
create policy tx_events_select on transaction_events for select to authenticated using (
  auth_is_staff(array['super_admin', 'finance']::staff_role[])
  or exists (select 1 from transactions t where t.id = transaction_events.transaction_id and t.user_id = auth.uid())
);
create policy grants_select on premium_grants for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
create policy premium_events_select on premium_events for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));

-- ───────────────────────────── Administration
create policy staff_select on staff_roles for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin']::staff_role[]));
create policy staff_manage on staff_roles for all to authenticated
  using (auth_is_staff(array['super_admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin']::staff_role[]));
create policy audit_select on audit_log for select to authenticated
  using (auth_is_staff(array['super_admin', 'tech']::staff_role[]));
create policy sms_select on sms_log for select to authenticated
  using (auth_is_staff(array['super_admin', 'finance', 'tech']::staff_role[]));
create policy deletion_select on account_deletion_requests for select to authenticated
  using (user_id = auth.uid() or auth_is_staff(array['super_admin', 'admin', 'support']::staff_role[]));
-- profile_views : aucune lecture directe (statistiques agrégées via my_profile_view_stats()).

-- ───────────────────────────── Privilèges
-- Supabase accorde par défaut tous les droits sur le schéma public aux rôles anon / authenticated :
-- on repart d'une base fermée, puis on n'ouvre que le nécessaire (RLS s'applique en plus).
grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon;
grant select on countries, cities, professions, legal_documents, app_config to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
-- Fonctions internes : appelées uniquement par les fonctions `security definer`, jamais par l'application.
revoke execute on function write_audit(text, text, text, jsonb, jsonb, text) from authenticated;
revoke execute on function cfg_int(text, int) from authenticated;
revoke execute on function cfg_bool(text, boolean) from authenticated;
revoke execute on function approved_photo_count(uuid) from authenticated;
revoke execute on function is_discoverable(uuid) from authenticated;
revoke execute on function message_violation_category(text) from authenticated;
revoke execute on function like_window_start() from authenticated;
