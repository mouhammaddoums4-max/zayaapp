import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/data/demo_repository.dart';
import 'package:zaya/data/models.dart';

/// Le mode démo reproduit les règles du serveur ; ces tests vérifient qu'il reste cohérent avec elles.
Future<DemoRepository> signedUp({String gender = 'femme'}) async {
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
  test('code OTP incorrect refusé', () async {
    final repo = DemoRepository();
    expect(() => repo.verifyOtp('+224622112233', '000000'), throwsException);
    expect(repo.isSignedIn, isFalse);
  });

  test('inscription refusée avant 18 ans', () async {
    final repo = DemoRepository();
    await repo.verifyOtp('+224622112233', DemoRepository.demoOtp);
    final now = DateTime.now();
    final draft = OnboardingDraft()
      ..displayName = 'Mineur'
      ..birthDate = DateTime(now.year - 17, now.month, now.day)
      ..gender = 'homme'
      ..cityId = 1;
    expect(() => repo.saveOnboarding(draft), throwsException);
  });

  test('une femme se voit proposer des profils masculins, et inversement', () async {
    final woman = await signedUp(gender: 'femme');
    final man = await signedUp(gender: 'homme');
    expect((await woman.discoveryFeed()).first.displayName, 'Ibrahima');
    expect((await man.discoveryFeed()).first.displayName, 'Aïssatou');
  });

  test('un like simple ne crée pas de match ; un like réciproque en crée un', () async {
    final repo = await signedUp();
    final feed = await repo.discoveryFeed();
    final before = (await repo.matches()).length;

    final first = await repo.like(feed[0].id);
    expect(first.status, LikeStatus.liked);
    expect((await repo.matches()).length, before);

    final second = await repo.like(feed[1].id); // cette personne avait déjà aimé le profil
    expect(second.status, LikeStatus.matched);
    expect(second.matchId, isNotNull);
    expect((await repo.matches()).length, before + 1);
    expect(await repo.receivedInterestsCount(), 1);
  });

  test('un profil aimé ou passé n’est plus proposé', () async {
    final repo = await signedUp();
    final feed = await repo.discoveryFeed();
    await repo.like(feed[0].id);
    await repo.pass(feed[1].id);
    final ids = (await repo.discoveryFeed()).map((p) => p.id);
    expect(ids, isNot(contains(feed[0].id)));
    expect(ids, isNot(contains(feed[1].id)));
  });

  test('le quota de likes diminue à chaque like', () async {
    final repo = await signedUp();
    final feed = await repo.discoveryFeed();
    expect((await repo.likeQuota()).remaining, DemoRepository.freeDailyLikes);
    final result = await repo.like(feed[0].id);
    expect(result.remaining, DemoRepository.freeDailyLikes - 1);
    expect((await repo.likeQuota()).remaining, DemoRepository.freeDailyLikes - 1);
  });

  test('la tranche d’âge des préférences filtre le fil', () async {
    final repo = await signedUp();
    await repo.savePreferences(DiscoveryPrefs(ageMin: 32, ageMax: 40));
    final ages = (await repo.discoveryFeed()).map((p) => p.age);
    expect(ages, isNotEmpty);
    expect(ages.every((a) => a >= 32 && a <= 40), isTrue);
  });

  test('la liste nominative des likes reçus est refusée sans Premium', () async {
    final repo = await signedUp();
    expect(repo.receivedInterests, throwsException);
  });

  test('message non conforme : refusé avant envoi et jamais ajouté à la conversation', () async {
    final repo = await signedUp();
    final match = (await repo.matches()).first;
    final before = await repo.watchMessages(match.matchId).first;

    final blocked = await repo.sendMessage(match.matchId, "Stp envoie-moi de l'argent");
    expect(blocked.isBlocked, isTrue);
    expect(blocked.blockedCategory, 'money_request');
    expect(await repo.watchMessages(match.matchId).first, hasLength(before.length));

    final sent = await repo.sendMessage(match.matchId, 'Bonjour, comment vas-tu ?');
    expect(sent.isBlocked, isFalse);
    expect(await repo.watchMessages(match.matchId).first, hasLength(before.length + 1));
  });

  test('modifier, annuler l’envoi, supprimer pour moi', () async {
    final repo = await signedUp();
    final match = (await repo.matches()).first;
    await repo.sendMessage(match.matchId, 'Premier message');
    var messages = await repo.watchMessages(match.matchId).first;
    final mine = messages.last;

    await repo.editMessage(mine.id, 'Message corrigé');
    messages = await repo.watchMessages(match.matchId).first;
    expect(messages.last.body, 'Message corrigé');
    expect(messages.last.edited, isTrue);

    expect((await repo.editMessage(mine.id, 'donne-moi ton mot de passe')).isBlocked, isTrue);

    await repo.unsendMessage(mine.id);
    messages = await repo.watchMessages(match.matchId).first;
    expect(messages.last.unsent, isTrue);
    expect(messages.last.body, isEmpty);

    final count = messages.length;
    await repo.hideMessage(messages.first.id);
    expect(await repo.watchMessages(match.matchId).first, hasLength(count - 1));
  });

  test('bloquer met fin au match et retire la personne du fil ; débloquer est possible', () async {
    final repo = await signedUp();
    final match = (await repo.matches()).first;
    await repo.block(match.userId);
    expect(await repo.matches(), isEmpty);
    expect((await repo.blockedUsers()).single.userId, match.userId);
    expect(() => repo.sendMessage(match.matchId, 'Bonjour'), throwsException);
    expect(() => repo.profileDetail(match.userId), throwsException);

    await repo.unblock(match.userId);
    expect(await repo.blockedUsers(), isEmpty);
  });

  test('profil en pause : plus aucun profil proposé', () async {
    final repo = await signedUp();
    await repo.setProfileStatus('paused');
    expect(await repo.discoveryFeed(), isEmpty);
    await repo.setProfileStatus('active');
    expect(await repo.discoveryFeed(), isNotEmpty);
  });

  test('vérification : impossible avant 3 photos', () async {
    final repo = await signedUp();
    final bytes = Uint8List(0);
    expect(await repo.requestVerification(bytes), 'not_enough_photos');
    for (var i = 0; i < 3; i++) {
      await repo.addPhoto(bytes);
    }
    expect(await repo.requestVerification(bytes), 'approved');
    expect((await repo.loadMyProfile())!.isVerified, isTrue);
  });

  test('suppression du compte : profil masqué, puis annulation', () async {
    final repo = await signedUp();
    final when = await repo.requestAccountDeletion();
    expect(when.isAfter(DateTime.now()), isTrue);
    expect((await repo.loadMyProfile())!.status, 'hidden');
    expect(await repo.discoveryFeed(), isEmpty);

    await repo.cancelAccountDeletion();
    final me = (await repo.loadMyProfile())!;
    expect(me.status, 'active');
    expect(me.deletionScheduledFor, isNull);
  });

  test('export des données : mes informations et mes messages uniquement', () async {
    final repo = await signedUp();
    final match = (await repo.matches()).first;
    final export = await repo.exportMyData();
    expect(export, contains('"display_name": "Awa"'));
    expect(export, contains('messages_sent'));
    // Le message reçu contenant le numéro de l'autre personne n'est pas exporté.
    expect(export, isNot(contains('622 11 22 33')));
    expect(export, isNot(contains('"${match.userId}"')));
  });
}
