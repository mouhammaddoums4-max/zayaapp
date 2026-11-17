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

  group('Communauté (mêmes règles que le serveur)', () {
    Future<DemoRepository> verified() async {
      final repo = await signedUp();
      for (var i = 0; i < 3; i++) {
        await repo.addPhoto(Uint8List(0));
      }
      await repo.requestVerification(Uint8List(0));
      return repo;
    }

    test('« Pour vous » : toutes les communautés tant qu’aucune n’est suivie, puis seulement les suivies', () async {
      final repo = await signedUp();
      final all = await repo.communityFeed();
      expect(all.map((p) => p.communityName).toSet().length, greaterThan(2));
      final couple = (await repo.communities()).firstWhere((c) => c.slug == 'vie-de-couple');
      await repo.joinCommunity(couple.id);
      final mine = await repo.communityFeed();
      expect(mine, isNotEmpty);
      expect(mine.every((p) => p.communityId == couple.id), isTrue);
      expect((await repo.communities()).firstWhere((c) => c.id == couple.id).joined, isTrue);
      await repo.leaveCommunity(couple.id);
      expect(await repo.communityFeed(), hasLength(all.length));
    });

    test('publier ou commenter exige un profil vérifié ; lire et réagir non', () async {
      final repo = await signedUp();
      final prep = (await repo.communities()).first;
      final post = (await repo.communityFeed()).first;
      expect(() => repo.createPost(communityId: prep.id, kind: 'question', body: 'Bonjour'),
          throwsA(predicate((e) => '$e'.contains('VERIFICATION_REQUIRED'))));
      expect(() => repo.addComment(post.id, 'Merci'), throwsA(predicate((e) => '$e'.contains('VERIFICATION_REQUIRED'))));
      expect(await repo.reactToPost(post.id, true), post.reactionCount + 1);
    });

    test('coordonnées et termes interdits refusés avant publication ; jamais publiés', () async {
      final repo = await verified();
      final prep = (await repo.communities()).first;
      final before = (await repo.communityFeed()).length;
      final phone = await repo.createPost(communityId: prep.id, kind: 'question', body: 'Écrivez-moi au 622 11 22 33');
      expect(phone.blockedCategory, 'contact_details');
      final email = await repo.createPost(communityId: prep.id, kind: 'advice', body: 'Contact : awa@exemple.com');
      expect(email.blockedCategory, 'contact_details');
      final money = await repo.createPost(communityId: prep.id, kind: 'advice', body: "Envoie-moi de l'argent");
      expect(money.blockedCategory, 'money_request');
      final amount = await repo.createPost(communityId: prep.id, kind: 'question', body: 'Une dot de 5 000 000 GNF, est-ce courant ?');
      expect(amount.isBlocked, isFalse, reason: 'un montant n’est pas un numéro de téléphone');
      expect(before, 5);
      // Publier fait suivre la communauté : « Pour vous » ne montre plus que celle-ci
      // (la publication de départ et la nouvelle) ; les contenus refusés n'apparaissent nulle part.
      final feed = await repo.communityFeed();
      expect(feed, hasLength(2));
      expect(feed.every((p) => p.communityId == prep.id), isTrue);
      expect(feed.where((p) => p.isMine).single.body, startsWith('Une dot de 5 000 000 GNF'));
    });

    test('limite de 5 publications par 24 h', () async {
      final repo = await verified();
      final prep = (await repo.communities()).first;
      for (var i = 0; i < 5; i++) {
        expect((await repo.createPost(communityId: prep.id, kind: 'question', body: 'Question $i')).isBlocked, isFalse);
      }
      expect(() => repo.createPost(communityId: prep.id, kind: 'question', body: 'Une de trop'),
          throwsA(predicate((e) => '$e'.contains('RATE_LIMITED'))));
    });

    test('modifier, désactiver les commentaires, supprimer : seulement ses propres publications', () async {
      final repo = await verified();
      final prep = (await repo.communities()).first;
      final id = (await repo.createPost(communityId: prep.id, kind: 'question', body: 'Première version')).id!;
      await repo.editPost(id, 'Version corrigée');
      final edited = await repo.communityPost(id);
      expect(edited.body, 'Version corrigée');
      expect(edited.edited, isTrue);
      await repo.setPostComments(id, false);
      expect(() => repo.addComment(id, 'Bonjour'), throwsA(predicate((e) => '$e'.contains('COMMENTS_DISABLED'))));
      final someoneElse = (await repo.communityFeed()).firstWhere((p) => !p.isMine);
      expect(() => repo.deletePost(someoneElse.id), throwsA(predicate((e) => '$e'.contains('POST_NOT_FOUND'))));
      await repo.deletePost(id);
      expect(() => repo.communityPost(id), throwsA(predicate((e) => '$e'.contains('POST_NOT_FOUND'))));
    });

    test('masquer, signaler, bloquer : le contenu disparaît pour moi', () async {
      final repo = await verified();
      final feed = await repo.communityFeed();
      await repo.hidePost(feed[0].id);
      await repo.reportPost(feed[1].id, reason: 'spam');
      final remaining = (await repo.communityFeed()).map((p) => p.id);
      expect(remaining, isNot(contains(feed[0].id)));
      expect(remaining, isNot(contains(feed[1].id)));

      final withComments = (await repo.communityFeed()).firstWhere((p) => p.commentCount > 0);
      final comment = (await repo.postComments(withComments.id)).first;
      await repo.block(comment.authorId);
      expect((await repo.postComments(withComments.id)).map((c) => c.authorId), isNot(contains(comment.authorId)));
      expect((await repo.communityFeed()).map((p) => p.authorId), isNot(contains(comment.authorId)));
      expect((await repo.blockedUsers()).single.displayName, comment.authorName);
    });

    test('enregistrer et retrouver une publication', () async {
      final repo = await signedUp();
      final post = (await repo.communityFeed()).first;
      await repo.savePost(post.id, true);
      expect((await repo.savedPosts()).single.id, post.id);
      expect((await repo.communityPost(post.id)).saved, isTrue);
      await repo.savePost(post.id, false);
      expect(await repo.savedPosts(), isEmpty);
    });

    test('notifications d’une communauté : réservées aux membres', () async {
      final repo = await signedUp();
      final c = (await repo.communities()).first;
      expect(() => repo.setCommunityNotifications(c.id, 'none'), throwsA(predicate((e) => '$e'.contains('NOT_A_MEMBER'))));
      await repo.joinCommunity(c.id);
      await repo.setCommunityNotifications(c.id, 'none');
      expect((await repo.communities()).firstWhere((x) => x.id == c.id).notifLevel, 'none');
    });
  });
}
