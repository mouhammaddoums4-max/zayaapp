import 'dart:typed_data';

import 'models.dart';

/// Contrat d'accès aux données. Deux implémentations :
/// - `DemoRepository` : données fictives en mémoire (développement, démonstration) ;
/// - `SupabaseRepository` : backend réel (toutes les règles sont appliquées côté serveur).
abstract class ZayaRepository {
  bool get isDemo;
  bool get isSignedIn;
  String? get userId;

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
  Future<String?> photoUrl(String? path);

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

  // ── Premium & paiements (lecture seule dans ce lot)
  Future<List<PremiumGrant>> premiumHistory();
  Future<List<PaymentTx>> payments();
}
