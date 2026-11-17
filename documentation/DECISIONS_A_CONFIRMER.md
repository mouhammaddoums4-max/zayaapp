# Décisions à confirmer par le propriétaire du projet

Tant qu'une décision n'est pas confirmée, elle reste **configurable** (`app_config` ou catalogue administrable) ou est signalée comme **bloquante**. Valeurs actuellement utilisées = valeurs provisoires.

## Bloquantes avant ouverture publique

| # | Décision | Valeur provisoire dans le code | Où la changer |
|---|---|---|---|
| B1 | Nom légal de l'éditeur, statut juridique, textes CGU / confidentialité / règles communautaires | Documents `v0-draft` | `legal_documents` |
| B2 | Prestataire de vérification selfie / identité + politique de conservation biométrique | Revue **manuelle** par un modérateur | `verification_requests` |
| B3 | Contrat et tarifs Nimba SMS, identifiant expéditeur, plafond mensuel | `sms_monthly_budget_gnf = 0` (envoi bloqué tant que non défini) | `app_config` + secrets |
| B4 | Budget et capacité de modération (délais critique < 2 h…) | SLA du cahier des charges | `app_config.report_sla_hours` |
| B5 | Projet Supabase staging / production (création = engagement) | Non créé | — |
| B6 | Chiffrement de la messagerie (E2E incompatible avec le filtrage serveur) | Chiffrement transit + repos, pas d'E2E | Architecture |

## Configurables (non bloquantes)

| # | Décision | Valeur provisoire |
|---|---|---|
| C1 | Catégories de genre du profil | `femme`, `homme` |
| C2 | Liste des confessions et libellés | 5 valeurs du §4.1 |
| C3 | Catalogue ethnies par pays (relu localement) | Guinée : 6 groupes cités au §23.2 + « autre » |
| C4 | Quota de likes gratuits / jour et heure de renouvellement | 20 / 00:00 UTC |
| C5 | Nombre minimum de photos | 3 |
| C6 | Durée d'édition / annulation d'un message | 15 min |
| C7 | Prix Premium (7 / 30 / 90 jours) et Boost | Non définis → achat désactivé (`payments_enabled = false`) |
| C8 | Moyens de paiement actifs par pays | Aucun actif |
| C9 | Numéro WhatsApp officiel du support | Vide → bouton masqué |
| C10 | Pays ouverts | Guinée uniquement |
| C11 | Liste des termes interdits (filtre messagerie) | Liste minimale de démonstration, à compléter par les modérateurs |
| C12 | Visibilité Gratuit des photos (floutage) | Profil principal net, photos suivantes floutées pour Gratuit (lot B) |
