-- Ajoute les huit communes de Conakry absentes du référentiel initial.
-- Liste actualisée selon l'arrêté A/2026/872/MATD/CAB/SGG du 13 octobre 2026.
-- Le pays doit exister : sur une base vide, le seed crée la Guinée puis ses villes.
insert into cities (country_code, name)
select v.country_code, v.name
from countries c
join (values
  ('GN', U&'Conakry \2014 Gbessia'),
  ('GN', U&'Conakry \2014 Kagb\00E9len'),
  ('GN', U&'Conakry \2014 Lambanyi'),
  ('GN', U&'Conakry \2014 Man\00E9ah'),
  ('GN', U&'Conakry \2014 Sanoyah'),
  ('GN', U&'Conakry \2014 Sonfonia'),
  ('GN', U&'Conakry \2014 Tombolia'),
  ('GN', U&'Conakry \2014 Kassa')
) as v(country_code, name) on v.country_code = c.code
on conflict (country_code, name) do nothing;
