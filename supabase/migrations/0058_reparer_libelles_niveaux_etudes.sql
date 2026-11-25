-- Répare les deux libellés français avec accents de la liste des niveaux d'études,
-- uniquement si leur valeur enregistrée contient un marqueur d'encodage abîmé.
update education_levels
set label_fr = case key
  when 'middle' then U&'Coll\00E8ge (BEPC)'
  when 'bac' then U&'Baccalaur\00E9at'
end
where key in ('middle', 'bac')
  and (
    position(U&'\FFFD' in label_fr) > 0
    or position(U&'\00C3' in label_fr) > 0
    or position('?' in label_fr) > 0
  );