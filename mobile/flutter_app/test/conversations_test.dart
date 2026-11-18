import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';

/// Mode démo : mêmes règles que le serveur pour les conversations actives et le re-match (migration 0040).
Future<DemoRepository> inscrit() async {
  final repo = DemoRepository();
  await repo.verifyOtp('+224622112233', DemoRepository.demoOtp);
  await repo.saveOnboarding(OnboardingDraft()
    ..displayName = 'Awa'
    ..birthDate = DateTime(1998, 5, 10)
    ..gender = 'femme'
    ..cityId = 4
    ..horizon = 'soon'
    ..ageMin = 18
    ..ageMax = 60);
  return repo;
}

void main() {
  test('places de conversation : la conversation de démo compte, 5 places au total', () async {
    final repo = await inscrit();
    final places = await repo.conversationSlots();
    expect(places.limit, 5);
    expect(places.active, 1, reason: 'le match de démo a déjà des messages');
  });

  test('re-match : une demande sur un match terminé passe à « envoyée » ; un match en cours reste actif', () async {
    final repo = await inscrit();
    final termine = (await repo.endedMatches()).first;
    expect(await repo.rematchState(termine.matchId), 'none');
    expect(await repo.requestRematch(termine.matchId), 'pending');
    expect(await repo.rematchState(termine.matchId), 'sent');
    final enCours = (await repo.matches()).first;
    expect(await repo.requestRematch(enCours.matchId), 'active');
  });

  test('résultat d’envoi « limite atteinte » distinct d’un message bloqué', () {
    const r = SendResult.activeLimit(5);
    expect(r.isActiveLimit && !r.isBlocked, isTrue);
    expect(r.activeLimit, 5);
  });
}
