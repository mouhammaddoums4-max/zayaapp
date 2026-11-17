-- ZAYA — Correction : un membre ne pouvait pas afficher les photos des autres membres (« Object not found »).
-- La règle de lecture du stockage (0004, photos_public_read) interrogeait public.profile_photos avec les droits
-- du membre connecté ; or la RLS de profile_photos ne lui montre que ses propres lignes, donc la condition
-- était toujours fausse pour la photo d'un autre. La vérification passe désormais par une fonction
-- `security definer`, avec exactement les mêmes conditions : photo approuvée, publique, et aucun blocage
-- entre les deux membres. Les photos privées ou floutées ne sont toujours jamais servies en original.

create function photo_is_viewable(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profile_photos ph
    where ph.storage_path = p_path
      and ph.moderation = 'approved' and ph.visibility = 'public'
      and not blocked_between(auth.uid(), ph.user_id)
  );
$$;
revoke execute on function photo_is_viewable(text) from public, anon;
grant execute on function photo_is_viewable(text) to authenticated;

drop policy photos_public_read on storage.objects;
create policy photos_public_read on storage.objects for select to authenticated
  using (bucket_id = 'profile-photos' and public.photo_is_viewable(name));
