import 'package:material_ui/material_ui.dart';

import '../../data/repository.dart';
import 'ad_settings.dart';
import 'ads_service.dart';
import 'sponsored_card.dart';

/// Publicités d'un fil (Communauté, Explorer) : une carte toutes les N publications, N fixé par le serveur.
/// Les campagnes directes passent d'abord (vendues par ZAYA, plafonnées par membre et par jour côté serveur) ;
/// les emplacements suivants reçoivent une bannière Google si elle est autorisée ; sinon, rien ne s'affiche.
class FeedAds extends ChangeNotifier {
  FeedAds({required this.feed, required this.ads, required Future<AdSettings> Function() settings, this.googleBuilder})
      : _readSettings = settings;

  factory FeedAds.forRepository(String feed, ZayaRepository repo) =>
      FeedAds(feed: feed, ads: AdsService.forRepository(repo), settings: () => AdSettings.load(repo));

  /// community_feed | explore (mêmes valeurs que les emplacements du serveur).
  final String feed;
  final AdsService ads;
  final GoogleBannerBuilder? googleBuilder;
  final Future<AdSettings> Function() _readSettings;

  AdSettings settings = AdSettings.disabled;
  List<SponsoredAd> direct = const <SponsoredAd>[];
  final Set<String> _counted = <String>{};
  bool _disposed = false;

  String get bannerPlacement => bannerPlacementFor(feed);

  Future<void> load() async {
    try {
      settings = await _readSettings();
      direct = settings.direct ? await ads.sponsored(feed, limit: 3) : const <SponsoredAd>[];
    } catch (_) {
      // Sans publicité, le fil reste intact.
    }
    if (!_disposed) notifyListeners();
  }

  /// Numéro de l'emplacement publicitaire placé juste après l'élément [index] du fil, ou null s'il n'y en a pas.
  int? slotAfter(int index) {
    final every = settings.everyFor(feed);
    if (every <= 0 || (index + 1) % every != 0) return null;
    final slot = (index + 1) ~/ every - 1;
    final hasContent = slot < direct.length || settings.bannerAllowed(bannerPlacement);
    return hasContent ? slot : null;
  }

  void countImpression(SponsoredAd ad) {
    if (!_counted.add(ad.campaignId)) return;
    ads.recordImpression(ad.campaignId, feed).then((_) {}, onError: (_) {});
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Emplacement n° [slot] d'un fil : campagne directe, sinon bannière Google.
class FeedAdSlot extends StatelessWidget {
  const FeedAdSlot({super.key, required this.ads, required this.slot, this.padding = EdgeInsets.zero});
  final FeedAds ads;
  final int slot;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (slot < ads.direct.length) {
      final ad = ads.direct[slot];
      return _Shown(
        onShown: () => ads.countImpression(ad),
        child: Padding(
          padding: padding,
          child: SponsoredCard(ad: ad, onOpen: () => openSponsored(ads.ads, ad, ads.feed)),
        ),
      );
    }
    if (ads.settings.bannerAllowed(ads.bannerPlacement)) {
      return Padding(
        padding: padding,
        child: (ads.googleBuilder ?? defaultGoogleBanner)(ads.settings, ads.bannerPlacement),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Signale l'affichage réel d'une carte, une fois, à sa première apparition.
class _Shown extends StatefulWidget {
  const _Shown({required this.onShown, required this.child});
  final VoidCallback onShown;
  final Widget child;

  @override
  State<_Shown> createState() => _ShownState();
}

class _ShownState extends State<_Shown> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
