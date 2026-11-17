import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import 'ads_service.dart';

/// Emplacement publicitaire : charge au plus une campagne directe pour [placement] et ne prend aucune place s'il n'y en
/// a pas (régie désactivée, plafond atteint, rien de programmé). Jamais utilisé dans les conversations.
class SponsoredSlot extends StatefulWidget {
  const SponsoredSlot({super.key, required this.placement, this.service, this.padding = EdgeInsets.zero});

  /// community_feed | explore | profile (mêmes valeurs que le serveur).
  final String placement;

  /// Pour les tests ; sinon, service déduit du dépôt de la session.
  final AdsService? service;
  final EdgeInsetsGeometry padding;

  @override
  State<SponsoredSlot> createState() => _SponsoredSlotState();
}

class _SponsoredSlotState extends State<SponsoredSlot> {
  late final AdsService _ads = widget.service ?? AdsService.forRepository(Session.read(context).repo);
  SponsoredAd? _ad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ads = await _ads.sponsored(widget.placement);
      if (!mounted || ads.isEmpty) return;
      setState(() => _ad = ads.first);
      // Affichage réel : compté une fois à l'apparition de la carte.
      _ads.recordImpression(ads.first.campaignId, widget.placement).then((_) {}, onError: (_) {});
    } catch (_) {
      // Sans publicité, rien ne s'affiche : aucune gêne pour le membre.
    }
  }

  Future<void> _open(SponsoredAd ad) async {
    final url = ad.destinationUrl;
    if (url == null || url.isEmpty) return;
    // Action volontaire du membre ; le serveur ne compte qu'un clic par jour, après affichage.
    _ads.recordClick(ad.campaignId, widget.placement).then((_) {}, onError: (_) {});
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Padding(padding: widget.padding, child: SponsoredCard(ad: ad, onOpen: () => _open(ad)));
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
