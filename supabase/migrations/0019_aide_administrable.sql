-- ZAYA — Aide administrable : les questions fréquentes ne sont plus écrites dans l'application (consigne du propriétaire
-- « pas de données en dur »). L'équipe (support, admin) les ajoute, modifie, ordonne et désactive ; l'application les lit
-- dans la langue de l'interface, avec repli en français.

create table help_articles (
  id bigint generated always as identity primary key,
  section text not null check (char_length(section) between 2 and 80),
  lang text not null default 'fr' check (lang ~ '^[a-z]{2,3}$'),
  question text not null check (char_length(question) between 5 and 200),
  answer text not null check (char_length(answer) between 5 and 2000),
  position int not null default 0,
  active boolean not null default true,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);
create index help_articles_lang on help_articles (lang, active, position);

alter table help_articles enable row level security;
create policy help_read on help_articles for select to anon, authenticated using (active);
create policy help_staff on help_articles for all to authenticated
  using (auth_is_staff(array['super_admin', 'admin', 'support']::staff_role[]))
  with check (auth_is_staff(array['super_admin', 'admin', 'support']::staff_role[]));
grant select on help_articles to anon, authenticated;
grant insert, update, delete on help_articles to authenticated;

insert into help_articles (section, lang, question, answer, position) values
  ('Compte et profil', 'fr', 'Pourquoi mon profil n’apparaît-il pas dans Découvrir ?',
   'Un profil n’est proposé aux autres membres qu’une fois vérifié par l’équipe ZAYA : il faut le nombre minimum de photos demandé et un selfie de contrôle (Profil → Vérification du profil). Un profil en pause ou masqué n’est pas proposé non plus.', 10),
  ('Compte et profil', 'fr', 'Mon numéro de téléphone est-il visible ?',
   'Non. Il sert uniquement à vous connecter et à sécuriser votre compte. Il n’apparaît jamais sur votre profil ni dans vos conversations.', 20),
  ('Compte et profil', 'fr', 'Puis-je modifier ma date de naissance ou mon genre ?',
   'Non : ils sont fixés à l’inscription pour protéger les membres contre les faux profils. En cas d’erreur, écrivez à l’assistance.', 30),
  ('Rencontres et messages', 'fr', 'Comment se crée un match ?',
   'Un match se crée seulement lorsque deux personnes s’aiment mutuellement. La conversation s’ouvre alors pour vous deux.', 40),
  ('Rencontres et messages', 'fr', 'Pourquoi mon message a-t-il été refusé ?',
   'Avant l’envoi, ZAYA bloque les messages contraires à la charte, par exemple une demande d’argent ou des insultes. Les numéros de téléphone sont masqués pour vous protéger. Reformulez votre message.', 50),
  ('Rencontres et messages', 'fr', 'Que se passe-t-il quand un match prend fin ?',
   'La conversation se ferme pour les deux personnes. Le match apparaît ensuite dans « Matchs terminés », dans l’onglet Messages.', 60),
  ('Sécurité', 'fr', 'Comment signaler ou bloquer quelqu’un ?',
   'Depuis son profil ou la conversation, ouvrez le menu ⋯ puis choisissez « Signaler » ou « Bloquer ». La personne n’est pas prévenue. Après un blocage, vous ne vous voyez plus.', 70),
  ('Sécurité', 'fr', 'Quelqu’un me demande de l’argent : que faire ?',
   'Ne transférez jamais d’argent à une personne que vous n’avez pas rencontrée, et ne communiquez jamais un code reçu par SMS. Signalez la personne : notre équipe examine chaque signalement.', 80),
  ('Abonnement et compte', 'fr', 'Que puis-je faire gratuitement ?',
   'Créer votre profil, découvrir des profils, aimer dans la limite prévue, obtenir des matchs et discuter avec eux restent gratuits. Premium ajoute des avantages, sans jamais fermer une conversation après un match.', 90),
  ('Abonnement et compte', 'fr', 'Comment supprimer mon compte ?',
   'Réglages → Gérer mon compte. Votre profil est masqué immédiatement et vous pouvez annuler pendant le délai indiqué. Vous pouvez aussi simplement mettre votre profil en pause.', 100),
  ('Account and profile', 'en', 'Why doesn’t my profile appear in Discover?',
   'A profile is only shown to other members once the ZAYA team has verified it: you need the minimum number of photos and a check selfie (Profile → Profile verification). A paused or hidden profile is not shown either.', 10),
  ('Account and profile', 'en', 'Is my phone number visible?',
   'No. It is only used to sign you in and secure your account. It never appears on your profile or in your conversations.', 20),
  ('Account and profile', 'en', 'Can I change my date of birth or gender?',
   'No: they are set when you sign up, to protect members from fake profiles. If there is a mistake, write to support.', 30),
  ('Matches and messages', 'en', 'How is a match made?',
   'A match is only made when two people like each other. The conversation then opens for both of you.', 40),
  ('Matches and messages', 'en', 'Why was my message refused?',
   'Before sending, ZAYA blocks messages that break the rules, such as a request for money or insults. Phone numbers are hidden to protect you. Rephrase your message.', 50),
  ('Matches and messages', 'en', 'What happens when a match ends?',
   'The conversation closes for both people. The match then appears in “Ended matches”, in the Messages tab.', 60),
  ('Safety', 'en', 'How do I report or block someone?',
   'From their profile or the conversation, open the ⋯ menu and choose “Report” or “Block”. The person is not notified. After blocking, you no longer see each other.', 70),
  ('Safety', 'en', 'Someone is asking me for money: what should I do?',
   'Never send money to someone you have not met, and never share a code received by SMS. Report the person: our team reviews every report.', 80),
  ('Subscription and account', 'en', 'What can I do for free?',
   'Creating your profile, discovering profiles, liking within the limit, getting matches and chatting with them are free. Premium adds benefits, but never closes a conversation after a match.', 90),
  ('Subscription and account', 'en', 'How do I delete my account?',
   'Settings → Manage my account. Your profile is hidden immediately and you can cancel during the period shown. You can also simply pause your profile.', 100);
