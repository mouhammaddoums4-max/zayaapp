# ZAYA — Cahier des charges fonctionnel : régie publicitaire, monétisation et récompenses

> Transcription fidèle du document PDF « Cahier_des_charges_Regie_Publicitaire_ZAYA.pdf » transmis par le propriétaire
> le 17/11/2026 (version de travail du 17 novembre 2026). Destinataires : développeur Flutter, backend et administration
> Web. Environnement : Flutter, Supabase, administration Web.

## 1. Objectif général

Mettre en place dans ZAYA un système complet de monétisation comprenant :

- les publicités Google AdMob ;
- les publicités commerciales directes négociées par l'administrateur avec les entreprises ;
- un système de récompenses obtenu en regardant volontairement des publicités Google récompensées ;
- un portefeuille séparant les crédits publicitaires et les pièces achetées ;
- les swipes supplémentaires, les boosts de profil, les cadeaux virtuels et les compliments payants ;
- une administration centralisée pour contrôler les campagnes, récompenses, quotas et statistiques.

Les publicités peuvent être diffusées aux comptes gratuits comme aux comptes Premium. L'abonnement Premium ne supprime
donc pas automatiquement les publicités.

## 2. Les deux sources publicitaires

### 2.1 Publicités Google AdMob

Intégrer Google AdMob dans l'application Flutter. Formats envisagés : bannières, interstitiels et vidéos récompensées,
sous réserve de l'admissibilité de l'application et du respect des règles Google.

Les publicités récompensées doivent être proposées de manière volontaire et afficher clairement la récompense avant le
visionnage.

### 2.2 Publicités commerciales directes

L'administrateur négocie personnellement avec les entreprises, encaisse le paiement selon les modalités convenues, puis
crée manuellement les campagnes depuis l'administration Web. Aucun portail autonome de paiement annonceur n'est requis
dans cette première version.

Formats acceptés : images JPG, PNG ou WebP ; vidéos MP4, verticales ou horizontales. Chaque campagne comprend le nom de
l'entreprise, son logo, le média, le texte publicitaire, le bouton d'action, l'URL de destination, les dates, les
emplacements, le budget négocié et les statistiques.

### 2.3 Redirection publicitaire

Chaque campagne directe peut comporter une URL vers un site, WhatsApp, Facebook, Instagram, TikTok, une page commerciale
ou une application compatible avec les liens profonds. Le clic sur le média ou sur le bouton peut ouvrir la destination.
La redirection doit toujours résulter d'une action volontaire.

Les publicités directes ne doivent jamais attribuer de récompense en fonction d'un clic ou d'une interaction incitée.

## 3. Système de récompenses Google

### 3.1 Fonctionnement

Lorsqu'un utilisateur atteint la limite d'une fonctionnalité, ZAYA peut lui proposer les options autorisées : souscrire à
Premium si cette fonctionnalité fait partie des avantages Premium, ou regarder volontairement une publicité récompensée
pour obtenir un avantage ponctuel.

Exemple : « Vous avez atteint votre limite quotidienne de swipes. Découvrez Premium ou regardez une publicité pour
obtenir des swipes supplémentaires. »

Après confirmation fiable de la récompense par AdMob et validation côté serveur, ZAYA crédite l'avantage prévu.

### 3.2 Récompenses possibles

- Swipes supplémentaires.
- Crédit de boost utilisable uniquement sur le profil du bénéficiaire.
- Avantage temporaire de visibilité.
- Autres avantages numériques personnels, non transférables et autorisés par les règles applicables.

Les récompenses et leur valeur doivent être configurables depuis l'administration.

### 3.3 Sécurité

- Utiliser la Server-Side Verification (SSV) d'AdMob.
- Attribuer un identifiant unique à chaque transaction publicitaire.
- Empêcher les doubles crédits et les réutilisations de jetons.
- Enregistrer la date, l'utilisateur, le format et la récompense attribuée.
- Appliquer les limites quotidiennes côté serveur.
- Ne jamais créditer une récompense sur la seule base d'un événement Flutter non vérifié.

Les récompenses publicitaires doivent rester personnelles et non transférables. Elles ne doivent pas être convertibles
en argent ni en biens transférables.

## 4. Gestion des swipes

Mettre en place un quota quotidien de swipes, contrôlé côté serveur. Lorsque le quota est atteint, afficher les
possibilités autorisées : accès à Premium ou visionnage d'une publicité récompensée pour obtenir des swipes
supplémentaires.

Paramètres administrables : quota gratuit, quota Premium, swipes accordés par publicité, nombre maximal de publicités
récompensées par jour, heure de réinitialisation et activation/désactivation de la fonctionnalité.

> Décision du propriétaire du 17/11/2026 (conversation) : 50 swipes toutes les 8 heures pour un compte Gratuit, likes et
> passages comptés ensemble. La durée de la période est donc elle aussi un paramètre administrable.

## 5. Système de boost de profil

Permettre d'augmenter temporairement la visibilité d'un profil. Les moyens d'obtention peuvent être l'achat direct, un
avantage inclus dans un abonnement ou un crédit publicitaire personnel non transférable.

Paramètres : durée du boost, nombre de boosts, coût, nombre de publicités nécessaires si applicable, conditions
d'activation et dates de début/fin. Chaque activation doit être historisée.

## 6. Pièces et cadeaux virtuels

Créer une boutique de cadeaux virtuels. Les pièces achetées par les moyens de paiement autorisés pourront servir à acheter
des cadeaux et à les envoyer à d'autres utilisateurs, selon les règles de la boutique et les réglementations applicables.

### 6.1 Cadeaux aléatoires

Un mécanisme de récompense aléatoire peut être proposé uniquement après validation des règles applicables aux
récompenses, aux achats intégrés et aux jeux de hasard. Avant toute participation, afficher clairement les récompenses
possibles, les probabilités réelles, les conditions et les éventuels coûts. Ne pas présenter une récompense comme
garantie si elle est aléatoire.

Ne pas financer des cadeaux transférables destinés à d'autres utilisateurs avec des récompenses AdMob. Garder les crédits
publicitaires et les pièces achetées dans des catégories distinctes.

### 6.2 Administration des cadeaux

- Ajouter, modifier et désactiver un cadeau.
- Définir son nom, son image ou son animation.
- Définir son prix en pièces achetées et, si utile, sa rareté.
- Consulter les achats, cadeaux envoyés et statistiques d'utilisation.

## 7. Système de compliments

Les compliments sont une fonctionnalité payante de ZAYA, accessible selon les conditions commerciales définies : achat en
pièces et/ou avantages Premium. Prévoir un catalogue, les prix, l'envoi à un autre utilisateur, la notification au
destinataire et l'historique des compliments envoyés et reçus.

Les récompenses AdMob ne doivent pas financer des compliments transférables.

## 8. Portefeuille utilisateur

Afficher séparément trois catégories :

- Crédits publicitaires : swipes supplémentaires, boosts personnels et autres avantages non transférables.
- Pièces achetées : solde, achats, cadeaux achetés/envoyés et transactions.
- Avantages Premium : statut, dates de début et d'expiration, avantages actifs.

Chaque opération doit être historisée. Ne jamais mélanger les crédits publicitaires et les pièces achetées. Les soldes
doivent être calculés et modifiés côté serveur.

## 9. Administration Web — Régie publicitaire

### 9.1 Tableau de bord

- Campagnes actives, programmées, suspendues et terminées.
- Nombre d'annonceurs.
- Impressions et clics par campagne.
- Revenus directs négociés et encaissés, selon les données saisies.
- Revenus AdMob lorsque les données sont disponibles.
- Historique et performances des campagnes.

### 9.2 Gestion AdMob

Configurer les identifiants et unités publicitaires, activer/désactiver les formats, paramétrer les récompenses, définir
les limites quotidiennes et consulter les événements de récompense.

### 9.3 Gestion des annonceurs directs

Créer une fiche entreprise, ajouter ses coordonnées, créer une campagne, téléverser les médias, définir l'URL, les dates,
les emplacements, le budget, puis suspendre, reprendre ou archiver la campagne.

### 9.4 Statuts

Brouillon ; en attente de validation ; programmée ; active ; suspendue ; terminée ; archivée. Le démarrage et l'arrêt
doivent être automatiques selon les dates et le fuseau horaire défini pour ZAYA.

## 10. Administration des récompenses

Créer un module permettant d'activer/désactiver chaque récompense, définir les swipes accordés, les crédits de boost, les
limites quotidiennes et les règles d'attribution. L'administrateur doit consulter les récompenses distribuées, les comptes
bénéficiaires et les opérations suspectes.

Toute récompense aléatoire doit afficher des probabilités exactes et faire l'objet d'une validation juridique et
conformité avant mise en production.

## 11. Base de données Supabase

Prévoir au minimum les entités suivantes, à adapter au schéma existant : `advertisers`, `ad_campaigns`, `ad_creatives`,
`ad_placements`, `ad_impressions`, `ad_clicks`, `ad_reward_transactions`, `reward_configurations`, `user_wallets`,
`wallet_transactions`, `virtual_coins_transactions`, `user_boosts`, `virtual_gifts`, `gift_transactions`, `compliments`,
`user_swipe_quotas`, `premium_subscriptions`.

Définir les relations, index, contraintes d'intégrité et politiques RLS. Les opérations sensibles doivent passer par des
fonctions backend sécurisées. Les crédits et débits doivent être atomiques afin d'éviter les doublons et les soldes
incohérents.

## 12. Statistiques et rapports

- Impressions, clics et taux de clics par campagne.
- Campagnes les plus performantes.
- Revenus directs par entreprise et état de paiement saisi.
- Revenus AdMob disponibles.
- Nombre de vidéos récompensées visionnées et récompenses distribuées.
- Nombre de boosts activés.
- Nombre de cadeaux achetés/envoyés et compliments envoyés.

Les revenus AdMob doivent être présentés séparément des revenus des campagnes commerciales directes. Un clic ne doit être
comptabilisé qu'après une action réelle et valide.

## 13. Sécurité et conformité

- Respecter les règles AdMob et les conditions des boutiques d'applications.
- Demander le consentement explicite avant chaque publicité récompensée et annoncer la récompense à l'avance.
- Ne pas utiliser de récompenses publicitaires pour inciter à cliquer sur une publicité commerciale directe.
- Valider les récompenses côté serveur avec SSV et prévenir les doubles attributions.
- Séparer les crédits publicitaires des pièces achetées et empêcher les transferts non autorisés.
- Identifier clairement les annonces directes comme « Sponsorisé ».
- Modérer les contenus et vérifier les URL de destination.
- Appliquer les règles de confidentialité, de consentement et de protection des données pertinentes.

Avant le lancement, vérifier l'éligibilité de ZAYA à AdMob selon ses fonctionnalités, son contenu, son public et les
politiques Google en vigueur.

## 14. Principes d'architecture

- Flutter : interfaces, affichage des publicités, portefeuille, récompenses et interactions utilisateur.
- Supabase : authentification, base de données, stockage des médias, campagnes et historiques.
- Backend sécurisé : validation SSV, attribution des récompenses, quotas, soldes, prévention de la fraude et tâches
  planifiées.
- Administration Web : régie, annonceurs, campagnes, récompenses, quotas, cadeaux, statistiques et paramètres.

## 15. Exigences de livraison

- Module publicitaire Flutter.
- Intégration Google AdMob et tests des formats retenus.
- Gestion des publicités commerciales directes.
- Portefeuille séparant crédits publicitaires et pièces achetées.
- Récompenses publicitaires et validation serveur SSV.
- Gestion des quotas de swipes et des boosts.
- Boutique de cadeaux et système de compliments.
- Module Régie publicitaire dans l'administration Web.
- Tables, fonctions et politiques Supabase.
- Statistiques, journaux, contrôles de sécurité et tests fonctionnels.

Exigence finale : les paramètres commerciaux, quotas, récompenses, durées, emplacements et campagnes doivent être
configurables depuis l'administration Web, sans nécessiter une nouvelle version de l'application pour chaque modification,
sauf évolution technique nécessitant une mise à jour.

## Références techniques officielles

- Google AdMob — politiques des annonces récompensées : <https://support.google.com/admob/answer/7313578>
- Google Mobile Ads SDK pour Flutter — annonces récompensées : <https://developers.google.com/admob/flutter/rewarded>
- Google AdMob — Server-Side Verification : <https://developers.google.com/admob/android/ssv>

> Note au développeur (document d'origine) : ce document décrit les besoins fonctionnels. Les règles exactes d'AdMob, des
> boutiques d'applications, des paiements et des récompenses aléatoires devront être vérifiées avant le lancement.
> L'architecture finale doit être adaptée au code et au schéma Supabase déjà existants.
