# ZAYA — Cahier des charges complet

**Version consolidée 6.4 — 16 novembre 2026**  
Document fonctionnel, technique, UX/UI, sécurité, administration et guide de développement.

> Cette édition conserve intégralement la base V6.0 et les addenda V6.2/V6.3, puis ajoute les exigences V6.4 relatives aux moyens de paiement, à l’historique des abonnements et transactions, à la gestion administrative du Premium et aux badges Premium et Profil vérifié. Les nouvelles exigences sont détaillées dans l’addendum consolidé.

---

ZAYA — Cahier des charges complet
Version 6.0 — 14 novembre 2026
Document fonctionnel, technique, UX/UI, sécurité et guide de développement
Marché pilote : Guinée (Conakry)
Lancement : Android en premier — architecture Flutter compatible iOS

Historique de la version
La version 5.0 reprend la version 4.0 et intègre les compléments fonctionnels, administratifs, de sécurité, d'inscription,
d'assistance et d'événementiel validés le 14 novembre 2026. La version 4.0 reprenait la base fonctionnelle et technique de la
version 3.0, puis consolide les nouvelles décisions : application de rencontres sérieuses à vocation matrimoniale, accueil de
plusieurs confessions, préférences de découverte modifiables, profils enrichis avec vidéos courtes, notifications économiques,
SMS via Nimba SMS, application Flutter multiplateforme, interface d'administration, site vitrine, GitHub, Vercel, Supabase,
Railway en option, et collaboration Claude Code/Codex.
Elle ajoute notamment ZAYA SHOP, ZAYA EVENT, les réservations de lieux et de prestataires, les vitrines et portfolios
professionnels, les cadeaux à retirer en boutique, ainsi que le partage sécurisé de profils par liens profonds. Les décisions non
confirmées sont signalées comme telles. Les estimations et objectifs sont des hypothèses à valider, non des garanties
commerciales.

1. Vision et objectifs
ZAYA est une application de mise en relation destinée aux adultes qui souhaitent construire une relation sérieuse pouvant
conduire au mariage. Elle vise une expérience respectueuse, inclusive, sûre, fluide et adaptée aux réalités de la Guinée, avec
une possibilité d'extension à la diaspora et à d'autres pays.
La plateforme accueille notamment les personnes musulmanes, chrétiennes, d'autres confessions, sans religion ou ne
souhaitant pas préciser leur confession. ZAYA ne décide pas de la validité religieuse d'une union et ne remplace pas un conseil
religieux, juridique ou familial.

Objectifs principaux
• Faciliter le parcours inscription → profil → découverte → intérêt réciproque → match → conversation.
• Mettre l'accent sur les intentions sérieuses et la sécurité.
• Rester accessible sur des téléphones Android modestes et des connexions limitées.
• Commencer avec une infrastructure économique, puis évoluer selon l'audience.
• Préparer iOS dès le départ sans financer sa publication lors de la première phase.

Principes non négociables
• Accès réservé aux personnes de 18 ans et plus.
• Pas de nudité ni de contenu sexuel explicite.
• Pas de match sans intérêt réciproque.
• Blocage et signalement accessibles.
• Pas de publicité dans les conversations privées.
• Pas de ciblage publicitaire basé sur la religion, les messages ou d'autres données sensibles.
• Pas de vente de données personnelles.
• Aucun paiement obligatoire pour utiliser les fonctions essentielles de découverte et de mise en relation.
• Aucun score ne prétend prédire la réussite d'un mariage.

2. Périmètre de lancement



Le MVP comprend :
1. Application mobile Flutter, Android en premier et compatibilité iOS maintenue.
2. Backend et base de données Supabase.
3. Authentification par téléphone et code OTP.
4. Profils détaillés, photos et présentation vidéo courte.
5. Découverte et filtres, dont les préférences confessionnelles facultatives.
6. Likes, matchs réciproques et messagerie texte.
7. Blocage, signalement et outils de modération.
8. Notifications push à faible coût.
9. SMS Nimba pour OTP et alertes exceptionnelles.
10. Console web d'administration.
11. Site vitrine public.

Les fonctions coûteuses (appels audio/vidéo, traduction temps réel, diffusion vidéo lourde, système complexe de portefeuille ou
paiements internationaux) sont reportées après validation du MVP.

3. Inscription et onboarding
L'inscription doit être progressive, simple et sauvegarder les réponses en cas d'interruption. S'inspirer des bonnes pratiques de
parcours guidé observées dans les applications de rencontre, sans copier les textes, visuels, marques ou interfaces d'un
concurrent.

Étapes proposées
1. Présentation de ZAYA et de sa promesse.
2. Confirmation de l'âge minimum de 18 ans.
3. Intention de rencontre et projet matrimonial.
4. Confession religieuse facultative.
5. Préférences de découverte.
6. Informations personnelles et critères de profil.
7. Ajout de photos.
8. Présentation vidéo courte, facultative et soumise à modération.
9. Numéro de téléphone et vérification OTP.
10. Consentements et réglages de confidentialité.
11. Accès à la découverte après validation des étapes obligatoires.

Le numéro de téléphone ne doit jamais apparaître publiquement sur le profil.

4. Confessions et préférences de découverte
4.1 Confession déclarée
Choix possibles :
• Musulman(e)
• Chrétien(ne)
• Autre confession
• Sans religion
• Je préfère ne pas préciser




La déclaration est facultative. ZAYA ne doit jamais déduire la religion d'une personne à partir de son nom, de sa photo, de sa
localisation ou de ses conversations.

4.2 Préférence de découverte
L'utilisateur peut choisir :
• Ma confession uniquement.
• Une ou plusieurs confessions choisies.
• Toutes les confessions.
• Sans filtre confessionnel.

Le choix de découverte est distinct de la confession déclarée. Les deux paramètres peuvent être modifiés à tout moment dans
les paramètres du compte.

4.3 Règles de fonctionnement
• Le filtre agit uniquement sur les profils proposés dans la découverte.
• Il ne suspend pas et ne bloque pas les comptes des autres confessions.
• Les profils qui ne précisent pas leur confession ne doivent pas être classés arbitrairement.
• Les règles d'affichage des profils sans confession déclarée doivent être expliquées.
• Les données religieuses sont sensibles : consentement explicite, accès restreint, minimisation et aucune utilisation publicitaire.
• Les conversations entre adultes consentants restent soumises aux règles communautaires de ZAYA. L'application ne tranche
pas les questions de validité religieuse d'une union.

5. Profils et médias
Informations de profil
• Prénom ou pseudonyme.
• Âge, ville et pays.
• Photos choisies par le membre.
• Courte biographie.
• Profession, études et langues, facultatives.
• Situation matrimoniale et enfants, si l'utilisateur souhaite les indiquer.
• Valeurs, habitudes de vie, attentes et projet de vie.
• Intention et horizon de mariage.

Photos et vidéos
• Photos publiques contrôlées par l'utilisateur.
• Vidéo de présentation courte, par exemple 5 à 10 secondes, avec limites de taille, durée et format configurables.
• Contrôle des contenus avant publication ou modération rapide après publication.
• Compression automatique et chargement progressif.
• Pas de stories publiques au lancement si la modération et les coûts ne sont pas maîtrisés.
• Possibilité de retirer ou remplacer ses médias.

6. Découverte, likes, matchs et messagerie
Découverte
Filtres possibles : âge, pays, ville, distance approximative, langues, profession, études, situation matrimoniale, projet de vie et
préférences confessionnelles facultatives.




Les utilisateurs peuvent consulter les profils sans système public de followers ou de classement de popularité.

Likes et matchs
• Un match est créé uniquement après deux likes réciproques.
• Protection contre les likes répétés et les abus automatisés.
• Les limites quotidiennes gratuites sont configurables côté serveur et doivent être ajustées après observation de l'usage.
• La consultation des personnes ayant aimé le profil doit rester gratuite si cette promesse est retenue dans le modèle produit.

Messagerie
• Messagerie texte dans le MVP, réservée aux matchs.
• Blocage, signalement et fin de match accessibles depuis la conversation.
• Notifications par défaut sans afficher le contenu privé sur l'écran verrouillé.
• Photos, notes vocales, appels audio/vidéo et traduction : phases ultérieures après analyse de sécurité, coûts et modération.

7. Sécurité, confiance et modération
Vérification graduée
• Téléphone vérifié.
• Vérification photo/selfie avec consentement et procédure de suppression définie.
• Vérification d'identité éventuelle si le cadre légal et le budget le permettent.
• Les badges décrivent uniquement le contrôle effectué et ne garantissent pas l'honnêteté d'un membre.

Règles communautaires
Interdiction de nudité, contenus sexuels explicites, harcèlement, menaces, chantage, usurpation, escroquerie, spam, liens
malveillants et partage non consenti d'images.

Outils de sécurité
• Signalement depuis un profil et une conversation.
• Blocage immédiat entre deux comptes.
• File de modération avec priorités et historique.
• Avertissement, restriction, suspension ou bannissement selon gravité.
• Possibilité d'appel et de réexamen humain.
• Avertissement anti-arnaque : ne jamais envoyer d'argent à une personne rencontrée en ligne.
• Modération et support réellement disponibles avant ouverture publique.

Objectifs initiaux de traitement à valider : critique < 2 h ; élevé < 12 h ; normal < 24 h ; faible < 72 h.

8. Cercle de confiance
Fonction facultative et contrôlée par le membre. L'utilisateur peut inviter un proche et choisir précisément les permissions :
• Voir le profil.
• Voir certains éléments de progression relationnelle.
• Être informé qu'un échange sérieux a commencé.
• Participer à une conversation de groupe uniquement si toutes les personnes concernées l'acceptent.

Aucun accès par défaut aux messages privés. Les accès doivent être journalisés, visibles et révocables à tout moment.

9. Notifications et SMS à budget maîtrisé



Notifications push
Utiliser Firebase Cloud Messaging (FCM) pour les notifications push, sans coût SMS par événement. Prévoir les événements :
• Nouveau match.
• Nouveau message.
• Vérification ou sécurité du compte.
• Rappel de complétion du profil, uniquement si l'utilisateur l'accepte.
• Informations de service.

Confidentialité
• Ne pas afficher le texte des messages dans les notifications par défaut.
• Ne pas révéler la confession, les préférences sensibles ou les détails privés.
• Séparer les notifications essentielles des notifications marketing.
• Permettre de désactiver certaines catégories et de définir des heures silencieuses.

Nimba SMS
Utiliser l'API Nimba SMS principalement pour :
• OTP de vérification du numéro.
• Récupération ou sécurisation du compte lorsque nécessaire.
• Alertes de sécurité exceptionnelles.

Ne pas envoyer de SMS pour chaque like, match ou message. Prévoir une limitation des tentatives, un délai de renvoi, un
plafond de dépenses et un journal des coûts. Les clés API restent côté serveur, jamais dans l'application mobile.
Avant intégration, confirmer la documentation API, les tarifs, la couverture, l'identifiant expéditeur, les limites, les accusés de
livraison et les conditions contractuelles.

10. Architecture technique et hébergement progressif
Technologies recommandées
Élément | Technologie | Utilisation
Application mobile | Flutter / Dart | Une base de code Android et iOS
Backend | Supabase | Auth, PostgreSQL, stockage, Realtime, fonctions
Notifications push | Firebase Cloud Messaging | Android puis iOS avec APNs
SMS | API Nimba SMS | OTP et alertes exceptionnelles
Site et administration | Next.js / TypeScript | Web public et console admin
Hébergement web | Vercel | Site vitrine et admin
Code source | GitHub | Dépôt, branches, versions et revues
Services optionnels | Railway | Jobs/API spécifiques si besoin futur
Monitoring | Sentry ou équivalent | Erreurs et performances

Pourquoi Flutter ?
Le même projet Flutter sert de base à Android et iOS. Le lancement se fait sur Android, mais les dépendances, permissions,
navigation, médias et notifications doivent être conçus pour rester compatibles iOS.
La publication iOS nécessitera ultérieurement macOS/Xcode, un compte Apple Developer, la configuration APNs, les tests et la
validation App Store.

Architecture économique
• Commencer avec les offres gratuites ou les plus petites offres adaptées, après vérification de leurs limites et conditions.




• Séparer développement, préproduction et production.
• Ne pas multiplier les services avant d'en avoir le besoin.
• Garder Railway optionnel au départ si Supabase couvre les besoins.
• Mesurer les coûts réels : stockage, bande passante, OTP, notifications, médias, monitoring et modération.
• Prévoir une migration progressive sans réécrire l'application mobile.

Organisation GitHub proposée
zaya/
mobile/
flutter_app/
lib/
assets/
test/
android/
ios/
web/
admin/
landing/
supabase/
migrations/
functions/
seed/
documentation/
cahier-des-charges/
architecture/
api/
securite/
tests/
AGENTS.md
README.md

Environnements
• Développement : données fictives et clés de test.
• Staging : préproduction isolée.
• Production : secrets séparés, sauvegardes, monitoring et accès restreints.

Aucun secret, token ou clé service_role ne doit être enregistré dans GitHub ni dans le code mobile.

11. Interface d'administration
Modules attendus :
• Tableau de bord : inscriptions, utilisateurs actifs, profils complets, matchs, signalements et revenus agrégés.
• Gestion des comptes : recherche, suspension, réactivation et historique.
• Modération : photos, vidéos, signalements et appels.
• Vérifications : suivi des niveaux de vérification.
• Notifications : modèles, catégories, campagnes de service et statistiques.
• SMS : suivi des envois, erreurs et dépenses Nimba.
• Publicité : campagnes, annonceurs, calendrier et rapports agrégés.




• Finance : transactions, remboursements et rapprochements.
• Paramètres : configuration générale et options activables.
• Sécurité : rôles, permissions et journal d'audit.

Rôles
Super-administrateur, modérateur, support, responsable financier, gestionnaire publicité et administrateur technique. Appliquer
le principe du moindre privilège.
La console ne doit pas permettre la lecture libre des conversations privées. Toute exception nécessaire à une enquête de
sécurité doit être justifiée, limitée et auditée.

12. Site vitrine
Le site public doit contenir :
• Présentation de ZAYA et explication du fonctionnement.
• Liens de téléchargement Google Play au lancement.
• Page iOS activable lorsque l'application sera prête.
• FAQ.
• Politique de confidentialité.
• Conditions d'utilisation.
• Règles communautaires et sécurité.
• Contact et assistance.
• Présentation des partenariats et annonceurs.

Le site doit être responsive, rapide, accessible et optimisé pour les connexions mobiles.

13. UX/UI, animations et performance
Direction artistique
Respecter le logo et l'identité visuelle ZAYA. Interface moderne, épurée, chaleureuse, professionnelle et cohérente.
Typographie lisible, contrastes suffisants, composants réutilisables et espaces réguliers.

Animations souhaitées
• Transitions de navigation rapides et naturelles.
• Micro-interactions sur les boutons, likes, matchs, cartes et changements d'onglet.
• Animation de match élégante et courte.
• Skeleton loading et transitions entre chargement, contenu et états vides.
• Gestes fluides sur les cartes, avec boutons alternatifs accessibles.
• Respect de la préférence système de réduction des animations.
• Aucune animation ne doit bloquer l'interaction.

Performance
• Viser 60 images/seconde sur appareils compatibles.
• Optimiser pour les Android d'entrée de gamme.
• Compresser les images et charger progressivement.
• Limiter les vidéos et effets lourds.
• Prévoir les états hors ligne, erreur réseau, chargement et absence de résultats.
• Mesurer la taille réelle de l'application et la consommation de données.




14. Modèle économique
Pistes à évaluer :
• Publicité AdMob conforme aux politiques applicables.
• Campagnes directes avec opérateurs télécoms, banques et marques.
• Cadeaux virtuels non convertibles en argent au lancement.
• Premium facultatif, sans bloquer les fonctions essentielles.
• Partenariats et services complémentaires en phase ultérieure.

Aucune publicité dans les conversations. Aucun ciblage à partir des données sensibles. Les campagnes sponsorisées doivent
être clairement identifiées. Vérifier les politiques Google Play/AdMob et les règles locales avant activation.
Les revenus ne sont pas garantis. Le business plan doit intégrer eCPM, impressions, campagnes directes, coûts d'acquisition,
modération, SMS, stockage, bande passante, frais de paiement et taxes.

15. Protection des données
• Collecter uniquement les données nécessaires.
• Consentements distincts lorsque requis, notamment pour les données religieuses, biométriques, notifications et marketing.
• Ne jamais vendre les données personnelles.
• Aucun accès public aux numéros de téléphone.
• Chiffrement en transit et protection des données stockées.
• Contrôle d'accès par rôle et journalisation des actions sensibles.
• Suppression de compte et politique de conservation documentées.
• Localisation limitée à la ville ou à une zone approximative.
• Sauvegardes et tests de restauration.
• Procédure de réponse aux incidents.
• Données religieuses et biométriques traitées comme particulièrement sensibles.

16. Instructions pour Claude Code et Codex
Les assistants doivent construire un produit réellement exécutable, testé et documenté, pas une simple maquette.

Méthode obligatoire
1. Lire le cahier des charges et AGENTS.md.
2. Auditer le dépôt existant avant de modifier quoi que ce soit.
3. Présenter l'architecture, les risques, les questions bloquantes et un plan par lots.
4. Définir le design system et les parcours prioritaires.
5. Mettre en place les environnements, conventions, lint, tests et CI.
6. Développer par lots : onboarding, authentification, profil, découverte, likes/match, messagerie, sécurité, admin, site vitrine.
7. Pour chaque lot, fournir critères d'acceptation, tests, documentation et résumé.
8. Ne jamais déployer en production ni engager une dépense sans autorisation explicite.

Collaboration
• Éviter que Claude Code et Codex modifient simultanément les mêmes fichiers.
• Utiliser des branches ou des tâches séparées.
• Claude peut implémenter un lot ; Codex peut effectuer une revue indépendante.
• Documenter les modifications, migrations, tests et risques.




• Ne jamais prétendre qu'un test ou une intégration a réussi s'il n'a pas été exécuté.
• Ne jamais inventer de clés API ni exposer les secrets.

Prompt de démarrage à envoyer à Claude Code
> Tu es l'architecte technique et le développeur principal du projet ZAYA. Lis intégralement
ZAYA_Cahier_des_charges_v2.0_complet.md et AGENTS.md. Commence par auditer le dépôt existant sans écraser de
fichiers. Présente l'architecture, les choix techniques, les risques, les questions bloquantes, les lots de développement et les
critères d'acceptation. Construis une application Flutter Android-first compatible iOS, avec Supabase, une console Next.js
d'administration et un site vitrine. Respecte les exigences de confidentialité, les préférences confessionnelles facultatives, les
notifications économiques, la modération et les performances décrites. Ne code pas tout en une seule fois : avance par lots
testables. Après chaque lot, exécute les tests disponibles, corrige les erreurs et documente précisément ce qui est terminé,
restant ou non vérifié. Ne déploie rien en production et n'engage aucune dépense sans mon accord.

Prompt de revue à envoyer à Codex
> Agis comme reviewer indépendant du projet ZAYA. Lis le cahier des charges et AGENTS.md, puis examine les changements
proposés sans réécrire tout le projet. Recherche en priorité les failles de sécurité, erreurs de logique, défauts RLS, fuites de
données, problèmes de confidentialité, bugs Flutter/iOS, problèmes d'accessibilité et de performance, erreurs de migration et
tests manquants. Classe les constats par criticité, indique les fichiers et les scénarios reproductibles, puis propose des
corrections minimales. Distingue les tests réellement exécutés des hypothèses.

17. Plan de réalisation
Phase | Travaux | Priorité
0 | Cadrage, maquettes, architecture, sécurité et budget | Avant développement
1 | GitHub, Flutter, Supabase, CI, authentification | P0
2 | Profil, médias, découverte, filtres, likes, matchs, chat | P0
3 | Vérification, blocage, signalement, modération, admin | P0 avant lancement
4 | Site vitrine, FAQ, politiques, assistance | P0/P1
5 | Pilote à Conakry, mesures et corrections | Avant acquisition large
6 | Publicité, cadeaux et Premium facultatif | Après validation
7 | iOS, diaspora, fonctions audio/vidéo et extensions | Progressif

18. Tests et critères de lancement
Tests fonctionnels
• Inscription, âge minimum, reprise d'onboarding et OTP.
• Création, modification, masquage et suppression de profil.
• Filtres confessionnels, profils sans confession déclarée et changement de préférences.
• Likes, matchs réciproques et messagerie.
• Blocage, signalement, sanctions et appels.
• Permissions admin et journal d'audit.
• Notifications push et SMS de test.
• Site vitrine et console admin sur mobile et ordinateur.

Tests non fonctionnels
• Android entrée et milieu de gamme.
• Réseau lent, coupures et reconnexion.
• Fluidité, mémoire, batterie et taille de l'application.
• Sécurité des API, règles RLS, accès non autorisés et secrets.
• Sauvegarde, restauration et reprise après incident.




• Compatibilité iOS continue avant publication.

Conditions minimales de lancement public
• Aucun accès non autorisé aux profils ou conversations.
• Blocage et signalement fonctionnels.
• Modération et support opérationnels.
• Politiques, conditions et règles communautaires publiées.
• Sauvegardes, monitoring et procédure d'incident vérifiés.
• Politiques des plateformes et contrats prestataires validés.
• Paiements et publicités désactivés tant que leur conformité n'est pas vérifiée.

19. Indicateurs du pilote
Hypothèses de départ à mesurer, et non garanties :
• 500 à 1 000 profils inscrits à Conakry.
• Au moins 60 % de profils complétés.
• Au moins 50 % de photos vérifiées.
• Rétention J30 supérieure à 25 %.
• Suivi des matchs menant à une conversation réciproque.
• Signalements pour 1 000 utilisateurs et respect des délais.
• Satisfaction volontaire supérieure à 4/5.
• Suivi des crashs, coûts SMS, stockage, bande passante et modération.

20. Décisions à confirmer
Avant le développement complet, le propriétaire du projet doit confirmer :
• Nom légal de l'éditeur et statut juridique.
• Pays et zones de lancement.
• Liste finale des confessions et libellés.
• Champs obligatoires et facultatifs des profils.
• Règles détaillées du Cercle de confiance.
• Tarifs, documentation et couverture de Nimba SMS.
• Fournisseur et règles de vérification selfie/identité.
• Budget et capacité de modération.
• Emplacements et fréquences publicitaires.
• Prix et règles des cadeaux ou Premium.
• Contrats Orange Money/MTN MoMo si des paiements sont prévus.
• Calendrier iOS et disponibilité d'un environnement Mac/Xcode.

Une décision non confirmée doit rester configurable ou être identifiée comme bloquante. Claude Code et Codex ne doivent pas
inventer ces décisions.

21. Livrables attendus
• Code source Flutter Android/iOS.
• Backend Supabase : migrations, fonctions, stockage et politiques RLS.
• Console d'administration web.




• Site vitrine responsive.
• Design system et maquettes des parcours essentiels.
• AGENTS.md, README.md, documentation architecture, base, API, sécurité, tests et déploiement.
• CI, environnements séparés, sauvegardes et procédure de restauration.
• Rapport de recette, anomalies et statut des critères d'acceptation.

Note : ce cahier des charges est un document produit et technique évolutif. Il ne remplace pas une consultation juridique,
réglementaire, fiscale, financière ou religieuse en Guinée et dans les pays d'extension.

22. Compléments fonctionnels validés — Version 2.1
Cette section complète les modules précédents. En cas de doublon, elle précise le comportement attendu sans supprimer les
exigences de sécurité et de confidentialité déjà définies.

22.1 Découverte « Rencontre » et « Mariage »
• Prévoir un accès clairement identifié à la rubrique Rencontre / Découverte et, si le produit le retient, à une rubrique Mariage
présentant les profils dans une perspective sérieuse.
• À l'ouverture, afficher une animation courte et légère de recherche/découverte, puis les cartes de profils. L'animation ne doit
jamais retarder l'accès aux profils.
• Les cartes doivent être fluides (glisser pour aimer/passer), avec des boutons accessibles comme alternative au geste.
• Toutes les fonctionnalités s'appliquent de manière équivalente aux profils féminins et masculins, sans parcours réservé à un seul
genre.
• Les profils proposés respectent les préférences définies par chaque membre : âge, ville, pays, distance, langues, projet de vie et
autres filtres autorisés.

22.2 Recherche géographique et extension Afrique de l'Ouest
• À l'inscription, demander le pays de résidence et la ville ; le pays d'origine peut être renseigné séparément et reste facultatif.
• Prévoir une sélection de pays et de villes maintenue depuis l'administration, avec lancement en Guinée et ouverture progressive
aux pays d'Afrique de l'Ouest.
• Rayons de recherche configurables : 5 km, 10 km, 20 km, 50 km, 100 km, puis « toute la ville », « tout le pays » et « autres pays
».
• La recherche à proximité utilise une position approximative et uniquement après autorisation explicite du système. Ne jamais
afficher l'adresse exacte ni la position en temps réel d'un membre.
• Permettre de désactiver la découverte locale, de masquer sa distance ou de choisir une ville manuellement.
• La recherche dans le pays de résidence doit rester accessible dans l'offre gratuite, dans des limites raisonnables et
configurables. L'accès multi-pays, la diaspora et les filtres géographiques avancés peuvent être des avantages Premium, sans
empêcher les fonctions essentielles de rencontre.
• La localisation doit être arrondie/approximée, protégée contre les tentatives de triangulation et non utilisée pour de la publicité
ciblée.

22.3 Suggestions intelligentes et notifications de proximité
• Envoyer, uniquement si les notifications sont autorisées, une alerte lorsqu'un nouveau profil pertinent rejoint ZAYA ou devient
actif dans une zone approximative proche de l'utilisateur.
• Exemple de formulation : « De nouveaux profils correspondant à vos critères sont disponibles près de vous. »
• Les notifications doivent être neutres et non genrées : elles peuvent concerner tout profil correspondant aux préférences
mutuelles, qu'il soit féminin ou masculin.
• Le moteur de recommandation peut proposer plusieurs profils dont les critères déclarés sont compatibles, sans promettre qu'un
Match aura lieu ni révéler des informations privées.
• Exemple : « Nous avons trouvé de nouveaux profils qui pourraient correspondre à vos critères. »




• Les suggestions doivent tenir compte de l'activité réelle, des préférences, de la fraîcheur du profil, de la sécurité et de la diversité
des résultats. Ne pas favoriser uniquement les profils payants.
• Respecter une fréquence maximale configurable, les heures silencieuses, les préférences de notification et un mécanisme de
désinscription simple.
• Ne pas envoyer de notification révélant le nom d'une personne, son activité précise ou sa localisation sur un écran verrouillé,
sauf choix explicite de l'utilisateur.

22.4 Likes, quota et propositions Premium contextuelles
• Le nombre de Likes gratuits par jour est configurable côté serveur. Le quota et l'heure de renouvellement doivent être affichés
clairement.
• Lorsque le quota est atteint, bloquer le Like supplémentaire et présenter un écran explicatif proposant : attendre le
renouvellement gratuit ou consulter Premium.
• L'offre Premium peut inclure des Likes/swipes illimités, sous réserve de limites anti-abus raisonnables, ainsi que les avantages
listés dans la grille tarifaire.
• Les propositions Premium peuvent apparaître au moment pertinent (quota atteint, demande d'un filtre réservé, demande d'une
recherche internationale), mais ne doivent pas être trompeuses, répétitives ou impossibles à fermer.
• Ne jamais prétendre qu'une personne précise attend l'utilisateur, qu'un Match est garanti ou qu'une opportunité va disparaître si
ce n'est pas vrai.
• Le membre peut fermer l'offre et continuer à utiliser les fonctions gratuites disponibles.

22.5 Abonnements Premium
• Prévoir trois durées : hebdomadaire (7 jours), mensuelle (30 jours) et trimestrielle (90 jours).
• Prix, avantages, taxes, durée, renouvellement automatique éventuel, date de prochaine facturation et conditions d'annulation
doivent être affichés avant paiement.
• Les tarifs sont configurables dans l'administration et adaptés aux moyens de paiement réellement disponibles dans chaque
pays.
• Prévoir un historique des achats, reçus, états de paiement, échecs, remboursements et expiration.
• Le renouvellement automatique ne peut être activé qu'avec un consentement explicite ; l'annulation doit être simple.
• Premium reste facultatif. Aucun paiement ne doit être nécessaire pour créer un profil, voir les profils accessibles selon les
critères de base, envoyer un nombre raisonnable de Likes ou obtenir un Match réciproque.
• La comparaison Gratuit/Premium doit être claire, stable et visible dans l'application.

22.6 Boost de profil indépendant de Premium
• Acheter un Boost ponctuel sans souscrire à Premium.
• Prix de référence demandé : 5 000 GNF pour 24 heures. Ce tarif est une proposition initiale à confirmer et doit être modifiable
depuis l'administration.
• Pendant le Boost, le profil peut bénéficier d'une visibilité supplémentaire dans les emplacements de découverte pertinents, selon
les préférences et la sécurité.
• Le Boost ne doit jamais contourner les filtres mutuels, les blocages, les signalements, les contrôles de modération ou les
préférences de l'autre membre.
• Afficher clairement le début, la fin, le prix et le statut du Boost. Aucun renouvellement automatique sans consentement.
• Distinguer les profils boostés avec une mention appropriée si nécessaire ; ne jamais présenter la visibilité payante comme une
vérification ou une garantie de compatibilité.
• L'administration configure les prix, durées, campagnes promotionnelles et statistiques.

22.7 Statistiques de consultation du profil
• Ajouter un écran « Visites du profil » indiquant le nombre de consultations sur des périodes définies (par exemple 7 et 30 jours).
• Distinguer les vues totales des visiteurs uniques afin d'éviter les doubles comptages trompeurs.




• L'identité des visiteurs ne peut être révélée que si le visiteur a choisi une option de visibilité explicite et si les règles de
confidentialité le permettent.
• Prévoir un mode de navigation discrète : un membre qui le choisit n'apparaît pas dans la liste nominative des visiteurs. Les
statistiques agrégées peuvent rester disponibles.
• Le nombre de visites ne doit pas inclure les préchargements techniques, les robots ou les propres consultations du titulaire du
profil.
• Les statistiques détaillées peuvent être un avantage Premium, mais le total agrégé peut être offert gratuitement selon la
stratégie commerciale.

22.8 Vérification obligatoire du profil et badge bleu
• La vérification est une étape obligatoire avant la publication du profil dans la découverte.
• Exiger au minimum trois photos de profil conformes, puis une vérification de présence/visage par selfie guidé ou procédure
équivalente.
• La vérification compare le selfie de contrôle aux photos du profil à l'aide d'un prestataire évalué et/ou d'une revue humaine en
cas d'échec. Le contrôle doit fonctionner équitablement sur différentes carnations et conditions d'éclairage.
• Après validation, attribuer un badge bleu « Profil vérifié » et envoyer un e-mail de confirmation si une adresse e-mail a été
fournie et vérifiée. Une notification dans l'application confirme aussi le résultat.
• Le badge certifie uniquement que le contrôle défini a été passé ; il ne garantit ni l'identité civile complète, ni l'honnêteté, ni la
sécurité d'une personne.
• Si le membre supprime des photos et passe sous le minimum requis de trois photos, retirer automatiquement le badge et
suspendre temporairement l'apparition du profil dans la découverte jusqu'au rétablissement du minimum et, si nécessaire, à une
nouvelle vérification.
• Prévenir l'utilisateur avant la suppression de la dernière photo nécessaire et expliquer les conséquences.
• Si une photo est retirée par modération, appliquer la même règle et proposer une procédure de recours.
• Prévoir une vérification manuelle de secours, un statut « en attente », « validé », « refusé » ou « à refaire », et un historique des
décisions.
• Les selfies et données biométriques sont sensibles : consentement explicite, minimisation, chiffrement, durée de conservation
limitée, accès restreint et suppression selon une politique documentée.

22.9 Gestion du compte, données et authentification renforcée
• Permettre de modifier les informations du compte, l'adresse e-mail et le numéro selon une procédure de vérification.
• Permettre de changer le mot de passe si une authentification par mot de passe est utilisée ; prévoir également la récupération
sécurisée du compte.
• Proposer le verrouillage local de l'application par biométrie : empreinte digitale sur appareils compatibles et Face ID sur iPhone,
via les mécanismes natifs du système. La biométrie locale ne doit pas être envoyée au serveur.
• Permettre l'activation/désactivation du verrouillage biométrique, avec solution de secours par code de l'appareil ou méthode
sécurisée.
• Permettre de télécharger/exporter les données personnelles dans un format courant, après vérification de l'identité.
• Permettre de demander la suppression du compte depuis l'application, avec confirmation claire, délai éventuel expliqué et
traitement effectif des données selon les obligations légales.
• Expliquer les données conservées temporairement pour obligations légales, prévention de fraude ou sécurité, sans conserver
inutilement les conversations et médias.
• La désactivation temporaire du profil doit être distincte de la suppression définitive du compte.
• Prévoir une page « Confidentialité et sécurité » regroupant sessions/appareils, mots de passe, biométrie, données,
consentements, notifications, blocages et suppression.

22.10 Messagerie enrichie et Zaya AI
• Après un Match réciproque, proposer d'ouvrir directement la conversation avec un accueil chaleureux.
• Ajouter des messages de départ prédéfinis et des cartes de questions pour faciliter les premiers échanges.
• Zaya AI peut proposer des réponses, reformulations, traductions et idées de sujets en fonction du contexte, uniquement avec
information claire et contrôle de l'utilisateur. Elle ne doit jamais envoyer un message sans validation explicite.




• Prévoir texte, emojis, stickers, GIFs autorisés, images, notes vocales, appels audio et appels vidéo dans les phases prévues.
• Ajouter des widgets de conversation : questions pour faire connaissance, sondage à deux, proposition de rendez-vous, carte
d'invitation et rappel accepté par les deux personnes.
• Lorsqu'une phrase ressemble à une proposition de rencontre (« On peut se voir demain ? »), suggérer facultativement de créer
une invitation avec date, créneau, ville/lieu public et confirmation mutuelle. Ne pas créer ou envoyer automatiquement un
rendez-vous.
• Proposer le partage facultatif du rendez-vous à une personne de confiance et un rappel de sécurité avant/après la rencontre.
• Les images envoyées doivent être contrôlées contre la nudité, le contenu sexuel, la violence et les contenus interdits. Prévoir
blocage ou floutage, avertissement, signalement et recours humain.
• La modération doit respecter la vie privée : minimiser l'analyse, expliquer les contrôles et ne pas utiliser le contenu des
conversations pour la publicité.

22.11 Appels audio, vidéo et messages vocaux
• Intégrer, dans une phase ultérieure, des appels audio et vidéo directement depuis une conversation, avec une connexion rapide
et une qualité adaptative.
• Utiliser une technologie temps réel éprouvée (WebRTC ou fournisseur spécialisé) après tests de latence, qualité, couverture
réseau et coût.
• Prévoir autorisation micro/caméra, acceptation de l'appel, refus, raccrochage, blocage et signalement.
• Optimiser pour les connexions faibles : adaptation de résolution, reprise réseau et bascule audio si la vidéo devient instable.
• Ajouter l'envoi et la lecture de notes vocales, avec durée maximale, indicateur d'enregistrement et possibilité de supprimer son
propre message selon les règles.
• Aucun appel ne doit être imposé ou déclenché automatiquement.

22.12 Zaya Shop : cadeaux, emojis et éléments virtuels
• Ajouter une boutique intégrée proposant des packs d'emojis, stickers, thèmes et cadeaux virtuels.
• Afficher le prix en GNF et, selon le pays, dans la devise locale disponible ; confirmer le montant avant achat.
• Les cadeaux virtuels sont des éléments symboliques. Ils ne sont pas convertibles en argent au lancement et ne doivent pas être
présentés comme un placement ou une récompense financière.
• Prévoir catalogue, aperçu, achat, historique et remboursement selon les règles applicables.
• Aucun tirage au sort payant, pari ou mécanisme aléatoire payant.

22.13 Publicité : AdMob et annonceurs directs
• Prévoir Google AdMob pour les formats publicitaires autorisés sur mobile, après validation des politiques et du compte éditeur.
• Prévoir dans l'administration un gestionnaire de campagnes directes : annonceur, visuel image ou vidéo, format/dimensions,
période, ciblage contextuel non sensible, fréquence, budget, statut et rapport.
• Les annonceurs directs (par exemple opérateurs télécoms ou marques locales) doivent pouvoir fournir une création validée par
l'équipe ZAYA.
• Les publicités doivent être identifiées comme sponsorisées. Aucune publicité dans les conversations privées, aucune publicité
ciblée à partir des messages, de la religion ou de données sensibles.
• Ne pas imposer une publicité vidéo non désactivable à chaque série de profils. Respecter les formats, fréquences et règles de
consentement des réseaux publicitaires.
• Prévoir des formats natifs ou interstitiels avec fréquence plafonnée, et récompensés uniquement si le format et la politique le
permettent.
• L'administration doit pouvoir mettre en pause une campagne immédiatement.

22.14 Conditions d'utilisation et parcours d'inscription
• Avant la création/activation du compte, présenter les Conditions d'utilisation, la Politique de confidentialité et les Règles
communautaires dans une langue comprise par l'utilisateur.
• Exiger une acceptation explicite et enregistrer la version du document, la date, l'heure et la preuve du consentement.




• Les consentements marketing, notifications, géolocalisation et traitement biométrique doivent être distincts lorsqu'ils sont
nécessaires ; ne pas les fusionner avec l'acceptation des conditions.
• Permettre de consulter à nouveau les documents depuis les paramètres et demander une nouvelle acceptation en cas de
modification importante.
• L'utilisateur doit pouvoir refuser les permissions facultatives sans perdre l'accès aux fonctions qui n'en dépendent pas.

22.15 Langues et localisation de l'expérience
• Prévoir au minimum français et anglais pour l'interface.
• Préparer les traductions du poular/pular, du maninka/malinké et du soussou pour la Guinée ; le wolof peut être ajouté pour le
Sénégal et l'expansion régionale.
• Le choix de langue de l'interface est indépendant des langues parlées indiquées sur le profil.
• Prévoir une architecture de traduction centralisée, des textes relus par des locuteurs compétents et une option de signalement
d'une traduction incorrecte.
• Les traductions de conversations doivent conserver le message original et afficher clairement la version traduite.
• Ne pas prétendre qu'une langue est entièrement prise en charge avant validation humaine des écrans et messages essentiels.

22.16 Console d'administration et règles configurables
Ajouter des paramètres administrables pour :
• Quota quotidien de Likes gratuit et heure de renouvellement.
• Avantages et prix Premium hebdomadaire, mensuel et trimestriel.
• Prix/durée du Boost (valeur initiale proposée : 5 000 GNF / 24 h).
• Rayon de recherche, pays activés et règles de découverte internationale.
• Nombre minimal de photos, règles de vérification et statuts de badge.
• Fréquence, heures silencieuses et catégories des notifications.
• Campagnes publicitaires, formats, dimensions, périodes et plafonds de fréquence.
• Catalogue Zaya Shop, prix et disponibilité.
• Langues actives et textes légaux par version.
• Rôles, permissions et journal d'audit.

Toute modification sensible doit être journalisée, avec date, administrateur et ancienne/nouvelle valeur.

22.17 Engagement responsable et mesure
Le module ZAYA Engagement Engine personnalise l'expérience sans enfermer l'utilisateur :
• suggestions de profils fondées sur les préférences déclarées et la pertinence ;
• rappels discrets pour les nouveaux profils pertinents, nouveaux messages ou renouvellement du quota ;
• propositions Premium uniquement lorsqu'elles répondent à une action ou une limite réelle ;
• notifications plafonnées, désactivables et respectant les heures silencieuses ;
• aucun faux compte à rebours, fausse rareté, fausse notification de Like ou fausse promesse de Match ;
• aucun ciblage publicitaire à partir des conversations, de la religion ou de données sensibles ;
• aucun classement payant qui ferait disparaître les profils non payants.

Indicateurs à suivre : utilisateurs actifs, retour après notification, désactivation des notifications, conversion Premium,
renouvellement, achats de Boost, qualité des matchs, conversations réciproques, signalements et satisfaction. La durée de
session n'est pas un objectif isolé : la réussite de ZAYA se mesure aussi à la qualité et à la sécurité des rencontres.

22.18 Priorisation de livraison
Lot | Fonctionnalités | Priorité




A | Inscription, conditions, profils, vérification obligatoire, découverte, filtres, likes/match, sécurité et suppression de compte | Indispensable avant
ouverture
B | Visites de profil, Boost, Premium, quotas, notifications pertinentes et console de gestion | Après pilote fonctionnel
C | Messagerie enrichie, photos modérées, vocaux, appels audio/vidéo, rendez-vous et Zaya AI | Déploiement progressif
D | Zaya Shop, packs emojis/cadeaux, langues nationales avancées et extension multi-pays | Selon adoption et budget

Chaque lot doit être chiffré, testé sur Android d'entrée de gamme et réseau lent, puis activé progressivement. Les prix, quotas,
pays et avantages commerciaux restent des paramètres à confirmer avant développement et publication.

ADDENDUM — VERSION 2.2
Écosystème, compatibilité, sécurité et croissance de ZAYA
Version : 2.2
Date : 14 novembre 2026
Statut : Extension fonctionnelle proposée — à valider avant développement
Principe directeur : faire de ZAYA une plateforme de rencontres sérieuses et de préparation au mariage, sûre, inclusive,
respectueuse de la vie privée et adaptée aux réalités de la Guinée et de l'Afrique de l'Ouest.
Cet addendum complète la version 2.1. En cas de contradiction, les règles de sécurité, de consentement, de confidentialité et de
conformité légale les plus protectrices prévalent. Les fonctionnalités ci-dessous doivent être estimées, priorisées et validées
avec les équipes produit, technique, juridique et modération.

1. Moteur de compatibilité intelligente — ZAYA Compatibility
1.1 Objectif
Compléter la découverte par photos et préférences avec une recommandation fondée sur les attentes déclarées par les
membres. Le système ne doit pas prétendre prédire la réussite d'un couple.

1.2 Critères configurables
• Intention relationnelle et horizon souhaité pour le mariage.
• Valeurs, pratiques et attentes personnelles que chaque membre choisit explicitement de renseigner.
• Projet familial et souhait d'avoir ou non des enfants.
• Style de communication, tempérament et centres d'intérêt.
• Études, activité professionnelle et projets de vie, uniquement si l'utilisateur choisit de les partager.
• Langues parlées, pays, ville et mobilité géographique.
• Préférences mutuelles, limites et critères non négociables.

1.3 Fonctionnement et interface
• Questionnaire progressif, facultatif par rubrique, avec possibilité de modifier ou masquer les réponses.
• Score ou niveau de compatibilité accompagné d'explications compréhensibles : intérêts communs, attentes alignées et sujets à
discuter.
• Recommandations réciproques : un profil n'est proposé que si les préférences et paramètres de visibilité des deux personnes
sont compatibles.
• Possibilité de désactiver la personnalisation et de consulter les profils selon les critères classiques.
• Tests de qualité pour éviter les biais de genre, d'âge, d'origine, de langue ou de situation économique.
• Aucun score ne doit être présenté comme une garantie de mariage, de sincérité ou de sécurité.

1.4 Protection des données
Les informations sensibles ne sont jamais utilisées pour la publicité. Les critères religieux ou autres données sensibles ne
peuvent être utilisés qu'avec une base légale appropriée, une information claire et un consentement explicite lorsque requis.
Prévoir minimisation, durée de conservation, suppression et contrôle d'accès.




2. Espace « Projet Mariage »
Créer un parcours spécifique pour les personnes qui déclarent rechercher une union sérieuse.
• Choix d'un horizon indicatif : bientôt, dans un délai défini ou sans échéance.
• Guides de préparation et sujets de discussion avant engagement.
• Liste personnelle de points à aborder : valeurs, finances, famille, enfants, lieu de vie, travail, responsabilités et attentes.
• Possibilité facultative d'associer un proche de confiance, uniquement après invitation et autorisation explicite.
• Contrôle granulaire des informations partagées avec ce proche et possibilité de révoquer l'accès à tout moment.
• Ressources d'accompagnement et rappels de sécurité avant une rencontre.
• Aucun membre ne doit être pénalisé ou moins visible parce qu'il ne souhaite pas impliquer sa famille.

3. Sécurité, anti-fraude et modération renforcées
3.1 Détection et prévention
• Détection des comptes multiples, comportements automatisés, spam et sollicitations répétées.
• Détection de signaux d'arnaque : demandes d'argent, liens suspects, usurpation, chantage et manipulation.
• Détection de réutilisation d'images lorsque les moyens techniques et les droits le permettent.
• Limitation progressive des actions suspectes et vérification renforcée proportionnée au risque.
• Alertes pédagogiques avant l'ouverture de liens externes ou l'envoi de coordonnées financières.
• Signalement accessible depuis profil, conversation, appel et rendez-vous.

3.2 Modération humaine
• File de traitement priorisée selon la gravité.
• Motifs de signalement structurés et pièces justificatives facultatives.
• Historique des décisions, preuves nécessaires et accès limité aux agents autorisés.
• Sanctions graduées : avertissement, restriction temporaire, suspension ou exclusion.
• Procédure de contestation et réexamen humain.
• Procédure d'urgence pour menaces, exploitation, chantage ou danger imminent, conformément aux obligations applicables.

3.3 Principes
Les outils automatisés assistent les modérateurs mais ne doivent pas être seuls responsables d'une sanction grave. Les faux
positifs doivent pouvoir être contestés. Ne jamais promettre une détection parfaite.

4. Confidentialité avancée et contrôle de visibilité
Ajouter un centre de confidentialité qui permet de :
• Mettre le profil en pause ou le masquer temporairement.
• Contrôler qui peut voir le profil et qui peut initier une conversation.
• Masquer la distance, les indicateurs d'activité et certaines informations du profil.
• Choisir une visibilité discrète lorsque cette option est disponible.
• Bloquer, débloquer et signaler des membres.
• Gérer les autorisations photo, caméra, microphone, contacts, notifications et localisation.
• Consulter les appareils et sessions connectés, puis fermer une session à distance.
• Régler la conservation des médias et les téléchargements lorsque la plateforme le permet.

Les captures d'écran ne peuvent pas être empêchées de manière fiable sur tous les appareils. L'application doit expliquer cette
limite plutôt que promettre une protection absolue. La localisation affichée reste approximative ; aucune adresse ni coordonnée
précise n'est révélée.




5. ZAYA Voice — Présentation vocale
• Enregistrement d'une courte présentation audio facultative.
• Prévisualisation, remplacement, suppression et contrôle de visibilité.
• Contrôle de durée, format, volume et qualité.
• Modération des contenus audio signalés.
• Lecture uniquement après action de l'utilisateur, avec option de désactivation.
• Pas de clonage vocal ni d'identification biométrique vocale sans projet distinct, base légale et consentement explicite.

6. ZAYA Academy — Ressources éducatives
Créer une bibliothèque éditorialisée de contenus :
• Communication et écoute dans le couple.
• Préparation à la vie conjugale et sujets à discuter avant le mariage.
• Gestion des désaccords et limites personnelles.
• Reconnaissance des comportements abusifs et des arnaques.
• Respect, consentement, sécurité et santé relationnelle.
• Ressources de préparation au mariage adaptées aux pays et langues ciblés.

Les contenus religieux doivent être relus par des personnes compétentes et clairement sourcés. Les contenus psychologiques
ou de santé doivent être validés par des professionnels qualifiés. L'application ne remplace ni un avis médical, ni un conseil
juridique, ni un accompagnement professionnel.

7. ZAYA Events — Événements et rencontres collectives
• Catalogue d'événements : conférences, ateliers, séances d'information et rencontres collectives encadrées.
• Filtres par pays, ville, langue, date et thème.
• Inscription, liste d'attente, annulation et rappels.
• Informations claires sur l'organisateur, le lieu, les frais et les règles de participation.
• Vérification des organisateurs et mécanisme de signalement.
• Recommandations de lieux publics et consignes de sécurité.
• Aucun partage de présence ou de localisation avec d'autres membres sans consentement.
• Outils d'administration pour gérer capacité, billets, remboursements et incidents.

8. ZAYA Match Intelligence — Assistant de conversation et de réflexion
Étendre Zaya AI pour :
• Suggérer des sujets de discussion à partir des intérêts communs autorisés.
• Proposer des questions utiles avant une décision importante.
• Aider à reformuler un message de manière respectueuse.
• Traduire les messages en conservant le texte original.
• Aider à identifier des sujets à clarifier, sans diagnostiquer la personnalité ni juger les intentions.
• Rappeler les règles de sécurité en présence de signaux de fraude.

Les suggestions restent privées et soumises à validation humaine. L'IA ne contacte personne, ne prend aucune décision à la
place du membre et ne doit pas fabriquer de faits ou prétendre connaître les intentions d'une personne. Les conversations
privées ne sont pas utilisées pour le ciblage publicitaire. Prévoir information sur l'usage de l'IA, minimisation des données,
contrôle utilisateur et mécanisme de désactivation.




9. Paiements et portefeuille — ZAYA Payments
Prévoir une architecture de paiement modulaire, dépendante des opérateurs et prestataires réellement disponibles dans chaque
pays :
• Orange Money et MTN Mobile Money lorsque les contrats et API locales le permettent.
• Autres portefeuilles mobiles locaux.
• Cartes bancaires via un prestataire agréé.
• Paiement des abonnements Premium, Boost et achats ZAYA Shop.
• Historique, reçus, statut des transactions et assistance.
• Gestion des échecs, doublons, remboursements et litiges.
• Vérification serveur des notifications de paiement ; ne jamais faire confiance au seul écran de confirmation du téléphone.
• Tarification affichée dans la devise locale, frais et renouvellement clairement indiqués.
• Conformité aux règles de paiement, protection des consommateurs et fiscalité de chaque marché.

Aucun portefeuille de conservation de fonds ne sera créé sans analyse réglementaire spécifique. Les données de carte sont
traitées par des prestataires conformes ; ZAYA évite de stocker les numéros complets de carte.

10. Croissance, parrainage et outils commerciaux
10.1 Parrainage
• Code ou lien de parrainage unique.
• Suivi des inscriptions valides et prévention des comptes fictifs.
• Récompense configurable après vérification et activité réelle, selon les règles du programme.
• Conditions transparentes, plafonds et lutte contre l'auto-parrainage.

10.2 Codes promotionnels
• Codes pour Premium, Boost ou ZAYA Shop.
• Période de validité, pays, devise, nombre d'utilisations et conditions.
• Journal des créations et utilisations.

10.3 Ambassadeurs
• Programme d'ambassadeurs par ville ou pays.
• Kit de communication et liens de suivi.
• Règles de conduite, transparence sur les rémunérations et interdiction des faux témoignages.
• Tableau de bord des résultats et mécanisme de retrait du programme.

10.4 Tableau de bord de pilotage
Suivre notamment :
• Inscriptions, profils vérifiés et taux d'activation.
• Utilisateurs actifs quotidiens et mensuels.
• Taux de complétion des profils et de conversations réciproques.
• Taux de signalement, délai de modération et incidents.
• Conversion Premium, résiliations et remboursements.
• Revenus publicitaires par emplacement et par campagne, sans profilage sensible.
• Coût d'acquisition, rétention et valeur moyenne par utilisateur.
• Performances par pays, langue et version de l'application, avec seuils d'anonymisation.

11. Expérience mobile adaptée à l'Afrique de l'Ouest




• Mode économie de données activable.
• Chargement progressif des photos et vidéos, avec qualité adaptative.
• Compression côté client et limites de taille configurables.
• Mise en cache contrôlée des éléments non sensibles.
• Reprise fiable des envois interrompus.
• Gestion des réseaux instables et des appels audio/vidéo à débit adaptatif.
• Messages d'erreur compréhensibles et possibilité de réessayer.
• Notifications optimisées pour limiter consommation de données et batterie.
• Compatibilité avec une gamme de téléphones Android modestes et iPhone pris en charge.
• Mesures de performance sur appareils réels et réseaux 2G/3G/4G lorsque disponibles.

Les conversations et données sensibles ne doivent pas être stockées en clair dans un cache non protégé. La synchronisation
hors ligne doit respecter les règles de chiffrement et de suppression.

12. Centre d'assistance et qualité de service
• Centre d'aide avec recherche et articles en plusieurs langues.
• Formulaire de contact et suivi des demandes.
• Catégories : compte, vérification, paiement, sécurité, modération et données personnelles.
• Numéro de ticket, accusé de réception et statut.
• Procédure accélérée pour les problèmes de sécurité.
• FAQ et messages de maintenance.
• Mesure des délais de réponse et de résolution.

13. Administration et gouvernance
Ajouter au back-office :
• Gestion des questionnaires et pondérations du moteur de compatibilité.
• Gestion des contenus Academy et calendrier Events.
• Validation des organisateurs et suivi des incidents.
• Gestion des codes promo, parrainages et ambassadeurs.
• Suivi des paiements, remboursements et rapprochements.
• Paramétrage par pays, devise, langue et opérateur de paiement.
• Gestion des demandes d'accès, export et suppression des données.
• Gestion des signalements, appels et décisions de modération.
• Tableau de bord qualité, sécurité, performance et revenus.
• Permissions par rôle, authentification renforcée des administrateurs et journal d'audit non modifiable par les opérateurs
ordinaires.

14. Priorisation et feuille de route
Phase 1 — Lancement sécurisé (MVP)
À livrer avant l'ouverture publique :
• Inscription, consentements, profil et vérification.
• Découverte, préférences mutuelles, likes et match.
• Messagerie, blocage et signalement.
• Modération opérationnelle et outils d'administration.
• Confidentialité de base, suppression/export des données.




• Paiement Premium et contrôle des abonnements si activés au lancement.
• Analytics de base, sauvegardes, supervision et gestion des incidents.
• Optimisation réseau et tests sur appareils modestes.
• Tests de sécurité, charge, accessibilité et parcours utilisateurs.

Phase 2 — Amélioration de l'engagement (0 à 3 mois après lancement)
• Compatibilité intelligente initiale.
• Projet Mariage.
• ZAYA Voice.
• ZAYA Match Intelligence étendu.
• Parrainage et codes promotionnels.
• Tableau de bord commercial avancé.
• Centre d'aide multilingue.
• Mode économie de données avancé.

Phase 3 — Écosystème (3 à 6 mois)
• ZAYA Academy.
• ZAYA Events dans les villes où l'organisation est possible.
• Paiements Mobile Money supplémentaires selon accords locaux.
• Programme ambassadeurs.
• Améliorations anti-fraude et modération assistée.
• Expansion progressive vers les pays d'Afrique de l'Ouest.

Phase 4 — Déploiement régional et optimisation (après 6 mois)
• Localisation pays par pays, langues et devises.
• Partenariats institutionnels et commerciaux.
• Optimisation du moteur de recommandation avec audits de biais.
• Événements multi-pays et nouveaux moyens de paiement.
• Amélioration continue selon les indicateurs de sécurité, de qualité et de satisfaction.

Les durées sont des objectifs indicatifs et doivent être recalibrées après étude technique, budget, recrutement et validation
réglementaire.

15. Indicateurs de réussite et critères d'acceptation
Chaque fonctionnalité doit avoir des tests et des critères mesurables. Indicateurs recommandés :
• Taux de profils vérifiés avant publication.
• Taux de faux positifs et de contestations de modération.
• Délai médian de traitement des signalements urgents et ordinaires.
• Taux de réussite des paiements et taux de remboursement.
• Temps de chargement des écrans clés sur réseau faible.
• Taux d'échec des envois de messages et appels.
• Taux de consentement et de retrait des consentements.
• Taux d'export et de suppression des comptes traités dans les délais définis.
• Satisfaction des utilisateurs et qualité des conversations réciproques.

Les objectifs chiffrés seront fixés après une phase pilote et une mesure de référence. Ne pas optimiser uniquement le temps
passé dans l'application ou le nombre de swipes : privilégier la sécurité, la confiance, la qualité des échanges et la satisfaction.




16. Exigences transversales non négociables
1. Consentement explicite, compréhensible et révocable lorsque cela s'applique.
2. Minimisation des données et chiffrement en transit et au repos.
3. Contrôle d'accès strict et journalisation des accès administratifs.
4. Pas de publicité fondée sur les messages privés, les données biométriques ou les données sensibles.
5. Pas de faux likes, faux profils, fausse urgence ou notifications trompeuses.
6. Pas de message, appel, invitation ou partage de données initié par l'IA sans validation de l'utilisateur.
7. Protection des mineurs : accès réservé aux adultes, contrôle d'âge proportionné, traitement spécialisé des signalements
impliquant des mineurs et respect des lois applicables.
8. Procédure de réponse aux incidents, sauvegardes testées et plan de continuité.
9. Évaluation juridique et protection des données avant chaque lancement dans un nouveau pays.
10. Accessibilité, langues locales, transparence des prix et mécanisme de recours.

17. Décisions à valider avant développement
• Âge minimum légal et méthode de contrôle d'âge selon les pays.
• Prestataires de paiement et contrats Mobile Money disponibles.
• Fournisseurs de vérification d'identité et politique de conservation des données biométriques.
• Pondération du moteur de compatibilité et critères réellement nécessaires.
• Gouvernance éditoriale et validation des contenus Academy.
• Conditions d'organisation et responsabilité des événements.
• Modèle économique du parrainage et du programme ambassadeurs.
• Budget de modération humaine, assistance et infrastructure.
• Textes juridiques, responsables de traitement, hébergement et transferts internationaux.
• Objectifs de lancement et seuils de qualité mesurés lors du pilote.

Fin de l'addendum version 2.2.

ADDENDUM — VERSION 2.3
Protection contre les captures d'écran et réseau communautaire ZAYA Community
Version : 2.3
Date : 14 novembre 2026
Statut : Extension fonctionnelle à intégrer à la feuille de route

1. Protection contre les captures d'écran et enregistrements
1.1 Objectif
Réduire au maximum la copie non autorisée des profils, photos, vidéos, conversations et contenus privés. La protection doit être
activée par défaut dans les espaces sensibles, avec une information claire sur ses limites techniques.

1.2 Android
• Utiliser les mécanismes de sécurité de la plateforme, notamment FLAG_SECURE, sur les écrans qui affichent des informations
privées lorsque cela est compatible avec l'architecture.
• Empêcher la capture d'écran et limiter l'affichage dans les aperçus d'applications récentes sur les écrans protégés.
• Tester le comportement sur différentes versions Android et fabricants.




• Détecter, lorsque le système le permet, certaines tentatives de capture ou de partage d'écran et appliquer les règles prévues.

1.3 iPhone / iOS
• Utiliser les API iOS disponibles pour détecter certains états de capture ou d'enregistrement d'écran et réagir dans les limites
autorisées par Apple.
• Masquer les informations sensibles dans les aperçus d'applications en arrière-plan.
• Afficher un avertissement ou masquer temporairement certains contenus lorsqu'un enregistrement d'écran est détecté, si le
comportement est pris en charge.
• Ne pas prétendre qu'une application iOS peut bloquer toutes les captures d'écran : les possibilités du système sont limitées.

1.4 Règles fonctionnelles
• Appliquer la protection aux profils, albums privés, photos envoyées en conversation, médias temporaires, appels et espaces
communautaires privés, selon les capacités de chaque plateforme.
• Prévoir une option permettant de protéger davantage les médias partagés.
• Informer les utilisateurs lorsque la protection est active et expliquer ses limites.
• Ne pas envoyer automatiquement une notification à l'autre membre pour chaque capture détectée si la plateforme ne fournit pas
un signal fiable.
• Prévoir une politique de signalement en cas de diffusion non consentie d'une image.
• Ajouter un filigrane discret et non intrusif sur certains médias sensibles, par exemple un identifiant de session ou un marquage
dynamique, uniquement après analyse juridique et technique. Éviter d'exposer publiquement le nom complet ou des données
personnelles.
• Ne jamais conserver ni transmettre une capture d'écran du téléphone de l'utilisateur.

1.5 Limites et critères d'acceptation
Une personne peut toujours photographier l'écran avec un autre appareil ou contourner certaines protections. ZAYA doit donc
parler de réduction des captures et de protection renforcée, et non de blocage absolu. Les tests doivent couvrir captures,
enregistrements, partage d'écran, aperçus multitâches, appareils modifiés et scénarios d'accessibilité.

2. ZAYA Community — Communauté et publications
2.1 Objectif
Créer un espace social modéré où les membres peuvent échanger autour de sujets utiles, partager des expériences et
apprendre à mieux préparer une relation sérieuse, sans transformer l'application en réseau social généraliste non contrôlé.

2.2 Fonctionnalités côté membre
• Fil communautaire avec publications récentes et contenus recommandés selon les thèmes suivis.
• Création de publications texte, photos et vidéos, avec légende et catégorie.
• Possibilité de poser une question, partager un conseil ou raconter une expérience.
• Commentaires, réponses en fil, réactions et enregistrement des publications favorites.
• Suivi de communautés ou de thèmes.
• Recherche de publications par thème, langue et pays.
• Partage d'une publication à l'intérieur de ZAYA, selon les paramètres de confidentialité.
• Modification et suppression de ses propres publications et commentaires.
• Contrôle des commentaires et possibilité de désactiver les réponses sur une publication.
• Blocage et signalement d'un membre depuis une publication, un commentaire ou son profil.

2.3 Communautés thématiques proposées
• Préparation au mariage.
• Communication et vie de couple.
• Conseils et expériences.
• Famille et parentalité.




• Éducation et développement personnel.
• Événements et activités locales.
• Questions et réponses.
• Communautés linguistiques et régionales.

Les catégories doivent être ouvertes ou activées progressivement selon la capacité de modération. Les communautés ne
doivent pas servir à publier des annonces de recherche de partenaire contenant des coordonnées privées, ni à contourner les
règles de découverte et de messagerie.

2.4 Règles de publication
Sont interdits :
• Harcèlement, insultes, menaces, intimidation et discours haineux.
• Nudité, contenus sexuels explicites ou sollicitations sexuelles.
• Arnaques, demandes d'argent, publicité non autorisée et spam.
• Diffusion de coordonnées, photos ou conversations d'une autre personne sans autorisation.
• Doxxing, chantage, usurpation d'identité et contenus visant à humilier.
• Contenus illégaux ou mettant des personnes en danger.
• Faux témoignages, faux comptes et manipulations coordonnées.
• Contenus portant atteinte aux droits d'auteur ou à la vie privée.

2.5 Modération et sécurité
• Modération automatique en amont et après publication, complétée par une équipe humaine.
• Signalement simple de publications, commentaires, membres et communautés.
• Possibilité de masquer immédiatement un contenu pour la personne qui le signale.
• File de modération avec priorité aux menaces, exploitation, chantage et diffusion non consentie d'images.
• Sanctions graduées, motifs expliqués et possibilité de faire appel.
• Outils anti-spam : limites de fréquence, détection de liens suspects et prévention des publications répétitives.
• Prévisualisation et confirmation avant publication de contenus multimédias.
• Règles de conservation des éléments nécessaires au traitement d'un signalement, avec accès restreint et durée définie.
• Modérateurs identifiés par rôle, journal des actions et contrôle d'accès.

2.6 Confidentialité communautaire
• Paramètres de visibilité de la publication : publique dans ZAYA, réservée aux membres connectés, ou limitée à une
communauté privée.
• Affichage du nom de profil choisi ; pas d'adresse, de numéro ou de localisation précise.
• Possibilité de publier sous pseudonyme uniquement si le modèle de confiance et la modération le permettent ; les
administrateurs habilités conservent les informations nécessaires à la sécurité selon les règles légales.
• Contrôle des mentions, réponses, notifications et abonnements.
• Option de désactiver les notifications communautaires.
• Les publications privées ne doivent pas être indexées par les moteurs de recherche externes.
• Pas de ciblage publicitaire basé sur les publications privées, les messages ou les données sensibles.

2.7 Administration des communautés
Le back-office doit permettre :
• Créer, modifier, suspendre ou fermer une communauté.
• Définir les règles, thèmes, langues, pays et conditions d'accès.
• Nommer des modérateurs avec permissions limitées.
• Valider les publications lorsque le mode de pré-modération est activé.




• Gérer signalements, appels, contenus supprimés et sanctions.
• Consulter les statistiques agrégées : membres actifs, publications, commentaires, signalements et délais de modération.
• Définir les limites de fréquence et la taille maximale des médias.
• Désactiver temporairement les commentaires ou les publications en cas d'incident.

2.8 Monétisation de la communauté
• Possibilité de proposer des partenariats ou contenus sponsorisés clairement identifiés.
• Les annonces commerciales doivent être séparées des publications ordinaires et respecter une fréquence plafonnée.
• Aucun annonceur ne peut accéder aux messages privés ou aux données sensibles des membres.
• Les contenus sponsorisés ne peuvent pas être présentés comme des recommandations indépendantes.
• Pas de paiement pour supprimer un signalement ou contourner une sanction.

3. Navigation et expérience utilisateur
Ajouter un onglet Communauté dans la navigation principale, à côté de Rencontre/Découverte et Messagerie, selon les tests
d'ergonomie.
Écrans à concevoir :
1. Accueil Communauté : fil et thèmes.
2. Explorer les communautés.
3. Détail d'une communauté.
4. Créer une publication.
5. Détail d'une publication et commentaires.
6. Favoris et publications enregistrées.
7. Notifications communautaires.
8. Règles et paramètres de confidentialité.
9. Signalement et suivi de modération.

Les publications doivent être lisibles sur petits écrans et réseaux faibles. Chargement progressif des médias, compression et
lecture vidéo adaptative sont requis.

4. Priorisation et conditions de lancement
Protection anti-capture
• Phase 1 : protection Android des écrans sensibles, masquage des aperçus, protections iOS possibles, avertissements et tests.
• Phase 2 : extension aux médias temporaires, appels et contenus communautaires, filigrane si validé.

ZAYA Community
• Phase 1 : lancer un fil simple avec publications texte, signalement, blocage, règles communautaires et modération
opérationnelle.
• Phase 2 : photos/vidéos, commentaires en fil, abonnements aux thèmes et communautés privées.
• Phase 3 : événements communautaires, outils avancés des modérateurs et partenariats sponsorisés.

La communauté ne doit pas être ouverte publiquement avant que l'équipe de modération, les procédures de signalement et les
règles de confidentialité soient opérationnelles.

5. Critères d'acceptation
• Les écrans Android désignés comme sensibles résistent aux captures via les protections système prises en charge.
• Sur iOS, les réactions aux captures et enregistrements sont testées et documentées sans promesse de blocage impossible.
• Les aperçus multitâches ne révèlent pas les contenus privés.




• Un membre peut créer, modifier et supprimer ses propres publications.
• Un membre peut signaler et bloquer depuis chaque surface communautaire.
• Les modérateurs peuvent examiner, retirer et restaurer un contenu avec une trace d'audit.
• Les publications et commentaires respectent les règles de confidentialité, de rétention et de suppression.
• Les outils anti-spam et limites de fréquence sont testés avant ouverture à grande échelle.

Fin de l'addendum version 2.3.

ADDENDUM — VERSION 3.0
Confidentialité intégrale, protections anti-capture et règles d'accès Gratuit /
Premium
Version : 3.0
Date : 14 novembre 2026
Statut : Exigences fonctionnelles à intégrer au produit et à la feuille de route
Cette version formalise les décisions prises sur la confidentialité, le floutage des photos, la protection contre les captures
d'écran, la consultation des profils et la séparation des avantages Gratuit et Premium. Elle complète les sections précédentes ;
en cas de contradiction, les règles plus précises de cet addendum prévalent.

1. Principes directeurs
1. Tous les membres adultes peuvent découvrir les profils, qu'ils soient Gratuit ou Premium.
2. L'abonnement Premium donne accès à des fonctionnalités supplémentaires, mais ne permet jamais de contourner les réglages
de confidentialité d'un autre membre.
3. Les protections fondamentales — blocage, signalement, contrôle de visibilité, suppression du compte et sécurité — restent
gratuites.
4. Le floutage appliqué par défaut aux comptes gratuits est une règle d'accès commerciale ; le propriétaire du profil conserve
gratuitement le droit de protéger davantage ses photos.
5. Aucune option payante ne doit rendre un membre vulnérable ou exposer ses données contre son gré.
6. Les différences entre forfaits doivent être expliquées clairement avant tout paiement, sans faux compte à rebours ni pression
trompeuse.

2. Règles de visibilité entre comptes Gratuit et Premium
2.1 Matrice de visibilité
Profil consulté | Visiteur Gratuit | Visiteur Premium
Profil Gratuit | Profil consultable ; médias floutés selon la règle du forfait et les choix du propriétaire | Profil consultable ; médias visibles
uniquement si le propriétaire l'autorise
Profil Premium | Profil consultable ; médias floutés selon la règle du forfait et les choix du propriétaire | Profil consultable ; médias visibles
uniquement si le propriétaire l'autorise

Les comptes Gratuit ne doivent pas être exclus des résultats de recherche au seul motif que le profil proposé est Premium.
Réciproquement, les comptes Premium peuvent découvrir les comptes Gratuit. Le moteur de découverte ne doit pas créer deux
communautés séparées.

2.2 Règle de priorité des autorisations
L'affichage d'un média suit toujours cet ordre :
1. Le choix de confidentialité du propriétaire du média.
2. Les autorisations individuelles éventuellement accordées par le propriétaire.
3. Les droits liés au forfait du membre qui consulte.




4. Les restrictions de sécurité, de modération ou de conformité.

Le forfait Premium ne peut jamais outrepasser un profil masqué, un album verrouillé, une autorisation révoquée ou un blocage.

3. Photos floutées et albums privés
3.1 Expérience Gratuit
• Les photos protégées sont affichées sous forme de vignettes floutées ou de placeholders.
• Le compte Gratuit ne peut pas retirer le floutage réservé à l'accès Premium.
• L'interface peut indiquer qu'un profil contient des photos supplémentaires, sans révéler leur contenu.
• Aucun aperçu net, miniature en cache ou URL publique ne doit permettre de contourner le floutage.
• Les photos ne doivent pas être téléchargeables directement depuis l'application.

3.2 Expérience Premium
• Le compte Premium peut consulter les photos non floutées lorsque le propriétaire a autorisé leur visibilité.
• Les albums privés restent verrouillés jusqu'à autorisation explicite du propriétaire.
• Le propriétaire peut accorder l'accès à une personne, le limiter dans le temps ou le révoquer.
• La révocation doit prendre effet immédiatement côté serveur et empêcher les consultations futures ; elle ne peut pas effacer une
copie déjà obtenue illicitement.

3.3 Contrôles du propriétaire — gratuits
• Choisir quelles photos sont publiques, floutées ou privées.
• Verrouiller un album.
• Autoriser ou refuser une personne.
• Révoquer une autorisation.
• Retirer ou remplacer une photo.
• Masquer toutes ses photos.
• Prévisualiser son profil comme le verra un compte Gratuit et un compte Premium.

La possibilité de protéger ses propres photos ne doit pas être payante. L'avantage Premium concerne la consultation des
médias lorsque leur propriétaire a autorisé l'accès, pas le droit de passer outre la volonté de celui-ci.

4. Visiteurs et likes : notifications et accès Premium
4.1 Notifications
Lorsqu'un membre visite un profil ou envoie un like, le propriétaire peut recevoir une notification :
• « Une personne a consulté votre profil. »
• « Une personne a aimé votre profil. »

Les notifications doivent respecter les réglages de visibilité et ne pas révéler l'identité d'un membre qui utilise un mode discret
lorsque ce mode est autorisé.

4.2 Compte Gratuit
• Peut recevoir un compteur ou une notification signalant de nouvelles visites ou de nouveaux likes.
• Peut voir qu'il existe des interactions en attente.
• Ne peut pas consulter l'identité complète des visiteurs ou des personnes ayant liké son profil lorsque cette consultation est
réservée au Premium.
• Peut continuer à utiliser la découverte, envoyer des likes dans les limites prévues et obtenir des matchs réciproques.
• Un match réciproque doit être révélé aux deux membres : il ne peut pas être artificiellement verrouillé derrière Premium.

4.3 Compte Premium




• Peut consulter la liste des personnes ayant liké son profil.
• Peut consulter les visiteurs identifiables, sous réserve du mode discret et des paramètres de confidentialité de ces personnes.
• Peut accéder aux filtres et outils de tri avancés prévus dans son forfait.
• Ne peut pas voir les personnes qui ont masqué leur profil ou désactivé cette visibilité.

4.4 Transparence commerciale
Avant l'achat, l'écran Premium doit indiquer précisément ce qui sera débloqué, la durée, le prix, le renouvellement éventuel, les
modalités de résiliation et les règles de remboursement applicables. L'application ne doit jamais simuler un like ou une visite
pour inciter à payer.

5. Catalogue des forfaits
5.1 Forfait Gratuit
Inclut au minimum :
• Création et gestion du profil.
• Découverte des profils Gratuit et Premium.
• Filtres de base.
• Likes dans une limite quotidienne configurable.
• Matchs réciproques.
• Messagerie après match selon les règles communes.
• Réception des notifications de likes et visites, sans nécessairement révéler l'identité.
• Réglages essentiels de confidentialité.
• Blocage, signalement et assistance sécurité.
• Export et suppression du compte selon la politique de données.

5.2 Forfait Premium
Peut inclure :
• Consultation de la liste des likes reçus.
• Consultation des visiteurs identifiables lorsque leur confidentialité le permet.
• Affichage des photos non floutées lorsque le propriétaire l'autorise.
• Filtres de recherche avancés.
• Quotas de likes supérieurs.
• Contrôles avancés de visibilité et mode incognito.
• Statistiques enrichies du profil.
• Boosts ou avantages de visibilité, selon le produit acheté.

Les quotas, prix, durées et avantages doivent être configurables depuis le back-office, par pays et devise. Les achats ponctuels
(Boost, cadeaux) doivent être distingués de l'abonnement.

5.3 Règles communes
• Aucun membre ne doit payer pour bloquer, signaler, protéger ses données ou supprimer son compte.
• Les fonctionnalités essentielles de rencontre et les matchs réciproques restent accessibles gratuitement.
• Les abonnements ne garantissent ni match, ni réponse, ni relation, ni mariage.
• Les avantages Premium ne doivent pas créer de faux profils ni modifier artificiellement les intentions d'un membre.

6. Centre de confidentialité et de sécurité
Créer une page unique, accessible depuis le profil et les paramètres, avec les catégories suivantes.




6.1 Visibilité du profil
• Profil visible, masqué ou temporairement en pause.
• Mode incognito : profil présenté uniquement aux membres que l'utilisateur a préalablement aimés, si cette option est activée.
• Exclusion des suggestions et résultats de recherche.
• Contrôle de l'apparition dans les visiteurs.
• Masquage de la ville précise, de la distance, de l'activité et de la dernière connexion.
• Aperçu du profil selon les différents forfaits.

6.2 Informations personnelles
• Masquer l'âge exact lorsque la politique produit le permet.
• Afficher une zone géographique approximative, jamais l'adresse ou les coordonnées exactes.
• Ne jamais publier le numéro de téléphone, l'adresse e-mail ou les identifiants personnels.
• Contrôler les champs facultatifs et leur visibilité.
• Ne pas révéler les données sensibles dans les notifications.

6.3 Interactions
• Choisir qui peut envoyer une demande ou initier un échange.
• Désactiver les invitations et cadeaux.
• Bloquer, débloquer et signaler un membre.
• Retirer un match et supprimer une conversation de son propre espace, avec information claire sur ce que l'autre membre
conserve.
• Filtrer les messages abusifs, liens suspects et sollicitations répétées.
• Restreindre les contacts aux matchs réciproques selon le réglage choisi.

6.4 Statut et notifications
• Masquer « En ligne » et la dernière activité.
• Désactiver les confirmations de lecture lorsque cette fonction existe.
• Choisir le contenu affiché sur l'écran verrouillé.
• Désactiver séparément les notifications de likes, visites, messages, événements et marketing.
• Définir des heures silencieuses.

6.5 Appels et médias
• Autoriser ou refuser les appels audio et vidéo.
• Autoriser les appels uniquement après un match.
• Contrôler caméra et microphone.
• Ne pas afficher le numéro de téléphone.
• Ne pas enregistrer les appels à l'insu des participants.
• Gérer les photos temporaires et les médias privés.
• Signaler tout partage non consenti.

6.6 Compte et appareils
• Code PIN de l'application.
• Authentification biométrique locale (empreinte ou Face ID) si l'appareil la prend en charge.
• Authentification à deux facteurs lorsque disponible.
• Alertes de nouvelle connexion.
• Liste des appareils et sessions.
• Déconnexion à distance.




• Changement et récupération sécurisés du mot de passe ou du numéro.

6.7 Données personnelles
• Télécharger une copie des données.
• Corriger ou supprimer les informations modifiables.
• Retirer les consentements facultatifs.
• Demander la suppression du compte.
• Consulter les règles de conservation et les éventuelles exceptions légales.
• Refuser la publicité personnalisée lorsque cette option est applicable.

7. Protection anti-capture et anti-enregistrement
La protection anti-capture décrite dans la version 2.3 est confirmée et doit être appliquée en priorité aux profils privés, photos,
albums verrouillés, conversations et contenus sensibles.
• Android : utiliser les mécanismes disponibles, dont FLAG_SECURE pour les écrans concernés.
• iOS : détecter les états de capture/enregistrement pris en charge, masquer les contenus sensibles lorsque possible et protéger
les aperçus multitâches.
• Ajouter un filigrane discret sur certains médias sensibles si la mise en œuvre est proportionnée et conforme.
• Ne pas annoncer un blocage universel : un autre téléphone peut toujours photographier l'écran.
• Ne notifier une capture que si un événement fiable est effectivement fourni par le système.
• Documenter les différences Android/iOS et tester les appareils réels.

8. Mode discret et protection d'urgence
Ajouter un raccourci « Masquer mon profil » permettant de :
• Retirer rapidement le profil des résultats de découverte.
• Désactiver temporairement les nouvelles visites visibles.
• Mettre en pause les interactions entrantes selon le choix du membre.
• Masquer les aperçus sensibles.
• Proposer ensuite une reprise contrôlée du compte.

Ce mode ne doit pas supprimer les preuves nécessaires à une enquête de sécurité ni empêcher un membre de contacter
l'assistance en cas de danger.

9. Architecture et sécurité technique
• Les règles de forfait et de visibilité doivent être vérifiées côté serveur, jamais uniquement dans l'interface mobile.
• Les médias privés doivent être stockés dans des espaces privés, servis par des liens temporaires et autorisés.
• Les miniatures floutées doivent être générées côté serveur ; l'image originale ne doit jamais être envoyée au client Gratuit puis
simplement floutée visuellement.
• Appliquer le contrôle d'accès au niveau des lignes et des objets (RLS et règles de stockage).
• Journaliser les changements d'abonnement, les accès privés et les révocations, sans conserver inutilement des données
sensibles.
• Tester les tentatives d'accès direct par URL, API, cache, sauvegarde locale et compte expiré.
• En cas d'expiration ou d'échec de paiement, recalculer les droits côté serveur et appliquer une période de grâce uniquement si
elle est définie.
• Prévoir la résiliation simple et la gestion des remboursements selon les règles des boutiques et prestataires.

10. Critères d'acceptation




La version ne peut être considérée comme conforme que si :
1. Un compte Gratuit peut découvrir un compte Premium.
2. Un compte Premium peut découvrir un compte Gratuit.
3. Le floutage Gratuit s'applique réellement côté serveur et ne peut pas être contourné par une URL directe.
4. Un compte Premium ne voit jamais un média privé sans autorisation du propriétaire.
5. Le propriétaire peut masquer son profil et révoquer les accès aux albums.
6. Un compte Gratuit peut obtenir un match réciproque et commencer la conversation selon les règles communes.
7. Les likes et visites ne sont jamais inventés pour provoquer un achat.
8. Les avantages Premium et leur prix sont expliqués avant paiement.
9. Le blocage, le signalement et la suppression du compte restent gratuits.
10. Les écrans sensibles appliquent les protections anti-capture disponibles et expliquent leurs limites.
11. Les tests vérifient les accès par API, stockage, cache, notifications et sessions expirées.
12. Les paramètres de confidentialité sont persistants, compréhensibles et réversibles.

11. Priorisation de réalisation
MVP / lancement
• Matrice de visibilité Gratuit/Premium.
• Découverte croisée des comptes.
• Floutage côté serveur pour les comptes Gratuit.
• Photos privées avec autorisations.
• Centre de confidentialité de base.
• Blocage, signalement, masquage du profil.
• Notifications de likes et visites sans divulgation non autorisée.
• Contrôle d'accès serveur et tests de contournement.

Phase suivante
• Liste des visiteurs et likes réservée au Premium.
• Mode incognito avancé.
• Albums privés avec autorisations granulaires.
• Filigranes dynamiques.
• Statistiques avancées et contrôles Premium supplémentaires.
• Détection des captures et adaptations spécifiques aux versions Android/iOS.

Phase ultérieure
• Contrôles avancés des appels.
• Modes d'urgence enrichis.
• Analyses anti-fraude et audit périodique de la confidentialité.

12. Décisions produit retenues pour la version 3.0
• ZAYA reste une application de rencontre, pas une agence matrimoniale.
• Le parcours « Projet Mariage » fournit des ressources facultatives et des outils de réflexion ; ZAYA ne garantit pas une union et
n'organise pas le choix du conjoint à la place des membres.
• Les comptes Gratuit et Premium se découvrent mutuellement.
• Les photos sont floutées pour les consultations Gratuites selon les règles du forfait.
• Premium permet de voir les photos non floutées uniquement si le propriétaire les a rendues accessibles.




• La liste des likes reçus et des visiteurs identifiables est un avantage Premium, sous réserve du mode discret des autres
membres.
• Les matchs réciproques ne sont pas verrouillés derrière Premium.
• Les protections fondamentales et les droits sur les données restent gratuits.
• La protection anti-capture est mise en œuvre selon les capacités réelles d'Android et iOS, sans promesse impossible.

13. Architecture générale de l'écosystème ZAYA
ZAYA comprend trois espaces complémentaires, accessibles selon leur nature et sans obligation de créer un compte
matrimonial pour utiliser les services commerciaux :
• ZAYA RENCONTRE : découverte de profils adultes, intentions sérieuses, likes, matchs et conversations.
• ZAYA SHOP : catalogue de produits et cadeaux proposés par des boutiques partenaires, achat et remise au bénéficiaire.
• ZAYA EVENT : annuaire, portfolios, demandes de devis et réservations de lieux et de prestataires événementiels.

ZAYA EVENT doit être consultable indépendamment de ZAYA RENCONTRE. Une personne qui prépare un mariage avec un
partenaire rencontré ailleurs doit pouvoir rechercher une salle, une décoratrice ou un traiteur sans créer de profil de rencontre.
Les espaces peuvent partager un compte ZAYA général si l'utilisateur le souhaite, mais les données, consentements et usages
doivent rester cloisonnés.
ZAYA agit comme plateforme technologique de mise en relation et, lorsque le parcours le prévoit, d'intermédiation de
commande ou de réservation. ZAYA ne se présente pas comme agence matrimoniale, organisateur de mariage, propriétaire de
salle, décorateur ou vendeur des produits des partenaires. Les responsabilités de chaque partie, les paiements, les annulations,
remboursements, garanties et litiges doivent être définis contractuellement et affichés clairement.

14. ZAYA SHOP — boutiques, cadeaux et retrait en magasin
14.1 Catalogue et boutiques partenaires
Les boutiques partenaires peuvent disposer d'une vitrine avec :
• nom commercial, logo, adresse, zone desservie et contacts professionnels ;
• catégories et fiches produits ;
• photos authentiques, description, variantes, tailles ou matériaux ;
• prix, disponibilité et conditions de retrait ou de livraison ;
• délais de préparation et horaires de retrait ;
• politique de retour, échange et remboursement ;
• statut de vérification du partenaire.

Catégories de départ possibles : bijoux, montres, vêtements et tenues de cérémonie, parfums, accessoires, coffrets et cadeaux.
Les produits soumis à des restrictions légales ou réglementaires doivent être exclus ou traités selon les règles applicables.

14.2 Achat d'un cadeau pour une autre personne
Parcours cible :
1. L'acheteur choisit un produit et une boutique partenaire.
2. Il indique qu'il s'agit d'un cadeau et renseigne le bénéficiaire ou choisit de lui envoyer une invitation cadeau.
3. Il règle la commande par un moyen de paiement pris en charge et voit le prix, les frais éventuels et les conditions avant
confirmation.
4. Après confirmation du paiement et acceptation de la commande par la boutique, ZAYA crée un bon cadeau doté d'un identifiant
unique et, de préférence, d'un QR code signé ou vérifiable côté serveur.
5. Le bénéficiaire reçoit une notification ou un lien sécurisé avec les instructions de retrait : boutique, adresse, horaires, date
limite, conditions et code de retrait.




6. À la boutique, le personnel vérifie le code depuis son espace professionnel ou un écran de validation sécurisé. Le code est
marqué comme utilisé après remise effective du produit.
7. L'acheteur et le bénéficiaire reçoivent une confirmation de remise, selon leurs préférences de notification.

14.3 Sécurité et règles du bon cadeau
• Le code doit être aléatoire, non devinable, à usage unique et vérifié en ligne côté serveur. Un QR code seul ne constitue pas une
preuve suffisante.
• Prévoir expiration, annulation, remboursement, perte du téléphone, erreur de bénéficiaire, produit indisponible et retrait partiel si
le panier le permet.
• Le code ne doit révéler aucune donnée personnelle de l'acheteur au-delà de ce qui est nécessaire.
• La boutique ne peut pas valider deux fois le même bon. Les opérations sont horodatées et journalisées.
• Prévoir un mode de vérification de secours contrôlé en cas de panne réseau, sans permettre la double remise ; ce mode doit
être réconcilié dès le retour du réseau.
• Définir contractuellement qui encaisse, qui détient les fonds, quand la boutique est payée et qui supporte les remboursements.
• Ne jamais afficher « cadeau remis » avant validation effective par le partenaire.

15. ZAYA EVENT — annuaire et services événementiels ouverts à
tous
15.1 Public et périmètre
ZAYA EVENT est un espace public de découverte de professionnels et de lieux pour les mariages, fiançailles, cérémonies
religieuses ou traditionnelles, anniversaires et autres événements. Il est indépendant de ZAYA RENCONTRE. Les utilisateurs
peuvent consulter les annonces sans profil matrimonial ; les fonctions de réservation ou de contact peuvent demander un
compte ZAYA général afin de prévenir les abus.

15.2 Catégories
• Salles de réception, hôtels, villas, maisons, jardins et espaces extérieurs.
• Décorateurs et décoratrices, avec styles et spécialités : musulman/modeste, traditionnel, moderne, minimaliste, luxe, etc.
• Photographes et vidéastes.
• Traiteurs et services de restauration.
• Maquilleurs, coiffeurs, henné et beauté.
• Couturiers, boutiques de robes et tenues de cérémonie.
• Location de tentes, tables, chaises, mobilier, vaisselle, sonorisation et éclairage.
• Animateurs, maîtres de cérémonie et autres prestataires événementiels, sous réserve de conformité.

15.3 Fiche professionnelle et portfolio
Chaque professionnel peut disposer d'une page comprenant :
• nom commercial, logo/photo, description et spécialités ;
• adresse, zone d'intervention, carte et contacts professionnels ;
• galerie de photos et vidéos de réalisations ;
• portfolio organisé par type d'événement ou style ;
• tarifs indicatifs ou fourchettes, formules et prestations incluses ;
• disponibilités, délais de réponse et conditions ;
• bouton Appeler, WhatsApp si le partenaire fournit ce contact, Demander un devis et Ajouter aux favoris ;
• avis clients publiés après une prestation vérifiée, avec modération et droit de réponse ;




• badge partenaire vérifié, sans laisser entendre que ZAYA garantit la qualité de chaque prestation.

Le prestataire doit confirmer qu'il détient les droits nécessaires sur les photos publiées et obtenir le consentement des
personnes reconnaissables lorsque requis. Les clients peuvent demander le retrait d'une image les représentant.

15.4 Fiche d'un lieu et calendrier de disponibilité
Les lieux de réception disposent d'une fiche avec capacité, adresse, photos, équipements, accessibilité, règles du lieu, prix ou
tarifs indicatifs, frais additionnels, horaires et conditions de réservation.
Le responsable du lieu renseigne et maintient le calendrier dans son espace professionnel. Il peut également transmettre un
calendrier à l'administration ZAYA, qui le saisit après validation du partenaire. Le calendrier doit indiquer clairement les états :
disponible, demande en attente, option temporaire, réservé, indisponible ou date à confirmer.
Une date affichée comme disponible doit porter la date et l'heure de dernière mise à jour. Si la disponibilité n'est pas
synchronisée en temps réel, l'interface doit le signaler et demander une confirmation du partenaire avant paiement définitif.

15.5 Parcours de réservation
1. L'utilisateur filtre les lieux par ville/quartier, date, capacité, budget et équipements.
2. Il ouvre une fiche, consulte photos, tarifs, règles et disponibilités.
3. Il choisit une date, un créneau et ses besoins, puis envoie une demande.
4. Le partenaire confirme, refuse ou propose une autre date.
5. Après confirmation, l'utilisateur voit le prix total, l'acompte, le solde, les frais, la politique d'annulation et les conditions.
6. Le paiement est réalisé uniquement via un prestataire de paiement intégré et autorisé, si le partenaire active cette option.
7. La réservation confirmée génère un numéro de dossier, un reçu et des notifications aux parties.
8. Le partenaire met le calendrier à jour automatiquement ; un verrou temporaire évite que deux demandes acceptées se
chevauchent.

Ne pas considérer une simple demande comme une réservation confirmée. Définir la durée d'une option temporaire, l'expiration
du paiement, la libération de la date, les remboursements et le traitement des litiges.

15.6 Prestataires sans réservation intégrée
Pour les décorateurs, photographes, traiteurs et autres professionnels, la première version peut proposer une mise en relation
directe : appel, WhatsApp ou demande de devis. Les coordonnées ne sont publiées qu'avec l'accord du professionnel. La
disponibilité et les prix restent à confirmer directement auprès du prestataire si aucun calendrier de réservation n'est activé.

15.7 Devis, comparaison et favoris
L'utilisateur peut :
• envoyer une demande de devis à un ou plusieurs prestataires ;
• préciser date, lieu, budget, nombre d'invités, style et prestations souhaitées ;
• comparer les offres reçues, prix, prestations incluses, disponibilité et conditions ;
• enregistrer des lieux et professionnels en favoris ;
• partager une fiche avec son conjoint, sa famille ou ses proches.

Les comparaisons doivent distinguer les prix confirmés des prix indicatifs et ne pas classer un prestataire comme meilleur sans
critères transparents.

16. Espace professionnel et administration commerciale
16.1 Espace partenaire




Chaque boutique, salle ou prestataire dispose de permissions adaptées à son activité pour :
• gérer sa fiche, ses contacts, ses photos, vidéos, portfolios et documents ;
• publier produits, services, tarifs, formules et conditions ;
• gérer demandes de devis, commandes, réservations et disponibilités ;
• confirmer ou refuser une demande et proposer une alternative ;
• vérifier les bons cadeaux et QR codes ;
• suivre ventes, réservations, commissions, paiements et remboursements ;
• consulter des statistiques de consultation et de conversion agrégées ;
• gérer les membres de son équipe et les accès autorisés.

16.2 Console d'administration ZAYA
L'administration peut vérifier les partenaires, modérer les contenus, gérer les catégories, suspendre une annonce, traiter les
signalements, consulter les réservations et transactions selon les droits, gérer les commissions et suivre les indicateurs. Les
actions sensibles doivent être journalisées et soumises au principe du moindre privilège.
Les équipes ZAYA ne doivent pas pouvoir consulter les messages privés de RENCONTRE ou les données privées des
utilisateurs sans procédure justifiée, contrôle d'accès et journalisation.

17. Partage de profils et liens profonds (Deep Links)
17.1 Partager un profil
Un membre peut partager le profil d'une autre personne afin de le recommander à un ami ou à un proche. Cette fonction est
facultative et doit respecter les paramètres de confidentialité du profil partagé.
• Le bouton Partager n'est proposé que si le propriétaire du profil autorise le partage externe.
• Le lien ne doit pas exposer les photos privées, coordonnées, messages, localisation précise ou informations masquées.
• Le propriétaire peut désactiver le partage ou révoquer les liens existants lorsque l'architecture le permet.
• Le lien doit utiliser un identifiant opaque, non un numéro de compte ou une donnée personnelle.
• Prévoir une durée de validité configurable et une page intermédiaire respectueuse de la confidentialité.

17.2 Ouverture de l'application ou installation
Le lien partagé doit :
• ouvrir directement le profil dans l'application si ZAYA est installée et que l'utilisateur est autorisé à le consulter ;
• sinon ouvrir une page web légère qui présente uniquement les informations publiques autorisées et propose les liens officiels
Google Play ou App Store ;
• après installation et ouverture, reprendre le contexte du profil partagé (deferred deep linking) si la solution technique et les
plateformes le permettent ;
• si la reprise différée échoue, afficher une page de destination dans l'application et permettre à l'utilisateur de retrouver le lien
partagé, sans divulguer le profil à un compte non autorisé.

L'utilisateur destinataire doit se connecter, respecter l'âge minimum et les règles d'accès avant de voir les détails. Le lien ne doit
jamais contourner le floutage Gratuit/Premium ni les paramètres de confidentialité.

17.3 Prévention des abus
Limiter le nombre de partages, détecter les envois massifs, permettre le signalement d'un lien, empêcher l'indexation des profils
privés par les moteurs de recherche et éviter les aperçus sociaux qui exposent des informations sensibles. Les métadonnées
d'aperçu doivent être génériques pour les profils protégés.




La technologie de lien différé doit être choisie après vérification de sa disponibilité, de son coût, de la compatibilité Android/iOS
et de ses conditions de confidentialité. Ne pas promettre un retour automatique après installation tant que le fournisseur et les
tests ne l'ont pas confirmé.

18. Modèle économique des espaces SHOP et EVENT
Sources de revenus possibles, à valider avec les partenaires et les coûts réels :
• commission sur les ventes ZAYA SHOP ;
• commission sur les réservations effectivement confirmées et payées via ZAYA ;
• abonnement professionnel facultatif pour des outils avancés ;
• mise en avant sponsorisée clairement identifiée ;
• options de visibilité et statistiques professionnelles.

Les coordonnées publiques et la mise en relation directe peuvent ne pas générer de commission. Le modèle doit éviter de
facturer une commission sur une réservation que ZAYA n'a ni suivie ni facilitée. Les prix, commissions, taxes, frais de paiement,
modalités de reversement et conditions de résiliation doivent être visibles et contractuels.
La publicité ne doit jamais utiliser les données sensibles de RENCONTRE, les conversations, les photos privées ou les
intentions matrimoniales individuelles pour le ciblage.

19. Exigences transversales, données et conformité
• Séparer les données de profil matrimonial, les données commerciales et les données de commande/réservation selon des rôles
et permissions distincts.
• Obtenir le consentement requis avant de partager les coordonnées d'un bénéficiaire ou d'un destinataire de cadeau.
• Collecter uniquement les données nécessaires et définir des durées de conservation.
• Fournir conditions d'utilisation, politique de confidentialité, règles partenaires, politique de remboursement et procédure de
réclamation.
• Vérifier les obligations applicables en Guinée et dans les pays d'extension : commerce électronique, protection des données,
paiements, fiscalité, publicité, droits des consommateurs et droit à l'image. Faire valider les contrats et documents par un
professionnel compétent avant lancement.
• Prévoir l'accessibilité, les faibles débits, les images compressées, la reprise après interruption et les notifications configurables.

20. Priorisation de la version 4.0
Phase 1 — socle de lancement
• Finaliser et tester ZAYA RENCONTRE, sécurité, confidentialité, modération et matrice Gratuit/Premium.
• Partage de profil par lien sécurisé, page web de redirection et ouverture directe si l'application est installée.
• ZAYA EVENT en annuaire public avec catégories, fiches professionnelles, photos/portfolio, contacts, favoris et demandes de
devis simples.
• Espace d'administration pour validation et modération des partenaires.

Phase 2 — transactions
• ZAYA SHOP avec catalogue, commande, paiement et bon cadeau à code/QR à usage unique.
• ZAYA EVENT avec calendrier des salles, demandes de réservation, confirmation et acompte si les paiements sont prêts.
• Espace professionnel pour commandes, devis, calendrier et suivi.

Phase 3 — extension
• Comparateur enrichi, avis vérifiés, portfolios vidéo, réservation de plusieurs prestataires et tableaux de bord analytiques.
• Synchronisation de calendriers et automatisation des paiements/commissions selon les capacités des partenaires.




• Extension géographique et multilingue après validation du pilote.

Le lancement de chaque fonction dépend de tests réels, de contrats partenaires, de la capacité de support et de la conformité. Il
est préférable de publier un périmètre fiable plutôt qu'une réservation affichée comme confirmée alors qu'elle ne l'est pas.

21. Critères d'acceptation spécifiques V4.0
1. ZAYA EVENT est accessible sans inscription à ZAYA RENCONTRE.
2. Un visiteur peut rechercher des lieux et consulter les informations publiques des prestataires.
3. Chaque partenaire contrôle les informations et coordonnées qu'il publie.
4. Les portfolios n'affichent que des médias autorisés et modérables.
5. Une disponibilité est horodatée et son statut est compréhensible ; aucune date n'est confirmée sans validation définie.
6. Le système empêche les doubles réservations sur un créneau confirmé.
7. Les conditions de prix, acompte, solde, annulation et remboursement sont visibles avant paiement.
8. Un bon cadeau a un code unique, est vérifié côté serveur et ne peut être utilisé qu'une fois.
9. Un profil RENCONTRE partagé ne révèle aucune donnée privée et respecte les droits du propriétaire et les règles
Gratuit/Premium.
10. Le lien ouvre l'application installée ou une page web avec les liens officiels des stores ; le parcours après installation est testé
avant d'être annoncé comme garanti.
11. Les actions d'administration et de partenaire sont contrôlées par rôle et journalisées.
12. Les données commerciales ne sont pas réutilisées pour profiler les membres de RENCONTRE.

22. Décisions finales consolidées
• ZAYA est une plateforme avec trois espaces : RENCONTRE, SHOP et EVENT.
• RENCONTRE reste une application de rencontre et non une agence matrimoniale.
• SHOP permet d'acheter un cadeau et de le faire remettre à un bénéficiaire dans une boutique partenaire avec un code/QR
sécurisé.
• EVENT est un annuaire et une plateforme de mise en relation, de devis et de réservation, ouverte même aux personnes qui
n'utilisent pas RENCONTRE.
• Les salles peuvent afficher leurs disponibilités grâce à un calendrier géré par le partenaire ou l'administration après confirmation
du responsable.
• Les prestataires peuvent présenter coordonnées professionnelles, réalisations, photos, vidéos, portfolio, tarifs et spécialités.
• Les utilisateurs peuvent appeler, contacter, demander un devis, comparer, enregistrer et partager les fiches.
• Les profils RENCONTRE peuvent être partagés par lien profond uniquement dans les limites de confidentialité du propriétaire.
• Premium ne permet jamais de contourner les réglages privés d'un autre membre.
• Les paiements, commissions, réservations, retraits, annulations et remboursements doivent être traçables et clairement
encadrés.

Fin du cahier des charges ZAYA V4.0

23. Inscription matrimoniale détaillée et profil structuré — Version
5.0
23.1 Finalité de l'inscription
L'inscription doit présenter clairement ZAYA comme une plateforme destinée aux adultes recherchant une relation sérieuse en
vue du mariage. L'expérience, les textes d'aide et les choix proposés doivent rappeler cette finalité. ZAYA n'est pas un service
de rencontres occasionnelles. L'accès est réservé aux personnes âgées d'au moins 18 ans.




23.2 Parcours d'inscription progressif
Le formulaire est organisé en étapes courtes avec barre de progression, sauvegarde du brouillon et possibilité de reprendre plus
tard. Les champs indispensables à la sécurité et à la création du compte sont obligatoires. Les informations personnelles de
compatibilité qui ne sont pas indispensables peuvent être ignorées puis complétées dans le profil.

Étape A — Compte et admissibilité
• Prénom ou nom d'affichage, selon la politique de confidentialité.
• Date de naissance et contrôle de majorité (18 ans minimum).
• Genre du profil, selon les catégories retenues par le produit.
• Numéro de téléphone vérifié et/ou adresse e-mail.
• Pays de résidence et ville ou zone approximative.
• Mot de passe robuste, consentements et acceptation des conditions d'utilisation.

Étape B — Situation matrimoniale et familiale
Champs structurés, avec choix dans des listes :
• Situation matrimoniale : célibataire, divorcé(e), veuf/veuve, marié(e), séparé(e) ou autre statut juridiquement pertinent selon le
pays.
• Nombre d'enfants : aucun, 1, 2, 3, 4, 5 ou plus ; possibilité de ne pas répondre si le champ est facultatif.
• Le cas échéant, préciser si les enfants vivent avec le membre, selon un choix facultatif.
• Projet de mariage et horizon envisagé : bientôt, dans les prochains mois, à moyen terme, sans date précise.
• Informations complémentaires sur la famille, facultatives et contrôlées par l'utilisateur.

Les libellés doivent être clairs et adaptés aux réalités locales. Ne pas déduire une situation matrimoniale à partir d'autres
données.

Étape C — Nationalité, pays et origine culturelle
• Nationalité : sélection dans une liste de pays, avec recherche.
• Pays de résidence distinct de la nationalité.
• Ethnie / groupe culturel : liste dépendante du pays sélectionné, chargée depuis un catalogue administrable.
• Exemple de configuration Guinée : Peul, Malinké, Soussou, Kissi, Guerzé/Kpèlè, Baga et autres groupes à valider localement.
• Exemple de configuration Sénégal : catalogue propre au Sénégal, à valider avec des sources locales.
• Option « autre » avec saisie facultative et option « je préfère ne pas répondre ».

Le catalogue des groupes culturels ne doit pas être codé en dur dans l'application. Il doit être administrable, versionné et
extensible pour chaque pays d'Afrique de l'Ouest. Les appellations doivent être relues localement, tenir compte des variantes et
éviter de présenter une liste comme exhaustive lorsqu'elle ne l'est pas. L'ethnie est une donnée personnelle sensible : collecte
facultative, consentement explicite, visibilité contrôlée par le membre, accès restreint, durée de conservation définie et absence
de ciblage publicitaire fondé sur cette donnée.

Étape D — Profession et activité
• Profession / métier sélectionné dans une liste avec recherche.
• Catégories administrables : administration, agriculture, commerce, artisanat, bâtiment, transport, santé, éducation, informatique,
finance, sécurité, industrie, services, étudiant(e), sans emploi, retraité(e), travail domestique/ménager et autres.
• Valeur « autre » avec saisie facultative.
• Statut d'activité facultatif : salarié(e), indépendant(e), entrepreneur(e), étudiant(e), recherche d'emploi, retraité(e), au foyer ou
autre.
• Ne pas déduire le revenu ou le niveau social du métier.

Le catalogue des professions doit être administrable et traduisible. Les intitulés doivent être inclusifs et adaptés aux métiers
réellement exercés dans chaque pays.

Étape E — Informations de compatibilité facultatives




• Taille.
• Langues parlées.
• Niveau d'études.
• Habitudes et centres d'intérêt.
• Préférences de lieu de résidence après mariage.
• Projet familial et attentes de vie.
• Description personnelle.

Chaque champ doit afficher « facultatif » lorsqu'il peut être ignoré. L'utilisateur peut modifier ses réponses et choisir ce qui est
visible sur son profil.

23.3 Administration des formulaires et référentiels
Le back-office doit permettre de :
• Ajouter, modifier, désactiver et traduire les questions.
• Définir les champs obligatoires, facultatifs ou conditionnels.
• Gérer les listes de nationalités, pays, ethnies/groupes culturels, métiers et situations matrimoniales.
• Associer un catalogue culturel à un pays.
• Prévisualiser le formulaire avant publication.
• Versionner les formulaires et conserver la traçabilité des changements.
• Éviter de casser les profils existants lors d'une modification de catalogue.
• Exporter des statistiques agrégées, sans exposer inutilement les données individuelles.

23.4 Utilisation des informations dans le matching
Les critères de compatibilité doivent respecter les préférences déclarées par chaque membre et les règles de confidentialité.
L'ethnie, la nationalité, la profession et la situation familiale ne doivent jamais être utilisées de manière cachée. Si un filtre
correspondant est proposé, il doit être explicite, facultatif, contrôlé par l'utilisateur et soumis aux règles légales applicables.
Aucun algorithme ne doit prétendre garantir la réussite d'un mariage.

24. Administration générale, statistiques et supervision — Version
5.0
24.1 Tableau de bord central
Le back-office web centralise l'administration du site vitrine, des applications Android/iOS, des événements et des services
associés. Indicateurs agrégés :
• Inscriptions, nouveaux membres et utilisateurs actifs.
• Répartition des profils par genre déclaré, pays et tranche d'âge lorsque la collecte et l'usage sont licites.
• Profils complets et vérifiés.
• Abonnements gratuits et Premium.
• Signalements, suspensions, appels et délais de traitement.
• Revenus publicitaires, abonnements et autres services.
• État technique, incidents et alertes de sécurité.

Les statistiques démographiques sont agrégées. Les petits groupes doivent être masqués ou regroupés pour éviter la
réidentification. L'accès aux données détaillées est limité par rôle et journalisé. Les catégories de genre proposées et leur usage
doivent être définis dans la politique de données ; ne pas inférer le genre à partir du prénom, des photos ou d'un algorithme.

24.2 Gestion des utilisateurs et sanctions
• Recherche et consultation selon les permissions.




• Vérification, suspension temporaire, restriction ciblée, réactivation et bannissement.
• Historique des signalements, décisions et sanctions.
• Procédure de contestation et réexamen humain.
• Détection des faux comptes, usurpations, spam et comportements automatisés.
• Seuils de signalements configurables : plusieurs signalements déclenchent une priorité de revue, mais ne constituent pas à eux
seuls une preuve de faute ni un bannissement automatique.
• Conservation proportionnée des preuves et des journaux.

24.3 Modération et sécurité des échanges
La charte doit interdire clairement les insultes, menaces, harcèlement, sollicitations sexuelles explicites, escroqueries, trafic
d'êtres humains, vente ou trafic de drogues, blanchiment, transactions illicites et détournements de la finalité matrimoniale de
ZAYA.
Les règles s'appliquent aux profils, biographies, photos, vidéos, publications, événements et contenus partagés. Les
comportements sont évalués selon le contenu et le contexte ; une caractéristique personnelle ou une identité supposée ne
constitue pas en elle-même une violation. Les signalements de victimes, demandes d'aide, citations nécessaires à un
signalement et contenus éducatifs doivent pouvoir être examinés sans sanction automatique.

Filtrage de la messagerie avant envoi
• Le contrôle s'exécute avant la transmission effective du message.
• Si un contenu enfreint clairement la charte, le message reste non envoyé et apparaît en rouge ou dans un état visuel distinct.
• Afficher : « Votre message contient des termes ou un contenu qui ne respectent pas la politique d'utilisation de ZAYA. Modifiez
votre message avant de l'envoyer. »
• Proposer une explication de la règle concernée et permettre la correction.
• Détecter les variantes, abréviations, fautes volontaires et contournements, tout en tenant compte du contexte.
• Les listes de mots et expressions sont préchargées avant le lancement, puis modifiables par les administrateurs habilités.
• Prévoir des catégories, niveaux de gravité, langues, variantes et dates de mise à jour.
• Les cas ambigus sont orientés vers une vérification adaptée plutôt que bloqués aveuglément.
• Après des tentatives répétées, appliquer des avertissements puis une revue de modération ; la suspension ou le bannissement
repose sur une règle publiée, des éléments suffisants et une possibilité de recours.
• Ne jamais enregistrer les messages privés dans les journaux administratifs ordinaires ni permettre leur consultation libre. Tout
examen exceptionnel doit être strictement limité, justifié, autorisé et audité.

Prévention des trafics et activités illicites
Détecter les indices de recrutement coercitif, d'exploitation, de transactions suspectes, de vente de drogues, d'arnaques ou de
sollicitation financière illicite. Les alertes doivent être évaluées par une équipe habilitée. Prévoir un protocole de conservation
sécurisée des éléments pertinents et d'escalade vers les autorités compétentes lorsque la loi l'exige, après validation juridique
locale. Ne pas promettre une détection parfaite.

24.4 Rôles et permissions
• Super-administrateur : configuration globale et gestion des rôles.
• Administrateur général : opérations générales autorisées.
• Modérateur : signalements, contenus et sanctions dans son périmètre.
• Responsable support : tickets et assistance, sans accès général aux conversations privées.
• Responsable financier : transactions, abonnements, rapprochements et remboursements.
• Gestionnaire publicité : campagnes, annonceurs et statistiques.
• Administrateur technique / sécurité : supervision, incidents et déploiements.

Appliquer le moindre privilège, la séparation des tâches, l'authentification multifacteur et un journal d'audit protégé.

24.5 Paiements et revenus




Centraliser les intégrations disponibles et contractuellement autorisées : Orange Money, MTN Mobile Money, Google Pay et
Apple Pay. Vérifier chaque transaction côté serveur, sécuriser les webhooks, empêcher les doubles débits, rapprocher les
règlements, gérer les remboursements et afficher les revenus par jour, semaine, mois et période personnalisée. Les moyens de
paiement ne sont activés qu'après validation des contrats, API, conformité et tests.

24.6 Sécurité technique et continuité
• HTTPS/TLS, contrôle d'accès serveur et politiques RLS.
• Hachage robuste des mots de passe, MFA administrateur et limitation de débit.
• Protection contre injections, XSS, CSRF, abus d'API et force brute.
• Gestion et révocation des sessions et appareils.
• Secrets conservés côté serveur, jamais dans l'application mobile ou le dépôt Git.
• Environnements développement, préproduction et production séparés.
• Sauvegardes chiffrées, tests de restauration et plan de reprise après sinistre.
• Monitoring, alertes, tests de pénétration et audits réguliers.
• Mode maintenance et mécanisme d'urgence pour désactiver une fonctionnalité compromise sans détruire les données.
• Procédure de réponse aux incidents et communication aux utilisateurs selon les obligations applicables.

25. Centre d'aide intelligent et contact WhatsApp — Version 5.0
25.1 Aide en libre-service
Créer un centre d'aide intégré à l'application et au site, avec recherche et catégories :
• Inscription et profil.
• Vérification et sécurité du compte.
• Découverte, likes et matchs.
• Messagerie et blocage.
• Premium, abonnements et paiements.
• Confidentialité, export et suppression des données.
• ZAYA Events et ZAYA Shop.
• Signalement et contestation.
• Problèmes techniques.

Chaque sujet propose des solutions prédéfinies, illustrées si utile, avec étapes simples et liens directs vers le bon écran. Les
articles sont administrables, versionnés, traduisibles et consultables hors connexion lorsque cela est possible.

25.2 Escalade vers l'administration
Après consultation d'une solution, demander « Cette réponse vous a-t-elle aidé ? ». Si non, proposer :
• Créer un ticket avec numéro de suivi.
• Contacter le support par WhatsApp.
• Signaler un problème de sécurité via un parcours prioritaire.

25.3 Redirection WhatsApp
Le bouton WhatsApp ouvre une conversation avec le numéro officiel configuré par l'administration, via un lien sécurisé et
administrable. Le message prérempli peut inclure le numéro de ticket et une catégorie, mais jamais un mot de passe, code OTP,
donnée bancaire ou contenu privé sensible. Afficher les horaires et délais indicatifs. Si WhatsApp n'est pas installé ou
disponible, proposer le ticket intégré ou l'e-mail officiel.
Le numéro WhatsApp, les horaires, les messages préremplis et les règles de disponibilité doivent être modifiables dans le
back-office. Ne pas inventer de numéro dans le code.




25.4 Assistance automatisée
Un assistant d'aide peut proposer des réponses issues exclusivement de la base documentaire validée. Il doit reconnaître ses
limites, ne pas inventer de politiques ou de décisions, et transférer à un humain les litiges financiers, suspicions de fraude,
risques pour la sécurité et situations sensibles. Les échanges d'assistance sont soumis à une politique de confidentialité et à
une durée de conservation définie.

26. ZAYA Events — Événements de mariage et participation
26.1 Publication d'un événement
Un membre ayant trouvé un partenaire et souhaitant organiser son mariage peut publier un événement dédié dans ZAYA
Events, distinct du flux de découverte matrimoniale. Il choisit les informations à rendre publiques : type d'événement, date, ville
ou lieu approximatif, description, nombre de participants recherché et date limite d'inscription.

26.2 Appels à participation
L'organisateur peut publier des besoins tels que :
• Filles d'honneur / demoiselles d'honneur.
• Garçons d'honneur.
• Bénévoles ou aide à l'organisation.
• Prestataires ou services complémentaires, avec orientation vers ZAYA Shop lorsque pertinent.

Les personnes intéressées peuvent consulter les conditions, envoyer une candidature et suivre son statut : reçue, en attente,
acceptée, refusée ou retirée. L'organisateur conserve le contrôle de la sélection. La participation ne doit jamais être présentée
comme un emploi rémunéré si ce n'est pas le cas.

26.3 Sécurité et modération des événements
• Vérification proportionnée de l'organisateur.
• Règles claires sur les frais éventuels, la rémunération et les attentes.
• Interdiction des annonces trompeuses, coercitives, discriminatoires, de traite ou de transactions illicites.
• Signalement et modération des événements et candidatures.
• Échanges limités au contexte de l'événement, avec blocage et signalement.
• Protection des coordonnées personnelles et affichage du lieu précis uniquement lorsque nécessaire et consenti.
• Contrôle des participants et possibilité d'annuler un événement.
• Aucun paiement ou transfert d'argent non sécurisé ne doit être imposé dans la messagerie.

27. Critères d'acceptation spécifiques à la version 5.0
Avant validation :
1. Un utilisateur peut terminer l'inscription avec les seuls champs obligatoires et ignorer les champs facultatifs.
2. La sélection d'un pays charge le catalogue d'ethnies/groupes culturels associé, administrable et extensible.
3. Les métiers sont sélectionnables dans une liste administrable avec recherche et option « autre ».
4. La situation matrimoniale et le nombre d'enfants sont enregistrés selon les consentements et règles de visibilité.
5. Le back-office affiche des statistiques agrégées sans exposer les données sensibles aux rôles non autorisés.
6. Un message non conforme est bloqué avant transmission, signalé visuellement et accompagné d'une explication.
7. Les avertissements, sanctions et recours sont traçables et vérifiables.
8. Les articles du centre d'aide sont administrables et les tickets sont suivis.
9. Le bouton WhatsApp ouvre uniquement le contact officiel configuré, sans exposer de secret.
10. Un organisateur peut publier un événement de mariage et gérer les candidatures.




11. Les tests de sécurité, de confidentialité, de charge et de restauration sont documentés.
12. Les décisions juridiques et les contrats de paiement nécessaires sont validés avant activation publique.

28. Décisions de mise en œuvre à confirmer
Les éléments suivants doivent rester configurables jusqu'à validation :
• Liste finale des pays et catalogues culturels, relus localement.
• Libellés définitifs des situations matrimoniales et professions.
• Champs obligatoires et règles de visibilité des données familiales.
• Numéro officiel WhatsApp et horaires du support.
• Seuils de modération, niveaux de sanctions et délais de recours.
• Textes définitifs de la charte, des conditions et de la politique de confidentialité.
• Contrats et disponibilité réelle de chaque moyen de paiement.
• Procédure locale d'escalade des cas de traite, de trafic et de danger imminent.

Toute donnée sensible doit être collectée au strict nécessaire, avec information et consentement adaptés, accès limité, durée de
conservation définie et mécanismes d'accès, de rectification et de suppression selon le droit applicable.

24. Historique et portée de la version 6.0
La version 6.0 conserve intégralement les exigences fonctionnelles et techniques de la V5.0 et ajoute les modules de
messagerie enrichie, de gestion des publications, de communautés et de conseil matrimonial facultatif. En cas de contradiction,
les règles de sécurité, de confidentialité et de consentement de la présente version prévalent.

25. Messagerie enrichie
25.1 Gestion des messages
Les utilisateurs peuvent envoyer et recevoir des messages texte et les médias autorisés par la politique de contenu. La
messagerie doit proposer :
• Statuts d'envoi, de réception et de lecture, selon les paramètres de confidentialité.
• Indicateur de saisie en cours, désactivable.
• Réponse à un message précis, réactions, transfert si autorisé et recherche dans l'historique.
• Messages vocaux et pièces jointes uniquement après contrôle de sécurité et de format.
• Archivage, épinglage, mise en sourdine et recherche de conversations.
• Blocage et signalement accessibles depuis la conversation.

25.2 Modifier, supprimer et annuler l'envoi
• « Supprimer pour moi » retire le message de la vue de l'utilisateur demandeur, sans modifier la copie du destinataire.
• « Annuler l'envoi » retire le message de la conversation des deux côtés lorsque l'opération est confirmée par le serveur. Une
mention neutre peut signaler qu'un message a été retiré.
• « Modifier » met à jour le contenu visible pour les deux participants et affiche la mention « Modifié ».
• La durée autorisée pour annuler ou modifier un message est configurable par l'administration.
• L'application ne doit jamais promettre que le destinataire n'a pas déjà lu, copié, capturé ou reçu une notification contenant le
message.
• Les événements nécessaires à la sécurité, aux litiges et à la conformité sont conservés selon une durée limitée, documentée et
contrôlée ; la suppression côté interface ne signifie pas effacement immédiat de toutes les sauvegardes ou traces légales.




25.3 Accès au profil depuis le chat
Un clic sur la photo ou le nom du correspondant ouvre son profil dans les limites de ses réglages de confidentialité. Le retour à
la conversation conserve la position de lecture et, si possible, le brouillon non envoyé.

25.4 Info-box et prévention
• Lors du premier message ou de la première utilisation de la messagerie, afficher une info-box élégante expliquant la charte et la
modération.
• Après une action importante, afficher une confirmation discrète et contextualisée.
• Un message détecté comme non conforme reste en brouillon et n'est pas transmis ; il est signalé visuellement avec une
explication claire et la possibilité de le corriger.
• Les avertissements et sanctions sont progressifs, proportionnés, traçables et contestables.
• Les filtres tiennent compte du contexte : une demande d'aide, un signalement ou une citation nécessaire à une plainte ne doit
pas être automatiquement sanctionné.

26. Publications et espace communautaire
26.1 Gestion des publications personnelles
L'auteur peut créer, modifier et supprimer ses publications, gérer les médias autorisés, désactiver les commentaires lorsque
disponible, consulter les réactions et signaler les abus. Toute modification doit être enregistrée avec date et auteur ; les
contenus supprimés sont traités selon la politique de conservation.

26.2 Confidentialité
Les options peuvent inclure : public, membres d'une communauté, abonnés autorisés ou privé, selon le type de contenu. Les
réglages sont expliqués avant publication. Aucune option payante ne peut contourner la confidentialité choisie par un autre
membre.

26.3 Création de communautés
Un membre admissible peut proposer une communauté avec :
• Nom, description, image et catégorie.
• Objectif, règles et pays ou zone concernés si utile.
• Visibilité publique ou privée.
• Modalités d'adhésion : libre, sur demande ou sur invitation.
• Désignation de coadministrateurs et modérateurs.

La création peut nécessiter une validation initiale ou être soumise à une surveillance renforcée selon le niveau de confiance du
créateur. Le créateur accepte les règles de modération et reste responsable de l'administration de son espace, sans remplacer
les pouvoirs de sécurité de ZAYA.

26.4 Abonnement et participation
Les membres peuvent découvrir, suivre, rejoindre ou quitter une communauté. Selon ses paramètres, ils peuvent lire les
publications, publier, commenter et réagir. L'abonnement à une communauté ne crée pas automatiquement un match et ne
donne aucun accès aux conversations privées de ses membres.

26.5 Notifications communautaires
Chaque membre choisit le niveau de notifications : toutes les publications, annonces importantes, événements seulement ou
aucune. Les notifications push doivent respecter les préférences, les limites anti-spam et les paramètres du téléphone.

26.6 Administration des communautés
Le back-office permet de rechercher les communautés, consulter les statistiques agrégées, examiner les signalements, valider
ou suspendre une communauté, gérer les appels et contrôler les actions des administrateurs. Les créateurs peuvent gérer leurs




modérateurs et leurs règles dans le périmètre autorisé. Un journal d'audit conserve les actions sensibles.

27. ZAYA Conseil Matrimonial — service facultatif
27.1 Principe
ZAYA propose un service facultatif d'accompagnement. Les deux personnes qui souhaitent être accompagnées peuvent
continuer seules, sans frais de conseil, ou solliciter un intervenant. Aucun conseiller n'est imposé et le service n'est pas une
condition pour utiliser le matchmaking.

27.2 Types d'intervenants
Le service peut accueillir, après vérification adaptée :
• Conseillers matrimoniaux indépendants.
• Cabinets ou agences de conseil matrimonial.
• Imams, prêtres et autres responsables religieux, selon la spécialité déclarée.
• Médiateurs familiaux.
• Psychologues ou professionnels de l'accompagnement conjugal dûment qualifiés.

Les titres, compétences et limites professionnelles doivent être présentés sans exagération. Les qualifications réglementées
sont vérifiées selon les règles du pays concerné.

27.3 Demande et consentement
• Un membre peut consulter un annuaire de conseillers et leurs spécialités, langues, disponibilités, tarifs et statut de vérification.
• Pour une intervention dans une démarche impliquant deux personnes, le consentement explicite des deux est requis avant de
partager des informations ou d'ouvrir un espace commun.
• Le conseiller ne peut pas accéder spontanément aux messages privés, profils non publics ou données personnelles du couple.
• Les participants peuvent mettre fin à l'intervention et signaler un comportement abusif.
• Le service ne remplace pas une assistance d'urgence, un avis médical, juridique ou religieux faisant autorité.

27.4 Honoraires et paiements
Le conseiller ou cabinet communique ses honoraires avant réservation. Le membre voit le prix total, la durée, les modalités
d'annulation et de remboursement avant de confirmer. Les paiements sont traités par les prestataires autorisés ; les
transactions, remboursements et éventuelles commissions de ZAYA sont traçables. La commission de ZAYA, si elle existe, est
affichée clairement.

27.5 Vérification et contrôle
L'administration vérifie l'identité, les références et les qualifications pertinentes, approuve ou refuse les profils, gère les
réclamations, les évaluations et les suspensions. Les badges distinguent clairement identité vérifiée et qualification
professionnelle vérifiée.

27.6 Comptes professionnels et rôles
Un cabinet peut disposer d'un compte professionnel avec plusieurs intervenants nommés. Chaque intervenant possède un
accès individuel, des permissions limitées et un historique d'activité. Le compte professionnel ne peut pas accéder aux matchs
ni se présenter comme candidat matrimonial par défaut.

28. Types de comptes et séparation des rôles
Le parcours d'inscription distingue :
1. Candidat au mariage : accès aux fonctions de découverte et de matchmaking selon les critères d'admissibilité.




2. Conseiller ou cabinet : accès à l'annuaire professionnel et aux demandes d'accompagnement validées, sans apparition dans
les matchs.
3. Accompagnateur ou représentant familial : accès limité aux fonctions explicitement autorisées par le membre accompagné.

Le rôle de Wali, le rôle de conseiller matrimonial et le rôle d'imam ou de responsable religieux ne sont pas interchangeables.
Une même personne peut déclarer plusieurs fonctions, mais chacune est présentée et vérifiée séparément. Les règles relatives
au Wali sont configurables selon le contexte juridique et religieux ; ZAYA ne prétend pas déterminer seule la validité d'un
mariage.

29. Exigences UX/UI et critères d'acceptation V6.0
• Depuis une conversation, ouvrir le profil puis revenir sans perdre la position du chat.
• Un message annulé n'est plus visible dans la conversation des deux participants après confirmation serveur ; l'application
indique clairement les limites de cette fonction.
• Un message modifié affiche son statut « Modifié ».
• Un message bloqué par la modération n'est jamais transmis au destinataire.
• Un utilisateur peut modifier ou supprimer sa publication selon ses droits.
• Un créateur peut proposer une communauté, configurer sa visibilité et ses règles, puis gérer les abonnés et modérateurs
autorisés.
• Un membre peut s'abonner, se désabonner et régler les notifications d'une communauté.
• Aucun abonnement communautaire ne donne accès aux messages privés.
• Un conseiller ne reçoit aucune demande sans action volontaire de l'utilisateur.
• Une intervention commune n'est activée qu'après consentement explicite des deux personnes.
• Les honoraires sont affichés avant paiement et les opérations financières sont traçables.
• Toutes les actions administratives sensibles sont journalisées et accessibles selon les rôles.

30. Priorisation de livraison
MVP / première livraison : messagerie sécurisée, suppression pour soi, annulation d'envoi, modification encadrée, accès au
profil depuis le chat, publications modifiables, communautés avec abonnement et modération administrative.
Version suivante : annuaire de conseillers vérifiés, demandes d'accompagnement, consentement bilatéral, rendez-vous et
paiements.
Évolutions ultérieures : comptes de cabinets multi-intervenants, statistiques avancées, évaluations vérifiées et outils
professionnels supplémentaires.
Les modules de la V6.0 doivent être estimés séparément, testés en environnement de préproduction et activés progressivement
par configuration. La sécurité, la confidentialité et les règles de consentement restent obligatoires dès la première livraison.

# ADDENDUM CONSOLIDÉ — VERSION 6.3

**Date : 15 novembre 2026**  
**Statut : consolidation des fonctionnalités discutées ; décisions commerciales, juridiques et techniques encore à valider lorsqu'elles sont signalées comme telles.**

Cet addendum complète la base V6.0 reproduite intégralement ci-dessus. Il ne supprime aucune exigence antérieure. En cas de doublon, la règle la plus précise et la plus protectrice en matière de consentement, de sécurité et de confidentialité prévaut.

## 31. ZAYA Compatibility — moteur intelligent de compatibilité matrimoniale

### 31.1 Objectif

Aider chaque membre à découvrir des profils dont les attentes et préférences sont compatibles, et expliquer les points communs de manière compréhensible. Le moteur facilite la découverte ; il ne prédit ni la sincérité, ni la qualité future d'une relation, ni la réussite d'un mariage.

### 31.2 Étape 1 : filtres d'éligibilité réciproques

Avant tout score, appliquer les règles bloquantes des deux côtés : âge légal (18 ans minimum), type de compte admissible au matchmaking, comptes actifs et non suspendus, préférences d'âge et de localisation, paramètres de visibilité, exclusions, blocages, signalements nécessitant une restriction, disponibilité et critères explicitement déclarés non négociables. Un profil n'est recommandé que si les paramètres des deux personnes sont compatibles. Un Boost ou un paiement ne peut jamais contourner ces règles.

### 31.3 Étape 2 : score indicatif et pondérations configurables

Après les filtres, calculer un indicateur de compatibilité à partir des réponses volontaires et disponibles, par exemple :

- intention matrimoniale et horizon souhaité ;
- attentes de vie commune et projets de vie ;
- souhait d'avoir ou non des enfants et projet familial ;
- langues parlées et capacité de communication ;
- ville, pays, mobilité et distance approximative ;
- rythme de vie, centres d'intérêt et style de communication ;
- situation matrimoniale et informations de profil que chacun a choisi de partager ;
- valeurs et attentes personnelles déclarées, avec prudence particulière pour les données sensibles.

Les poids sont configurables et documentés. Les champs manquants ne sont pas considérés comme incompatibles : le moteur réduit la confiance de l'indicateur ou omet le critère. Ne pas inventer de points communs ni pénaliser une personne qui ne renseigne pas un champ facultatif. Les données ethniques ne sont pas un critère de classement par défaut. Les données religieuses et autres données sensibles ne sont utilisables qu'avec une base légale appropriée, une information claire et un consentement explicite lorsque requis ; elles sont exclues de la publicité.

### 31.4 Présentation des points communs

Sur une fiche profil, afficher quelques explications factuelles, par exemple : « Vous souhaitez tous deux vous marier dans un délai proche », « Vous parlez français », « Vous recherchez tous deux une vie familiale avec enfants », « Vous habitez dans la même région ». Ajouter si nécessaire « sujets à discuter » lorsque des réponses diffèrent. Chaque explication doit provenir de réponses réelles et visibles selon les autorisations de chaque membre.

Le score est présenté comme un repère indicatif, jamais comme une garantie. Prévoir une option pour désactiver la personnalisation et utiliser les filtres classiques. Tester régulièrement les biais et les effets disproportionnés selon le genre, l'âge, la langue, le pays, le handicap et la situation socio-économique.

### 31.5 Administration et mesure

Le back-office configure les critères autorisés, pondérations, seuils, explications, pays activés et tests A/B. Toute modification est versionnée et journalisée. Mesurer la pertinence déclarée, les intérêts réciproques, les conversations réciproques, les signalements et les écarts de performance, sans optimiser uniquement le temps passé dans l'application.

## 32. Règles détaillées de Match, refus et dématch

- Un intérêt unilatéral crée une demande ; il ne crée pas encore un Match.
- Le destinataire peut accepter, refuser ou ignorer. Si chacun a déjà exprimé son intérêt, le Match peut être confirmé automatiquement puisque le consentement est réciproque.
- Les mêmes droits s'appliquent à tous les genres : envoyer un intérêt, accepter, refuser, annuler, bloquer ou signaler.
- Après Match, ouvrir la conversation. L'un ou l'autre peut mettre fin au Match depuis le profil ou la conversation, après confirmation.
- Le dématch verrouille les nouveaux messages et retire le lien des listes de Match des deux côtés. L'application explique ce qui reste visible et ce qui est conservé pour sécurité, obligations légales ou traitement d'un signalement.
- Le dématch n'est pas un blocage. Le blocage empêche les interactions futures selon les règles produit ; le signalement transmet un dossier à la modération.
- Prévoir expiration configurable des demandes, limitation des sollicitations répétées et historique conforme aux réglages de confidentialité.
- Ajouter la pause temporaire du profil, distincte de la suppression du compte ; préserver les données et conversations selon le choix explicite et les règles de sécurité.

## 33. ZAYA Promotions, coupons et récompenses — V6.2

### 33.1 Types de campagnes

- Offre d'anniversaire : code personnel ou avantage automatique, avec durée de validité configurable.
- Codes de bienvenue, de parrainage ou de réactivation, sous réserve d'un programme de parrainage distinct et transparent.
- Campagnes saisonnières ou événementielles : Ramadan, fêtes, saison des mariages, lancement d'un pays, campagne partenaire ou opération spéciale.
- Réductions Premium : pourcentage, montant fixe, période d'essai ou jours Premium offerts.
- Offres ciblées selon des critères non sensibles et légalement autorisés ; aucun ciblage fondé sur les messages privés, la religion, l'ethnie ou les données biométriques.

### 33.2 Règles d'utilisation

Chaque coupon possède un identifiant, une période de validité, un pays ou périmètre, une population éligible, un type et montant d'avantage, un plafond global et individuel, un nombre d'utilisations, une règle de cumul, une éventuelle dépense minimale, et un statut actif/inactif. Vérifier côté serveur l'existence, la validité, l'éligibilité, les limites et l'absence de double utilisation avant de confirmer le paiement.

Les exemples de codes ou taux cités dans les échanges sont illustratifs et ne constituent pas des tarifs validés. Afficher le prix initial, la remise, le prix final, les conditions et la date d'expiration avant confirmation. Pas de fausse urgence ni de compte à rebours trompeur. En cas de remboursement, recalculer l'avantage selon des règles publiées et conserver une trace financière.

### 33.3 Administration et statistiques

Le back-office permet de créer, modifier, programmer, suspendre et clôturer une campagne ; gérer les codes automatiques ou manuels ; définir pays, dates, quotas, segments autorisés, remises et règles de cumul ; prévisualiser les messages ; exporter les résultats. Statistiques : codes émis/utilisés/expirés, conversions, nouveaux abonnements, revenus nets, remises accordées, remboursements et fraude suspectée. Séparer les permissions marketing et financières ; journaliser chaque changement.

### 33.4 Anniversaires et récompenses

Les avantages d'anniversaire sont facultatifs, annoncés à l'utilisateur et envoyés uniquement selon ses préférences de notification. La date de naissance reste privée ; ne jamais exposer l'année ou l'âge au-delà des règles de visibilité. Une récompense ne doit pas pousser à divulguer des données supplémentaires non nécessaires.

## 34. Centre de sécurité intelligent dans la messagerie — V6.3

### 34.1 Détection et masquage des coordonnées

Lorsqu'un message contient un numéro de téléphone identifiable, détecter le format selon les pays et afficher par défaut une version masquée au destinataire, par exemple « +224 ••• •• •• •• ». Le message doit rester accessible dans le contexte de la conversation, mais le numéro complet n'est révélé qu'après une action volontaire du destinataire et un avertissement clair. Proposer : « Afficher le numéro », « Garder masqué » et « Signaler ». Ne pas rendre le partage impossible de façon générale ; respecter le choix éclairé des adultes, sauf contenu manifestement illicite ou compte soumis à restriction.

La détection doit reconnaître les formats internationaux, espaces, tirets, chiffres séparés, préfixes locaux et variantes courantes, sans masquer abusivement des dates, montants, références de commande ou autres suites numériques. Les règles par pays sont administrables et testées.

### 34.2 Avertissement avant révélation

Texte de référence :

> **Votre sécurité est notre priorité.** Avant de partager vos coordonnées ou de poursuivre la conversation en dehors de ZAYA : ne transférez jamais d'argent à une personne que vous n'avez pas rencontrée et dont vous n'avez pas vérifié l'identité ; ne communiquez jamais de code OTP, mot de passe ou code bancaire ; gardez vos échanges et appels sur ZAYA aussi longtemps que possible ; si vous décidez de rencontrer cette personne, choisissez un lieu public, informez un proche et évitez de vous rendre seul(e) à un premier rendez-vous.

Boutons : « Afficher le numéro » et « Annuler ». L'avertissement ne doit pas prétendre que ZAYA a vérifié l'identité ou la fiabilité du correspondant. Il peut être réaffiché si un nouveau numéro est détecté ou si un risque plus élevé est identifié.

### 34.3 Détection de comportements à risque

Détecter, avec analyse contextuelle et seuils gradués : demandes de transfert d'argent ou de Mobile Money, demandes de codes OTP ou mots de passe, demandes de coordonnées bancaires, chantage, extorsion, urgence financière répétée, liens de phishing ou malveillants, usurpation d'identité, recrutement coercitif, propositions commerciales frauduleuses et tentatives de faire sortir rapidement la personne de la plateforme.

Pour un lien externe, afficher le domaine de destination lorsqu'il peut être déterminé, avertir avant ouverture et bloquer les URL confirmées malveillantes selon une liste de réputation actualisée. Ne jamais garantir qu'un lien est sûr uniquement parce qu'il n'est pas signalé.

### 34.4 Alerte avant envoi et mesures graduées

Si un message sortant paraît risqué, afficher une explication à l'expéditeur avant transmission. Selon le niveau : conseil non bloquant, confirmation, blocage temporaire du message, mise en attente pour examen ou signalement à la modération. Les faux positifs doivent pouvoir être contestés. Une détection automatique seule ne doit pas déclencher un bannissement définitif. Les messages manifestement interdits (menaces, chantage, fraude établie, exploitation) suivent la politique de modération et les procédures d'urgence.

### 34.5 Bouclier de sécurité dans chaque conversation

Ajouter une icône Bouclier accessible depuis l'en-tête de conversation. Elle ouvre un panneau contenant : conseils de sécurité, signaler, bloquer, gérer les coordonnées masquées, consulter les règles, vérifier les invitations de rencontre et accéder au centre d'aide. Les actions bloquer et signaler restent accessibles même si la conversation est verrouillée ou en erreur réseau ; prévoir une file d'attente sécurisée pour l'envoi du signalement si nécessaire.

### 34.6 Protection des rendez-vous

Lorsqu'une invitation de rencontre est créée, afficher des conseils : lieu public, transport indépendant, prévenir un proche, ne pas envoyer d'argent, ne pas partager de documents ou codes sensibles. Proposer facultativement de partager les détails du rendez-vous avec un contact de confiance, uniquement après consentement et avec contrôle précis de ce qui est partagé. Prévoir rappel avant et après le rendez-vous, désactivable.

### 34.7 Confidentialité et transparence de la modération

Définir précisément les données analysées, la finalité, la durée de conservation et les personnes autorisées. Ne jamais utiliser les conversations, numéros ou signaux de fraude pour la publicité ou le profilage commercial. Informer les membres des contrôles appliqués. Limiter les accès humains aux cas justifiés, avec journal d'audit. Les éléments nécessaires à une enquête peuvent être conservés selon une politique documentée, même si un message est supprimé de l'interface ; l'utilisateur doit être informé des limites de suppression.

Si le produit promet un chiffrement de bout en bout, la détection côté serveur des contenus doit être repensée : ne pas prétendre simultanément à un chiffrement de bout en bout et à une lecture serveur générale des messages. Les choix d'architecture, de chiffrement et de modération doivent être décidés explicitement avant développement.

### 34.8 Paramétrage de l'administration

Gérer les formats de numéros par pays, niveaux de masquage, textes d'avertissement traduits, catégories de risque, seuils, listes de domaines malveillants, règles de récidive, files de modération, accès aux dossiers, durée de conservation et statistiques agrégées. Toute règle sensible est versionnée et auditée. Les indicateurs incluent alertes affichées, numéros révélés, messages bloqués, faux positifs contestés, signalements, délais de traitement et récidives ; ne pas conserver plus de données que nécessaire.

## 35. Compléments de sécurité, de confidentialité et d'administration

- Appliquer la détection et la sensibilisation aux messages privés, publications communautaires, commentaires, événements et échanges avec les conseillers, avec des règles adaptées au contexte.
- Maintenir un filtrage administrable des insultes, vulgarités, menaces, contenus sexuels explicites et variantes de contournement. Le contexte doit être pris en compte ; un mot isolé ne suffit pas toujours à conclure à une infraction.
- Lorsqu'un message est bloqué, ne pas le transmettre ; l'afficher clairement à l'expéditeur avec motif compréhensible, possibilité de corriger et procédure de recours.
- Les sanctions sont graduées, proportionnées et traçables : avertissement, restriction temporaire, suspension, puis bannissement lorsque les faits le justifient. Réexamen humain pour les sanctions sévères.
- Le back-office utilise le moindre privilège, authentification multifacteur pour les rôles sensibles, séparation des tâches, journal d'audit non modifiable par les opérateurs ordinaires et alertes sur actions administratives anormales.
- Les opérateurs ne disposent pas d'un accès libre aux conversations privées. Tout accès exceptionnel doit avoir un motif, un dossier, une durée limitée et une trace consultable.
- Les fonctions de sécurité ne doivent pas devenir un prétexte à la collecte excessive, au ciblage publicitaire ou à une surveillance générale.

## 36. Critères d'acceptation additionnels V6.3

1. Le moteur applique les filtres d'éligibilité réciproques avant tout classement et ne recommande jamais un profil bloqué ou incompatible avec les préférences mutuelles.
2. Chaque point commun affiché correspond à une donnée réellement renseignée et visible ; les informations manquantes ne sont pas inventées.
3. Un score de compatibilité est présenté comme indicatif et peut être désactivé ; il ne garantit pas la réussite d'une union.
4. Les demandes d'intérêt, acceptations, refus, expirations et dématch fonctionnent de manière symétrique pour les membres concernés.
5. Un numéro reconnu est masqué par défaut dans le parcours prévu ; le destinataire peut l'afficher après avertissement, le garder masqué ou signaler.
6. Les formats de numéros locaux et internationaux sont testés contre les faux positifs.
7. Les avertissements anti-arnaque couvrent au minimum les transferts d'argent, Mobile Money, OTP, mots de passe, liens externes et rencontres physiques.
8. Les alertes de risque sont explicables ; les sanctions sévères ne reposent pas uniquement sur une décision automatique.
9. Les liens confirmés malveillants sont bloqués ou accompagnés d'une protection adaptée ; les autres liens déclenchent un avertissement externe lorsque nécessaire.
10. Le bouclier de sécurité est accessible depuis chaque conversation et donne accès au blocage, signalement et centre d'aide.
11. Les coupons sont vérifiés côté serveur et ne peuvent être utilisés au-delà de leurs limites ou cumulés contrairement à leurs conditions.
12. Les administrateurs peuvent configurer campagnes, dates, quotas, règles de sécurité et messages sans nouvelle version mobile, dans les limites prévues.
13. Les données de conversations et les signaux de fraude ne sont jamais utilisés à des fins publicitaires.
14. Les accès aux dossiers de modération et les changements de configuration sont journalisés et contrôlés par rôle.
15. Les tests couvrent Android d'entrée de gamme, réseau lent, formats guinéens et internationaux, accessibilité, faux positifs, recours et sécurité des données.

## 37. Priorisation consolidée et décisions ouvertes

**Avant ouverture publique :** inscription et consentements, vérification de profil, filtres réciproques, Match réciproque, signalement/blocage, règles communautaires, centre de sécurité minimal, protection des données, console de modération, assistance et procédures d'incident.

**Après pilote :** moteur de compatibilité explicable, masquage/révélation contrôlée des numéros, détection graduée des risques, coupons et campagnes Promotions, statistiques avancées et parcours rendez-vous sécurisé.

**Évolutions ultérieures :** analyse anti-fraude enrichie, intégrations de réputation de liens, appels audio/vidéo, automatisation avancée, programmes partenaires et extension multi-pays.

À confirmer avant développement : prestataires de vérification et de détection, choix du chiffrement de messagerie, base légale et politique de conservation, textes juridiques par pays, disponibilité des moyens de paiement, règles de remboursement, budgets de modération, langues prises en charge, tarifs Premium et coupons, seuils de détection, durées de conservation et SLA de support.

## 38. Historique des évolutions

- **V6.0** : base fonctionnelle et technique, messagerie enrichie, communautés, conseil matrimonial, comptes différenciés et événements.
- **V6.2** : module Promotions, coupons, réductions, offres d'anniversaire et récompenses administrables.
- **V6.3** : Centre de sécurité intelligent dans la messagerie, masquage des numéros, avertissements anti-arnaque, détection graduée des risques, bouclier de sécurité et précisions du moteur de compatibilité et du Match réciproque.

## 39. ZAYA Paiements — moyens de paiement et architecture centralisée V6.4

### 39.1 Périmètre

Créer un module centralisé **ZAYA Paiements**, utilisé par les espaces et services ZAYA concernés. Il couvre notamment les abonnements Premium, les achats de ZAYA Shop, les réservations et prestations ZAYA Event, ainsi que les autres opérations commerciales explicitement activées. Chaque opération est rattachée à un service, une commande ou un abonnement identifiable. Les paiements ne doivent pas être considérés comme confirmés sur la seule base d'une capture d'écran ou d'une déclaration du client.

### 39.2 Moyens de paiement à prévoir

Prévoir une architecture permettant d'intégrer, selon les pays, les contrats marchands et la disponibilité réelle des prestataires :

- Orange Money.
- Mobile Money des opérateurs disponibles, notamment MTN MoMo lorsque le service est accessible.
- Google Pay sur les marchés, appareils et parcours compatibles.
- Apple Pay sur les marchés, appareils et parcours compatibles.
- Les moyens complémentaires pourront être ajoutés ultérieurement après validation du propriétaire du projet et du prestataire concerné ; ils ne sont pas réputés actifs par défaut.

L'administration doit pouvoir configurer la disponibilité par pays, devise, service, plateforme et prestataire. L'interface mobile ne présente que les moyens réellement activés et utilisables pour le parcours concerné. L'intégration reste conditionnée à la documentation officielle, à l'éligibilité du compte marchand, aux contrats, aux frais, aux limites et aux règles réglementaires applicables.

**Règle particulière pour les abonnements numériques :** les achats de fonctionnalités ou d'avantages numériques consommés dans l'application doivent respecter les règles de facturation de Google Play et de l'App Store applicables au moment de la publication. Google Pay et Apple Pay ne remplacent pas automatiquement Google Play Billing ou Apple In-App Purchase. Le choix du circuit doit être validé séparément pour chaque plateforme et catégorie de vente. Les biens physiques et prestations réelles suivent le circuit de paiement autorisé correspondant.

### 39.3 Cycle de vie d'une transaction

Chaque transaction doit comporter au minimum : identifiant interne unique, référence lisible, compte utilisateur, service concerné, commande ou abonnement associé, montant, devise, moyen et prestataire, date de création, date de confirmation, statut, frais éventuels, montant net, référence du prestataire et motif d'échec ou de remboursement lorsqu'il existe.

Statuts à gérer : en attente, en cours, confirmée, échouée, annulée, remboursée, partiellement remboursée et contestée. Les transitions de statut sont contrôlées côté serveur. Une transaction ne peut être confirmée que par une réponse vérifiée du prestataire ou par le mécanisme officiel de facturation de la plateforme concernée.

Exigences techniques et anti-fraude :
- Vérifier côté serveur les paiements et notifications (webhooks) ; contrôler leur signature ou mécanisme d'authenticité.
- Utiliser des clés d'idempotence et des références uniques pour empêcher les doubles débits et doubles activations.
- Vérifier montant, devise, bénéficiaire, commande, statut et référence avant d'accorder un avantage.
- Prévoir rapprochement périodique entre les transactions ZAYA et les relevés des prestataires.
- Journaliser les remboursements, annulations, contestations et corrections ; limiter les actions manuelles et exiger une autorisation appropriée.
- Ne jamais stocker les codes PIN Mobile Money, mots de passe bancaires ou données complètes de carte dans ZAYA.
- Garder les clés et secrets des prestataires côté serveur, dans un gestionnaire de secrets ; aucun secret marchand dans l'application mobile ou le dépôt Git.
- Prévoir des environnements de test et de production séparés.

### 39.4 Historique des paiements côté utilisateur

Ajouter dans le compte une rubrique **« Mes paiements »** présentant les opérations du membre avec filtres et détail individuel. Pour chaque opération, afficher les informations disponibles : référence, date et heure, service ou achat, montant et devise, moyen de paiement, statut, frais éventuels et reçu téléchargeable lorsque le prestataire le permet.

Les erreurs doivent être expliquées sans exposer de données techniques sensibles. Les opérations en attente, échouées ou remboursées doivent être clairement distinguées des paiements confirmés. Un reçu ne doit être généré comme payé qu'après confirmation effective.

### 39.5 Administration web des paiements

Dans ZAYA Super Admin, créer un espace financier centralisé avec :
- Vue d'ensemble des volumes et montants par période, pays, devise, service, moyen de paiement et statut.
- Recherche par référence, compte, commande, abonnement ou référence prestataire.
- Consultation du détail d'une transaction et de son historique d'événements.
- Gestion des remboursements et contestations selon les droits accordés et les capacités du prestataire.
- Configuration des moyens activés, pays, devises, frais et paramètres non secrets.
- Suivi des échecs, paiements en attente, anomalies, doublons potentiels et rapprochements.
- Exports contrôlés pour la comptabilité et les rapports financiers.

Les informations de carte, secrets, OTP et données bancaires sensibles ne doivent pas être visibles dans la console. Les rôles financiers sont distincts des rôles de modération et de support. Les opérations sensibles nécessitent confirmation, permissions adaptées et journal d'audit.

## 40. Abonnements Premium — historique et cycle de vie V6.4

### 40.1 Historique côté utilisateur

Ajouter une rubrique **« Mes abonnements »** permettant de consulter :
- L'offre actuelle : Gratuit ou Premium.
- Le statut : actif, en attente, expiré, annulé, suspendu ou retiré, selon le cas.
- La date de début et la date de fin ou d'expiration.
- La durée souscrite ou accordée.
- Le mode d'obtention : achat, attribution administrative gratuite ou avantage partenaire.
- Le renouvellement éventuel et sa date, lorsqu'il existe.
- L'historique des abonnements précédents, prolongations et changements de statut.

Un abonnement offert ne doit jamais être présenté comme un paiement effectué. Le prix réellement payé, s'il y en a un, doit être consultable dans « Mes paiements » et relié à l'abonnement correspondant.

### 40.2 Règles de gestion

- À l'expiration, les avantages Premium cessent automatiquement et le compte revient au niveau Gratuit, sauf renouvellement confirmé ou prolongation valide.
- Un renouvellement automatique ne peut être activé que si le parcours et le prestataire le permettent et si le consentement requis a été recueilli.
- Une activation Premium intervient uniquement après confirmation serveur du paiement ou attribution administrative autorisée.
- Les dates et heures sont calculées côté serveur avec un fuseau de référence documenté ; l'interface affiche les dates dans le fuseau local du membre.
- Une prolongation doit appliquer une règle cohérente : si l'abonnement est encore actif, ajouter la durée à sa date de fin ; s'il est expiré, démarrer à la date d'effet définie. La règle appliquée doit être visible dans l'historique.
- L'annulation d'un renouvellement, l'expiration et le retrait administratif sont des événements distincts et doivent être identifiés séparément.

### 40.3 Gestion manuelle par l'administrateur

Depuis la fiche d'un compte dans ZAYA Super Admin, un administrateur disposant de l'autorisation appropriée peut :
- Accorder gratuitement Premium à un compte pour une durée définie.
- Choisir une durée prédéfinie (par exemple 7 jours, 15 jours, 1 mois, 3 mois, 6 mois ou 1 an) ou saisir une période personnalisée.
- Définir la date de début et la date d'expiration lorsque cela est nécessaire.
- Prolonger un accès Premium existant.
- Retirer Premium avant son expiration.

Toute attribution doit obligatoirement comporter un motif et une origine, par exemple : promotion, geste commercial, partenariat, compensation ou compte de test. Ces catégories sont administrables. Une attribution gratuite crée un droit Premium à montant payé nul ; elle ne crée aucune transaction financière fictive et n'augmente pas le chiffre d'affaires.

Lors du retrait, les avantages Premium sont désactivés selon la règle d'effet configurée et clairement indiquée avant confirmation. Le système conserve l'abonnement initial et ajoute un événement de retrait ; il ne supprime pas l'historique. L'utilisateur reçoit une notification informative lorsque cela est approprié.

### 40.4 Historique et audit des actions Premium

Pour chaque création, attribution, prolongation, retrait ou expiration, enregistrer : identifiant du compte, administrateur ou processus système à l'origine de l'action, date/heure, ancienne et nouvelle période, ancien et nouveau statut, motif, origine, identifiant de l'opération et éventuelle référence de transaction.

L'historique est append-only ou protégé contre toute modification par les opérateurs ordinaires. Les corrections se font par un nouvel événement traçable, jamais par effacement silencieux. Les permissions d'accorder et de retirer Premium sont distinctes si nécessaire ; les actions sensibles sont protégées par MFA pour les rôles concernés et soumises au moindre privilège.

### 40.5 Tableau de bord des abonnements

Le back-office doit permettre de filtrer les abonnements actifs, expirés, annulés, retirés et offerts ; de distinguer les abonnements payés des accès gratuits ; de consulter les dates, durées, renouvellements et revenus réellement encaissés ; et d'exporter des rapports agrégés. Les indicateurs de revenus excluent les accès Premium gratuits et identifient séparément les remises, remboursements et commissions.

## 41. Badges de compte — Premium et Profil vérifié V6.4

### 41.1 Badge Premium

Afficher un badge Premium distinctif sur le profil et dans les surfaces de découverte ou de conversation où l'information est pertinente et autorisée par les réglages de confidentialité. Son apparence graphique reste configurable dans le design system ZAYA.

Le badge est calculé à partir du statut Premium effectif côté serveur : il est actif pour un abonnement payé, offert ou partenaire valide ; il disparaît automatiquement à l'expiration ou au retrait. Il ne peut pas être attribué manuellement comme simple décoration sans droit Premium actif. L'affichage du badge ne doit pas divulguer le montant payé ni le motif d'un avantage offert.

### 41.2 Badge Profil vérifié

Créer un badge **« Profil vérifié »** indépendant du Premium. Il signale qu'une procédure de vérification définie par ZAYA a été réussie. Le fait d'être Premium ne donne aucun droit automatique au badge vérifié et le paiement ne peut jamais acheter une vérification.

Les niveaux de contrôle doivent être distingués dans les données et expliqués à l'utilisateur :
- Téléphone confirmé : numéro contrôlé par OTP ; afficher un indicateur spécifique « Téléphone vérifié », sans le confondre avec la vérification complète du profil.
- Photo/selfie vérifié : contrôle de présence réelle et cohérence avec les photos du profil, avec consentement et procédure de recours.
- Identité vérifiée : pièce d'identité contrôlée par une procédure adaptée, si le service est disponible et légalement justifié.

Le badge public « Profil vérifié » n'est accordé qu'après réussite du niveau de vérification photo/selfie ou identité défini comme admissible par la politique de ZAYA. Le détail accessible depuis le badge précise le type de contrôle réalisé et sa portée. Ne jamais laisser entendre qu'une vérification garantit l'honnêteté, la sécurité, la situation matrimoniale ou les intentions d'un membre.

### 41.3 Demande et traitement de vérification

Le membre peut demander une vérification et suivre son statut : non demandée, en attente, informations complémentaires requises, approuvée ou refusée. La procédure explique les données nécessaires, la finalité, la durée de conservation et les voies de recours. Le membre peut demander un réexamen d'un refus.

Les justificatifs et données biométriques éventuelles sont privés, chiffrés, accessibles uniquement aux personnes autorisées et conservés pendant la durée minimale justifiée. Les règles de suppression, de rétention en cas de fraude et les obligations légales doivent être documentées. Aucun justificatif brut ne doit être affiché sur le profil ni accessible aux autres membres.

### 41.4 Administration des vérifications

Créer dans l'administration une file de demandes permettant aux agents autorisés de consulter les dossiers nécessaires, demander un nouveau justificatif, approuver ou refuser avec motif, suspendre ou retirer un badge en cas d'erreur ou de fraude et traiter les recours. Chaque décision est horodatée et rattachée à l'agent ou au contrôle automatisé concerné. Les accès aux justificatifs sont eux-mêmes journalisés.

## 42. Critères d'acceptation additionnels V6.4

1. Un utilisateur peut consulter séparément son historique d'abonnements et son historique de paiements.
2. Chaque paiement affiche une référence unique, un montant, une devise, un moyen, une date et un statut cohérents avec la confirmation serveur.
3. Un paiement en attente ou échoué ne déclenche jamais Premium ni la livraison d'un achat.
4. Les moyens Orange Money, Mobile Money, Google Pay et Apple Pay peuvent être configurés par pays et ne sont affichés que lorsqu'ils sont réellement disponibles et autorisés pour le parcours.
5. Les règles de facturation Google Play et App Store sont respectées pour les abonnements numériques lorsque requises ; Google Pay/Apple Pay ne sont pas utilisés comme substituts non conformes.
6. Les notifications de paiement sont authentifiées, les opérations sont idempotentes et les doubles activations/débits sont empêchés par les contrôles serveur.
7. Un administrateur autorisé peut accorder Premium pour une durée prédéfinie ou personnalisée, le prolonger et le retirer.
8. Une attribution administrative est identifiée comme gratuite et n'est jamais comptabilisée comme revenu.
9. Toute action Premium est historisée avec administrateur, date, durée, motif, origine et changement de statut ; l'historique ne peut pas être effacé par un opérateur ordinaire.
10. À l'expiration ou au retrait, le badge Premium et les avantages associés sont désactivés conformément aux règles du produit.
11. Le badge Premium et le badge Profil vérifié sont visuellement et fonctionnellement distincts.
12. Le téléphone confirmé seul n'est pas présenté comme une vérification complète du profil.
13. Un profil ne reçoit le badge Profil vérifié qu'après validation d'un niveau admissible ; le type de contrôle est explicable depuis le badge.
14. Les demandes, décisions, recours et accès aux justificatifs de vérification sont journalisés et protégés par rôle.
15. Les tests couvrent paiements réussis, échecs, annulations, remboursements, notifications répétées, expirations, prolongations, retraits, fuseaux horaires, permissions et accès non autorisés.

## 43. Historique des évolutions

- **V6.0** : base fonctionnelle et technique, messagerie enrichie, communautés, conseil matrimonial, comptes différenciés et événements.
- **V6.2** : module Promotions, coupons, réductions, offres d'anniversaire et récompenses administrables.
- **V6.3** : Centre de sécurité intelligent dans la messagerie, masquage des numéros, avertissements anti-arnaque, détection graduée des risques, bouclier de sécurité et précisions du moteur de compatibilité et du Match réciproque.
- **V6.4** : moyens de paiement Orange Money, Mobile Money, Google Pay et Apple Pay sous réserve de disponibilité et de conformité ; historiques utilisateur des abonnements et paiements ; attribution, prolongation et retrait administratifs du Premium ; traçabilité financière ; badges Premium et Profil vérifié distincts.

**Fin du cahier des charges consolidé ZAYA V6.4.**
