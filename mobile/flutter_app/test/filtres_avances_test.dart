import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';

/// Mode démo : mêmes règles que le serveur pour les filtres avancés réservés à Premium (migration 0025).
Future<DemoRepository> inscrit() async {
  final repo = DemoRepository();
  await repo.verifyOtp('+224622445566', DemoRepository.demoOtp);
  await repo.saveOnboarding(OnboardingDraft()
    ..displayName = 'Mariama'
    ..birthDate = DateTime(1997, 2, 14)
    ..gender = 'femme'
    ..cityId = 4
    ..horizon = 'soon'
    ..ageMin = 18
    ..ageMax = 60);
  return repo;
}

Future<void> premium(DemoRepository repo, bool actif) async => (await repo.loadMyProfile())!.isPremium = actif;

void main() {
  test('Gratuit : un filtre avancé est refusé, les filtres de base restent permis', () async {
    final repo = await inscrit();
    final prefs = await repo.loadPreferences();
    expect(prefs.hasAdvancedFilters, isFalse);
    await expectLater(repo.savePreferences(prefs..languages = ['Soussou']), throwsA(isA<Exception>()));
    await repo.savePreferences((await repo.loadPreferences())..ageMin = 20);
    expect((await repo.loadPreferences()).ageMin, 20);
  });

  test('Premium : langues, projet de mariage et situation restreignent les profils proposés', () async {
    final repo = await inscrit();
    await premium(repo, true);
    final tous = await repo.discoveryFeed();

    await repo.savePreferences((await repo.loadPreferences())..languages = ['Soussou']);
    final parLangue = await repo.discoveryFeed();
    expect(parLangue, isNotEmpty);
    expect(parLangue.length, lessThan(tous.length));
    expect(parLangue.every((p) => p.languages.contains('Soussou')), isTrue);
    expect((await repo.loadPreferences()).isFiltered, isTrue);

    await repo.savePreferences((await repo.loadPreferences())
      ..languages = []
      ..horizons = ['soon']);
    final parProjet = await repo.discoveryFeed();
    expect(parProjet, isNotEmpty);
    expect(parProjet.every((p) => p.horizon == 'soon'), isTrue);

    await repo.savePreferences((await repo.loadPreferences())
      ..horizons = []
      ..maritalStatuses = ['divorced']);
    final parSituation = await repo.discoveryFeed();
    expect(parSituation, isNotEmpty);
    expect(parSituation.length, lessThan(tous.length));
  });

  test('Premium terminé : filtres conservés mais sans effet ; on peut seulement les retirer', () async {
    final repo = await inscrit();
    await premium(repo, true);
    final tous = await repo.discoveryFeed();
    await repo.savePreferences((await repo.loadPreferences())..languages = ['Soussou']);
    await premium(repo, false);

    final prefs = await repo.loadPreferences();
    expect(prefs.languages, ['Soussou'], reason: 'retrouvés en cas de réabonnement');
    expect((await repo.discoveryFeed()).length, tous.length, reason: 'sans effet sans Premium');
    await repo.savePreferences(prefs..ageMax = 50); // inchangés : accepté
    await expectLater(
        repo.savePreferences((await repo.loadPreferences())..languages = ['Poular']), throwsA(isA<Exception>()));
    await repo.savePreferences((await repo.loadPreferences())..languages = []);
    expect((await repo.loadPreferences()).hasAdvancedFilters, isFalse);
  });
}
