-- ZAYA — Matchs terminés (CARTE_ECRANS E01 « liste des matchs terminés, avec une explication », §7.1 ;
-- cahier des charges §32).
--
-- Après un dématch, plus aucun nouveau message n'est possible (send_message → MATCH_ENDED) et le match quitte
-- la liste des conversations des deux côtés. Cette liste sert à relire l'historique, qui reste lisible par les
-- deux personnes (RLS messages_select_participant), et à signaler la personne si besoin.
-- Le lien est retiré : ni photo ni accès au profil, seulement le nom affiché, masqué si le compte est fermé.
-- Un blocage efface toute trace dans cette liste : le dématch n'est pas un blocage, mais le blocage l'emporte.

create function my_ended_matches()
returns table (match_id uuid, user_id uuid, display_name text, matched_at timestamptz, ended_at timestamptz,
               ended_by_me boolean, account_closed boolean)
language sql stable security definer set search_path = public as $$
  select m.id,
         p.id,
         case when p.status in ('deleted', 'banned') then null else p.display_name end,
         m.created_at,
         m.ended_at,
         coalesce(m.ended_by = auth.uid(), false),
         p.status in ('deleted', 'banned')
  from matches m
  join profiles p on p.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
  where auth.uid() in (m.user_a, m.user_b)
    and m.ended_at is not null
    and not blocked_between(auth.uid(), p.id)
  order by m.ended_at desc
  limit 100;
$$;

revoke execute on function my_ended_matches() from public, anon;
grant execute on function my_ended_matches() to authenticated;
