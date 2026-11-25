-- ZAYA — données de référence (aucune donnée personnelle). Valeurs provisoires : voir DECISIONS_A_CONFIRMER.md

insert into countries (code, name_fr, name_en, phone_prefix, enabled) values
  ('GN', 'Guinée', 'Guinea', '+224', true),
  ('SN', 'Sénégal', 'Senegal', '+221', false),
  ('CI', 'Côte d''Ivoire', 'Côte d''Ivoire', '+225', false),
  ('ML', 'Mali', 'Mali', '+223', false),
  ('SL', 'Sierra Leone', 'Sierra Leone', '+232', false),
  ('LR', 'Libéria', 'Liberia', '+231', false),
  ('GW', 'Guinée-Bissau', 'Guinea-Bissau', '+245', false),
  ('GM', 'Gambie', 'Gambia', '+220', false),
  ('FR', 'France', 'France', '+33', false)
on conflict (code) do nothing;

insert into cities (country_code, name) values
  ('GN', 'Conakry — Kaloum'), ('GN', 'Conakry — Dixinn'), ('GN', 'Conakry — Matam'),
  ('GN', 'Conakry — Ratoma'), ('GN', 'Conakry — Matoto'),
  ('GN', U&'Conakry \2014 Gbessia'), ('GN', U&'Conakry \2014 Kagb\00E9len'),
  ('GN', U&'Conakry \2014 Lambanyi'), ('GN', U&'Conakry \2014 Man\00E9ah'),
  ('GN', U&'Conakry \2014 Sanoyah'), ('GN', U&'Conakry \2014 Sonfonia'),
  ('GN', U&'Conakry \2014 Tombolia'), ('GN', U&'Conakry \2014 Kassa'),
  ('GN', 'Coyah'), ('GN', 'Dubréka'), ('GN', 'Kindia'), ('GN', 'Boké'), ('GN', 'Kamsar'),
  ('GN', 'Labé'), ('GN', 'Mamou'), ('GN', 'Kankan'), ('GN', 'Siguiri'), ('GN', 'Faranah'),
  ('GN', 'N''Zérékoré'), ('GN', 'Kissidougou'), ('GN', 'Guéckédou')
on conflict do nothing;

-- Catalogue culturel Guinée : liste non exhaustive, à relire localement (§23.2)
insert into ethnic_groups (country_code, label_fr) values
  ('GN', 'Peul'), ('GN', 'Malinké'), ('GN', 'Soussou'), ('GN', 'Kissi'), ('GN', 'Guerzé / Kpèlè'), ('GN', 'Baga')
on conflict do nothing;

insert into professions (category, label_fr) values
  ('administration', 'Administration publique'), ('agriculture', 'Agriculture / élevage'),
  ('commerce', 'Commerce'), ('artisanat', 'Artisanat'), ('batiment', 'Bâtiment / BTP'),
  ('transport', 'Transport / logistique'), ('sante', 'Santé'), ('education', 'Éducation / enseignement'),
  ('informatique', 'Informatique / télécoms'), ('finance', 'Banque / finance'), ('securite', 'Sécurité'),
  ('industrie', 'Industrie / mines'), ('services', 'Services'), ('etudiant', 'Étudiant(e)'),
  ('sans_emploi', 'Sans emploi'), ('retraite', 'Retraité(e)'), ('domestique', 'Travail domestique / ménager')
on conflict do nothing;

insert into app_config (key, value, description, is_public) values
  ('free_daily_likes', '20', 'Quota quotidien de likes gratuits', true),
  ('premium_daily_likes', '200', 'Plafond anti-abus des likes Premium', true),
  ('likes_reset_hour_utc', '0', 'Heure (UTC = Conakry) de renouvellement du quota', true),
  ('min_profile_photos', '3', 'Nombre minimal de photos approuvées', true),
  ('message_edit_window_minutes', '15', 'Durée pour modifier ou annuler un message', true),
  ('payments_enabled', 'false', 'Achats désactivés tant que la conformité n''est pas validée', true),
  ('support_whatsapp', '""', 'Numéro WhatsApp officiel du support (vide = bouton masqué)', true),
  ('account_deletion_delay_days', '30', 'Délai de rétractation avant suppression définitive du compte', true),
  ('community_enabled', 'true', 'Communauté ouverte (à confirmer avant ouverture publique : modération opérationnelle)', true),
  ('community_post_requires_verification', 'true', 'Profil vérifié exigé pour publier et commenter', true),
  ('community_posts_per_day', '5', 'Nombre maximal de publications par membre et par 24 h', true),
  ('community_comments_per_hour', '20', 'Nombre maximal de commentaires par membre et par heure', true),
  ('sms_monthly_budget_gnf', '0', 'Plafond mensuel de dépenses SMS (0 = envoi bloqué)', false),
  ('sms_unit_cost_gnf', '0', 'Coût unitaire d''un SMS, à confirmer avec Nimba', false)
on conflict (key) do nothing;

insert into legal_documents (kind, version, lang, content) values
  ('tos', 'v0-draft', 'fr', 'Brouillon — conditions d''utilisation à faire valider par un professionnel compétent.'),
  ('privacy', 'v0-draft', 'fr', 'Brouillon — politique de confidentialité à faire valider.'),
  ('community', 'v0-draft', 'fr', 'Brouillon — règles communautaires : respect, pas de nudité, pas de harcèlement, pas de demande d''argent.')
on conflict do nothing;

-- Liste minimale de démonstration : à compléter et à relire par l'équipe de modération avant lancement
insert into moderation_terms (term, category, severity) values
  ('envoie-moi de l''argent', 'money_request', 3),
  ('envoie moi de l''argent', 'money_request', 3),
  ('ton code otp', 'credential_request', 3),
  ('ton mot de passe', 'credential_request', 3),
  ('ton code orange money', 'credential_request', 3),
  ('photo nue', 'sexual_content', 3),
  ('je vais te tuer', 'threat', 3)
on conflict do nothing;

-- Communautés thématiques de départ (CDC V2.3 §2.3), ouvertes progressivement selon la capacité de modération
insert into communities (slug, name, description, icon, position) values
  ('preparation-mariage', 'Préparation au mariage',
   'Les questions à se poser, les étapes, les sujets à aborder avant de s’engager.', 'favorite', 1),
  ('vie-de-couple', 'Communication et vie de couple',
   'Écoute, désaccords, respect : partager ce qui aide à construire une relation solide.', 'forum', 2),
  ('conseils-experiences', 'Conseils et expériences',
   'Rencontres, premiers rendez-vous, précautions : apprendre de l’expérience des autres.', 'lightbulb', 3),
  ('famille-parentalite', 'Famille et parentalité',
   'Présenter son projet à sa famille, fonder un foyer, accueillir des enfants.', 'family', 4),
  ('developpement-personnel', 'Éducation et développement personnel',
   'Études, travail, projets : grandir pour soi et pour le couple.', 'school', 5),
  ('evenements-locaux', 'Événements et activités locales',
   'Ateliers, conférences et rencontres encadrées près de chez vous.', 'event', 6),
  ('questions-reponses', 'Questions et réponses',
   'Une question sur ZAYA, la sécurité ou la vie à deux ? Posez-la ici.', 'help', 7),
  ('langues-regions', 'Communautés linguistiques et régionales',
   'Échanger dans sa langue et autour de sa région.', 'translate', 8)
on conflict (slug) do nothing;
