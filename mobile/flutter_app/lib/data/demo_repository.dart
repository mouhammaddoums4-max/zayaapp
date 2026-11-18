import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/content_rules.dart';
import 'demo_community.dart';
import 'models.dart';
import 'repository.dart';

class _DemoPerson {
  const _DemoPerson(this.profile,
      {this.maritalStatus = 'single', this.education, this.heightCm, this.childrenCount = 0});
  final DiscoveryProfile profile;
  final String maritalStatus;
  final String? education;
  final int? heightCm;
  final int childrenCount;
}

/// Données fictives en mémoire — uniquement pour le développement et la démonstration.
/// Aucune personne réelle : prénoms et textes inventés, aucune photo.
class DemoRepository implements ZayaRepository {
  DemoRepository();

  static const _me = 'demo-me';
  static const freeDailyLikes = 20;
  static const demoOtp = '123456';
  static const _blockedTerms = <String, String>{
    'envoie-moi de l’argent': 'money_request',
    "envoie-moi de l'argent": 'money_request',
    "envoie moi de l'argent": 'money_request',
    'ton code otp': 'credential_request',
    'ton mot de passe': 'credential_request',
  };

  bool _signedIn = false;
  String? _phone;
  MyProfile? _profile;
  final List<EndedMatch> _ended = <EndedMatch>[];
  final List<SupportTicket> _tickets = <SupportTicket>[];
  String _gender = 'homme';
  DiscoveryPrefs _prefs = DiscoveryPrefs(ageMax: 45);
  int _likesUsed = 0;
  int _seq = 0;
  final Set<String> _seen = <String>{};
  final Map<String, String> _blocked = <String, String>{};
  final Set<String> _likedMe = <String>{};

  /// Profils que j'ai aimés sans réponse, du plus récent au plus ancien.
  final List<String> _likedByMe = <String>[];
  final List<MatchSummary> _matches = <MatchSummary>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>> _streams = <String, StreamController<List<ChatMessage>>>{};
  late final DemoCommunityStore _community = DemoCommunityStore(
    meId: _me,
    myName: () => _profile?.displayName ?? 'Moi',
    isVerified: () => _profile?.isVerified ?? false,
    isBlocked: _blocked.containsKey,
    violation: _communityViolation,
  );

  /// Même ordre que le serveur : termes interdits d'abord, puis coordonnées.
  String? _communityViolation(String text) {
    final lower = text.toLowerCase();
    for (final e in _blockedTerms.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return containsContactDetails(text) ? 'contact_details' : null;
  }

  static const _women = <_DemoPerson>[
    _DemoPerson(
      DiscoveryProfile(
        id: 'w1',
        displayName: 'Aïssatou',
        age: 27,
        city: 'Conakry — Ratoma',
        horizon: 'few_months',
        profession: 'Santé',
        languages: ['Français', 'Poular'],
        interests: ['Lecture', 'Cuisine', 'Famille'],
        isVerified: true,
        bio: 'Infirmière, proche de ma famille. Je cherche une relation sérieuse, fondée sur le respect et l’écoute.',
      ),
      education: 'Licence',
      heightCm: 165,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'w2',
        displayName: 'Kadiatou',
        age: 25,
        city: 'Conakry — Dixinn',
        horizon: 'soon',
        profession: 'Commerce',
        languages: ['Français', 'Soussou'],
        interests: ['Entrepreneuriat', 'Voyages'],
        isVerified: true,
        isPremium: true,
        bio: 'Commerçante, souriante et déterminée. Le mariage est pour moi un projet de vie à deux.',
      ),
      education: 'Baccalauréat',
      heightCm: 170,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'w3',
        displayName: 'Hawa',
        age: 29,
        city: 'Kindia',
        horizon: 'medium_term',
        profession: 'Éducation / enseignement',
        languages: ['Français', 'Malinké'],
        interests: ['Éducation', 'Nature'],
        isVerified: true,
        bio: 'Enseignante. J’aime les discussions sincères et les projets construits pas à pas.',
      ),
      maritalStatus: 'divorced',
      education: 'Master',
      heightCm: 162,
      childrenCount: 1,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'w4',
        displayName: 'Fatoumata',
        age: 24,
        city: 'Conakry — Matoto',
        horizon: 'no_date',
        profession: 'Étudiant(e)',
        languages: ['Français', 'Anglais'],
        interests: ['Sport', 'Musique', 'Bénévolat'],
        isVerified: true,
        bio: 'Étudiante en gestion. Je prends le temps de bien connaître la personne avant de m’engager.',
      ),
      education: 'Licence en cours',
      heightCm: 168,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'w5',
        displayName: 'Mabinty',
        age: 31,
        city: 'Conakry — Kaloum',
        horizon: 'soon',
        profession: 'Banque / finance',
        languages: ['Français', 'Soussou', 'Anglais'],
        interests: ['Cuisine', 'Voyages'],
        isVerified: true,
        bio: 'Cadre dans une banque. Je souhaite fonder un foyer stable avec une personne de confiance.',
      ),
      education: 'Master',
      heightCm: 172,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'w6',
        displayName: 'Oumou',
        age: 26,
        city: 'Labé',
        horizon: 'few_months',
        profession: 'Artisanat',
        languages: ['Poular', 'Français'],
        interests: ['Traditions', 'Famille'],
        isVerified: true,
        bio: 'Couturière passionnée. La famille et la parole donnée comptent beaucoup pour moi.',
      ),
      heightCm: 160,
    ),
  ];

  static const _men = <_DemoPerson>[
    _DemoPerson(
      DiscoveryProfile(
        id: 'm1',
        displayName: 'Ibrahima',
        age: 30,
        city: 'Conakry — Ratoma',
        horizon: 'few_months',
        profession: 'Informatique / télécoms',
        languages: ['Français', 'Poular', 'Anglais'],
        interests: ['Technologie', 'Sport', 'Famille'],
        isVerified: true,
        bio: 'Ingénieur réseau. Calme et attentionné, je cherche une compagne pour construire un foyer serein.',
      ),
      education: 'Master',
      heightCm: 180,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'm2',
        displayName: 'Mamadou',
        age: 33,
        city: 'Conakry — Kaloum',
        horizon: 'soon',
        profession: 'Commerce',
        languages: ['Français', 'Malinké'],
        interests: ['Entrepreneuriat', 'Voyages'],
        isVerified: true,
        isPremium: true,
        bio: 'Entrepreneur. Sérieux dans mes engagements, je souhaite me marier et fonder une famille.',
      ),
      education: 'Licence',
      heightCm: 176,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'm3',
        displayName: 'Alpha',
        age: 28,
        city: 'Labé',
        horizon: 'medium_term',
        profession: 'Éducation / enseignement',
        languages: ['Poular', 'Français'],
        interests: ['Lecture', 'Éducation'],
        isVerified: true,
        bio: 'Professeur de mathématiques. J’accorde beaucoup d’importance au dialogue et au respect mutuel.',
      ),
      education: 'Master',
      heightCm: 174,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'm4',
        displayName: 'Sékou',
        age: 35,
        city: 'Kankan',
        horizon: 'soon',
        profession: 'Santé',
        languages: ['Français', 'Malinké'],
        interests: ['Bénévolat', 'Nature', 'Famille'],
        isVerified: true,
        bio: 'Médecin. Après un premier mariage, je souhaite reconstruire une vie de couple stable.',
      ),
      maritalStatus: 'divorced',
      education: 'Doctorat',
      heightCm: 182,
      childrenCount: 1,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'm5',
        displayName: 'Ousmane',
        age: 27,
        city: 'Conakry — Matoto',
        horizon: 'no_date',
        profession: 'Transport / logistique',
        languages: ['Français', 'Soussou'],
        interests: ['Sport', 'Musique'],
        isVerified: true,
        bio: 'Logisticien. Simple et travailleur, je veux d’abord bien connaître la personne.',
      ),
      education: 'BTS',
      heightCm: 178,
    ),
    _DemoPerson(
      DiscoveryProfile(
        id: 'm6',
        displayName: 'Thierno',
        age: 31,
        city: 'Conakry — Dixinn',
        horizon: 'few_months',
        profession: 'Banque / finance',
        languages: ['Français', 'Poular', 'Anglais'],
        interests: ['Cuisine', 'Voyages'],
        isVerified: true,
        bio: 'Analyste financier. Je cherche une relation sincère, avec la bénédiction de nos familles.',
      ),
      education: 'Master',
      heightCm: 175,
    ),
  ];

  List<_DemoPerson> get _pool => _gender == 'femme' ? _men : _women;

  _DemoPerson? _person(String id) {
    for (final p in [..._women, ..._men]) {
      if (p.profile.id == id) return p;
    }
    return null;
  }

  @override
  bool get isDemo => true;
  @override
  bool get isSignedIn => _signedIn;
  @override
  String? get userId => _signedIn ? _me : null;

  @override
  String? get phoneNumber => _signedIn ? _phone : null;

  /// Mêmes clés que `app_config` (lisible par tous) ; aucun numéro WhatsApp de support en démo.
  @override
  Future<Map<String, Object?>> publicConfig() async => const <String, Object?>{
        'active_languages': ['fr', 'en'],
        'support_whatsapp': '',
      };

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<void> verifyOtp(String phone, String code) async {
    if (code != demoOtp) throw Exception('Code incorrect. En mode démo, le code est $demoOtp.');
    _signedIn = true;
    _phone = phone;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _phone = null;
    _profile = null;
    _ended.clear();
    _rematchSent.clear();
    _tickets.clear();
    _seen.clear();
    _blocked.clear();
    _likedMe.clear();
    _likedByMe.clear();
    _matches.clear();
    _messages.clear();
    _likesUsed = 0;
    _community.reset();
  }

  @override
  Future<List<City>> cities() async => const <City>[
        City(1, 'Conakry — Kaloum'),
        City(2, 'Conakry — Dixinn'),
        City(3, 'Conakry — Matam'),
        City(4, 'Conakry — Ratoma'),
        City(5, 'Conakry — Matoto'),
        City(6, 'Kindia'),
        City(7, 'Labé'),
        City(8, 'Kankan'),
        City(9, 'Boké'),
        City(10, 'N’Zérékoré'),
      ];

  /// Même référentiel que le seed serveur (supabase/seed/seed.sql).
  @override
  Future<List<Country>> countries() async => const <Country>[
        Country('GN', 'Guinée', 'Guinea'),
        Country('SN', 'Sénégal', 'Senegal'),
        Country('CI', 'Côte d’Ivoire', 'Côte d’Ivoire'),
        Country('ML', 'Mali', 'Mali'),
        Country('SL', 'Sierra Leone', 'Sierra Leone'),
        Country('LR', 'Libéria', 'Liberia'),
        Country('GW', 'Guinée-Bissau', 'Guinea-Bissau'),
        Country('GM', 'Gambie', 'Gambia'),
        Country('FR', 'France', 'France'),
      ];

  @override
  Future<List<Profession>> professions() async => const <Profession>[
        Profession(1, 'Administration publique'),
        Profession(2, 'Agriculture / élevage'),
        Profession(3, 'Commerce'),
        Profession(4, 'Artisanat'),
        Profession(5, 'Bâtiment / BTP'),
        Profession(6, 'Transport / logistique'),
        Profession(7, 'Santé'),
        Profession(8, 'Éducation / enseignement'),
        Profession(9, 'Informatique / télécoms'),
        Profession(10, 'Banque / finance'),
        Profession(11, 'Sécurité'),
        Profession(12, 'Industrie / mines'),
        Profession(13, 'Services'),
        Profession(14, 'Étudiant(e)'),
        Profession(15, 'Sans emploi'),
        Profession(16, 'Retraité(e)'),
        Profession(17, 'Travail domestique / ménager'),
      ];

  @override
  Future<MyProfile?> loadMyProfile() async => _profile;

  @override
  Future<void> saveOnboarding(OnboardingDraft d) async {
    final birth = d.birthDate;
    if (birth == null || !isAdult(birth)) throw Exception('ZAYA est réservé aux personnes de 18 ans et plus.');
    String? city;
    for (final c in await cities()) {
      if (c.id == d.cityId) city = c.name;
    }
    _gender = d.gender ?? 'homme';
    _prefs = DiscoveryPrefs(
        ageMin: d.ageMin, ageMax: d.ageMax, confessionMode: d.confessionMode, confessions: [...d.selectedConfessions]);
    _profile = MyProfile(
      id: _me,
      displayName: d.displayName.trim(),
      status: 'active',
      verificationStatus: 'not_requested',
      isPhoneVerified: true,
      age: ageFrom(birth),
      city: city,
      bio: d.bio.trim().isEmpty ? null : d.bio.trim(),
      horizon: d.horizon,
      maritalStatus: d.maritalStatus,
      languages: const <String>['Français'],
      birthDate: birth,
      gender: d.gender,
    );

    // Jeu de données de démonstration : deux personnes ont déjà aimé le profil, un match existe avec une conversation.
    final pool = _pool;
    _likedMe
      ..clear()
      ..addAll([pool[1].profile.id, pool[4].profile.id]);
    final friend = pool[5].profile;
    final matchId = 'match-${friend.id}';
    _seen
      ..clear()
      ..add(friend.id);
    _matches
      ..clear()
      ..add(MatchSummary(matchId: matchId, userId: friend.id, displayName: friend.displayName, isVerified: true));
    final now = DateTime.now();
    _messages[matchId] = <ChatMessage>[
      ChatMessage(
          id: 'seed-1',
          senderId: friend.id,
          body: 'Bonjour ! Heureux de ce match 😊',
          createdAt: now.subtract(const Duration(hours: 3))),
      ChatMessage(
          id: 'seed-2',
          senderId: _me,
          body: 'Bonjour ${friend.displayName}, moi aussi. Comment se passe ta semaine ?',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 40))),
      ChatMessage(
          id: 'seed-3',
          senderId: friend.id,
          body: 'Très bien, merci. Si tu veux, voici mon numéro : +224 622 11 22 33',
          createdAt: now.subtract(const Duration(hours: 2))),
    ];

    // Un match terminé par l'autre personne il y a deux jours : historique relisible, plus d'envoi possible.
    // Personne fictive hors du fil de découverte, pour ne rien retirer de Découvrir.
    final formerId = _gender == 'femme' ? 'former-m' : 'former-w';
    final formerName = _gender == 'femme' ? 'Lamine' : 'Mariama';
    final endedId = 'match-$formerId';
    _messages[endedId] = <ChatMessage>[
      ChatMessage(
          id: 'ended-1',
          senderId: formerId,
          body: 'Bonjour, enchanté(e) de faire ta connaissance.',
          createdAt: now.subtract(const Duration(days: 4))),
      ChatMessage(
          id: 'ended-2',
          senderId: _me,
          body: 'Bonjour ! De même, merci pour ton message.',
          createdAt: now.subtract(const Duration(days: 4, hours: -1))),
    ];
    _ended
      ..clear()
      ..add(EndedMatch(
        matchId: endedId,
        userId: formerId,
        displayName: formerName,
        matchedAt: now.subtract(const Duration(days: 5)),
        endedAt: now.subtract(const Duration(days: 2)),
        endedByMe: false,
      ));
  }

  @override
  Future<void> updateProfile({
    String? bio,
    String? horizon,
    String? maritalStatus,
    List<String>? languages,
    List<String>? interests,
  }) async {
    final p = _profile;
    if (p == null) return;
    if (bio != null) p.bio = bio.trim().isEmpty ? null : bio.trim();
    if (horizon != null) p.horizon = horizon;
    if (maritalStatus != null) p.maritalStatus = maritalStatus;
    if (languages != null) p.languages = [...languages];
    if (interests != null) p.interests = [...interests];
  }

  @override
  Future<void> setProfileStatus(String status) async {
    _profile?.status = status;
  }

  @override
  Future<void> updatePrivacy({bool? incognito, bool? discreetBrowsing, bool? showOnline}) async {
    final p = _profile;
    if (p == null) return;
    p.incognito = incognito ?? p.incognito;
    p.discreetBrowsing = discreetBrowsing ?? p.discreetBrowsing;
    p.showOnline = showOnline ?? p.showOnline;
  }

  @override
  Future<void> addPhoto(Uint8List bytes) async {
    final p = _profile;
    if (p != null) p.photoCount++;
  }

  @override
  Future<String> requestVerification(Uint8List selfie) async {
    final p = _profile;
    if (p == null || p.photoCount < 3) return 'not_enough_photos';
    // Mode démo : pas de modérateur, la validation est simulée immédiatement.
    p.verificationStatus = 'approved';
    return 'approved';
  }

  @override
  Future<String?> photoUrl(String? path, {bool blurred = false}) async => null;

  @override
  String? cachedPhotoUrl(String? path, {bool blurred = false}) => null;

  @override
  Future<DiscoveryPrefs> loadPreferences() async => DiscoveryPrefs(
      ageMin: _prefs.ageMin,
      ageMax: _prefs.ageMax,
      confessionMode: _prefs.confessionMode,
      confessions: [..._prefs.confessions],
      cityIds: [..._prefs.cityIds],
      languages: [..._prefs.languages],
      horizons: [..._prefs.horizons],
      maritalStatuses: [..._prefs.maritalStatuses]);

  @override
  Future<void> savePreferences(DiscoveryPrefs prefs) async {
    // Même règle que le serveur (0025) : un compte Gratuit ne peut pas définir ni changer de filtre avancé.
    bool change(List<String> avant, List<String> apres) =>
        apres.isNotEmpty && (avant.length != apres.length || avant.any((v) => !apres.contains(v)));
    if (!(_profile?.isPremium ?? false) &&
        (change(_prefs.languages, prefs.languages) ||
            change(_prefs.horizons, prefs.horizons) ||
            change(_prefs.maritalStatuses, prefs.maritalStatuses))) {
      throw Exception('PREMIUM_REQUIRED');
    }
    _prefs = prefs;
  }

  @override
  Future<List<DiscoveryProfile>> discoveryFeed() async {
    if (_profile?.status != 'active') return const <DiscoveryProfile>[];
    // Filtre par ville ou commune (même règle que le serveur, 0012) : liste vide = toutes les villes.
    final villes = {
      for (final c in await cities())
        if (_prefs.cityIds.contains(c.id)) c.name,
    };
    // Filtres avancés (0025) : appliqués seulement pour un compte Premium ; liste vide = tous.
    final avances = _profile?.isPremium ?? false;
    final langues = avances ? _prefs.languages : const <String>[];
    final projets = avances ? _prefs.horizons : const <String>[];
    final situations = avances ? _prefs.maritalStatuses : const <String>[];
    return [
      for (final p in _pool)
        if (!_seen.contains(p.profile.id) &&
            !_blocked.containsKey(p.profile.id) &&
            p.profile.age >= _prefs.ageMin &&
            p.profile.age <= _prefs.ageMax &&
            (villes.isEmpty || villes.contains(p.profile.city)) &&
            (langues.isEmpty || p.profile.languages.any(langues.contains)) &&
            (projets.isEmpty || projets.contains(p.profile.horizon)) &&
            (situations.isEmpty || situations.contains(p.maritalStatus)))
          p.profile,
    ];
  }

  @override
  Future<ProfileDetail> profileDetail(String userId) async {
    final p = _person(userId);
    if (p == null || _blocked.containsKey(userId)) throw Exception('Ce profil n’est plus disponible.');
    return ProfileDetail(
      base: p.profile,
      maritalStatus: p.maritalStatus,
      childrenCount: p.childrenCount,
      education: p.education,
      heightCm: p.heightCm,
      isPhoneVerified: true,
      matched: _matches.any((m) => m.userId == userId),
      // Même règle que le serveur (0009) : photo principale nette, suivantes floutées pour un membre Gratuit.
      photos: [
        for (var i = 0; i < 3; i++)
          ProfilePhoto(
            id: '$userId-photo-$i',
            visibility: 'public',
            access: i == 0 || (_profile?.isPremium ?? false) ? 'original' : 'blurred',
          ),
      ],
    );
  }

  DateTime get _resetsAt {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  @override
  Future<LikeResult> like(String userId) async {
    if (_seen.contains(userId)) return const LikeResult(LikeStatus.alreadyLiked);
    if (_likesUsed >= freeDailyLikes) return LikeResult(LikeStatus.quotaReached, resetsAt: _resetsAt);
    _likesUsed++;
    _seen.add(userId);
    if (_likedMe.remove(userId)) {
      final p = _person(userId)!.profile;
      final matchId = 'match-$userId';
      _matches.insert(
          0, MatchSummary(matchId: matchId, userId: userId, displayName: p.displayName, isVerified: p.isVerified));
      _messages[matchId] = <ChatMessage>[];
      return LikeResult(LikeStatus.matched, matchId: matchId);
    }
    _likedByMe.insert(0, userId);
    return LikeResult(LikeStatus.liked, remaining: freeDailyLikes - _likesUsed);
  }

  @override
  Future<void> pass(String userId) async {
    _seen.add(userId);
  }

  @override
  Future<LikeQuota> likeQuota() async =>
      LikeQuota(limit: freeDailyLikes, remaining: freeDailyLikes - _likesUsed, resetsAt: _resetsAt);

  @override
  Future<int> receivedInterestsCount() async => _likedMe.where((id) => !_blocked.containsKey(id)).length;

  @override
  Future<List<DiscoveryProfile>> receivedInterests() async => throw Exception('PREMIUM_REQUIRED');

  @override
  Future<List<DiscoveryProfile>> sentInterests() async => [
        for (final id in _likedByMe)
          if (!_blocked.containsKey(id) && !_matches.any((m) => m.userId == id) && _person(id) != null)
            _person(id)!.profile,
      ];

  @override
  Future<List<MatchSummary>> matches() async => [
        for (final m in _matches)
          if (!_blocked.containsKey(m.userId)) _withLastMessage(m),
      ];

  MatchSummary _withLastMessage(MatchSummary m) {
    ChatMessage? last;
    for (final x in _messages[m.matchId] ?? const <ChatMessage>[]) {
      if (!x.unsent) last = x;
    }
    return MatchSummary(
      matchId: m.matchId,
      userId: m.userId,
      displayName: m.displayName,
      isVerified: m.isVerified,
      lastMessage: last?.body,
      lastAt: last?.createdAt,
    );
  }

  @override
  Future<void> unmatch(String matchId) async {
    for (final m in _matches.where((m) => m.matchId == matchId)) {
      _ended.insert(
          0,
          EndedMatch(
              matchId: m.matchId,
              userId: m.userId,
              displayName: m.displayName,
              endedAt: DateTime.now(),
              endedByMe: true));
    }
    _matches.removeWhere((m) => m.matchId == matchId);
  }

  /// Demandes de re-match envoyées (démo : la personne fictive ne répond pas).
  final Set<String> _rematchSent = <String>{};

  @override
  Future<({int active, int limit})> conversationSlots() async => (
        active: _matches
            .where((m) => !_blocked.containsKey(m.userId) && (_messages[m.matchId] ?? const <ChatMessage>[]).isNotEmpty)
            .length,
        limit: 5,
      );

  @override
  Future<List<RematchRequest>> rematchRequests() async => const <RematchRequest>[];

  @override
  Future<String> rematchState(String matchId) async => _rematchSent.contains(matchId) ? 'sent' : 'none';

  @override
  Future<String> requestRematch(String matchId) async {
    if (_matches.any((m) => m.matchId == matchId)) return 'active';
    _rematchSent.add(matchId);
    return 'pending';
  }

  @override
  Future<String> respondRematch(String matchId, {required bool accept}) async =>
      throw Exception('REQUEST_NOT_FOUND');

  @override
  Future<List<EndedMatch>> endedMatches() async => [
        for (final e in _ended)
          if (!_blocked.containsKey(e.userId)) e,
      ];

  void _emit(String matchId) =>
      _streams[matchId]?.add(List<ChatMessage>.unmodifiable(_messages[matchId] ?? const <ChatMessage>[]));

  @override
  Stream<List<ChatMessage>> watchMessages(String matchId) {
    final controller = _streams.putIfAbsent(matchId, () => StreamController<List<ChatMessage>>.broadcast());
    Future<void>.microtask(() => _emit(matchId));
    return controller.stream;
  }

  @override
  Future<SendResult> sendMessage(String matchId, String body) async {
    if (!_matches.any((m) => m.matchId == matchId)) throw Exception('Cette conversation est terminée.');
    // Même règle que le serveur (0040) : le premier message d'un match exige une place de conversation libre.
    final slots = await conversationSlots();
    if ((_messages[matchId] ?? const <ChatMessage>[]).isEmpty && slots.active >= slots.limit) {
      return SendResult.activeLimit(slots.limit);
    }
    final lower = body.toLowerCase();
    for (final e in _blockedTerms.entries) {
      if (lower.contains(e.key)) return SendResult.blocked(e.value);
    }
    _messages
        .putIfAbsent(matchId, () => <ChatMessage>[])
        .add(ChatMessage(id: 'local-${_seq++}', senderId: _me, body: body.trim(), createdAt: DateTime.now()));
    _emit(matchId);
    return const SendResult.sent();
  }

  @override
  Future<SendResult> editMessage(String messageId, String body) async {
    final lower = body.toLowerCase();
    for (final e in _blockedTerms.entries) {
      if (lower.contains(e.key)) return SendResult.blocked(e.value);
    }
    for (final e in _messages.entries) {
      final i = e.value.indexWhere((m) => m.id == messageId && m.senderId == _me && !m.unsent);
      if (i >= 0) {
        final m = e.value[i];
        e.value[i] =
            ChatMessage(id: m.id, senderId: m.senderId, body: body.trim(), createdAt: m.createdAt, edited: true);
        _emit(e.key);
      }
    }
    return const SendResult.sent();
  }

  @override
  Future<void> unsendMessage(String messageId) async {
    for (final e in _messages.entries) {
      final i = e.value.indexWhere((m) => m.id == messageId && m.senderId == _me);
      if (i >= 0) {
        final m = e.value[i];
        e.value[i] = ChatMessage(id: m.id, senderId: m.senderId, body: '', createdAt: m.createdAt, unsent: true);
        _emit(e.key);
      }
    }
  }

  @override
  Future<void> hideMessage(String messageId) async {
    for (final e in _messages.entries) {
      final before = e.value.length;
      e.value.removeWhere((m) => m.id == messageId);
      if (e.value.length != before) _emit(e.key);
    }
  }

  @override
  Future<void> block(String userId) async {
    _blocked[userId] = _person(userId)?.profile.displayName ?? _community.authorName(userId) ?? 'Membre';
    _matches.removeWhere((m) => m.userId == userId);
    _ended.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<void> unblock(String userId) async {
    _blocked.remove(userId);
  }

  @override
  Future<List<BlockedUser>> blockedUsers() async =>
      [for (final e in _blocked.entries) BlockedUser(userId: e.key, displayName: e.value)];

  @override
  Future<void> report(String userId,
      {required String context, required String reason, String? details, String? matchId}) async {}

  @override
  Future<DateTime> requestAccountDeletion() async {
    final p = _profile;
    if (p == null) throw Exception('Profil introuvable.');
    p.deletionScheduledFor ??= DateTime.now().add(const Duration(days: 30));
    p.status = 'hidden';
    return p.deletionScheduledFor!;
  }

  @override
  Future<void> cancelAccountDeletion() async {
    final p = _profile;
    if (p == null) return;
    p.deletionScheduledFor = null;
    p.status = 'active';
  }

  @override
  Future<String> exportMyData() async {
    final p = _profile;
    return const JsonEncoder.withIndent('  ').convert({
      'exported_at': DateTime.now().toIso8601String(),
      'profile': p == null
          ? null
          : {
              'display_name': p.displayName,
              'age': p.age,
              'city': p.city,
              'bio': p.bio,
              'marriage_horizon': p.horizon,
              'marital_status': p.maritalStatus,
              'languages': p.languages,
              'interests': p.interests,
              'status': p.status,
            },
      'messages_sent': [
        for (final list in _messages.values)
          for (final m in list)
            if (m.senderId == _me && !m.unsent) {'body': m.body, 'created_at': m.createdAt.toIso8601String()},
      ],
      'support_requests': [
        for (final t in _tickets)
          {
            'category': t.category,
            'message': t.message,
            'status': t.status,
            'created_at': t.createdAt.toIso8601String()
          },
      ],
    });
  }

  // ── Assistance et documents légaux (mêmes règles que 0008_assistance.sql)
  static const supportTicketsPerDay = 5;

  /// Textes de démonstration seulement : les versions officielles viennent de `legal_documents` (décision B1).
  @override
  Future<List<LegalDocument>> legalDocuments() async {
    final published = DateTime(2026, 11, 16);
    const body = 'Texte provisoire affiché en mode démo. La version officielle sera publiée par ZAYA après '
        'validation juridique.';
    return [
      for (final kind in ['tos', 'privacy', 'community'])
        LegalDocument(kind: kind, version: 'v0-draft', lang: 'fr', content: body, publishedAt: published),
    ];
  }

  @override
  Future<void> createSupportTicket({required String category, required String message, String? language}) async {
    if (!_signedIn) throw Exception('NOT_AUTHENTICATED');
    if (!supportCategories.contains(category)) throw Exception('INVALID_CATEGORY');
    final text = message.trim();
    if (text.length < 10) throw Exception('MESSAGE_TOO_SHORT');
    final since = DateTime.now().subtract(const Duration(hours: 24));
    if (_tickets.where((t) => t.createdAt.isAfter(since)).length >= supportTicketsPerDay) {
      throw Exception('SUPPORT_RATE_LIMITED');
    }
    _tickets.insert(
        0,
        SupportTicket(
          id: 'ticket-${_seq++}',
          category: category,
          message: text.length > 2000 ? text.substring(0, 2000) : text,
          status: 'open',
          createdAt: DateTime.now(),
        ));
  }

  @override
  Future<List<SupportTicket>> mySupportTickets() async => List<SupportTicket>.unmodifiable(_tickets);

  @override
  Future<List<PremiumGrant>> premiumHistory() async => const <PremiumGrant>[];

  @override
  Future<List<PaymentTx>> payments() async => const <PaymentTx>[];

  // ── Communauté (délégué au magasin de démonstration)
  @override
  Future<List<Community>> communities() async => _community.communities();

  @override
  Future<void> joinCommunity(String communityId) async => _community.join(communityId);

  @override
  Future<void> leaveCommunity(String communityId) async => _community.leave(communityId);

  @override
  Future<void> setCommunityNotifications(String communityId, String level) async =>
      _community.setNotifications(communityId, level);

  @override
  Future<List<CommunityPost>> communityFeed({String? communityId, DateTime? before}) async =>
      _community.feed(communityId: communityId, before: before);

  @override
  Future<CommunityPost> communityPost(String postId) async => _community.post(postId);

  @override
  Future<List<CommunityPost>> savedPosts() async => _community.saved();

  @override
  Future<PublishResult> createPost({required String communityId, required String kind, required String body}) async =>
      _community.create(communityId: communityId, kind: kind, body: body);

  @override
  Future<PublishResult> editPost(String postId, String body) async => _community.edit(postId, body);

  @override
  Future<void> deletePost(String postId) async => _community.delete(postId);

  @override
  Future<void> setPostComments(String postId, bool enabled) async => _community.setComments(postId, enabled);

  @override
  Future<int> reactToPost(String postId, bool on) async => _community.react(postId, on);

  @override
  Future<void> savePost(String postId, bool saved) async => _community.save(postId, saved);

  @override
  Future<void> hidePost(String postId) async => _community.hide(postId);

  @override
  Future<List<PostComment>> postComments(String postId) async => _community.comments(postId);

  @override
  Future<PublishResult> addComment(String postId, String body) async => _community.addComment(postId, body);

  @override
  Future<PublishResult> editComment(String commentId, String body) async => _community.editComment(commentId, body);

  @override
  Future<void> deleteComment(String commentId) async => _community.deleteComment(commentId);

  @override
  Future<void> reportPost(String postId, {required String reason, String? details}) async =>
      _community.reportPost(postId);

  @override
  Future<void> reportComment(String commentId, {required String reason, String? details}) async =>
      _community.reportComment(commentId);
}
