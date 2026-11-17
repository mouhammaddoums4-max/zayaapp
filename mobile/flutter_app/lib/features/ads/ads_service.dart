import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repository.dart';

/// Campagne directe à afficher (régie publicitaire, migration 0015). Toujours présentée comme « Sponsorisé ».
class SponsoredAd {
  const SponsoredAd({
    required this.campaignId,
    required this.advertiserName,
    required this.headline,
    this.body,
    this.ctaLabel,
    this.destinationUrl,
    this.logoUrl,
    this.mediaUrl,
    this.mediaType,
  });

  final String campaignId;
  final String advertiserName;
  final String headline;
  final String? body;
  final String? ctaLabel;
  final String? destinationUrl;
  final String? logoUrl;
  final String? mediaUrl;
  final String? mediaType; // image | video

  bool get hasImage => mediaUrl != null && mediaType == 'image';
}

/// Accès à la régie, séparé du dépôt principal. Les règles (dates, plafonds, emplacements, Premium, activation) sont
/// toutes appliquées par le serveur : l'application se contente d'afficher et de signaler affichages et clics réels.
abstract class AdsService {
  Future<List<SponsoredAd>> sponsored(String placement, {int limit = 1});
  Future<void> recordImpression(String campaignId, String placement);

  /// Vrai si le clic a été compté (un seul par jour, après un affichage réel).
  Future<bool> recordClick(String campaignId, String placement);

  /// Service adapté au dépôt : aucune publicité en mode démo.
  static AdsService forRepository(ZayaRepository repo) =>
      repo.isDemo ? const NoAdsService() : SupabaseAdsService(Supabase.instance.client);
}

class NoAdsService implements AdsService {
  const NoAdsService();

  @override
  Future<List<SponsoredAd>> sponsored(String placement, {int limit = 1}) async => const <SponsoredAd>[];
  @override
  Future<void> recordImpression(String campaignId, String placement) async {}
  @override
  Future<bool> recordClick(String campaignId, String placement) async => false;
}

class SupabaseAdsService implements AdsService {
  SupabaseAdsService(this._db);
  final SupabaseClient _db;

  String? _publicUrl(Object? path) {
    final p = (path ?? '').toString();
    return p.isEmpty ? null : _db.storage.from('ad-media').getPublicUrl(p);
  }

  @override
  Future<List<SponsoredAd>> sponsored(String placement, {int limit = 1}) async {
    final rows = await _db.rpc('sponsored_ads', params: {'p_placement': placement, 'p_limit': limit}) as List;
    return [
      for (final raw in rows)
        () {
          final r = Map<String, dynamic>.from(raw as Map);
          return SponsoredAd(
            campaignId: r['campaign_id'] as String,
            advertiserName: r['advertiser_name'] as String,
            headline: r['headline'] as String,
            body: r['body'] as String?,
            ctaLabel: r['cta_label'] as String?,
            destinationUrl: r['destination_url'] as String?,
            logoUrl: _publicUrl(r['logo_path']),
            mediaUrl: _publicUrl(r['media_path']),
            mediaType: r['media_type'] as String?,
          );
        }(),
    ];
  }

  @override
  Future<void> recordImpression(String campaignId, String placement) async {
    await _db
        .rpc('record_ad_event', params: {'p_campaign': campaignId, 'p_kind': 'impression', 'p_placement': placement});
  }

  @override
  Future<bool> recordClick(String campaignId, String placement) async =>
      await _db.rpc('record_ad_event', params: {'p_campaign': campaignId, 'p_kind': 'click', 'p_placement': placement})
          as bool? ??
      false;
}
