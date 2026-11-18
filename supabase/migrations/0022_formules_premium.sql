-- ZAYA — Formules et avantages Premium administrables (CDC §22.16 : « avantages et prix Premium hebdomadaire, mensuel
-- et trimestriel » ; consigne « pas de données en dur »).
--   • Noms proposés le 17/11/2026 à la demande du propriétaire : Étincelle (7 jours), Flamme (30 jours),
--     Alliance (90 jours), en écho à la flamme du logo ZAYA et à l'alliance du mariage. Modifiables par l'équipe.
--   • Prix : non décidés (décision C7) → price_gnf reste vide ; l'achat reste fermé (payments_enabled = false).
--   • Avantages : liste descriptive affichée dans l'application ; les règles réelles restent appliquées par le serveur.

create table premium_plans (
  code text primary key check (code ~ '^[a-z_]{2,30}$'),
  name_fr text not null check (char_length(name_fr) between 2 and 40),
  name_en text not null check (char_length(name_en) between 2 and 40),
  tagline_fr text check (char_length(tagline_fr) <= 120),
  tagline_en text check (char_length(tagline_en) <= 120),
  duration_days int not null check (duration_days between 1 and 366),
  price_gnf numeric(12, 0) check (price_gnf >= 0),     -- vide tant que le prix n'est pas décidé (C7)
  position int not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table premium_features (
  code text primary key check (code ~ '^[a-z_]{2,40}$'),
  label_fr text not null check (char_length(label_fr) between 2 and 120),
  label_en text not null check (char_length(label_en) between 2 and 120),
  in_free boolean not null default false,
  in_premium boolean not null default true,
  position int not null default 0,
  active boolean not null default true
);

alter table premium_plans enable row level security;
alter table premium_features enable row level security;
create policy plans_read on premium_plans for select to anon, authenticated using (active);
create policy features_read on premium_features for select to anon, authenticated using (active);
create policy plans_staff on premium_plans for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
create policy features_staff on premium_features for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'finance']::staff_role[]));
grant select on premium_plans, premium_features to anon, authenticated;
grant insert, update, delete on premium_plans, premium_features to authenticated;

insert into premium_plans (code, name_fr, name_en, tagline_fr, tagline_en, duration_days, position) values
  ('week', 'Étincelle', 'Spark', 'Une semaine pour aller plus loin', 'One week to go further', 7, 1),
  ('month', 'Flamme', 'Flame', 'Un mois pour prendre le temps de bien choisir', 'One month to take your time', 30, 2),
  ('quarter', 'Alliance', 'Alliance', 'Trois mois pour construire sereinement', 'Three months to build with peace of mind',
   90, 3)
on conflict (code) do nothing;

insert into premium_features (code, label_fr, label_en, in_free, in_premium, position) values
  ('profile', 'Créer et gérer son profil', 'Create and manage your profile', true, true, 10),
  ('discover', 'Découvrir tous les profils, Gratuit et Premium', 'Discover all profiles, Free and Premium', true, true, 20),
  ('swipes', 'Swipes à chaque période', 'Swipes every period', true, true, 30),
  ('matches', 'Matchs réciproques et messagerie', 'Mutual matches and messaging', true, true, 40),
  ('safety', 'Bloquer, signaler, masquer son profil', 'Block, report, hide your profile', true, true, 50),
  ('data', 'Exporter et supprimer ses données', 'Export and delete your data', true, true, 60),
  ('who_liked', 'Voir qui a aimé votre profil', 'See who liked your profile', false, true, 70),
  ('more_swipes', 'Davantage de swipes', 'More swipes', false, true, 80),
  ('filters', 'Filtres de recherche avancés', 'Advanced search filters', false, true, 90),
  ('photos', 'Photos des profils sans floutage', 'Profile photos without blur', false, true, 100)
on conflict (code) do nothing;
