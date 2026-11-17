-- ZAYA — outil de PRÉPRODUCTION : valider la vérification des comptes d'essai.
--
-- Pourquoi : la console de modération n'existe pas encore (documentation/PLAN_LOTS.md, A12). Or un profil
-- n'apparaît dans Découvrir, et ne peut publier dans la Communauté, qu'une fois sa vérification validée par
-- l'équipe ZAYA. Ce script joue ce rôle, uniquement pour les numéros listés ci-dessous.
-- En production, chaque demande est examinée par un modérateur (selfie, photos) : ne pas utiliser ce script.
--
-- Avant : chaque compte d'essai s'est connecté dans l'application, a ajouté 3 photos et a demandé la
-- vérification (Profil → Vérifier mon profil).
-- Usage : Supabase → SQL Editor → New query → coller ce fichier → adapter la liste des numéros → Run.
-- Effets : le premier numéro de la liste devient modérateur ; les demandes en attente des numéros listés sont
-- validées en son nom et tracées dans le journal d'audit. Relancer le script ne fait rien de plus.

do $$
declare
  -- ↓ Numéros des comptes d'essai : indicatif compris, sans « + » ni espace. Le premier sert de modérateur.
  v_numeros constant text[] := array['224620000001', '224620000002'];
  v_moderateur uuid;
  v_demande record;
begin
  select u.id into v_moderateur from auth.users u
  where regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') = v_numeros[1];
  if v_moderateur is null then
    raise exception 'Aucun compte avec le numéro % : connectez-vous d''abord une fois dans l''application.', v_numeros[1];
  end if;
  insert into staff_roles (user_id, role) values (v_moderateur, 'moderator') on conflict do nothing;

  -- Agir au nom du modérateur, comme le ferait la console (auth.uid() lit ce réglage).
  perform set_config('request.jwt.claim.sub', v_moderateur::text, true);
  for v_demande in
    select r.id from verification_requests r join auth.users u on u.id = r.user_id
    where r.status = 'pending' and regexp_replace(coalesce(u.phone, ''), '\D', '', 'g') = any (v_numeros)
    order by r.created_at
  loop
    perform admin_decide_verification(v_demande.id, 'approved', 'Compte d''essai validé en préproduction');
  end loop;
  perform set_config('request.jwt.claim.sub', '', true);
end $$;

-- Résultat affiché : tous les comptes et l'état de leur vérification.
select u.phone as numero,
       p.display_name as prenom,
       coalesce(p.verification_status::text, 'profil non créé') as verification,
       exists (select 1 from staff_roles s where s.user_id = u.id) as equipe_zaya
from auth.users u
left join profiles p on p.id = u.id
order by u.phone;
