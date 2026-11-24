import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repository.dart';

/// Réglages publicitaires du membre connecté, décidés par le serveur (my_ad_settings, migration 0034) : activation des
/// campagnes directes et de Google, règle Premium, emplacements, rythme et identifiants des blocs AdMob.
/// Rien n'est codé en dur : l'équipe change tout depuis app_config, sans nouvelle version de l'application.
class AdSettings {
  const AdSettings({
    this.direct = false,
    this.admob = false,
    this.nonPersonalized = true,
    this.communityEvery = 0,
    this.exploreEvery = 0,
    this.bannerPlacements = const <String>{},
    this.bannerUnitAndroid = '',
    this.interstitialUnitAndroid = '',
    this.interstitialEverySwipes = 0,
    this.interstitialMinMinutes = 10,
  });

  factory AdSettings.fromJson(Map<String, dynamic> j) => AdSettings(
        direct: j['direct'] == true,
        admob: j['admob'] == true,
        nonPersonalized: j['non_personalized'] != false,
        communityEvery: (j['community_every'] as num?)?.toInt() ?? 0,
        exploreEvery: (j['explore_every'] as num?)?.toInt() ?? 0,
        bannerPlacements: {for (final p in (j['banner_placements'] as List? ?? const [])) p.toString()},
        bannerUnitAndroid: (j['banner_unit_android'] ?? '').toString(),
        interstitialUnitAndroid: (j['interstitial_unit_android'] ?? '').toString(),
        interstitialEverySwipes: (j['interstitial_every_swipes'] as num?)?.toInt() ?? 0,
        interstitialMinMinutes: (j['interstitial_min_minutes'] as num?)?.toInt() ?? 10,
      );

  /// Aucune publicité (mode démo, hors connexion, régie désactivée).
  static const disabled = AdSettings();

  final bool direct;
  final bool admob;
  final bool nonPersonalized;
  final int communityEvery;
  final int exploreEvery;
  final Set<String> bannerPlacements;
  final String bannerUnitAndroid;
  final String interstitialUnitAndroid;
  final int interstitialEverySwipes;
  final int interstitialMinMinutes;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Identifiant du bloc bannière pour cette plateforme ('' : aucun).
  String get bannerUnit => _android ? bannerUnitAndroid : '';
  String get interstitialUnit => _android ? interstitialUnitAndroid : '';

  /// Une bannière Google peut-elle apparaître à cet emplacement (explore | community | profile) ?
  bool bannerAllowed(String placement) => admob && bannerUnit.isNotEmpty && bannerPlacements.contains(placement);

  bool get interstitialEnabled => admob && interstitialUnit.isNotEmpty && interstitialEverySwipes > 0;

  /// Une carte publicitaire toutes les N publications ou cartes (0 : aucune).
  int everyFor(String feed) {
    if (!direct && !admob) return 0;
    return switch (feed) {
      'community_feed' => communityEvery,
      'explore' => exploreEvery,
      _ => 0,
    };
  }

  // ── Lecture, partagée par tous les écrans et renouvelée toutes les 10 minutes.
  static Future<AdSettings>? _pending;
  static DateTime? _readAt;

  static Future<AdSettings> load(ZayaRepository repo) {
    if (repo.isDemo) return Future.value(disabled);
    final fresh = _readAt != null && DateTime.now().difference(_readAt!) < const Duration(minutes: 10);
    if (_pending != null && fresh) return _pending!;
    _readAt = DateTime.now();
    return _pending = _fetch();
  }

  static Future<AdSettings> _fetch() async {
    try {
      final raw = await Supabase.instance.client.rpc('my_ad_settings');
      return AdSettings.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      _readAt = null; // nouvel essai à la prochaine lecture
      return disabled;
    }
  }

  /// À appeler après un changement de compte ou de formule (Premium) : relecture au prochain affichage.
  static void invalidate() {
    _pending = null;
    _readAt = null;
  }
}
