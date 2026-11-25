-- ZAYA — Niveaux d'études : libellés rétablis et recopiés dans les profils (suite de 0052).
--
-- Cause : la 0052 a été appliquée sur la préproduction depuis PowerShell 5.1, qui lit les fichiers dans l'encodage
-- Windows : les accents sont arrivés abîmés (« CollÃ¨ge », « BaccalaurÃ©at », « Sans diplÃ´me »). La 0058 répare
-- deux libellés ; cette migration rétablit les neuf, et recopie le bon libellé dans profiles.education_level,
-- que le déclencheur de 0052 avait rempli avec le texte abîmé (fiches des profils d'essai).
-- Sans effet sur une base saine. Les accents sont écrits en échappements Unicode, insensibles à l'encodage du fichier.

update education_levels l
set label_fr = v.label_fr, label_en = v.label_en
from (values
  ('none', U&'Sans dipl\00F4me', 'No diploma'),
  ('primary', 'Primaire (CEPE)', 'Primary school'),
  ('middle', U&'Coll\00E8ge (BEPC)', 'Middle school'),
  ('bac', U&'Baccalaur\00E9at', 'High school diploma'),
  ('vocational', 'Formation professionnelle', 'Vocational training'),
  ('bac2', 'Bac +2 (BTS, DUT)', 'Two-year degree'),
  ('licence', 'Licence (Bac +3)', 'Bachelor''s degree'),
  ('master', 'Master (Bac +5)', 'Master''s degree'),
  ('doctorate', 'Doctorat', 'Doctorate')
) as v (key, label_fr, label_en)
where l.key = v.key and (l.label_fr is distinct from v.label_fr or l.label_en is distinct from v.label_en);

-- Le déclencheur de 0052 recopie le libellé quand education_key est réécrit (même valeur).
update profiles p
set education_key = p.education_key
from education_levels l
where l.key = p.education_key and p.education_level is distinct from l.label_fr;
