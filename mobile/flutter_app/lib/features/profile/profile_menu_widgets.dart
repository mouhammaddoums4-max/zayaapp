import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// Lien de la fiche Google Play, à défaut d'un lien d'invitation configuré (`app_config.invite_url`).
const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.zaya.app.zaya';

/// Invite un proche à découvrir ZAYA (feuille de partage du téléphone). Aucun contact n'est lu par l'application.
Future<void> inviteToZaya(BuildContext context) async {
  final s = context.s;
  var url = playStoreUrl;
  try {
    final config = await Session.read(context).repo.publicConfig();
    for (final key in ['invite_url', 'app_update_url']) {
      final value = (config[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        url = value;
        break;
      }
    }
  } catch (_) {
    // Lien par défaut.
  }
  await SharePlus.instance.share(ShareParams(text: s.inviteMessage(url), subject: 'ZAYA'));
}

/// Raccourcis du profil, en puces défilantes.
class ProfileShortcuts extends StatelessWidget {
  const ProfileShortcuts({super.key, required this.items});
  final List<(IconData, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (icon, label, onTap) = items[i];
            return ActionChip(
              avatar: Icon(icon, size: 18, color: ZColors.primaryDark),
              label: Text(label),
              labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.ink),
              backgroundColor: Colors.white,
              side: const BorderSide(color: ZColors.line),
              shape: const StadiumBorder(),
              onPressed: onTap,
            );
          },
        ),
      );
}

/// Offre en cours : ce qui est inclus, réellement ; une seule entrée Premium, sans compte à rebours (§22.4).
class PlanCard extends StatelessWidget {
  const PlanCard(
      {super.key, required this.premium, required this.freeSwipes, required this.windowHours, required this.onOpen});
  final bool premium;
  final int? freeSwipes;
  final int windowHours;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final body = premium
        ? s.planPremiumBody
        : [if (freeSwipes != null) s.planFreeSwipes(freeSwipes!, windowHours), s.planFreeEssentials].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: premium ? ZColors.brandGradient : null,
        color: premium ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: premium ? null : Border.all(color: ZColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(premium ? Icons.workspace_premium : Icons.favorite_outline,
              color: premium ? Colors.white : ZColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(premium ? s.planPremiumTitle : s.planFreeTitle,
                style: GoogleFonts.sora(
                    fontSize: 18, fontWeight: FontWeight.w700, color: premium ? Colors.white : ZColors.ink)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(body,
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.45, color: premium ? Colors.white.withValues(alpha: 0.95) : ZColors.muted)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: premium
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                  onPressed: onOpen,
                  child: Text(s.planMySubscription),
                )
              : FilledButton(onPressed: onOpen, child: Text(s.planDiscoverPremium)),
        ),
      ]),
    );
  }
}

/// Likes restants du jour (quota appliqué par le serveur). Proposition Premium seulement une fois la limite atteinte.
class LikesLeftCard extends StatefulWidget {
  const LikesLeftCard({super.key, required this.premium, required this.onMore});
  final bool premium;
  final VoidCallback onMore;

  @override
  State<LikesLeftCard> createState() => _LikesLeftCardState();
}

class _LikesLeftCardState extends State<LikesLeftCard> {
  LikeQuota? _quota;

  @override
  void initState() {
    super.initState();
    final session = Session.read(context);
    _quota = session.feed.quota;
    if (_quota == null) {
      session.repo.likeQuota().then((q) {
        if (mounted) setState(() => _quota = q);
      }, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final quota = Session.of(context).feed.quota ?? _quota;
    if (quota == null) return const SizedBox.shrink();
    final reset = quota.resetsAt.toLocal();
    final time = '${reset.hour.toString().padLeft(2, '0')}:${reset.minute.toString().padLeft(2, '0')}';
    final exhausted = quota.remaining <= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZColors.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          label: '${quota.remaining} / ${quota.limit}',
          child: Text('${quota.remaining}',
              style: GoogleFonts.sora(
                  fontSize: 34, fontWeight: FontWeight.w700, color: exhausted ? ZColors.muted : ZColors.primary)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.likesLeftTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            // La fin de période n'a de sens qu'une fois la période commencée (premier swipe).
            Text(
                quota.remaining < quota.limit
                    ? '${quota.remaining} / ${quota.limit} · ${s.likesRenewAt(time)}'
                    : '${quota.remaining} / ${quota.limit}',
                style: Theme.of(context).textTheme.bodyMedium),
            if (exhausted && !widget.premium) ...[
              const SizedBox(height: 10),
              FilledButton.tonal(onPressed: widget.onMore, child: Text(s.likesMore)),
            ],
          ]),
        ),
      ]),
    );
  }
}
