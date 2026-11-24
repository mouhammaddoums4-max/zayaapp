import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import 'ad_settings.dart';
import 'ads_service.dart';
import 'google_ads.dart';

/// Construit la bannière Google de repli (remplaçable dans les tests, où le SDK Google n'existe pas).
typedef GoogleBannerBuilder = Widget Function(AdSettings settings, String placement);

Widget defaultGoogleBanner(AdSettings settings, String placement) =>
    GoogleBanner(unitId: settings.bannerUnit, nonPersonalized: settings.nonPersonalized);

/// Emplacement de bannière Google correspondant à un emplacement de campagne directe.
String bannerPlacementFor(String placement) => placement == 'community_feed' ? 'community' : placement;

/// Ouvre la destination d'une campagne, après une action volontaire du membre ; le serveur ne compte qu'un clic par
/// jour, après un affichage réel.
Future<void> openSponsored(AdsService ads, SponsoredAd ad, String placement) async {
  final url = ad.destinationUrl;
  if (url == null || url.isEmpty) return;
  ads.recordClick(ad.campaignId, placement).then((_) {}, onError: (_) {});
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Emplacement publicitaire : une campagne directe pour [placement] en priorité (vendue par ZAYA), sinon une bannière
/// Google si le serveur l'autorise à cet endroit ; aucune place prise s'il n'y a ni l'une ni l'autre. Jamais utilisé
/// dans les conversations.
class SponsoredSlot extends StatefulWidget {
  const SponsoredSlot({
    super.key,
    required this.placement,
    this.service,
    this.settings,
    this.googleBuilder,
    this.padding = EdgeInsets.zero,
  });

  /// community_feed | explore | profile (mêmes valeurs que le serveur).
  final String placement;

  /// Pour les tests ; sinon, service déduit du dépôt de la session.
  final AdsService? service;

  /// Réglages publicitaires (tests) ; sinon lus sur le serveur (my_ad_settings).
  final Future<AdSettings> Function()? settings;
  final GoogleBannerBuilder? googleBuilder;
  final EdgeInsetsGeometry padding;

  @override
  State<SponsoredSlot> createState() => _SponsoredSlotState();
}

class _SponsoredSlotState extends State<SponsoredSlot> {
  late final AdsService _ads = widget.service ?? AdsService.forRepository(Session.read(context).repo);
  SponsoredAd? _ad;
  AdSettings? _google;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<AdSettings> _settings() {
    if (widget.settings != null) return widget.settings!();
    // Service imposé sans réglages (tests) : campagnes directes seules, comme avant 0034.
    if (widget.service != null) return Future.value(const AdSettings(direct: true));
    return AdSettings.load(Session.read(context).repo);
  }

  Future<void> _load() async {
    try {
      final settings = await _settings();
      final ads = settings.direct ? await _ads.sponsored(widget.placement) : const <SponsoredAd>[];
      if (!mounted) return;
      if (ads.isNotEmpty) {
        setState(() => _ad = ads.first);
        // Affichage réel : compté une fois à l'apparition de la carte.
        _ads.recordImpression(ads.first.campaignId, widget.placement).then((_) {}, onError: (_) {});
      } else if (settings.bannerAllowed(bannerPlacementFor(widget.placement))) {
        setState(() => _google = settings);
      }
    } catch (_) {
      // Sans publicité, rien ne s'affiche : aucune gêne pour le membre.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad != null) {
      return Padding(
        padding: widget.padding,
        child: SponsoredCard(ad: ad, onOpen: () => openSponsored(_ads, ad, widget.placement)),
      );
    }
    final google = _google;
    if (google != null) {
      return Padding(
        padding: widget.padding,
        child: (widget.googleBuilder ?? defaultGoogleBanner)(google, bannerPlacementFor(widget.placement)),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Carte « Sponsorisé » : annonceur identifié, visuel, texte, bouton d'action.
class SponsoredCard extends StatelessWidget {
  const SponsoredCard({super.key, required this.ad, required this.onOpen});
  final SponsoredAd ad;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final hasLink = (ad.destinationUrl ?? '').isNotEmpty;
    return Semantics(
      container: true,
      label: '${s.adSponsored}, ${ad.advertiserName}',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), side: const BorderSide(color: ZColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasLink ? onOpen : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: ZColors.primarySoft,
                  foregroundImage: ad.logoUrl == null ? null : NetworkImage(ad.logoUrl!),
                  child: Text(ad.advertiserName.characters.first.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ad.advertiserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ZColors.ink)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ZColors.line, borderRadius: BorderRadius.circular(99)),
                  child: Text(s.adSponsored,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: ZColors.muted)),
                ),
              ]),
            ),
            if (ad.hasImage)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(ad.mediaUrl!,
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: ZColors.line)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ad.headline, style: Theme.of(context).textTheme.titleMedium),
                if ((ad.body ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ad.body!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (hasLink) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: onOpen,
                      child: Text((ad.ctaLabel ?? '').isEmpty ? s.adLearnMore : ad.ctaLabel!),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
