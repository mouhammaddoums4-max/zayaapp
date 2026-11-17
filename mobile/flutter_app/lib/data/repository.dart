import 'dart:typed_data';

import 'models.dart';

/// Contrat d'accès aux données. Deux implémentations :
/// - `DemoRepository` : données fictives en mémoire (développement, démonstration) ;
/// - `SupabaseRepository` : backend réel (toutes les règles sont appliquées côté serveur).
abstract class ZayaRepository {
  bool get isDemo;
  bool get isSignedIn;
  String? get userId;

  /// Numéro du membre connecté, montré à lui seul dans les Réglages.
  String? get phoneNumber;

  /// Réglages publics de l'application (`app_config` lisible par tous) : langues actives, WhatsApp du support…
  Future<Map<String, Object?>> publicConfig();

  // ── Authentification par téléphone + OTP
  Future<void> requestOtp(String phone);
  Future<void> verifyOtp(String phone, String code);
  Future<void> signOut();

  // ── Mon profil
  Future<List<City>> cities();
  Future<MyProfile?> loadMyProfile();
  Future<void> saveOnboarding(OnboardingDraft draft);
  Future<void> updateProfile({
    String? bio,
    String? horizon,
    String? maritalStatus,
    List<String>? languages,
    List<String>? interests,
  });
  Future<void> setProfileStatus(String status);
  Future<void> updatePrivacy({bool? incognito, bool? discreetBrowsing, bool? showOnline});
  Future<void> addPhoto(Uint8List bytes);

  /// Retourne `pending` si la demande est enregistrée, `not_enough_photos` sinon.
  Future<String> requestVerification(Uint8List selfie);
  /// URL temporaire d'une photo ; `blurred` : version floutée fabriquée par le serveur (bucket profile-photos-blur).
  Future<String?> photoUrl(String? path, {bool blurred = false});

  // ── Préférences de découverte
  Future<DiscoveryPrefs> loadPreferences();
  Future<void> savePreferences(DiscoveryPrefs prefs);

  // ── Découverte, likes, matchs
  Future<List<DiscoveryProfile>> discoveryFeed();
  Future<ProfileDetail> profileDetail(String userId);
  Future<LikeResult> like(String userId);
  Future<void> pass(String userId);
  Future<LikeQuota> likeQuota();
  Future<int> receivedInterestsCount();

  /// Liste nominative des personnes qui ont aimé mon profil — avantage Premium (échoue sinon).
  Future<List<DiscoveryProfile>> receivedInterests();
  Future<List<MatchSummary>> matches();
  Future<void> unmatch(String matchId);

  /// Matchs terminés, des deux côtés (rien après un blocage).
  Future<List<EndedMatch>> endedMatches();

  // ── Messagerie
  Stream<List<ChatMessage>> watchMessages(String matchId);
  Future<SendResult> sendMessage(String matchId, String body);

  /// Modifie un de mes messages (délai limité côté serveur) ; le nouveau texte repasse par le filtre.
  Future<SendResult> editMessage(String messageId, String body);
  Future<void> unsendMessage(String messageId);
  Future<void> hideMessage(String messageId);

  // ── Sécurité
  Future<void> block(String userId);
  Future<void> unblock(String userId);
  Future<List<BlockedUser>> blockedUsers();
  Future<void> report(String userId,
      {required String context, required String reason, String? details, String? matchId});

  // ── Données personnelles
  /// Demande la suppression du compte ; retourne la date d'effet (délai de rétractation).
  Future<DateTime> requestAccountDeletion();
  Future<void> cancelAccountDeletion();

  /// Export des données personnelles au format JSON.
  Future<String> exportMyData();

  // ── Assistance et documents légaux
  /// Toutes les versions publiées ; l'écran choisit la plus récente dans la langue du membre.
  Future<List<LegalDocument>> legalDocuments();

  /// Erreurs : MESSAGE_TOO_SHORT, INVALID_CATEGORY, SUPPORT_RATE_LIMITED.
  Future<void> createSupportTicket({required String category, required String message, String? language});
  Future<List<SupportTicket>> mySupportTickets();

  // ── Premium & paiements (lecture seule dans ce lot)
  Future<List<PremiumGrant>> premiumHistory();
  Future<List<PaymentTx>> payments();

  // ── Communauté (CDC V2.3 §2, V6.0 §26). Les erreurs serveur arrivent sous forme de code :
  // COMMUNITY_DISABLED, VERIFICATION_REQUIRED, RATE_LIMITED, COMMENTS_DISABLED, POST_NOT_FOUND…
  Future<List<Community>> communities();
  Future<void> joinCommunity(String communityId);
  Future<void> leaveCommunity(String communityId);
  Future<void> setCommunityNotifications(String communityId, String level);

  /// Une communauté, ou « Pour vous » si [communityId] est nul : les communautés suivies, toutes si aucune.
  Future<List<CommunityPost>> communityFeed({String? communityId, DateTime? before});
  Future<CommunityPost> communityPost(String postId);
  Future<List<CommunityPost>> savedPosts();
  Future<PublishResult> createPost({required String communityId, required String kind, required String body});
  Future<PublishResult> editPost(String postId, String body);
  Future<void> deletePost(String postId);
  Future<void> setPostComments(String postId, bool enabled);

  /// Ajoute ou retire ma réaction ; retourne le nouveau nombre de réactions.
  Future<int> reactToPost(String postId, bool on);
  Future<void> savePost(String postId, bool saved);
  Future<void> hidePost(String postId);
  Future<List<PostComment>> postComments(String postId);
  Future<PublishResult> addComment(String postId, String body);
  Future<PublishResult> editComment(String commentId, String body);
  Future<void> deleteComment(String commentId);

  /// Le contenu signalé disparaît aussitôt pour la personne qui signale.
  Future<void> reportPost(String postId, {required String reason, String? details});
  Future<void> reportComment(String commentId, {required String reason, String? details});
}
