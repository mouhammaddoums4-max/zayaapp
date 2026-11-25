/// Modèles de données ZAYA (côté application).
library;

const confessionLabels = <String, String>{
  'muslim': 'Musulman(e)',
  'christian': 'Chrétien(ne)',
  'other': 'Autre confession',
  'none': 'Sans religion',
  'undisclosed': 'Je préfère ne pas préciser',
};

const horizonLabels = <String, String>{
  'soon': 'Bientôt',
  'few_months': 'Dans les prochains mois',
  'medium_term': 'À moyen terme',
  'no_date': 'Sans date précise',
};

const maritalLabels = <String, String>{
  'single': 'Célibataire',
  'divorced': 'Divorcé(e)',
  'widowed': 'Veuf / veuve',
  'separated': 'Séparé(e)',
  'married': 'Marié(e)',
  'other': 'Autre',
};

const confessionModeLabels = <String, String>{
  'no_filter': 'Sans filtre confessionnel',
  'mine_only': 'Ma confession uniquement',
  'selected': 'Une ou plusieurs confessions choisies',
  'all': 'Toutes les confessions',
};

/// Listes proposées dans l'application (à rendre administrables au lot « référentiels »).
const languageOptions = <String>[
  'Français',
  'Anglais',
  'Poular',
  'Malinké',
  'Soussou',
  'Kissi',
  'Guerzé',
  'Arabe',
  'Wolof',
];

const interestOptions = <String>[
  'Famille',
  'Lecture',
  'Cuisine',
  'Sport',
  'Voyages',
  'Entrepreneuriat',
  'Éducation',
  'Bénévolat',
  'Musique',
  'Traditions',
  'Technologie',
  'Nature',
];

class City {
  const City(this.id, this.name);
  final int id;
  final String name;
}

/// Pays du référentiel (`countries`) : nationalité, pays de résidence.
class Country {
  const Country(this.code, this.nameFr, this.nameEn);
  final String code; // ISO 3166-1 alpha-2
  final String nameFr;
  final String nameEn;

  String name(String lang) => lang == 'en' ? nameEn : nameFr;
}

/// Profession du catalogue administrable (`professions`, jamais codé en dur dans l'application).
class Profession {
  const Profession(this.id, this.labelFr, {this.labelEn});
  final int id;
  final String labelFr;
  final String? labelEn;

  /// Libellé dans la langue de l'interface ; français si la traduction manque encore.
  String label(String lang) => lang == 'en' && (labelEn ?? '').isNotEmpty ? labelEn! : labelFr;
}

/// Niveau d'études : liste fermée tenue par l'administration (table education_levels, migration 0052).
class EducationLevel {
  const EducationLevel(this.key, this.labelFr, {this.labelEn});
  final String key;
  final String labelFr;
  final String? labelEn;

  /// Libellé dans la langue de l'interface ; français si la traduction manque encore.
  String label(String lang) => lang == 'en' && (labelEn ?? '').isNotEmpty ? labelEn! : labelFr;
}

/// Brouillon d'inscription, sauvegardé localement pour reprendre après interruption.
class OnboardingDraft {
  bool adultConfirmed = false;
  String displayName = '';
  DateTime? birthDate;
  String? gender; // femme | homme
  int? cityId;
  String? horizon;
  String? maritalStatus; // facultatif
  String? nationalityCode; // facultatif (B07)
  int? professionId; // facultatif (B08)
  String professionOther = ''; // « Autre », 60 caractères au plus
  String? educationKey; // facultatif : clé de education_levels (0052)
  int? childrenCount; // facultatif : 0 à 20 (0052)
  String? confession; // facultatif
  bool confessionConsent = false;
  String confessionMode = 'no_filter';
  List<String> selectedConfessions = [];
  int ageMin = 18;
  int ageMax = 45;
  String bio = '';
  String phone = '';
  bool acceptedTerms = false;
  bool marketingConsent = false;
  int step = 0;

  Map<String, dynamic> toJson() => {
        'adultConfirmed': adultConfirmed,
        'displayName': displayName,
        'birthDate': birthDate?.toIso8601String(),
        'gender': gender,
        'cityId': cityId,
        'horizon': horizon,
        'maritalStatus': maritalStatus,
        'nationalityCode': nationalityCode,
        'professionId': professionId,
        'professionOther': professionOther,
        'educationKey': educationKey,
        'childrenCount': childrenCount,
        'confession': confession,
        'confessionConsent': confessionConsent,
        'confessionMode': confessionMode,
        'selectedConfessions': selectedConfessions,
        'ageMin': ageMin,
        'ageMax': ageMax,
        'bio': bio,
        'phone': phone,
        'step': step,
      };

  static OnboardingDraft fromJson(Map<String, dynamic> j) => OnboardingDraft()
    ..adultConfirmed = j['adultConfirmed'] == true
    ..displayName = (j['displayName'] as String?) ?? ''
    ..birthDate = j['birthDate'] == null ? null : DateTime.tryParse(j['birthDate'] as String)
    ..gender = j['gender'] as String?
    ..cityId = (j['cityId'] as num?)?.toInt()
    ..horizon = j['horizon'] as String?
    ..maritalStatus = j['maritalStatus'] as String?
    ..nationalityCode = j['nationalityCode'] as String?
    ..professionId = (j['professionId'] as num?)?.toInt()
    ..professionOther = (j['professionOther'] as String?) ?? ''
    ..educationKey = j['educationKey'] as String?
    ..childrenCount = (j['childrenCount'] as num?)?.toInt()
    ..confession = j['confession'] as String?
    ..confessionConsent = j['confessionConsent'] == true
    ..confessionMode = (j['confessionMode'] as String?) ?? 'no_filter'
    ..selectedConfessions = List<String>.from(j['selectedConfessions'] as List? ?? const <String>[])
    ..ageMin = (j['ageMin'] as num?)?.toInt() ?? 18
    ..ageMax = (j['ageMax'] as num?)?.toInt() ?? 45
    ..bio = (j['bio'] as String?) ?? ''
    ..phone = (j['phone'] as String?) ?? ''
    ..step = (j['step'] as num?)?.toInt() ?? 0;
}

/// Âge révolu à la date [now].
int ageFrom(DateTime birthDate, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) age--;
  return age;
}

bool isAdult(DateTime birthDate, {DateTime? now}) => ageFrom(birthDate, now: now) >= 18;

class MyProfile {
  MyProfile({
    required this.id,
    required this.displayName,
    required this.status,
    required this.verificationStatus,
    this.isPhoneVerified = false,
    this.isPremium = false,
    this.age,
    this.city,
    this.bio,
    this.horizon,
    this.maritalStatus,
    this.languages = const <String>[],
    this.interests = const <String>[],
    this.incognito = false,
    this.discreetBrowsing = false,
    this.showOnline = true,
    this.photoCount = 0,
    this.mainPhotoPath,
    this.deletionScheduledFor,
    this.birthDate,
    this.gender,
  });

  final String id;

  /// Figés après l'inscription (`profiles_guard`) : affichés dans les Réglages, jamais modifiables.
  final DateTime? birthDate;
  final String? gender; // femme | homme
  String displayName;
  String? mainPhotoPath;
  String status; // draft | active | paused | hidden | suspended | banned | deleted
  String verificationStatus; // not_requested | pending | more_info_required | approved | rejected | redo
  bool isPhoneVerified;
  bool isPremium;
  int? age;
  String? city;
  String? bio;
  String? horizon;
  String? maritalStatus;
  List<String> languages;
  List<String> interests;
  bool incognito;
  bool discreetBrowsing;
  bool showOnline;
  int photoCount;
  DateTime? deletionScheduledFor;

  bool get isVerified => verificationStatus == 'approved';

  /// Complétude du profil (0 à 1), calculée sur les champs réellement renseignés.
  double get completeness {
    final checks = <bool>[
      displayName.isNotEmpty,
      city != null,
      bio != null && bio!.trim().isNotEmpty,
      horizon != null,
      maritalStatus != null,
      languages.isNotEmpty,
      interests.isNotEmpty,
      photoCount >= 3,
      isVerified,
    ];
    return checks.where((ok) => ok).length / checks.length;
  }
}

class DiscoveryProfile {
  const DiscoveryProfile({
    required this.id,
    required this.displayName,
    required this.age,
    this.city,
    this.bio,
    this.horizon,
    this.profession,
    this.languages = const <String>[],
    this.interests = const <String>[],
    this.isVerified = false,
    this.isPremium = false,
    this.photoPath,
  });

  final String id;
  final String displayName;
  final int age;
  final String? city;
  final String? bio;
  final String? horizon;
  final String? profession;
  final List<String> languages;
  final List<String> interests;
  final bool isVerified;
  final bool isPremium;
  final String? photoPath;

  static DiscoveryProfile fromRow(Map<String, dynamic> r) => DiscoveryProfile(
        id: (r['id'] ?? r['user_id']) as String,
        displayName: (r['display_name'] as String?) ?? '',
        age: (r['age'] as num?)?.toInt() ?? 18,
        city: r['city'] as String?,
        bio: r['bio'] as String?,
        horizon: r['marriage_horizon'] as String?,
        profession: r['profession'] as String?,
        languages: List<String>.from(r['languages'] as List? ?? const <String>[]),
        interests: List<String>.from(r['interests'] as List? ?? const <String>[]),
        isVerified: r['is_verified'] != false,
        isPremium: r['is_premium'] == true,
        photoPath: r['photo_path'] as String?,
      );
}

/// Photo d'un profil consulté. Ce que le visiteur peut voir est décidé par le serveur (migration 0009, photo_access) :
/// l'original n'est envoyé que si `access == original` ; sinon, au mieux, une version floutée fabriquée par le serveur.
class ProfilePhoto {
  const ProfilePhoto({required this.id, required this.visibility, required this.access, this.path, this.blurPath});
  final String id;
  final String visibility; // choix du propriétaire : public | blurred | private
  final String access; // pour le visiteur : original | blurred | none
  final String? path; // original, seulement si access == original
  final String? blurPath; // version floutée, seulement si access == blurred (nulle tant qu'elle n'est pas fabriquée)

  bool get isBlurred => access == 'blurred';
  bool get isHidden => access == 'none';

  /// Floutée par choix de sa propriétaire : Premium ne la rend pas nette (addendum V6.4 §2.2).
  bool get blurredByOwner => visibility == 'blurred';
}

/// Fiche complète d'un profil, limitée à ce que son propriétaire a choisi de montrer.
class ProfileDetail {
  const ProfileDetail({
    required this.base,
    this.maritalStatus,
    this.childrenCount,
    this.education,
    this.heightCm,
    this.confession,
    this.ethnicGroup,
    this.isPhoneVerified = false,
    this.matched = false,
    this.photos = const <ProfilePhoto>[],
  });

  final DiscoveryProfile base;
  final String? maritalStatus;
  final int? childrenCount;
  final String? education;
  final int? heightCm;
  final String? confession;
  final String? ethnicGroup;
  final bool isPhoneVerified;
  final bool matched;
  final List<ProfilePhoto> photos;

  /// Photos privées, ni nettes ni floutées pour ce visiteur.
  int get hiddenPhotoCount => photos.where((p) => p.isHidden).length;

  static ProfileDetail fromJson(Map<String, dynamic> j) {
    final photos = <ProfilePhoto>[
      for (final raw in (j['photos'] as List? ?? const <dynamic>[]))
        ProfilePhoto(
          id: (raw as Map)['id'] as String,
          visibility: raw['visibility'] as String,
          // Serveur antérieur à 0009 : pas de champ access, déduit du chemin.
          access: raw['access'] as String? ?? (raw['path'] != null ? 'original' : 'none'),
          path: raw['path'] as String?,
          blurPath: raw['blur_path'] as String?,
        ),
    ];
    String? mainPath;
    for (final p in photos) {
      if (p.path != null) {
        mainPath = p.path;
        break;
      }
    }
    return ProfileDetail(
      base: DiscoveryProfile(
        id: j['id'] as String,
        displayName: (j['display_name'] as String?) ?? '',
        age: (j['age'] as num?)?.toInt() ?? 18,
        city: j['city'] as String?,
        bio: j['bio'] as String?,
        horizon: j['marriage_horizon'] as String?,
        profession: j['profession'] as String?,
        languages: List<String>.from(j['languages'] as List? ?? const <String>[]),
        interests: List<String>.from(j['interests'] as List? ?? const <String>[]),
        isVerified: j['is_verified'] == true,
        isPremium: j['is_premium'] == true,
        photoPath: mainPath,
      ),
      maritalStatus: j['marital_status'] as String?,
      childrenCount: (j['children_count'] as num?)?.toInt(),
      education: j['education_level'] as String?,
      heightCm: (j['height_cm'] as num?)?.toInt(),
      confession: j['confession'] as String?,
      ethnicGroup: j['ethnic_group'] as String?,
      isPhoneVerified: j['is_phone_verified'] == true,
      matched: j['matched'] == true,
      photos: photos,
    );
  }
}

/// Points communs factuels entre mon profil et un autre (§31.4).
/// Chaque phrase provient de réponses réellement renseignées des deux côtés ; rien n'est inventé.
List<String> commonPoints(MyProfile me, DiscoveryProfile other) {
  final points = <String>[];
  if (me.horizon != null && me.horizon == other.horizon) {
    points.add(switch (me.horizon) {
      'soon' => 'Vous souhaitez tous deux vous marier bientôt',
      'few_months' => 'Vous envisagez tous deux le mariage dans les prochains mois',
      'medium_term' => 'Vous envisagez tous deux le mariage à moyen terme',
      _ => 'Vous n’avez tous deux pas fixé de date pour le mariage',
    });
  }
  final myCity = me.city;
  final theirCity = other.city;
  if (myCity != null && theirCity != null) {
    if (myCity == theirCity) {
      points.add('Vous habitez la même ville');
    } else if (myCity.startsWith('Conakry') && theirCity.startsWith('Conakry')) {
      points.add('Vous habitez tous deux à Conakry');
    }
  }
  final languages = me.languages.where(other.languages.contains).toList();
  if (languages.isNotEmpty) points.add('Vous parlez ${languages.join(', ')}');
  final interests = me.interests.where(other.interests.contains).toList();
  if (interests.isNotEmpty) points.add('Centres d’intérêt communs : ${interests.join(', ')}');
  return points;
}

class DiscoveryPrefs {
  DiscoveryPrefs({
    this.ageMin = 18,
    this.ageMax = 60,
    this.confessionMode = 'no_filter',
    List<String>? confessions,
    List<int>? cityIds,
    List<String>? languages,
    List<String>? horizons,
    List<String>? maritalStatuses,
    List<String>? educationKeys,
    this.childrenMax,
  })  : confessions = confessions ?? <String>[],
        cityIds = cityIds ?? <int>[],
        languages = languages ?? <String>[],
        horizons = horizons ?? <String>[],
        maritalStatuses = maritalStatuses ?? <String>[],
        educationKeys = educationKeys ?? <String>[];

  int ageMin;
  int ageMax;
  String confessionMode;
  List<String> confessions;

  /// Villes ou communes choisies (vide = toutes) ; filtre à sens unique (migration 0012).
  List<int> cityIds;

  // Filtres avancés, réservés à Premium (migration 0025) ; vide = tous. Le serveur ne les applique que pour un
  // membre Premium, et refuse qu'un membre Gratuit les définisse.

  /// Langues parlées : au moins une en commun.
  List<String> languages;

  /// Projets de mariage acceptés (clés de [horizonLabels]).
  List<String> horizons;

  /// Situations matrimoniales acceptées (clés de [maritalLabels]).
  List<String> maritalStatuses;

  /// Niveaux d'études acceptés (clés de education_levels, migration 0052).
  List<String> educationKeys;

  /// Nombre d'enfants au plus (null = peu importe ; 0 = sans enfant), migration 0052.
  int? childrenMax;

  bool get hasAdvancedFilters =>
      languages.isNotEmpty ||
      horizons.isNotEmpty ||
      maritalStatuses.isNotEmpty ||
      educationKeys.isNotEmpty ||
      childrenMax != null;

  /// Un réglage s'écarte des valeurs par défaut (point sur l'icône des filtres).
  bool get isFiltered {
    final d = DiscoveryPrefs();
    return ageMin != d.ageMin ||
        ageMax != d.ageMax ||
        !const {'no_filter', 'all'}.contains(confessionMode) ||
        cityIds.isNotEmpty ||
        hasAdvancedFilters;
  }
}

class BlockedUser {
  const BlockedUser({required this.userId, required this.displayName});
  final String userId;
  final String displayName;
}

enum LikeStatus { liked, matched, quotaReached, alreadyLiked }

class LikeResult {
  const LikeResult(this.status, {this.matchId, this.remaining, this.resetsAt});
  final LikeStatus status;
  final String? matchId;
  final int? remaining;
  final DateTime? resetsAt;
}

class LikeQuota {
  const LikeQuota({required this.limit, required this.remaining, required this.resetsAt});
  final int limit;
  final int remaining;
  final DateTime resetsAt;
}

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.userId,
    required this.displayName,
    this.photoPath,
    this.isVerified = false,
    this.lastMessage,
    this.lastAt,
    this.unread = 0,
  });
  final String matchId;
  final String userId;
  final String displayName;
  final String? photoPath;
  final bool isVerified;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;
}

/// Match terminé (CDC §32) : plus de nouveaux messages, historique relisible, signalement possible.
/// Ni photo ni profil ; nom absent si le compte est fermé.
class EndedMatch {
  const EndedMatch({
    required this.matchId,
    required this.userId,
    required this.displayName,
    required this.endedAt,
    required this.endedByMe,
    this.matchedAt,
    this.accountClosed = false,
  });

  final String matchId;
  final String userId;
  final String? displayName;
  final DateTime? matchedAt;
  final DateTime endedAt;
  final bool endedByMe;
  final bool accountClosed;

  static EndedMatch fromRow(Map<String, dynamic> r) => EndedMatch(
        matchId: r['match_id'] as String,
        userId: r['user_id'] as String,
        displayName: r['display_name'] as String?,
        matchedAt: r['matched_at'] == null ? null : DateTime.parse(r['matched_at'] as String),
        endedAt: DateTime.parse(r['ended_at'] as String),
        endedByMe: r['ended_by_me'] == true,
        accountClosed: r['account_closed'] == true,
      );
}

/// Document légal versionné (`legal_documents`) : conditions, confidentialité, règles communautaires.
class LegalDocument {
  const LegalDocument({
    required this.kind,
    required this.version,
    required this.lang,
    required this.content,
    required this.publishedAt,
  });

  final String kind; // tos | privacy | community
  final String version;
  final String lang;
  final String content;
  final DateTime publishedAt;

  /// Version provisoire (« v0… ») tant que les textes ne sont pas validés juridiquement (décision B1).
  bool get isDraft => version.toLowerCase().startsWith('v0');

  static LegalDocument fromRow(Map<String, dynamic> r) => LegalDocument(
        kind: r['kind'] as String,
        version: r['version'] as String,
        lang: r['lang'] as String? ?? 'fr',
        content: r['content'] as String,
        publishedAt: DateTime.parse(r['published_at'] as String),
      );
}

/// Sujets d'une demande à l'assistance (mêmes valeurs que la contrainte serveur de `support_tickets`).
const supportCategories = <String>['account', 'verification', 'payment', 'safety', 'translation', 'bug', 'other'];

/// Demande à l'assistance et, le cas échéant, la réponse de l'équipe.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.message,
    required this.status,
    required this.createdAt,
    this.reply,
    this.repliedAt,
  });

  final String id;
  final String category;
  final String message;
  final String status; // open | in_progress | answered | closed
  final String? reply;
  final DateTime createdAt;
  final DateTime? repliedAt;

  static SupportTicket fromRow(Map<String, dynamic> r) => SupportTicket(
        id: r['id'] as String,
        category: r['category'] as String,
        message: r['message'] as String,
        status: r['status'] as String,
        reply: r['reply'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        repliedAt: r['replied_at'] == null ? null : DateTime.parse(r['replied_at'] as String),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.edited = false,
    this.unsent = false,
  });
  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool edited;
  final bool unsent;
}

/// Résultat d'un envoi : `blockedCategory` non nul = message refusé par le filtre avant transmission.
class SendResult {
  const SendResult.sent()
      : blockedCategory = null,
        activeLimit = null;
  const SendResult.blocked(String category)
      : blockedCategory = category,
        activeLimit = null;

  /// Premier message refusé : toutes les places de conversation sont prises (migration 0040).
  const SendResult.activeLimit(int limit)
      : blockedCategory = null,
        activeLimit = limit;
  final String? blockedCategory;
  final int? activeLimit;
  bool get isBlocked => blockedCategory != null;
  bool get isActiveLimit => activeLimit != null;
}

/// Demande de re-match reçue après la fin d'un match (migration 0040).
class RematchRequest {
  const RematchRequest({required this.matchId, required this.userId, required this.displayName, this.photoPath});
  final String matchId;
  final String userId;
  final String displayName;
  final String? photoPath;
}

class PremiumGrant {
  const PremiumGrant({
    required this.source,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });
  final String source; // purchase | admin_grant | partner
  final String status; // active | revoked | cancelled | pending
  final DateTime startsAt;
  final DateTime endsAt;

  bool get isActive {
    final now = DateTime.now();
    return status == 'active' && endsAt.isAfter(now) && !startsAt.isAfter(now);
  }

  String get statusLabel {
    if (status == 'revoked') return 'Retiré';
    if (status == 'cancelled') return 'Annulé';
    if (status == 'pending') return 'En attente';
    return endsAt.isAfter(DateTime.now()) ? 'Actif' : 'Expiré';
  }

  /// Un abonnement offert n'est jamais présenté comme un paiement (V6.4 §40.1).
  String get sourceLabel => switch (source) {
        'purchase' => 'Achat',
        'partner' => 'Avantage partenaire',
        _ => 'Offert par ZAYA',
      };
}

class PaymentTx {
  const PaymentTx({
    required this.reference,
    required this.service,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.createdAt,
  });
  final String reference;
  final String service;
  final num amount;
  final String currency;
  final String method;
  final String status;
  final DateTime createdAt;

  bool get isConfirmed => status == 'confirmed';

  String get statusLabel =>
      const <String, String>{
        'pending': 'En attente',
        'processing': 'En cours',
        'confirmed': 'Confirmé',
        'failed': 'Échoué',
        'cancelled': 'Annulé',
        'refunded': 'Remboursé',
        'partially_refunded': 'Partiellement remboursé',
        'disputed': 'Contesté',
      }[status] ??
      status;

  String get serviceLabel =>
      const <String, String>{
        'premium': 'Abonnement Premium',
        'boost': 'Boost de profil',
        'shop': 'ZAYA Shop',
        'event': 'ZAYA Event',
        'counsel': 'Conseil matrimonial',
      }[service] ??
      service;
}

const reportReasons = <String, String>{
  'money_request': 'Demande d’argent',
  'scam': 'Arnaque ou fraude',
  'harassment': 'Harcèlement ou insultes',
  'threat': 'Menaces ou chantage',
  'impersonation': 'Faux profil / usurpation',
  'sexual_content': 'Contenu sexuel ou nudité',
  'minor': 'Personne mineure',
  'other': 'Autre',
};

const blockedCategoryLabels = <String, String>{
  'money_request': 'les demandes d’argent',
  'credential_request': 'les demandes de code ou de mot de passe',
  'sexual_content': 'les contenus sexuels',
  'threat': 'les menaces',
  'contact_details': 'le partage de coordonnées (numéro, e-mail, lien de messagerie)',
};

String formatDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

String formatTime(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// « à l’instant », « il y a 5 min », « il y a 3 h », « hier », « il y a 4 j », puis la date.
String formatRelative(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 2) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return formatDate(time);
}

// ───────────────────────────── Communauté (CDC V2.3 §2, V6.0 §26)

const postKindLabels = <String, String>{
  'question': 'Question',
  'advice': 'Conseil',
  'experience': 'Expérience',
};

const communityNotifLabels = <String, String>{
  'all': 'Toutes les publications',
  'important': 'Annonces importantes',
  'events': 'Événements seulement',
  'none': 'Aucune',
};

class Community {
  const Community({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    this.icon = 'groups',
    this.memberCount = 0,
    this.joined = false,
    this.notifLevel,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final String icon;
  final int memberCount;
  final bool joined;
  final String? notifLevel;

  Community copyWith({bool? joined, int? memberCount, String? notifLevel}) => Community(
        id: id,
        slug: slug,
        name: name,
        description: description,
        icon: icon,
        memberCount: memberCount ?? this.memberCount,
        joined: joined ?? this.joined,
        notifLevel: notifLevel ?? this.notifLevel,
      );

  static Community fromRow(Map<String, dynamic> r) => Community(
        id: r['community_id'] as String,
        slug: r['slug'] as String,
        name: r['name'] as String,
        description: (r['description'] as String?) ?? '',
        icon: (r['icon'] as String?) ?? 'groups',
        memberCount: (r['member_count'] as num?)?.toInt() ?? 0,
        joined: r['joined'] == true,
        notifLevel: r['notif_level'] as String?,
      );
}

/// Publication telle que la voit le membre connecté : l'auteur n'est identifié que par son nom
/// de profil et son badge vérifié (aucune photo, décision C15).
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.authorId,
    required this.authorName,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.authorVerified = false,
    this.commentsEnabled = true,
    this.edited = false,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.reacted = false,
    this.saved = false,
    this.isMine = false,
  });

  final String id;
  final String communityId;
  final String communityName;
  final String authorId;
  final String authorName;
  final bool authorVerified;
  final String kind;
  final String body;
  final bool commentsEnabled;
  final DateTime createdAt;
  final bool edited;
  final int reactionCount;
  final int commentCount;
  final bool reacted;
  final bool saved;
  final bool isMine;

  CommunityPost copyWith({
    String? body,
    bool? edited,
    bool? commentsEnabled,
    int? reactionCount,
    int? commentCount,
    bool? reacted,
    bool? saved,
  }) =>
      CommunityPost(
        id: id,
        communityId: communityId,
        communityName: communityName,
        authorId: authorId,
        authorName: authorName,
        authorVerified: authorVerified,
        kind: kind,
        body: body ?? this.body,
        commentsEnabled: commentsEnabled ?? this.commentsEnabled,
        createdAt: createdAt,
        edited: edited ?? this.edited,
        reactionCount: reactionCount ?? this.reactionCount,
        commentCount: commentCount ?? this.commentCount,
        reacted: reacted ?? this.reacted,
        saved: saved ?? this.saved,
        isMine: isMine,
      );

  static CommunityPost fromRow(Map<String, dynamic> r) => CommunityPost(
        id: r['post_id'] as String,
        communityId: r['community_id'] as String,
        communityName: (r['community_name'] as String?) ?? '',
        authorId: r['author_id'] as String,
        authorName: (r['author_name'] as String?) ?? 'Membre',
        authorVerified: r['author_verified'] == true,
        kind: (r['kind'] as String?) ?? 'question',
        body: (r['body'] as String?) ?? '',
        commentsEnabled: r['comments_enabled'] != false,
        createdAt: DateTime.parse(r['created_at'] as String),
        edited: r['edited'] == true,
        reactionCount: (r['reaction_count'] as num?)?.toInt() ?? 0,
        commentCount: (r['comment_count'] as num?)?.toInt() ?? 0,
        reacted: r['reacted'] == true,
        saved: r['saved'] == true,
        isMine: r['is_mine'] == true,
      );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorVerified = false,
    this.edited = false,
    this.isMine = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final bool authorVerified;
  final String body;
  final DateTime createdAt;
  final bool edited;
  final bool isMine;

  static PostComment fromRow(Map<String, dynamic> r) => PostComment(
        id: r['comment_id'] as String,
        authorId: r['author_id'] as String,
        authorName: (r['author_name'] as String?) ?? 'Membre',
        authorVerified: r['author_verified'] == true,
        body: (r['body'] as String?) ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
        edited: r['edited'] == true,
        isMine: r['is_mine'] == true,
      );
}

/// Résultat d'une publication ou d'un commentaire : `blockedCategory` non nul = refusé avant publication.
class PublishResult {
  const PublishResult.published(String this.id) : blockedCategory = null;
  const PublishResult.blocked(String category)
      : id = null,
        blockedCategory = category;

  final String? id;
  final String? blockedCategory;
  bool get isBlocked => blockedCategory != null;
}
