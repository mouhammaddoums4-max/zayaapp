import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/content_rules.dart';
import 'demo_community.dart';
import 'demo_zaya2.dart';
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
class DemoRepository implements ZayaRepository, QuickDiscoveryRepository {
  /// [initialPin] : code de connexion du compte démo (6236 par défaut, choix du propriétaire) ; `null` = compte sans
  /// code, pour montrer la création du code à l'arrivée dans l'application.
  DemoRepository({String? initialPin = demoPin}) : _pin = initialPin;

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
  final DemoZaya2 _zaya2 = DemoZaya2();
  final Map<String, List<MessageReaction>> _reactions = <String, List<MessageReaction>>{};
  final Map<String, StreamController<List<MessageReaction>>> _reactionStreams =
      <String, StreamController<List<MessageReaction>>>{};
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
        // ZAYA 2.0 et demandes du 25/11/2026 (migrations 0067 à 0071) : tout est actif en démo.
        'feature_match_of_day_enabled': true,
        'feature_pulse_enabled': true,
        'feature_invitation_enabled': true,
        'feature_surprise_enabled': true,
        'feature_challenge_enabled': true,
        'feature_questions_enabled': true,
        'flowers_enabled': true,
        'flowers_per_day': 3,
        'pin_login_enabled': true,
        'max_profile_photos': 6,
        'min_profile_photos': 3,
      };

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<void> verifyOtp(String phone, String code) async {
    if (code != demoOtp) throw Exception('Code incorrect. En mode démo, le code est $demoOtp.');
    _signedIn = true;
    _phone = phone;
    _otpVerifiedAt = DateTime.now();
    // Comme sur le serveur, un SMS vérifié reconnecte le compte existant de ce numéro (code oublié).
    final saved = _savedPhone;
    if (saved != null && _digits(saved) == _digits(phone)) _profile ??= _savedProfile;
  }

  // ── Connexion par code (démo) : mêmes règles que le serveur (0071), en mémoire.
  /// Code par défaut des comptes démo (choix du propriétaire) ; une valeur nulle = compte sans code.
  static const demoPin = '6236';
  String? _pin;
  int _pinErrors = 0;
  DateTime? _pinLockedUntil;
  DateTime? _otpVerifiedAt;

  static String _digits(String phone) {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    return d.length == 9 ? '224$d' : d;
  }

  static bool _weakPin(String p) =>
      RegExp(r'^(.)\1{3}$').hasMatch(p) ||
      const {
        '0123',
        '1234',
        '2345',
        '3456',
        '4567',
        '5678',
        '6789',
        '9876',
        '8765',
        '7654',
        '6543',
        '5432',
        '4321',
        '3210'
      }.contains(p);

  /// Dernier compte démo, gardé après une déconnexion pour pouvoir s'y reconnecter par code.
  MyProfile? _savedProfile;
  String? _savedPhone;

  /// Le compte démo existe dès qu'un profil a été créé dans cette session (inscription vérifiée).
  bool _isDemoAccount(String phone) {
    final known = _phone ?? _savedPhone;
    return (_profile ?? _savedProfile) != null && known != null && _digits(known) == _digits(phone);
  }

  @override
  Future<String> phoneStatus(String phone) async {
    if (!_isDemoAccount(phone)) return 'new';
    return _pin == null ? 'no_pin' : 'pin';
  }

  @override
  Future<PinLoginResult> signInWithPin(String phone, String pin) async {
    if (!_isDemoAccount(phone)) return const PinLoginResult('unknown');
    if (_pin == null) return const PinLoginResult('no_pin');
    final until = _pinLockedUntil;
    if (until != null && until.isAfter(DateTime.now())) return PinLoginResult('locked', lockedUntil: until);
    if (pin != _pin) {
      _pinErrors++;
      if (_pinErrors >= 5) {
        _pinErrors = 0;
        _pinLockedUntil = DateTime.now().add(const Duration(minutes: 15));
        return PinLoginResult('locked', lockedUntil: _pinLockedUntil);
      }
      return PinLoginResult('wrong', remaining: 5 - _pinErrors);
    }
    _pinErrors = 0;
    _profile ??= _savedProfile;
    _phone ??= _savedPhone;
    _signedIn = true;
    return const PinLoginResult('ok');
  }

  @override
  Future<({bool hasPin, bool mustChange})> myPinStatus() async => (hasPin: _pin != null, mustChange: false);

  @override
  Future<void> setPin(String pin) async {
    if (_pin != null) throw Exception('PIN_ALREADY_SET');
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw Exception('PIN_FORMAT');
    if (_weakPin(pin)) throw Exception('PIN_TOO_WEAK');
    _pin = pin;
  }

  @override
  Future<void> changePin(String oldPin, String newPin) async {
    if (oldPin != _pin) throw Exception('PIN_WRONG');
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) throw Exception('PIN_FORMAT');
    if (_weakPin(newPin) || newPin == oldPin) throw Exception('PIN_TOO_WEAK');
    _pin = newPin;
  }

  @override
  Future<void> resetPin(String newPin) async {
    final at = _otpVerifiedAt;
    if (at == null || DateTime.now().difference(at) > const Duration(minutes: 5)) throw Exception('OTP_REQUIRED');
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) throw Exception('PIN_FORMAT');
    if (_weakPin(newPin)) throw Exception('PIN_TOO_WEAK');
    _pin = newPin;
    _pinErrors = 0;
    _pinLockedUntil = null;
  }

  @override
  Future<void> signOut() async {
    // Le compte démo reste connu : on peut s'y reconnecter avec son numéro et son code (connexion par code).
    if (_profile != null) {
      _savedProfile = _profile;
      _savedPhone = _phone;
    }
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
        City(11, 'Conakry — Gbessia'),
        City(12, 'Conakry — Kagb\u00E9len'),
        City(13, 'Conakry — Lambanyi'),
        City(14, 'Conakry — Man\u00E9ah'),
        City(15, 'Conakry — Sanoyah'),
        City(16, 'Conakry — Sonfonia'),
        City(17, 'Conakry — Tombolia'),
        City(18, 'Conakry — Kassa'),
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
  Future<List<EducationLevel>> educationLevels() async => const <EducationLevel>[
        // Mêmes valeurs de départ que le serveur (0052).
        EducationLevel('none', 'Sans diplôme', labelEn: 'No diploma'),
        EducationLevel('primary', 'Primaire (CEPE)', labelEn: 'Primary school'),
        EducationLevel('middle', 'Collège (BEPC)', labelEn: 'Middle school'),
        EducationLevel('bac', 'Baccalauréat', labelEn: 'High school diploma'),
        EducationLevel('vocational', 'Formation professionnelle', labelEn: 'Vocational training'),
        EducationLevel('bac2', 'Bac +2 (BTS, DUT)', labelEn: 'Two-year degree'),
        EducationLevel('licence', 'Licence (Bac +3)', labelEn: 'Bachelor’s degree'),
        EducationLevel('master', 'Master (Bac +5)', labelEn: 'Master’s degree'),
        EducationLevel('doctorate', 'Doctorat', labelEn: 'Doctorate'),
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

  /// Photos ajoutées en démo (aucun fichier envoyé : l'emplacement montre l'initiale).
  final List<MyPhoto> _demoPhotos = <MyPhoto>[];

  @override
  Future<void> addPhoto(Uint8List bytes) async {
    final p = _profile;
    if (_demoPhotos.length >= 6) throw Exception('MAX_PHOTOS');
    final n = _seq++;
    _demoPhotos.add(MyPhoto(id: 'demo-photo-$n', path: 'demo/$_me/$n.jpg', position: _demoPhotos.length));
    if (p != null) {
      p.photoCount = _demoPhotos.length;
      p.mainPhotoPath = _demoPhotos.first.path;
    }
  }

  @override
  Future<List<MyPhoto>> myPhotos() async => [
        for (var i = 0; i < _demoPhotos.length; i++)
          MyPhoto(id: _demoPhotos[i].id, path: _demoPhotos[i].path, position: i),
      ];

  void _syncDemoPhotos() {
    final p = _profile;
    if (p == null) return;
    p.photoCount = _demoPhotos.length;
    p.mainPhotoPath = _demoPhotos.isEmpty ? null : _demoPhotos.first.path;
  }

  @override
  Future<void> deleteMyPhoto(String photoId) async {
    _demoPhotos.removeWhere((x) => x.id == photoId);
    _syncDemoPhotos();
  }

  @override
  Future<void> setMainPhoto(String photoId) async {
    final i = _demoPhotos.indexWhere((x) => x.id == photoId);
    if (i <= 0) return;
    _demoPhotos.insert(0, _demoPhotos.removeAt(i));
    _syncDemoPhotos();
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
      maritalStatuses: [..._prefs.maritalStatuses],
      educationKeys: [..._prefs.educationKeys],
      childrenMax: _prefs.childrenMax);

  @override
  Future<void> savePreferences(DiscoveryPrefs prefs) async {
    // Même règle que le serveur (0025, 0052) : un compte Gratuit ne peut pas définir ni changer de filtre avancé.
    bool change(List<String> avant, List<String> apres) =>
        apres.isNotEmpty && (avant.length != apres.length || avant.any((v) => !apres.contains(v)));
    if (!(_profile?.isPremium ?? false) &&
        (change(_prefs.languages, prefs.languages) ||
            change(_prefs.horizons, prefs.horizons) ||
            change(_prefs.maritalStatuses, prefs.maritalStatuses) ||
            change(_prefs.educationKeys, prefs.educationKeys) ||
            (prefs.childrenMax != null && prefs.childrenMax != _prefs.childrenMax))) {
      throw Exception('PREMIUM_REQUIRED');
    }
    _prefs = prefs;
  }

  /// Clé de niveau d'études d'un profil fictif, d'après son texte (même correspondance que la reprise de 0052).
  static String? _educationKey(String? texte) {
    final t = (texte ?? '').toLowerCase();
    if (t.startsWith('doctorat')) return 'doctorate';
    if (t.startsWith('master')) return 'master';
    if (t.startsWith('licence')) return 'licence';
    if (t.startsWith('bts') || t.startsWith('dut')) return 'bac2';
    if (t.startsWith('bac')) return 'bac';
    return null;
  }

  @override
  Future<List<DiscoveryProfile>> discoveryFeed() => discoveryFeedFiltered(null);

  @override
  Future<List<DiscoveryProfile>> discoveryFeedFiltered(String? quickFilter) async {
    if (quickFilter != null && quickFilter != 'verified' && quickFilter != 'soon') {
      throw Exception('INVALID_DISCOVERY_FILTER');
    }
    if (quickFilter == 'soon' && !(_profile?.isPremium ?? false)) throw Exception('PREMIUM_REQUIRED');
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
    final etudes = avances ? _prefs.educationKeys : const <String>[];
    final enfantsMax = avances ? _prefs.childrenMax : null;
    return [
      for (final p in _pool)
        if (!_seen.contains(p.profile.id) &&
            !_blocked.containsKey(p.profile.id) &&
            p.profile.age >= _prefs.ageMin &&
            p.profile.age <= _prefs.ageMax &&
            (villes.isEmpty || villes.contains(p.profile.city)) &&
            (langues.isEmpty || p.profile.languages.any(langues.contains)) &&
            (projets.isEmpty || projets.contains(p.profile.horizon)) &&
            (quickFilter != 'verified' || p.profile.isVerified) &&
            (quickFilter != 'soon' || p.profile.horizon == 'soon') &&
            (situations.isEmpty || situations.contains(p.maritalStatus)) &&
            (etudes.isEmpty || etudes.contains(_educationKey(p.education))) &&
            (enfantsMax == null || p.childrenCount <= enfantsMax))
          p.profile,
    ];
  }

  @override
  Future<void> recordProfileView(String userId) async {}

  @override
  Future<ProfileDetail> profileDetail(String userId, {bool recordView = true}) async {
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
    _passed.remove(userId);
    _passed.insert(0, userId);
  }

  /// Profils passés, du plus récent au plus ancien (retour arrière, même règle que le serveur 0016).
  final List<String> _passed = <String>[];

  @override
  Future<DiscoveryProfile?> rewindLastPass() async {
    final depth = (_profile?.isPremium ?? false) ? 10 : 1;
    for (final id in _passed.take(depth)) {
      final p = _person(id);
      if (p == null || _blocked.containsKey(id)) continue;
      _passed.remove(id);
      _seen.remove(id);
      return p.profile;
    }
    return null;
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
      lastMessage: last?.isAnimatedSticker == true
          ? 'GIF animé'
          : last?.isVoice == true
              ? 'Note vocale'
              : last?.body,
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
  Future<String> respondRematch(String matchId, {required bool accept}) async => throw Exception('REQUEST_NOT_FOUND');

  @override
  Future<List<EndedMatch>> endedMatches() async => [
        for (final e in _ended)
          if (!_blocked.containsKey(e.userId)) e,
      ];

  void _emit(String matchId) =>
      _streams[matchId]?.add(List<ChatMessage>.unmodifiable(_messages[matchId] ?? const <ChatMessage>[]));

  /// Mode démo : tout est déjà en mémoire, aucun signal à attendre.
  @override
  Stream<String> watchSignals() => const Stream<String>.empty();

  @override
  Stream<List<ChatMessage>> watchMessages(String matchId) {
    final controller = _streams.putIfAbsent(matchId, () => StreamController<List<ChatMessage>>.broadcast());
    Future<void>.microtask(() => _emit(matchId));
    return controller.stream;
  }

  @override
  Stream<List<MessageReaction>> watchReactions(String matchId) {
    final controller = _reactionStreams.putIfAbsent(matchId, () => StreamController<List<MessageReaction>>.broadcast());
    Future<void>.microtask(() => controller.add(List.of(_reactions[matchId] ?? const <MessageReaction>[])));
    return controller.stream;
  }

  @override
  Future<Object?> zayaRpc(String function, [Map<String, Object?> params = const <String, Object?>{}]) async =>
      _zaya2.call(function, params, [for (final p in _pool) p.profile]);

  /// Fleurs envoyées aujourd'hui (démo) : même limite provisoire que le serveur (app_config.flowers_per_day = 3).
  final Set<String> _flowersSent = <String>{};

  @override
  Future<LikeResult> sendFlower(String userId) async {
    if (!(_profile?.isPremium ?? false)) throw Exception('PREMIUM_REQUIRED');
    if (_flowersSent.contains(userId)) return const LikeResult(LikeStatus.alreadyLiked);
    if (_flowersSent.length >= 3) throw Exception('FLOWER_LIMIT');
    final result = await like(userId);
    if (result.status != LikeStatus.quotaReached) _flowersSent.add(userId);
    return result;
  }

  /// Une fleur reçue fictive, pour montrer l'emplacement en démo.
  @override
  Future<List<DiscoveryProfile>> receivedFlowers() async {
    final pool = _pool;
    return pool.length > 3 ? [pool[3].profile] : const <DiscoveryProfile>[];
  }

  @override
  Future<int> hideConversations(List<String> matchIds) async {
    var n = 0;
    for (final id in matchIds) {
      final removed = _messages.remove(id) != null;
      final before = _matches.length;
      _matches.removeWhere((m) => m.matchId == id);
      if (removed || _matches.length != before) n++;
      _emit(id);
    }
    return n;
  }

  /// En démo, la première personne de la liste des matchs est « en ligne ».
  @override
  Future<Set<String>> onlineMatches() async => {if (_matches.isNotEmpty) _matches.first.userId};

  @override
  Future<void> touchActive() async {}

  @override
  Future<void> reactToMessage(String messageId, String emoji) async {
    for (final e in _messages.entries) {
      if (!e.value.any((m) => m.id == messageId && !m.unsent)) continue;
      final list = _reactions.putIfAbsent(e.key, () => <MessageReaction>[]);
      final i = list.indexWhere((r) => r.messageId == messageId && r.userId == _me);
      final same = i >= 0 && list[i].emoji == emoji;
      if (i >= 0) list.removeAt(i);
      if (!same) list.add(MessageReaction(messageId: messageId, userId: _me, emoji: emoji));
      _reactionStreams[e.key]?.add(List.of(list));
    }
  }

  @override
  Future<SendResult> sendMessage(String matchId, String body, {String? replyToId}) async {
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
    final scam = demoScamCategory(body);
    _messages.putIfAbsent(matchId, () => <ChatMessage>[]).add(ChatMessage(
        id: 'local-${_seq++}',
        senderId: _me,
        body: body.trim(),
        createdAt: DateTime.now(),
        replyToId: replyToId,
        scamCategory: scam));
    _emit(matchId);
    return SendResult.sent(warning: scam);
  }

  @override
  Future<SendResult> sendVoiceMessage(String matchId, String localFilePath, int durationSeconds) async {
    if (!_matches.any((m) => m.matchId == matchId)) throw Exception('Cette conversation est terminée.');
    final slots = await conversationSlots();
    if ((_messages[matchId] ?? const <ChatMessage>[]).isEmpty && slots.active >= slots.limit) {
      return SendResult.activeLimit(slots.limit);
    }
    _messages.putIfAbsent(matchId, () => <ChatMessage>[]).add(ChatMessage(
          id: 'local-${_seq++}',
          senderId: _me,
          body: 'Note vocale',
          createdAt: DateTime.now(),
          kind: 'voice',
          mediaPath: localFilePath,
          mediaDurationSeconds: durationSeconds,
        ));
    _emit(matchId);
    return const SendResult.sent();
  }

  @override
  Future<SendResult> sendAnimatedSticker(String matchId, String stickerId) async {
    const allowed = {
      'heart_bounce',
      'laugh_shake',
      'kiss_pulse',
      'hug_squeeze',
      'party_spin',
      'prayer_bounce',
      'rose_sway',
      'fire_flicker',
    };
    if (!allowed.contains(stickerId)) throw Exception('Animation indisponible.');
    if (!_matches.any((m) => m.matchId == matchId)) throw Exception('Cette conversation est terminée.');
    final slots = await conversationSlots();
    if ((_messages[matchId] ?? const <ChatMessage>[]).isEmpty && slots.active >= slots.limit) {
      return SendResult.activeLimit(slots.limit);
    }
    _messages.putIfAbsent(matchId, () => <ChatMessage>[]).add(ChatMessage(
          id: 'local-${_seq++}',
          senderId: _me,
          body: 'Animation',
          createdAt: DateTime.now(),
          kind: 'sticker',
          stickerId: stickerId,
        ));
    _emit(matchId);
    return const SendResult.sent();
  }

  @override
  Future<String?> voiceMessageUrl(String storagePath) async => storagePath;

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
        e.value[i] = ChatMessage(
            id: m.id,
            senderId: m.senderId,
            body: body.trim(),
            createdAt: m.createdAt,
            edited: true,
            replyToId: m.replyToId);
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
