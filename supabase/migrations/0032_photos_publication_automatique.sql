-- ZAYA — Photos publiées automatiquement, modérées ensuite (demande du propriétaire du 18/11/2026 : « toute
-- modification ou mise à jour doit s'effectuer automatiquement »).
--
-- Constat : une photo ajoutée restait « en attente » (photos_guard) jusqu'à une validation de l'équipe ; sans console
-- de modération, elle n'était jamais montrée aux autres membres. Le cahier des charges admet les deux modes :
-- « contrôle des contenus avant publication ou modération rapide après publication ».
--   • app_config.photo_auto_publish = true : une nouvelle photo est approuvée dès l'envoi, donc visible aussitôt
--     (dans le respect de sa visibilité et du floutage) ; l'équipe peut la refuser ensuite, et les membres peuvent la
--     signaler. false : retour à la validation préalable.
--   • Les photos déjà en attente sont publiées par cette migration.
--   • admin_moderate_photo : refus ou rétablissement par l'équipe, motif obligatoire pour un refus, tracé.

insert into app_config (key, value, description, is_public) values
  ('photo_auto_publish', 'true',
   'Photos visibles dès l''envoi puis modérées ensuite (true) ; false = visibles après validation de l''équipe', false)
on conflict (key) do nothing;

-- S'exécute après photos_guard (ordre alphabétique des déclencheurs BEFORE : « photos_guard » < « photos_zz… »).
create function photos_auto_publish() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if cfg_bool('photo_auto_publish', true) then
    new.moderation := 'approved';
  end if;
  return new;
end;
$$;
create trigger photos_zz_auto_publish_trg before insert on profile_photos
  for each row execute function photos_auto_publish();

do $$
begin
  if cfg_bool('photo_auto_publish', true) then
    perform set_config('zaya.internal', '1', true);
    update profile_photos set moderation = 'approved' where moderation = 'pending';
    perform set_config('zaya.internal', '0', true);
  end if;
end $$;

create function admin_moderate_photo(p_photo uuid, p_status moderation_status, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_old profile_photos;
begin
  if not auth_is_staff(array['super_admin', 'admin', 'moderator']::staff_role[]) then raise exception 'FORBIDDEN'; end if;
  if p_status = 'rejected' and coalesce(trim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_old from profile_photos where id = p_photo for update;
  if not found then raise exception 'PHOTO_NOT_FOUND'; end if;
  perform set_config('zaya.internal', '1', true);
  update profile_photos set moderation = p_status where id = p_photo;
  perform set_config('zaya.internal', '0', true);
  perform write_audit('photo.' || p_status::text, 'profile_photos', p_photo::text,
                      jsonb_build_object('moderation', v_old.moderation), jsonb_build_object('moderation', p_status),
                      p_reason);
end;
$$;

revoke execute on function photos_auto_publish() from public, anon, authenticated;
revoke execute on function admin_moderate_photo(uuid, moderation_status, text) from public, anon;
grant execute on function admin_moderate_photo(uuid, moderation_status, text) to authenticated;
