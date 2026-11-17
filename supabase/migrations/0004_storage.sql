-- ZAYA — Lot A : stockage des médias (buckets privés, URLs signées).
-- Convention de chemin : <bucket>/<user_id>/<fichier>

insert into storage.buckets (id, name, public) values
  ('profile-photos', 'profile-photos', false),
  ('verification', 'verification', false)
on conflict (id) do nothing;

-- Photos de profil : le propriétaire gère son dossier.
create policy photos_owner_all on storage.objects for all to authenticated
  using (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'profile-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Les autres membres ne lisent qu'une photo approuvée ET publique d'un profil visible et non bloqué.
-- Les photos privées / floutées ne sont jamais servies en original (variante floutée serveur : lot B).
create policy photos_public_read on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and exists (
      select 1 from public.profile_photos ph
      where ph.storage_path = storage.objects.name
        and ph.moderation = 'approved' and ph.visibility = 'public'
        and not public.blocked_between(auth.uid(), ph.user_id)
    )
  );

-- Selfies de vérification : dépôt par le propriétaire, lecture réservée aux modérateurs.
create policy verification_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'verification' and (storage.foldername(name))[1] = auth.uid()::text);
create policy verification_staff_read on storage.objects for select to authenticated
  using (bucket_id = 'verification'
         and public.auth_is_staff(array['super_admin', 'admin', 'moderator']::public.staff_role[]));
