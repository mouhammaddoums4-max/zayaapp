import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import 'ad_settings.dart';

/// Initialisation du SDK Google, une seule fois pour toute l'application.
Future<void>? _sdk;
Future<void> ensureMobileAds() => _sdk ??= MobileAds.instance.initialize().then((_) {});

/// Bannière Google (format 300 × 250) dans une carte marquée « Publicité ». Ne prend aucune place tant qu'aucune
/// annonce n'est chargée, ni en cas d'échec : le membre ne voit jamais de cadre vide.
class GoogleBanner extends StatefulWidget {
  const GoogleBanner({super.key, required this.unitId, this.nonPersonalized = true, this.padding = EdgeInsets.zero});
  final String unitId;
  final bool nonPersonalized;
  final EdgeInsetsGeometry padding;

  @override
  State<GoogleBanner> createState() => _GoogleBannerState();
}

class _GoogleBannerState extends State<GoogleBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await ensureMobileAds();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: widget.unitId,
      size: AdSize.mediumRectangle,
      request: AdRequest(nonPersonalizedAds: widget.nonPersonalized),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: AdFrame(
        child: SizedBox(
          width: AdSize.mediumRectangle.width.toDouble(),
          height: AdSize.mediumRectangle.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}

/// Cadre commun des annonces Google : marqué « Publicité », distinct des profils et des publications.
class AdFrame extends StatelessWidget {
  const AdFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: context.s.adLabel,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZColors.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.adLabel,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: ZColors.muted)),
            const SizedBox(height: 6),
            Center(child: child),
          ]),
        ),
      );
}

/// Règle de rythme des interstitiels : après N swipes, et jamais deux fois en moins de M minutes.
class InterstitialRule {
  const InterstitialRule({required this.everySwipes, required this.minMinutes});
  final int everySwipes;
  final int minMinutes;

  bool shouldShow({required int swipesSinceLast, required DateTime? lastShown, required DateTime now}) {
    if (everySwipes <= 0 || swipesSinceLast < everySwipes) return false;
    return lastShown == null || now.difference(lastShown) >= Duration(minutes: minMinutes);
  }
}

/// Interstitiels Google entre deux séries de swipes. Jamais pendant une conversation ni juste après un match :
/// l'écran Découvrir n'appelle [onSwipe] que pour un swipe ordinaire. Ne bloque jamais le swipe.
class InterstitialPacer {
  InterstitialPacer._();
  static final InterstitialPacer instance = InterstitialPacer._();

  int _swipes = 0;
  DateTime? _lastShown;
  InterstitialAd? _ready;
  bool _loading = false;

  void onSwipe(ZayaRepository repo) => unawaited(_onSwipe(repo));

  Future<void> _onSwipe(ZayaRepository repo) async {
    final s = await AdSettings.load(repo);
    if (!s.interstitialEnabled) return;
    _swipes++;
    final rule = InterstitialRule(everySwipes: s.interstitialEverySwipes, minMinutes: s.interstitialMinMinutes);
    if (!rule.shouldShow(swipesSinceLast: _swipes, lastShown: _lastShown, now: DateTime.now())) {
      // Préparée à l'avance, pour s'afficher sans attente le moment venu.
      if (_swipes >= s.interstitialEverySwipes - 2) _preload(s);
      return;
    }
    final ad = _ready;
    if (ad == null) {
      _preload(s);
      return;
    }
    _ready = null;
    _swipes = 0;
    _lastShown = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    await ad.show();
  }

  Future<void> _preload(AdSettings s) async {
    if (_ready != null || _loading) return;
    _loading = true;
    try {
      await ensureMobileAds();
      await InterstitialAd.load(
        adUnitId: s.interstitialUnit,
        request: AdRequest(nonPersonalizedAds: s.nonPersonalized),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ready = ad;
            _loading = false;
          },
          onAdFailedToLoad: (_) => _loading = false,
        ),
      );
    } catch (_) {
      _loading = false;
    }
  }
}
