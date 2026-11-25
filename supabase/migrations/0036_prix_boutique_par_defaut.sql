-- 0036 : prix par défaut de la boutique, demandés par le propriétaire le 25/11/2026 (décision C21).
-- Prix en pièces, provisoires et modifiables à tout moment par l'équipe (admin_save_shop_item). Un prix déjà fixé
-- par l'équipe n'est jamais écrasé. La valeur d'une pièce en GNF sera fixée avec l'ouverture des paiements (C7, C8).

update public.shop_items as i set price_coins = d.price, updated_at = now()
from (values
  ('rose', 10),
  ('the_menthe', 15),
  ('bouquet', 30),
  ('parfum', 60),
  ('bague', 150),
  ('sourire', 5),
  ('valeurs', 5),
  ('serieux', 5)
) as d (code, price)
where i.code = d.code and i.price_coins is null;
