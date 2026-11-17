import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';

/// Backend réel. L'application n'utilise que la clé `anon` : toutes les règles
/// (quota, match réciproque, blocage, filtre des messages, Premium) sont appliquées par le serveur.
class SupabaseRepository implements ZayaRepository {
  SupabaseRepository(this._db);
  final SupabaseClient _db;

  @override
  bool get isDemo => false;
  @override
  bool get isSignedIn => _db.auth.currentUser != null;
  @override
  String? get userId => _db.auth.currentUser?.id;

  @override
  String? get phoneNumber {
    final phone = _db.auth.currentUser?.phone;
    return phone == null || phone.isEmpty ? null : phone;
  }

  /// La RLS ne renvoie que les clés publiques de `app_config`.
  @override
  Future<Map<String, Object?>> publicConfig() async {
    final rows = await _db.from('app_config').select('key, value');
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  String get _uid {
    final id = userId;
    if (id == null) throw Exception('Vous devez être connecté.');
    return id;
  }

  /// Appel sans attente du résultat (statistiques, marqueurs) : un échec ne doit pas gêner l'utilisateur.
  void _fireAndForget(String function, [Map<String, dynamic>? params]) {
    _db.rpc(function, params: params).then((_) {}, onError: (_) {});
  }

  List<String> _strings(Object? value) => List<String>.from(value as List? ?? const <String>[]);

  // ── Authentification
  @override
  Future<void> requestOtp(String phone) => _db.auth.signInWithOtp(phone: phone);

  @override
  Future<void> verifyOtp(String phone, String code) async {
    await _db.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  // ── Mon profil
  @override
  Future<List<City>> cities() async {
    final rows = await _db.from('cities').select('id, name').eq('country_code', 'GN').order('name');
    return [for (final r in rows) City((r['id'] as num).toInt(), r['name'] as String)];
  }

  @override
  Future<List<Country>> countries() async {
    final rows = await _db.from('countries').select('code, name_fr, name_en').order('name_fr');
    return [for (final r in rows) Country(r['code'] as String, r['name_fr'] as String, r['name_en'] as String)];
  }

  /// Seules les professions actives sont lisibles (RLS `professions_read`).
  @override
  Future<List<Profession>> professions() async {
    final rows = await _db.from('professions').select('id, label_fr, label_en').order('label_fr');
    return [
      for (final r in rows)
        Profession((r['id'] as num).toInt(), r['label_fr'] as String, labelEn: r['label_en'] as String?),
    ];
  }

  @override
  Future<MyProfile?> loadMyProfile() async {
    final uid = userId;
    if (uid == null) return null;
    final row = await _db.from('profiles').select('*, cities(name)').eq('id', uid).maybeSingle();
    if (row == null || row['display_name'] == null) return null;
    final premium = await _db.rpc('is_premium', params: {'p_user': uid});
    final photos = await _db.from('profile_photos').select('storage_path').eq('user_id', uid).order('position');
    final deletion =
        await _db.from('account_deletion_requests').select('scheduled_for').eq('user_id', uid).maybeSingle();
    _fireAndForget('touch_last_active');

    final birth = row['birth_date'] == null ? null : DateTime.parse(row['birth_date'] as String);
    final city = row['cities'];
    return MyProfile(
      id: uid,
      displayName: row['display_name'] as String,
      status: row['status'] as String,
      verificationStatus: row['verification_status'] as String,
      isPhoneVerified: row['is_phone_verified'] == true,
      isPremium: premium == true,
      age: birth == null ? null : ageFrom(birth),
      city: city is Map ? city['name'] as String? : null,
      bio: row['bio'] as String?,
      horizon: row['marriage_horizon'] as String?,
      maritalStatus: row['marital_status'] as String?,
      languages: _strings(row['languages']),
      interests: _strings(row['interests']),
      incognito: row['incognito'] == true,
      discreetBrowsing: row['discreet_browsing'] == true,
      showOnline: row['show_online'] != false,
      photoCount: photos.length,
      mainPhotoPath: photos.isEmpty ? null : photos.first['storage_path'] as String?,
      deletionScheduledFor: deletion == null ? null : DateTime.parse(deletion['scheduled_for'] as String),
      birthDate: birth,
      gender: row['gender'] as String?,
    );
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<void> saveOnboarding(OnboardingDraft d) async {
    final uid = _uid;
    final birth = d.birthDate;
    if (birth == null || !isAdult(birth)) throw Exception('ZAYA est réservé aux personnes de 18 ans et plus.');
    final bio = d.bio.trim();
    await _db.from('profiles').upsert({
      'id': uid,
      'display_name': d.displayName.trim(),
      'birth_date': _date(birth),
      'gender': d.gender,
      'seeking_gender': d.gender == 'femme' ? 'homme' : 'femme',
      'country_code': 'GN',
      'city_id': d.cityId,
      'marital_status': d.maritalStatus,
      'nationality_code': d.nationalityCode,
      'profession_id': d.professionId,
      'profession_other':
          d.professionId == null && d.professionOther.trim().isNotEmpty ? d.professionOther.trim() : null,
      'marriage_horizon': d.horizon,
      'bio': bio.isEmpty ? null : bio,
    });

    final docs = await _db.from('legal_documents').select('kind, version').order('published_at');
    final versions = <String, String>{for (final r in docs) r['kind'] as String: r['version'] as String};
    final consents = <Map<String, dynamic>>[
      for (final kind in const ['tos', 'privacy', 'community'])
        {'user_id': uid, 'kind': kind, 'document_version': versions[kind], 'granted': true},
      {'user_id': uid, 'kind': 'marketing', 'granted': d.marketingConsent},
    ];
    // La confession n'est enregistrée qu'avec un consentement explicite et distinct.
    final confession = d.confession;
    if (confession != null && confession != 'undisclosed' && d.confessionConsent) {
      consents.add({'user_id': uid, 'kind': 'religion_data', 'document_version': versions['privacy'], 'granted': true});
      await _db.from('profile_sensitive').upsert({'user_id': uid, 'confession': confession});
    }
    await _db.from('consents').insert(consents);
    await _db.from('discovery_preferences').upsert({
      'user_id': uid,
      'age_min': d.ageMin,
      'age_max': d.ageMax,
      'confession_mode': d.confessionMode,
      'confessions': d.selectedConfessions,
    });

    final res = Map<String, dynamic>.from(await _db.rpc('complete_onboarding') as Map);
    if (res['status'] == 'incomplete') {
      throw Exception('Inscription incomplète. Vérifiez les informations obligatoires puis réessayez.');
    }
  }

  @override
  Future<void> updateProfile({
    String? bio,
    String? horizon,
    String? maritalStatus,
    List<String>? languages,
    List<String>? interests,
  }) async {
    final patch = <String, dynamic>{
      if (bio != null) 'bio': bio.trim().isEmpty ? null : bio.trim(),
      if (horizon != null) 'marriage_horizon': horizon,
      if (maritalStatus != null) 'marital_status': maritalStatus,
      if (languages != null) 'languages': languages,
      if (interests != null) 'interests': interests,
    };
    if (patch.isNotEmpty) await _db.from('profiles').update(patch).eq('id', _uid);
  }

  @override
  Future<void> setProfileStatus(String status) async {
    await _db.from('profiles').update({'status': status}).eq('id', _uid);
  }

  @override
  Future<void> updatePrivacy({bool? incognito, bool? discreetBrowsing, bool? showOnline}) async {
    final patch = <String, dynamic>{
      if (incognito != null) 'incognito': incognito,
      if (discreetBrowsing != null) 'discreet_browsing': discreetBrowsing,
      if (showOnline != null) 'show_online': showOnline,
    };
    if (patch.isNotEmpty) await _db.from('profiles').update(patch).eq('id', _uid);
  }

  @override
  Future<void> addPhoto(Uint8List bytes) async {
    final uid = _uid;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from('profile-photos')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    final existing = await _db.from('profile_photos').select('id').eq('user_id', uid);
    final row = await _db
        .from('profile_photos')
        .insert({'user_id': uid, 'storage_path': path, 'position': existing.length})
        .select('id')
        .single();
    // Version floutée fabriquée par le serveur (fonction blur-photos), sans faire attendre le membre. Si l'appel
    // échoue, le rattrapage s'en charge ; d'ici là, les visiteurs concernés voient un emplacement neutre.
    unawaited(_db.functions.invoke('blur-photos', body: {'photo_id': row['id']}).then((_) {}, onError: (Object _) {}));
  }

  @override
  Future<String> requestVerification(Uint8List selfie) async {
    final uid = _uid;
    final path = '$uid/selfie-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from('verification')
        .uploadBinary(path, selfie, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    // Consentement biométrique explicite, recueilli à l'écran juste avant l'envoi du selfie.
    await _db.from('consents').insert({'user_id': uid, 'kind': 'biometric', 'granted': true});
    final res =
        Map<String, dynamic>.from(await _db.rpc('request_verification', params: {'p_selfie_path': path}) as Map);
    return res['status'] as String;
  }

  // URLs signées gardées en mémoire 50 minutes : une même photo n'est pas re-signée ni re-téléchargée
  // à chaque écran (économie de données).
  final Map<String, ({String url, DateTime expires})> _signedUrls = <String, ({String url, DateTime expires})>{};

  @override
  String? cachedPhotoUrl(String? path, {bool blurred = false}) {
    if (path == null) return null;
    final cached = _signedUrls['${blurred ? 'profile-photos-blur' : 'profile-photos'}/$path'];
    return cached != null && cached.expires.isAfter(DateTime.now()) ? cached.url : null;
  }

  @override
  Future<String?> photoUrl(String? path, {bool blurred = false}) async {
    if (path == null) return null;
    final cached = cachedPhotoUrl(path, blurred: blurred);
    if (cached != null) return cached;
    final bucket = blurred ? 'profile-photos-blur' : 'profile-photos';
    final key = '$bucket/$path';
    try {
      final url = await _db.storage.from(bucket).createSignedUrl(path, 3600);
      _signedUrls[key] = (url: url, expires: DateTime.now().add(const Duration(minutes: 50)));
      return url;
    } catch (_) {
      return null;
    }
  }

  // ── Préférences de découverte
  @override
  Future<DiscoveryPrefs> loadPreferences() async {
    final row = await _db.from('discovery_preferences').select().eq('user_id', _uid).maybeSingle();
    if (row == null) return DiscoveryPrefs();
    return DiscoveryPrefs(
      ageMin: (row['age_min'] as num).toInt(),
      ageMax: (row['age_max'] as num).toInt(),
      confessionMode: row['confession_mode'] as String,
      confessions: _strings(row['confessions']),
      cityIds: [for (final v in (row['city_ids'] as List? ?? const <dynamic>[])) (v as num).toInt()],
    );
  }

  @override
  Future<void> savePreferences(DiscoveryPrefs prefs) async {
    await _db.from('discovery_preferences').upsert({
      'user_id': _uid,
      'age_min': prefs.ageMin,
      'age_max': prefs.ageMax,
      'confession_mode': prefs.confessionMode,
      'confessions': prefs.confessions,
      'city_ids': prefs.cityIds,
    });
  }

  // ── Découverte, likes, matchs
  @override
  Future<List<DiscoveryProfile>> discoveryFeed() async {
    final rows = await _db.rpc('discovery_feed', params: {'p_limit': 30}) as List;
    return [for (final r in rows) DiscoveryProfile.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<ProfileDetail> profileDetail(String userId) async {
    final json = Map<String, dynamic>.from(await _db.rpc('get_profile', params: {'p_id': userId}) as Map);
    _fireAndForget('record_profile_view', {'p_target': userId});
    return ProfileDetail.fromJson(json);
  }

  @override
  Future<LikeResult> like(String userId) async {
    final r = Map<String, dynamic>.from(await _db.rpc('send_like', params: {'p_target': userId}) as Map);
    switch (r['status']) {
      case 'matched':
        return LikeResult(LikeStatus.matched, matchId: r['match_id'] as String);
      case 'quota_reached':
        return LikeResult(LikeStatus.quotaReached, resetsAt: DateTime.parse(r['resets_at'] as String));
      case 'already_liked':
        return const LikeResult(LikeStatus.alreadyLiked);
      default:
        return LikeResult(LikeStatus.liked, remaining: (r['remaining'] as num?)?.toInt());
    }
  }

  @override
  Future<void> pass(String userId) async {
    await _db.rpc('pass_profile', params: {'p_target': userId});
  }

  @override
  Future<LikeQuota> likeQuota() async {
    final r = Map<String, dynamic>.from(await _db.rpc('my_like_quota') as Map);
    return LikeQuota(
      limit: (r['limit'] as num).toInt(),
      remaining: (r['remaining'] as num).toInt(),
      resetsAt: DateTime.parse(r['resets_at'] as String),
    );
  }

  @override
  Future<int> receivedInterestsCount() async => ((await _db.rpc('received_interests_count')) as num).toInt();

  @override
  Future<List<DiscoveryProfile>> receivedInterests() async {
    final rows = await _db.rpc('received_interests') as List;
    return [for (final r in rows) DiscoveryProfile.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  @override
  Future<List<MatchSummary>> matches() async {
    final rows = await _db.rpc('my_matches') as List;
    final result = <MatchSummary>[];
    for (final raw in rows) {
      final r = Map<String, dynamic>.from(raw as Map);
      result.add(MatchSummary(
        matchId: r['match_id'] as String,
        userId: r['user_id'] as String,
        displayName: (r['display_name'] as String?) ?? '',
        photoPath: r['photo_path'] as String?,
        isVerified: r['is_verified'] == true,
        lastMessage: r['last_message'] as String?,
        lastAt: r['last_at'] == null ? null : DateTime.parse(r['last_at'] as String),
        unread: (r['unread'] as num?)?.toInt() ?? 0,
      ));
    }
    return result;
  }

  @override
  Future<void> unmatch(String matchId) async {
    await _db.rpc('unmatch', params: {'p_match': matchId});
  }

  @override
  Future<List<EndedMatch>> endedMatches() async {
    final rows = await _db.rpc('my_ended_matches') as List;
    return [for (final r in rows) EndedMatch.fromRow(Map<String, dynamic>.from(r as Map))];
  }

  // ── Assistance et documents légaux
  @override
  Future<List<LegalDocument>> legalDocuments() async {
    final rows = await _db
        .from('legal_documents')
        .select('kind, version, lang, content, published_at')
        .order('published_at', ascending: false);
    return [for (final r in rows) LegalDocument.fromRow(r)];
  }

  @override
  Future<void> createSupportTicket({required String category, required String message, String? language}) async {
    await _db
        .rpc('create_support_ticket', params: {'p_category': category, 'p_message': message, 'p_language': language});
  }

  @override
  Future<List<SupportTicket>> mySupportTickets() async {
    final rows = await _db
        .from('support_tickets')
        .select('id, category, message, status, reply, created_at, replied_at')
        .order('created_at', ascending: false);
    return [for (final r in rows) SupportTicket.fromRow(r)];
  }

  // ── Messagerie
  @override
  Stream<List<ChatMessage>> watchMessages(String matchId) {
    _fireAndForget('mark_conversation_read', {'p_match': matchId});
    return _db.from('messages').stream(primaryKey: ['id']).eq('match_id', matchId).order('created_at').map(
          (rows) => [
            for (final r in rows)
              ChatMessage(
                id: r['id'] as String,
                senderId: r['sender_id'] as String,
                body: (r['body'] as String?) ?? '',
                createdAt: DateTime.parse(r['created_at'] as String),
                edited: r['edited_at'] != null,
                unsent: r['unsent_at'] != null,
              ),
          ],
        );
  }

  @override
  Future<SendResult> sendMessage(String matchId, String body) async {
    final r =
        Map<String, dynamic>.from(await _db.rpc('send_message', params: {'p_match': matchId, 'p_body': body}) as Map);
    return r['status'] == 'blocked' ? SendResult.blocked(r['category'] as String) : const SendResult.sent();
  }

  @override
  Future<SendResult> editMessage(String messageId, String body) async {
    final r = Map<String, dynamic>.from(
        await _db.rpc('edit_message', params: {'p_message': messageId, 'p_body': body}) as Map);
    return r['status'] == 'blocked' ? SendResult.blocked(r['category'] as String) : const SendResult.sent();
  }

  @override
  Future<void> unsendMessage(String messageId) async {
    await _db.rpc('unsend_message', params: {'p_message': messageId});
  }

  @override
  Future<void> hideMessage(String messageId) async {
    await _db.rpc('hide_message', params: {'p_message': messageId});
  }

  // ── Sécurité
  @override
  Future<void> block(String userId) async {
    await _db.rpc('block_user', params: {'p_target': userId});
  }

  @override
  Future<void> unblock(String userId) async {
    await _db.rpc('unblock_user', params: {'p_target': userId});
  }

  @override
  Future<List<BlockedUser>> blockedUsers() async {
    final rows = await _db.rpc('my_blocked_users') as List;
    return [
      for (final r in rows)
        BlockedUser(
          userId: (r as Map)['user_id'] as String,
          displayName: (r['display_name'] as String?) ?? 'Membre',
        ),
    ];
  }

  @override
  Future<void> report(String userId,
      {required String context, required String reason, String? details, String? matchId}) async {
    await _db.rpc('report_user', params: {
      'p_target': userId,
      'p_context': context,
      'p_reason': reason,
      'p_details': details,
      'p_match': matchId,
    });
  }

  // ── Données personnelles
  @override
  Future<DateTime> requestAccountDeletion() async {
    final r = Map<String, dynamic>.from(await _db.rpc('request_account_deletion') as Map);
    return DateTime.parse(r['scheduled_for'] as String);
  }

  @override
  Future<void> cancelAccountDeletion() async {
    await _db.rpc('cancel_account_deletion');
  }

  @override
  Future<String> exportMyData() async {
    final data = await _db.rpc('export_my_data');
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ── Premium & paiements
  @override
  Future<List<PremiumGrant>> premiumHistory() async {
    final rows = await _db.from('premium_grants').select().eq('user_id', _uid).order('starts_at', ascending: false);
    return [
      for (final r in rows)
        PremiumGrant(
          source: r['source'] as String,
          status: r['status'] as String,
          startsAt: DateTime.parse(r['starts_at'] as String),
          endsAt: DateTime.parse(r['ends_at'] as String),
        ),
    ];
  }

  @override
  Future<List<PaymentTx>> payments() async {
    final rows = await _db.from('transactions').select().eq('user_id', _uid).order('created_at', ascending: false);
    return [
      for (final r in rows)
        PaymentTx(
          reference: r['reference'] as String,
          service: r['service'] as String,
          amount: r['amount'] as num,
          currency: r['currency'] as String,
          method: r['method'] as String,
          status: r['status'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  // ── Communauté : uniquement des fonctions serveur (aucune lecture directe des publications)
  List<Map<String, dynamic>> _rows(Object? result) =>
      [for (final r in (result as List? ?? const <dynamic>[])) Map<String, dynamic>.from(r as Map)];

  PublishResult _publishResult(Object? result) {
    final r = Map<String, dynamic>.from(result as Map);
    return r['status'] == 'blocked'
        ? PublishResult.blocked(r['category'] as String)
        : PublishResult.published(r['id'] as String);
  }

  @override
  Future<List<Community>> communities() async =>
      _rows(await _db.rpc('list_communities')).map(Community.fromRow).toList();

  @override
  Future<void> joinCommunity(String communityId) async {
    await _db.rpc('join_community', params: {'p_community': communityId});
  }

  @override
  Future<void> leaveCommunity(String communityId) async {
    await _db.rpc('leave_community', params: {'p_community': communityId});
  }

  @override
  Future<void> setCommunityNotifications(String communityId, String level) async {
    await _db.rpc('set_community_notifications', params: {'p_community': communityId, 'p_level': level});
  }

  @override
  Future<List<CommunityPost>> communityFeed({String? communityId, DateTime? before}) async {
    final result = await _db.rpc('community_feed', params: {
      'p_community': communityId,
      'p_before': before?.toUtc().toIso8601String(),
      'p_limit': 20,
    });
    return _rows(result).map(CommunityPost.fromRow).toList();
  }

  @override
  Future<CommunityPost> communityPost(String postId) async {
    final rows = _rows(await _db.rpc('community_post', params: {'p_post': postId}));
    if (rows.isEmpty) throw Exception('POST_NOT_FOUND');
    return CommunityPost.fromRow(rows.first);
  }

  @override
  Future<List<CommunityPost>> savedPosts() async =>
      _rows(await _db.rpc('saved_community_posts')).map(CommunityPost.fromRow).toList();

  @override
  Future<PublishResult> createPost({required String communityId, required String kind, required String body}) async =>
      _publishResult(
          await _db.rpc('create_post', params: {'p_community': communityId, 'p_kind': kind, 'p_body': body}));

  @override
  Future<PublishResult> editPost(String postId, String body) async =>
      _publishResult(await _db.rpc('edit_post', params: {'p_post': postId, 'p_body': body}));

  @override
  Future<void> deletePost(String postId) async {
    await _db.rpc('delete_post', params: {'p_post': postId});
  }

  @override
  Future<void> setPostComments(String postId, bool enabled) async {
    await _db.rpc('set_post_comments', params: {'p_post': postId, 'p_enabled': enabled});
  }

  @override
  Future<int> reactToPost(String postId, bool on) async =>
      ((await _db.rpc('react_to_post', params: {'p_post': postId, 'p_on': on})) as num).toInt();

  @override
  Future<void> savePost(String postId, bool saved) async {
    await _db.rpc('save_post', params: {'p_post': postId, 'p_on': saved});
  }

  @override
  Future<void> hidePost(String postId) async {
    await _db.rpc('hide_post', params: {'p_post': postId});
  }

  @override
  Future<List<PostComment>> postComments(String postId) async =>
      _rows(await _db.rpc('post_comments', params: {'p_post': postId})).map(PostComment.fromRow).toList();

  @override
  Future<PublishResult> addComment(String postId, String body) async =>
      _publishResult(await _db.rpc('add_comment', params: {'p_post': postId, 'p_body': body}));

  @override
  Future<PublishResult> editComment(String commentId, String body) async =>
      _publishResult(await _db.rpc('edit_comment', params: {'p_comment': commentId, 'p_body': body}));

  @override
  Future<void> deleteComment(String commentId) async {
    await _db.rpc('delete_comment', params: {'p_comment': commentId});
  }

  @override
  Future<void> reportPost(String postId, {required String reason, String? details}) async {
    await _db.rpc('report_post', params: {'p_post': postId, 'p_reason': reason, 'p_details': details});
  }

  @override
  Future<void> reportComment(String commentId, {required String reason, String? details}) async {
    await _db.rpc('report_comment', params: {'p_comment': commentId, 'p_reason': reason, 'p_details': details});
  }
}
