-- ZAYA — Likes : liste des likes envoyés ; compteur des likes reçus aligné sur la liste (demande du 17/11/2026).
--
-- Le compteur des likes reçus comptait aussi les likes de membres qui ne sont pas visibles (profil non vérifié, en
-- pause, suspendu…), que la liste nominative (Premium) n'affiche pas : le membre voyait « 1 like » et une liste vide.
-- Le compteur suit désormais exactement la même règle que la liste. Jamais de like inventé ni caché au compteur
-- d'un profil visible.

create or replace function received_interests_count() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from interests i
  where i.to_user = auth.uid() and i.status = 'pending'
    and is_discoverable(i.from_user) and not blocked_between(i.from_user, i.to_user);
$$;

-- Profils que j'ai aimés et qui n'ont pas encore répondu (gratuit pour tous). Un match ou une réponse les retire de
-- la liste, de même qu'un profil devenu invisible (pause, suspension) ou un blocage.
create function my_sent_interests()
returns table (interest_id uuid, user_id uuid, display_name text, age int, city text, photo_path text,
               created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select i.id, p.id, p.display_name, age_of(p.birth_date), ci.name,
         (select ph.storage_path from profile_photos ph
           where ph.user_id = p.id and ph.moderation = 'approved' and ph.visibility = 'public'
           order by ph.position limit 1),
         i.created_at
  from interests i
  join profiles p on p.id = i.to_user
  left join cities ci on ci.id = p.city_id
  where i.from_user = auth.uid() and i.status = 'pending'
    and is_discoverable(p.id) and not blocked_between(i.from_user, i.to_user)
  order by i.created_at desc;
$$;
revoke execute on function my_sent_interests() from public, anon;
grant execute on function my_sent_interests() to authenticated;
