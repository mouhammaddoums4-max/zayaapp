# ZAYA — application mobile (Flutter)

Application Android d'abord, compatible iOS et Web. Voir le [README du dépôt](../../README.md) pour la vue d'ensemble.

## Lancer l'application

```bash
flutter pub get
flutter run -d chrome                                    # mode démo : profils fictifs, aucun serveur
flutter run --dart-define-from-file=env.staging.json     # connectée à Supabase (voir env.staging.example.json)
```

En mode démo, le code de vérification du téléphone est `123456`.

## Vérifier

```bash
flutter analyze
flutter test
```

## Organisation du code

```
lib/
├── main.dart            Point d'entrée : mode démo ou Supabase selon la configuration
├── app.dart             Session, fil de découverte partagé, aiguillage accueil / application
├── core/                Thème, animations, barre d'onglets, composants communs, masquage des numéros
├── data/                Modèles, contrat d'accès aux données, mode démo, Supabase
└── features/
    ├── onboarding/      Accueil, inscription (une question par écran), connexion par téléphone
    ├── home/            Navigation à 5 onglets
    ├── discovery/       Découvrir (cartes), Explorer (sélections), fiche profil, like et match
    ├── likes/           Personnes qui ont aimé mon profil
    ├── chat/            Conversations, messagerie, bouclier de sécurité
    ├── profile/         Mon profil, modification, préférences, vérification, confidentialité
    ├── premium/         Comparaison des offres, mes abonnements, mes paiements
    └── safety/          Signalement, blocage, conseils de sécurité
```
