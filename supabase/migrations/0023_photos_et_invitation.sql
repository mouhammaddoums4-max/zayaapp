-- ZAYA — Photos du profil : 6 au plus (demande du propriétaire du 17/11/2026), limite réglable et appliquée par le
-- serveur ; lien d'invitation administrable (consigne « pas de données en dur »).
--   • max_profile_photos : au-delà, l'ajout est refusé (MAX_PHOTOS), même par un appel direct.
--   • min_profile_photos (déjà public) reste le minimum demandé pour la vérification.
--   • invite_url : lien partagé par « Inviter » (fiche Google Play tant qu'aucun autre lien n'est défini).
-- La suppression et l'ordre des photos par leur propriétaire sont déjà permis par la RLS (photos_update_own,
-- photos_delete_own) ; photos_guard garde la modération, le chemin et la version floutée hors de sa portée.

insert into app_config (key, value, description, is_public) values
  ('max_profile_photos', '6', 'Nombre maximal de photos par profil', true),
  ('invite_url', '"https://play.google.com/store/apps/details?id=com.zaya.app.zaya"',
   'Lien partagé par le bouton « Inviter » du profil', true)
on conflict (key) do nothing;

create function photos_max_guard() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not zaya_internal()
     and (select count(*) from profile_photos where user_id = new.user_id) >= cfg_int('max_profile_photos', 6) then
    raise exception 'MAX_PHOTOS';
  end if;
  return new;
end;
$$;
create trigger photos_max_guard_trg before insert on profile_photos
  for each row execute function photos_max_guard();
revoke execute on function photos_max_guard() from public, anon, authenticated;
