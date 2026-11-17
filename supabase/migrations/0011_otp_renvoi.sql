-- ZAYA — Délai avant de pouvoir redemander un code de connexion (cahier des charges §9, CARTE_ECRANS A03).
-- Réglable sans nouvelle version de l'application : l'écran affiche un compte à rebours, puis « Renvoyer le code ».
-- Le serveur d'authentification garde ses propres limites (fréquence et nombre d'envois) : ce réglage ne les remplace pas.

insert into app_config (key, value, description, is_public) values
  ('otp_resend_seconds', '60', 'Secondes avant de pouvoir redemander un code de connexion (compte à rebours)', true)
on conflict (key) do nothing;
