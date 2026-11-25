-- ZAYA — Mise en service de la connexion par code (migration 0071), PRÉPRODUCTION SEULEMENT.
-- À exécuter une seule fois dans Supabase > SQL Editor, après la migration 0071, par une personne autorisée.
--
-- ⚠ Sécurité : un code par défaut connu de tous permet à quiconque connaît un numéro d'ouvrir le compte tant que
-- son titulaire n'a pas choisi son propre code. Le changement est imposé à la première connexion, mais ce script
-- ne doit pas être lancé sur une base qui contient de vrais membres (décision D17, DECISIONS_A_CONFIRMER.md).

-- 1) Secret « poivre » des codes, gardé dans le coffre Vault (jamais dans Git). Remplacer la valeur par 64
--    caractères aléatoires, par exemple produits avec : openssl rand -hex 32
-- select vault.create_secret('<64 caractères aléatoires>', 'zaya_pin_pepper');

-- 2) Code par défaut 6236 (demande du propriétaire du 25/11/2026) pour chaque compte qui n'a pas encore de code ;
--    changement obligatoire à la première connexion.
select admin_set_member_pin(u.id, '6236')
from auth.users u
where not exists (select 1 from private.member_pins p where p.user_id = u.id);

-- 3) Vérification : nombre de comptes avec un code, et combien doivent encore le changer.
select count(*) as comptes_avec_code, count(*) filter (where must_change) as a_changer
from private.member_pins;
