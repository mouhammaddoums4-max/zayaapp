import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';

/// Mode démo : mêmes règles que le serveur pour les likes envoyés (0024) et le filtre par ville (0012).
Future<DemoRepository> inscrit({String gender = 'femme'}) async {
  final repo = DemoRepository();
  await repo.verifyOtp('+224622112233', DemoRepository.demoOtp);
  await repo.saveOnboarding(OnboardingDraft()
    ..displayName = 'Awa'
    ..birthDate = DateTime(1998, 5, 10)
    ..gender = gender
    ..cityId = 4
    ..horizon = 'soon'
    ..ageMin = 18
    ..ageMax = 60);
  return repo;
}

void main() {
  test('likes envoyés : un like sans réponse apparaît, un match n’y apparaît pas', () async {
    final repo = await inscrit();
    expect(await repo.sentInterests(), isEmpty);
    final aimes = <String>[];
    final matchs = <String>[];
    for (final p in await repo.discoveryFeed()) {
      final r = await repo.like(p.id);
      (r.status == LikeStatus.matched ? matchs : aimes).add(p.id);
    }
    final envoyes = (await repo.sentInterests()).map((p) => p.id).toList();
    expect(envoyes, aimes.reversed.toList(), reason: 'du plus récent au plus ancien');
    expect(envoyes.any(matchs.contains), isFalse, reason: 'un match quitte la liste des likes envoyés');
  });

  test('filtre par ville : seuls les profils des villes choisies sont proposés ; liste vide = toutes', () async {
    final repo = await inscrit();
    final tous = await repo.discoveryFeed();
    final ville = (await repo.cities()).firstWhere((c) => c.name == tous.first.city);
    final prefs = await repo.loadPreferences();
    await repo.savePreferences(prefs..cityIds = [ville.id]);
    final filtres = await repo.discoveryFeed();
    expect(filtres, isNotEmpty);
    expect(filtres.every((p) => p.city == ville.name), isTrue);
    expect((await repo.loadPreferences()).isFiltered, isTrue);
    await repo.savePreferences(prefs..cityIds = []);
    expect((await repo.discoveryFeed()).length, tous.length);
  });
}
