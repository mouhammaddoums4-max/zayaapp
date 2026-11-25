import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../discovery/profile_widgets.dart';
import 'zaya2_api.dart';
import 'zaya_hub_screen.dart';

/// Bannière « Match du jour » en tête d'Explorer. Invisible si la fonction est coupée, si aucune suggestion
/// n'est possible ou si celle du jour a déjà reçu une réponse : jamais de place vide ni de profil inventé.
class DailyMatchBanner extends StatefulWidget {
  const DailyMatchBanner({super.key});

  @override
  State<DailyMatchBanner> createState() => _DailyMatchBannerState();
}

class _DailyMatchBannerState extends State<DailyMatchBanner> {
  late Future<DailyMatch> _match = Zaya2Api.of(context).dailyMatch();

  Future<void> _open() async {
    await Navigator.of(context).push(zRoute<void>(const ZayaHubScreen()));
    if (!mounted) return;
    setState(() {
      _match = Zaya2Api.of(context).dailyMatch();
    });
  }

  @override
  // Serveur sans le Match du jour (migration non appliquée, fonction coupée) : rien n'est demandé ni affiché.
  Widget build(BuildContext context) => !Session.of(context).featureOn('match_of_day')
      ? const SizedBox.shrink()
      : FutureBuilder<DailyMatch>(
          future: _match,
          builder: (context, snap) {
            final m = snap.data;
            final p = m?.profile;
            if (m == null || !m.ready || p == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FadeSlideIn(
                child: PressScale(
                  onTap: _open,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ZColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      RemoteAvatar(name: p.displayName, photoPath: p.photoPath, size: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(context, 'Votre match du jour', 'Your daily match'),
                              style: GoogleFonts.inter(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Flexible(
                              child: Text('${p.displayName}, ${p.age}',
                                  overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                            ),
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 16),
                          ]),
                          if (p.city != null)
                            Text(p.city!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: ZColors.muted),
                    ]),
                  ),
                ),
              ),
            );
          },
        );
}
