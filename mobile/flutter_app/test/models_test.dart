import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/models.dart';

void main() {
  group('Contrôle de majorité', () {
    final today = DateTime(2026, 11, 16);

    test('18 ans révolus le jour même de l’anniversaire', () {
      expect(isAdult(DateTime(2008, 11, 16), now: today), isTrue);
      expect(ageFrom(DateTime(2008, 11, 16), now: today), 18);
    });

    test('la veille des 18 ans : refusé', () {
      expect(isAdult(DateTime(2008, 11, 17), now: today), isFalse);
      expect(ageFrom(DateTime(2008, 11, 17), now: today), 17);
    });

    test('né un 29 février', () {
      expect(ageFrom(DateTime(2004, 2, 29), now: DateTime(2026, 2, 28)), 21);
      expect(ageFrom(DateTime(2004, 2, 29), now: DateTime(2026, 3, 1)), 22);
    });
  });

  group('Brouillon d’inscription', () {
    test('aller-retour JSON sans perte', () {
      final draft = OnboardingDraft()
        ..adultConfirmed = true
        ..displayName = 'Awa'
        ..birthDate = DateTime(1998, 5, 10)
        ..gender = 'femme'
        ..cityId = 4
        ..horizon = 'few_months'
        ..confession = 'muslim'
        ..confessionConsent = true
        ..confessionMode = 'selected'
        ..selectedConfessions = ['muslim', 'christian']
        ..ageMin = 25
        ..ageMax = 40
        ..bio = 'Bonjour'
        ..phone = '+224622112233'
        ..step = 7;
      final restored = OnboardingDraft.fromJson(draft.toJson());
      expect(restored.toJson(), draft.toJson());
      expect(restored.birthDate, DateTime(1998, 5, 10));
    });

    test('l’acceptation des conditions n’est jamais restaurée : elle doit être redonnée', () {
      final draft = OnboardingDraft()
        ..acceptedTerms = true
        ..marketingConsent = true;
      final restored = OnboardingDraft.fromJson(draft.toJson());
      expect(restored.acceptedTerms, isFalse);
      expect(restored.marketingConsent, isFalse);
    });

    test('brouillon vide ou partiel : valeurs par défaut', () {
      final restored = OnboardingDraft.fromJson(const <String, dynamic>{});
      expect(restored.step, 0);
      expect(restored.confessionMode, 'no_filter');
      expect(restored.ageMin, 18);
    });
  });

  group('Points communs (§31.4) — jamais inventés', () {
    MyProfile me(
            {String? horizon, String? city, List<String> languages = const [], List<String> interests = const []}) =>
        MyProfile(
            id: 'me',
            displayName: 'Awa',
            status: 'active',
            verificationStatus: 'approved',
            horizon: horizon,
            city: city,
            languages: languages,
            interests: interests);

    const other = DiscoveryProfile(
        id: 'o',
        displayName: 'Ibrahima',
        age: 30,
        city: 'Conakry — Ratoma',
        horizon: 'soon',
        languages: ['Français', 'Poular'],
        interests: ['Sport', 'Famille']);

    test('aucune information renseignée de mon côté : aucun point commun affiché', () {
      expect(commonPoints(me(), other), isEmpty);
    });

    test('horizon, ville, langues et centres d’intérêt communs', () {
      final points = commonPoints(
          me(horizon: 'soon', city: 'Conakry — Dixinn', languages: ['Français', 'Soussou'], interests: ['Famille']),
          other);
      expect(points, [
        'Vous souhaitez tous deux vous marier bientôt',
        'Vous habitez tous deux à Conakry',
        'Vous parlez Français',
        'Centres d’intérêt communs : Famille',
      ]);
    });

    test('des réponses différentes ne créent pas de point commun', () {
      final points = commonPoints(me(horizon: 'no_date', city: 'Labé', languages: ['Anglais']), other);
      expect(points, isEmpty);
    });
  });

  group('Complétude du profil', () {
    test('profil minimal puis complet', () {
      final p = MyProfile(id: 'me', displayName: 'Awa', status: 'active', verificationStatus: 'not_requested');
      expect(p.completeness, closeTo(1 / 9, 0.001));
      p
        ..city = 'Kindia'
        ..bio = 'Bonjour'
        ..horizon = 'soon'
        ..maritalStatus = 'single'
        ..languages = ['Français']
        ..interests = ['Lecture']
        ..photoCount = 3
        ..verificationStatus = 'approved';
      expect(p.completeness, 1);
      expect(p.isVerified, isTrue);
    });
  });

  group('Abonnements et paiements (V6.4)', () {
    test('un accès offert n’est jamais présenté comme un achat', () {
      final offered = PremiumGrant(
          source: 'admin_grant',
          status: 'active',
          startsAt: DateTime.now().subtract(const Duration(days: 1)),
          endsAt: DateTime.now().add(const Duration(days: 6)));
      expect(offered.sourceLabel, 'Offert par ZAYA');
      expect(offered.isActive, isTrue);
      expect(offered.statusLabel, 'Actif');
    });

    test('expiré, retiré : plus actif', () {
      final expired = PremiumGrant(
          source: 'purchase',
          status: 'active',
          startsAt: DateTime.now().subtract(const Duration(days: 40)),
          endsAt: DateTime.now().subtract(const Duration(days: 10)));
      expect(expired.isActive, isFalse);
      expect(expired.statusLabel, 'Expiré');
      final revoked = PremiumGrant(
          source: 'admin_grant',
          status: 'revoked',
          startsAt: DateTime.now().subtract(const Duration(days: 1)),
          endsAt: DateTime.now().add(const Duration(days: 6)));
      expect(revoked.isActive, isFalse);
      expect(revoked.statusLabel, 'Retiré');
    });

    test('seul un paiement confirmé est considéré comme payé', () {
      PaymentTx tx(String status) => PaymentTx(
          reference: 'ZY-1',
          service: 'premium',
          amount: 25000,
          currency: 'GNF',
          method: 'Orange Money',
          status: status,
          createdAt: DateTime(2026, 11, 16));
      expect(tx('confirmed').isConfirmed, isTrue);
      for (final status in ['pending', 'processing', 'failed', 'cancelled', 'refunded']) {
        expect(tx(status).isConfirmed, isFalse, reason: status);
      }
      expect(tx('pending').statusLabel, 'En attente');
    });
  });

  group('Préférences de découverte', () {
    test('le point sur l’icône des filtres n’apparaît que si un réglage s’écarte des valeurs par défaut', () {
      expect(DiscoveryPrefs().isFiltered, isFalse);
      expect(DiscoveryPrefs(confessionMode: 'all').isFiltered, isFalse, reason: '« toutes » ne filtre rien');
      expect(DiscoveryPrefs(ageMin: 25).isFiltered, isTrue);
      expect(DiscoveryPrefs(confessionMode: 'mine_only').isFiltered, isTrue);
      expect(DiscoveryPrefs(cityIds: [4]).isFiltered, isTrue, reason: 'ville ou commune choisie');
    });
  });

  group('Fiche profil reçue du serveur', () {
    test('une photo privée n’a pas de chemin et n’est pas choisie comme photo principale', () {
      final detail = ProfileDetail.fromJson(<String, dynamic>{
        'id': 'u1',
        'display_name': 'Paul',
        'age': 34,
        'city': 'Kindia',
        'is_verified': true,
        'languages': ['Français'],
        'interests': <String>[],
        'confession': null,
        'photos': [
          {'id': 'p1', 'visibility': 'private', 'path': null},
          {'id': 'p2', 'visibility': 'public', 'path': 'u1/p2.jpg'},
        ],
      });
      expect(detail.hiddenPhotoCount, 1);
      expect(detail.base.photoPath, 'u1/p2.jpg');
      expect(detail.confession, isNull);
    });

    test('floutage (0009) : seul l’accès « original » donne un chemin d’original ; les floutées ne sont pas privées', () {
      final detail = ProfileDetail.fromJson(<String, dynamic>{
        'id': 'u2',
        'display_name': 'Mariama',
        'photos': [
          {'id': 'a', 'visibility': 'public', 'access': 'original', 'path': 'u2/a.png', 'blur_path': null},
          {'id': 'b', 'visibility': 'public', 'access': 'blurred', 'path': null, 'blur_path': 'u2/b.jpg'},
          {'id': 'c', 'visibility': 'blurred', 'access': 'blurred', 'path': null, 'blur_path': null},
          {'id': 'd', 'visibility': 'private', 'access': 'none', 'path': null, 'blur_path': null},
        ],
      });
      final [a, b, c, d] = detail.photos;
      expect(detail.base.photoPath, 'u2/a.png');
      expect(detail.hiddenPhotoCount, 1, reason: 'seule la photo privée est cachée');
      expect(a.isBlurred || a.isHidden, isFalse);
      expect(b.isBlurred && !b.blurredByOwner && b.blurPath == 'u2/b.jpg', isTrue, reason: 'floutée par le forfait');
      expect(c.isBlurred && c.blurredByOwner, isTrue, reason: 'floutée par la propriétaire : Premium ne la rend pas nette');
      expect(d.isHidden && d.path == null && d.blurPath == null, isTrue);
    });
  });
}
