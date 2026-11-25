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

  // ── Connexion par numéro + code à 4 chiffres (0071) : plus de SMS à chaque connexion.
  /// État d'un numéro avant connexion : 'pin' (code défini), 'no_pin' (compte sans code), 'new' (aucun compte),
  /// 'disabled' ou 'rate_limited'.
  Future<String> phoneStatus(String phone);

  /// Connexion par numéro + code ; ouvre la session quand le code est bon.
  Future<PinLoginResult> signInWithPin(String phone, String pin);

  /// Mon code : défini ou non, et s'il doit être changé (code imposé).
  Future<({bool hasPin, bool mustChange})> myPinStatus();

  /// Premier code, après l'inscription vérifiée par SMS.
  Future<void> setPin(String pin);

  /// Changement : l'ancien code est exigé (PIN_WRONG sinon).
  Future<void> changePin(String oldPin, String newPin);

  /// Code oublié : permis seulement juste après une vérification par SMS (OTP_REQUIRED sinon).
  Future<void> resetPin(String newPin);
  Future<void> signOut();

  // ── Mon profil
  Future<List<City>> cities();

  /// Référentiels publics (lisibles avant la connexion) : pays et catalogue des professions.
  Future<List<Country>> countries();
  Future<List<Profession>> professions();

  /// Niveaux d'études proposés (liste tenue par l'administration, migration 0052), dans l'ordre d'affichage.
  Future<List<EducationLevel>> educationLevels();
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

  /// Mes photos, dans l'ordre (la première est la principale), avec leur état de modération.
  Future<List<MyPhoto>> myPhotos();

  /// Supprime une de mes photos ; les suivantes remontent d'un rang (la RLS limite à mes propres photos).
  Future<void> deleteMyPhoto(String photoId);

  /// Fait de cette photo ma photo principale (premier rang).
  Future<void> setMainPhoto(String photoId);

  /// Retourne `pending` si la demande est enregistrée, `not_enough_photos` sinon.
  Future<String> requestVerification(Uint8List selfie);

  /// URL temporaire d'une photo ; `blurred` : version floutée fabriquée par le serveur (bucket profile-photos-blur).
  Future<String?> photoUrl(String? path, {bool blurred = false});

  /// URL déjà signée et encore valide, sans appel réseau (sinon `null`). Permet d'afficher une photo
  /// dès la première image d'un écran ou d'une animation, au lieu d'un fond provisoire qui clignote.
  String? cachedPhotoUrl(String? path, {bool blurred = false});

  // ── Préférences de découverte
  Future<DiscoveryPrefs> loadPreferences();
  Future<void> savePreferences(DiscoveryPrefs prefs);

  // ── Découverte, likes, matchs
  Future<List<DiscoveryProfile>> discoveryFeed();

  /// Fiche d'un profil. [recordView] à `false` pour un préchargement (carte suivante de Découvrir) : la visite
  /// n'est alors comptée qu'avec [recordProfileView], si le membre regarde vraiment la fiche.
  Future<ProfileDetail> profileDetail(String userId, {bool recordView = true});
  Future<LikeResult> like(String userId);
  Future<void> pass(String userId);

  /// Fait revenir le dernier profil passé (0016 : Gratuit, le dernier ; Premium, plusieurs) ; `null` s'il n'y en a pas.
  Future<DiscoveryProfile?> rewindLastPass();

  /// Compte une visite du profil (statistiques « Visites du profil »), quand le membre regarde vraiment sa fiche.
  Future<void> recordProfileView(String userId);
  Future<LikeQuota> likeQuota();
  Future<int> receivedInterestsCount();

  /// Liste nominative des personnes qui ont aimé mon profil — avantage Premium (échoue sinon).
  Future<List<DiscoveryProfile>> receivedInterests();

  /// Profils que j'ai aimés et qui n'ont pas encore répondu — gratuit pour tous (migration 0024).
  Future<List<DiscoveryProfile>> sentInterests();
  Future<List<MatchSummary>> matches();
  Future<void> unmatch(String matchId);

  /// Matchs terminés, des deux côtés (rien après un blocage).
  Future<List<EndedMatch>> endedMatches();

  /// Signaux instantanés du membre connecté (migration 0055) : nature d'un événement qui change ce qu'il voit
  /// ('like', 'match', 'message', 'photo', 'premium', 'profile', 'visit', 'wallet'), jamais l'identité de
  /// l'auteur. Flux vide hors connexion.
  Stream<String> watchSignals();

  // ── Messagerie
  Stream<List<ChatMessage>> watchMessages(String matchId);
  Future<SendResult> sendMessage(String matchId, String body, {String? replyToId});

  /// ZAYA 2.0 (migrations 0067 à 0069) : Match du jour, Pulse, Invitation, Surprise, Défis, Questions.
  /// Seules les fonctions serveur connues sont appelables ; chaque règle est vérifiée côté serveur.
  Future<Object?> zayaRpc(String function, [Map<String, Object?> params = const <String, Object?>{}]);

  /// Fleur Premium (0070) : un « J'aime » mis en avant. Refusée sans Premium (PREMIUM_REQUIRED) ou au-delà de la
  /// limite du jour (FLOWER_LIMIT) ; un match se crée comme pour un « J'aime ».
  Future<LikeResult> sendFlower(String userId);

  /// Fleurs reçues : l'expéditeur s'est fait connaître en l'envoyant, elles sont visibles même sans Premium.
  Future<List<DiscoveryProfile>> receivedFlowers();

  /// Supprime des conversations pour moi seulement (0070) ; renvoie le nombre réellement supprimé.
  Future<int> hideConversations(List<String> matchIds);

  /// Matchs en ligne (0070), selon le réglage « en ligne » des deux personnes.
  Future<Set<String>> onlineMatches();

  /// Signale que je suis actif (présence « en ligne »), appelé régulièrement tant que l'application est ouverte.
  Future<void> touchActive();

  /// Réactions de la conversation (temps réel). Une seule par membre et par message.
  Stream<List<MessageReaction>> watchReactions(String matchId);

  /// Pose ou remplace ma réaction ; le même emoji une seconde fois la retire.
  Future<void> reactToMessage(String messageId, String emoji);
  Future<SendResult> sendVoiceMessage(String matchId, String localFilePath, int durationSeconds);
  Future<SendResult> sendAnimatedSticker(String matchId, String stickerId);
  Future<String?> voiceMessageUrl(String storagePath);

  /// Places de conversation : conversations actives et limite (« 3/5 », migration 0040).
  Future<({int active, int limit})> conversationSlots();

  /// Demandes de re-match reçues, en attente.
  Future<List<RematchRequest>> rematchRequests();

  /// État de la demande pour un match terminé : none | sent | received | accepted | declined.
  Future<String> rematchState(String matchId);

  /// Demande à reprendre un match terminé : pending | rematched | declined | accepted | active.
  Future<String> requestRematch(String matchId);

  /// Réponse à une demande reçue : rematched | declined.
  Future<String> respondRematch(String matchId, {required bool accept});

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

/// Filtre rapide du fil, appliqué par le serveur en mode connecté.
abstract interface class QuickDiscoveryRepository {
  Future<List<DiscoveryProfile>> discoveryFeedFiltered(String? filter);
}
