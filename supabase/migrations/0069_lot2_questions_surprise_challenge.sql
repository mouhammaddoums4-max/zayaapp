-- ZAYA 2.0 — Lot 2 : Questions (visibilité par réponse), Surprise quotidienne, Challenge.
-- Les montants de récompense sont à 0 tant que le propriétaire ne les fixe pas (documentation/DECISIONS_A_CONFIRMER.md, D9 à D12).

insert into app_config (key, value, description, is_public) values
  ('challenge_daily_reward_cap', '3', 'Défis récompensés par membre et par jour', false),
  ('challenge_weekly_reward_cap', '10', 'Défis récompensés par membre et par semaine', false),
  ('challenge_device_daily_cap', '6', 'Défis récompensés par jour et par appareil (tous comptes confondus)', false)
on conflict (key) do nothing;

-- ── Questions pour mieux se connaître
create table public.marriage_questions (
  id bigint generated always as identity primary key,
  code text not null unique,
  topic text not null check (topic in ('marriage', 'family', 'children', 'living', 'goals', 'communication')),
  text_fr text not null,
  text_en text not null,
  sensitive boolean not null default false,
  position int not null default 0,
  active boolean not null default true
);
create table public.question_answers (
  user_id uuid not null references public.profiles (id) on delete cascade,
  question_id bigint not null references public.marriage_questions (id) on delete cascade,
  answer text not null check (char_length(answer) between 1 and 500),
  visibility text not null default 'me' check (visibility in ('me', 'matches', 'verified')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, question_id)
);
create index question_answers_day_idx on public.question_answers (user_id, created_at desc);
alter table public.marriage_questions enable row level security;
alter table public.question_answers enable row level security;
create policy questions_read on public.marriage_questions for select to authenticated using (active);
create policy answers_own on public.question_answers for select to authenticated using (user_id = auth.uid());
revoke all on public.marriage_questions, public.question_answers from anon, authenticated;
grant select on public.marriage_questions, public.question_answers to authenticated;

insert into public.marriage_questions (code, topic, text_fr, text_en, sensitive, position) values
  ('marriage_success', 'marriage', 'Pour vous, qu''est-ce qui fait un mariage réussi ?', 'In your view, what makes a marriage successful?', false, 1),
  ('family_place', 'family', 'Quelle place souhaitez-vous donner à vos familles dans votre couple ?', 'What place do you want your families to have in your couple?', true, 2),
  ('children_plan', 'children', 'Souhaitez-vous des enfants ? Combien, et à quel moment ?', 'Do you want children? How many, and when?', true, 3),
  ('living_place', 'living', 'Où aimeriez-vous vivre après le mariage ?', 'Where would you like to live after marriage?', false, 4),
  ('life_goals', 'goals', 'Quels sont vos principaux objectifs de vie pour les cinq prochaines années ?', 'What are your main life goals for the next five years?', false, 5),
  ('communication', 'communication', 'Comment aimez-vous que l''on vous parle quand quelque chose ne va pas ?', 'How do you like to be spoken to when something is wrong?', false, 6),
  ('disagreement', 'communication', 'Comment gérez-vous un désaccord avec la personne que vous aimez ?', 'How do you handle a disagreement with someone you love?', false, 7),
  ('daily_life', 'living', 'À quoi ressemble, pour vous, une journée ordinaire heureuse à deux ?', 'What does an ordinary happy day together look like for you?', false, 8)
on conflict (code) do nothing;

create function public.marriage_questions_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not feature_enabled('questions') then jsonb_build_object('status', 'disabled')
    else jsonb_build_object('status', 'ready', 'questions',
      coalesce((select jsonb_agg(jsonb_build_object(
          'id', q.id, 'topic', q.topic, 'text_fr', q.text_fr, 'text_en', q.text_en, 'sensitive', q.sensitive,
          'answer', a.answer, 'visibility', a.visibility) order by q.position)
        from marriage_questions q
        left join question_answers a on a.question_id = q.id and a.user_id = auth.uid()
        where q.active), '[]'::jsonb)) end;
$$;
revoke execute on function public.marriage_questions_list() from public, anon;
grant execute on function public.marriage_questions_list() to authenticated;

-- Réponse : privée par défaut (« moi seul »). Le texte passe par le même filtre que la messagerie.
create function public.answer_question(p_question bigint, p_answer text, p_visibility text default 'me') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_text text := trim(p_answer);
  v_category text;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('questions') then raise exception 'FEATURE_DISABLED'; end if;
  if p_visibility not in ('me', 'matches', 'verified') then raise exception 'INVALID_VISIBILITY'; end if;
  if v_text is null or v_text = '' or char_length(v_text) > 500 then raise exception 'INVALID_ANSWER'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active') then raise exception 'PROFILE_NOT_ACTIVE'; end if;
  if not exists (select 1 from marriage_questions where id = p_question and active) then raise exception 'QUESTION_NOT_FOUND'; end if;
  v_category := message_violation_category(v_text);
  if v_category is null and contains_link(v_text) then v_category := 'link'; end if;
  if v_category is not null then
    insert into message_violations (user_id, category) values (v_me, v_category);
    return jsonb_build_object('status', 'blocked', 'category', v_category);
  end if;
  insert into question_answers (user_id, question_id, answer, visibility) values (v_me, p_question, v_text, p_visibility)
    on conflict (user_id, question_id) do update
      set answer = excluded.answer, visibility = excluded.visibility, updated_at = now();
  return jsonb_build_object('status', 'saved');
end;
$$;
revoke execute on function public.answer_question(bigint, text, text) from public, anon;
grant execute on function public.answer_question(bigint, text, text) to authenticated;

create function public.delete_answer(p_question bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  delete from question_answers where user_id = auth.uid() and question_id = p_question;
end;
$$;
revoke execute on function public.delete_answer(bigint) from public, anon;
grant execute on function public.delete_answer(bigint) to authenticated;

-- Réponses d'un membre que je consulte : la visibilité choisie par la personne est appliquée ici, côté serveur.
create function public.answers_of(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_matched boolean;
  v_verified boolean;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('questions') then return '[]'::jsonb; end if;
  if v_me <> p_user and blocked_between(v_me, p_user) then return '[]'::jsonb; end if;
  v_matched := exists (select 1 from matches where user_a = least(v_me, p_user) and user_b = greatest(v_me, p_user)
                        and ended_at is null);
  v_verified := exists (select 1 from profiles where id = v_me and status = 'active' and verification_status = 'approved');
  return coalesce((
    select jsonb_agg(jsonb_build_object('question_id', q.id, 'text_fr', q.text_fr, 'text_en', q.text_en,
                                        'answer', a.answer, 'visibility', a.visibility) order by q.position)
    from question_answers a
    join marriage_questions q on q.id = a.question_id and q.active
    join profiles t on t.id = a.user_id and t.status = 'active'
    where a.user_id = p_user
      and (v_me = p_user
           or (a.visibility = 'matches' and v_matched)
           or (a.visibility = 'verified' and v_verified))), '[]'::jsonb);
end;
$$;
revoke execute on function public.answers_of(uuid) from public, anon;
grant execute on function public.answers_of(uuid) to authenticated;

-- ── Surprise quotidienne : tirage serveur, une par jour (clé primaire), probabilités publiques.
create table public.surprise_prizes (
  code text primary key,
  kind text not null check (kind in ('question', 'swipes')),
  label_fr text not null,
  label_en text not null,
  weight int not null default 0 check (weight >= 0),
  amount int not null default 0 check (amount >= 0),
  active boolean not null default true
);
insert into public.surprise_prizes (code, kind, label_fr, label_en, weight, amount, active) values
  ('question', 'question', 'Une question pour mieux vous connaître', 'A question to know yourself better', 100, 0, true),
  ('swipes', 'swipes', 'Des swipes offerts', 'Free swipes', 0, 0, false)
on conflict (code) do nothing;
alter table public.surprise_prizes enable row level security;
create policy prizes_read on public.surprise_prizes for select to authenticated using (true);
create policy prizes_staff on public.surprise_prizes for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
revoke all on public.surprise_prizes from anon, authenticated;
grant select on public.surprise_prizes to authenticated;
grant update on public.surprise_prizes to authenticated;

create table public.daily_surprises (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  prize_code text not null references public.surprise_prizes (code),
  amount int not null default 0,
  question_id bigint references public.marriage_questions (id),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.daily_surprises enable row level security;
revoke all on public.daily_surprises from anon, authenticated;

-- Probabilités réelles affichées avant l'ouverture : pas de promesse ambiguë.
create function public.surprise_odds() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', p.code, 'label_fr', p.label_fr, 'label_en', p.label_en, 'amount', p.amount,
           'percent', round(100.0 * p.weight / nullif(t.total, 0), 1)) order by p.code), '[]'::jsonb)
  from surprise_prizes p, (select sum(weight) as total from surprise_prizes where active and weight > 0) t
  where p.active and p.weight > 0;
$$;
revoke execute on function public.surprise_odds() from public, anon;
grant execute on function public.surprise_odds() to authenticated;

create function public.open_daily_surprise() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_day date := (now() at time zone 'utc')::date;
  v_total int;
  v_pick int;
  v_bytes bytea;
  v_prize surprise_prizes;
  v_question bigint;
  v_row daily_surprises;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('surprise') then return jsonb_build_object('status', 'disabled'); end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active' and verification_status = 'approved') then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select * into v_row from daily_surprises where user_id = v_me and day = v_day;
  if not found then
    select coalesce(sum(weight), 0) into v_total from surprise_prizes where active and weight > 0;
    if v_total = 0 then return jsonb_build_object('status', 'unavailable'); end if;
    -- Aléa du générateur sûr de PostgreSQL (UUID v4), réduit à un entier : ni le client ni l'heure n'y changent rien.
    v_bytes := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    v_pick := (((get_byte(v_bytes, 0)::bigint << 24) + (get_byte(v_bytes, 1)::bigint << 16)
              + (get_byte(v_bytes, 2)::bigint << 8) + get_byte(v_bytes, 3)) % v_total)::int;
    select * into v_prize from (
      select p.*, sum(p.weight) over (order by p.code) as cum from surprise_prizes p where p.active and p.weight > 0
    ) x where x.cum > v_pick order by x.cum limit 1;
    if v_prize.kind = 'question' then
      select q.id into v_question from marriage_questions q
        where q.active and not exists (select 1 from question_answers a where a.question_id = q.id and a.user_id = v_me)
        order by random() limit 1;
    end if;
    insert into daily_surprises (user_id, day, prize_code, amount, question_id)
      values (v_me, v_day, v_prize.code, v_prize.amount, v_question)
      on conflict (user_id, day) do nothing;
    select * into v_row from daily_surprises where user_id = v_me and day = v_day;
    if v_prize.kind = 'swipes' and v_prize.amount > 0 and v_row.prize_code = v_prize.code then
      perform grant_reward(v_me, 'surprise', 'swipes', v_prize.amount, 'surprise:' || v_me || ':' || v_day, 'Surprise du jour');
    end if;
    return jsonb_build_object('status', 'opened', 'prize', v_row.prize_code, 'amount', v_row.amount,
                              'question_id', v_row.question_id);
  end if;
  return jsonb_build_object('status', 'already_opened', 'prize', v_row.prize_code, 'amount', v_row.amount,
                            'question_id', v_row.question_id);
end;
$$;
revoke execute on function public.open_daily_surprise() from public, anon;
grant execute on function public.open_daily_surprise() to authenticated;

-- ── Challenge : chaque défi est validé par le serveur à partir d'événements réels.
create table public.challenges (
  code text primary key,
  kind text not null check (kind in ('complete_profile', 'answer_questions', 'view_profiles')),
  title_fr text not null,
  title_en text not null,
  target int not null default 1 check (target >= 1),
  once boolean not null default false,
  reward_amount int not null default 0 check (reward_amount >= 0),
  position int not null default 0,
  active boolean not null default true
);
insert into public.challenges (code, kind, title_fr, title_en, target, once, reward_amount, position) values
  ('complete_profile', 'complete_profile', 'Complétez votre profil', 'Complete your profile', 1, true, 0, 1),
  ('answer_question', 'answer_questions', 'Répondez à une question', 'Answer a question', 1, false, 0, 2),
  ('discover_profiles', 'view_profiles', 'Découvrez 5 profils', 'Discover 5 profiles', 5, false, 0, 3)
on conflict (code) do nothing;
create table public.challenge_claims (
  user_id uuid not null references public.profiles (id) on delete cascade,
  challenge_code text not null references public.challenges (code),
  day date not null,
  reward_amount int not null default 0,
  created_at timestamptz not null default now(),
  primary key (user_id, challenge_code, day)
);
alter table public.challenges enable row level security;
alter table public.challenge_claims enable row level security;
create policy challenges_read on public.challenges for select to authenticated using (active);
create policy challenge_claims_own on public.challenge_claims for select to authenticated using (user_id = auth.uid());
create policy challenges_staff on public.challenges for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin']::staff_role[]));
revoke all on public.challenges, public.challenge_claims from anon, authenticated;
grant select on public.challenges, public.challenge_claims to authenticated;
grant update on public.challenges to authenticated;

create function public.challenge_progress(p_user uuid, p_code text) returns int
language plpgsql stable security definer set search_path = public as $$
declare c challenges;
begin
  select * into c from challenges where code = p_code;
  if not found then return 0; end if;
  if c.kind = 'complete_profile' then
    return case when exists (
      select 1 from profiles p
      where p.id = p_user and char_length(coalesce(p.bio, '')) >= 20 and p.marriage_horizon is not null
        and p.profession_id is not null and approved_photo_count(p.id) >= cfg_int('min_profile_photos', 3)) then 1 else 0 end;
  elsif c.kind = 'answer_questions' then
    return (select count(*)::int from question_answers where user_id = p_user
             and created_at >= (now() at time zone 'utc')::date);
  else
    return (select count(distinct viewed)::int from profile_views
             where viewer = p_user and viewed <> p_user and viewed_at >= (now() at time zone 'utc')::date);
  end if;
end;
$$;
revoke execute on function public.challenge_progress(uuid, text) from public, anon, authenticated;

create function public.my_challenges() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('challenge') then return jsonb_build_object('status', 'disabled'); end if;
  return jsonb_build_object('status', 'ready', 'challenges', coalesce((
    select jsonb_agg(jsonb_build_object(
        'code', c.code, 'title_fr', c.title_fr, 'title_en', c.title_en, 'target', c.target,
        'progress', least(c.target, challenge_progress(v_me, c.code)), 'reward', c.reward_amount,
        'claimed', exists (select 1 from challenge_claims k where k.user_id = v_me and k.challenge_code = c.code
                            and k.day = case when c.once then date '2000-01-01' else (now() at time zone 'utc')::date end))
      order by c.position)
    from challenges c where c.active), '[]'::jsonb));
end;
$$;
revoke execute on function public.my_challenges() from public, anon;
grant execute on function public.my_challenges() to authenticated;

create function public.claim_challenge(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  c challenges;
  v_day date;
  v_today date := (now() at time zone 'utc')::date;
begin
  if v_me is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not feature_enabled('challenge') then raise exception 'FEATURE_DISABLED'; end if;
  if not exists (select 1 from profiles where id = v_me and status = 'active' and verification_status = 'approved') then
    raise exception 'NOT_ELIGIBLE';
  end if;
  select * into c from challenges where code = p_code and active;
  if not found then raise exception 'CHALLENGE_NOT_FOUND'; end if;
  if challenge_progress(v_me, p_code) < c.target then raise exception 'NOT_COMPLETED'; end if;
  v_day := case when c.once then date '2000-01-01' else v_today end;
  if exists (select 1 from challenge_claims where user_id = v_me and challenge_code = p_code and day = v_day) then
    raise exception 'ALREADY_CLAIMED';
  end if;
  -- Plafonds par membre (jour, semaine) et par appareil : un défi récompensé de plus est refusé, pas crédité.
  if c.reward_amount > 0 then
    if (select count(*) from challenge_claims where user_id = v_me and reward_amount > 0 and created_at >= date_trunc('day', now()))
         >= cfg_int('challenge_daily_reward_cap', 3)
       or (select count(*) from challenge_claims where user_id = v_me and reward_amount > 0 and created_at >= date_trunc('week', now()))
         >= cfg_int('challenge_weekly_reward_cap', 10) then
      raise exception 'REWARD_CAP_REACHED';
    end if;
    if (select count(*) from challenge_claims k
         where k.reward_amount > 0 and k.created_at >= date_trunc('day', now())
           and k.user_id in (select d2.user_id from member_devices d1 join member_devices d2 on d1.device_hash = d2.device_hash
                              where d1.user_id = v_me))
       >= cfg_int('challenge_device_daily_cap', 6) then
      raise exception 'DEVICE_LIMIT';
    end if;
  end if;
  insert into challenge_claims (user_id, challenge_code, day, reward_amount) values (v_me, p_code, v_day, c.reward_amount);
  perform grant_reward(v_me, 'challenge', 'swipes', c.reward_amount, 'challenge:' || p_code || ':' || v_me || ':' || v_day, 'Défi : ' || c.title_fr);
  return jsonb_build_object('status', 'claimed', 'reward', c.reward_amount);
end;
$$;
revoke execute on function public.claim_challenge(text) from public, anon;
grant execute on function public.claim_challenge(text) to authenticated;
