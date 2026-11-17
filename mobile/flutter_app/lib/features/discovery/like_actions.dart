import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../chat/chat_screen.dart';
import 'profile_detail_screen.dart';
import 'profile_widgets.dart';

/// Envoie le like au serveur. Retourne `null` si l'envoi a échoué (l'erreur est déjà affichée).
Future<LikeResult?> sendLike(BuildContext context, DiscoveryProfile profile) async {
  final repo = Session.read(context).repo;
  try {
    return await repo.like(profile.id);
  } catch (e) {
    if (context.mounted) showZayaSnack(context, friendlyError(e), error: true);
    return null;
  }
}

/// Applique le résultat d'un like : mise à jour du fil, écran de quota ou écran de match.
/// La mise à jour du fil a lieu de façon synchrone, avant toute attente.
Future<void> applyLikeResult(BuildContext context, DiscoveryProfile profile, LikeResult result) async {
  final session = Session.read(context);
  switch (result.status) {
    case LikeStatus.quotaReached:
      await showQuotaSheet(context, result.resetsAt);
    case LikeStatus.alreadyLiked:
      session.feed.remove(profile.id);
    case LikeStatus.liked:
      session.feed.remove(profile.id);
      final remaining = result.remaining;
      if (remaining != null) session.feed.setRemaining(remaining);
    case LikeStatus.matched:
      session.feed.remove(profile.id);
      session.refreshBadges();
      final matchId = result.matchId;
      final openChat = await showMatchOverlay(context, profile);
      if (openChat && matchId != null && context.mounted) {
        await Navigator.of(context).push(zRoute<void>(ChatScreen(
          match: MatchSummary(
            matchId: matchId,
            userId: profile.id,
            displayName: profile.displayName,
            photoPath: profile.photoPath,
            isVerified: profile.isVerified,
          ),
        )));
      }
  }
}

/// Like complet (envoi + suites) pour les écrans sans animation de carte. Retourne le statut, ou null si échec.
Future<LikeStatus?> performLike(BuildContext context, DiscoveryProfile profile) async {
  final result = await sendLike(context, profile);
  if (result == null || !context.mounted) return result?.status;
  await applyLikeResult(context, profile, result);
  return result.status;
}

/// Ouvre la fiche d'un profil avec les boutons Passer / Aimer, puis applique le choix du membre.
Future<void> openProfileWithActions(BuildContext context, DiscoveryProfile profile, {required String heroTag}) async {
  final session = Session.read(context);
  final action = await Navigator.of(context).push<String>(zRoute<String>(ProfileDetailScreen(
    userId: profile.id,
    name: profile.displayName,
    preview: profile,
    heroTag: heroTag,
    showActions: true,
  )));
  if (!context.mounted) return;
  switch (action) {
    case 'like':
      await performLike(context, profile);
    case 'pass':
      // Sans réseau, le profil pourra simplement être proposé à nouveau plus tard.
      session.repo.pass(profile.id).then((_) {}, onError: (_) {});
      session.feed.remove(profile.id);
    case 'blocked':
      session.feed.remove(profile.id);
  }
}

/// Quota quotidien atteint : explication claire, sans pression commerciale ni fausse urgence.
Future<void> showQuotaSheet(BuildContext context, DateTime? resetsAt) {
  final when = resetsAt == null ? 'demain' : 'à ${formatTime(resetsAt)}';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: ZColors.primarySoft,
              child: Icon(Icons.hourglass_bottom, color: ZColors.primary, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text('Vous avez utilisé vos likes du jour',
              style: Theme.of(sheetContext).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Vos likes gratuits se renouvellent $when. D’ici là, vous pouvez continuer à parcourir les profils '
            'et à discuter avec vos matchs.',
            style: Theme.of(sheetContext).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('D’accord')),
        ]),
      ),
    ),
  );
}

/// Écran de match. Retourne `true` si le membre choisit d'ouvrir la conversation.
Future<bool> showMatchOverlay(BuildContext context, DiscoveryProfile profile) async {
  final result = await Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
    opaque: false,
    barrierColor: Colors.black26,
    transitionDuration: ZMotion.medium,
    reverseTransitionDuration: ZMotion.fast,
    pageBuilder: (_, __, ___) => _MatchOverlay(profile: profile),
    transitionsBuilder: (context, animation, _, child) =>
        ZMotion.reduced(context) ? child : FadeTransition(opacity: animation, child: child),
  ));
  return result ?? false;
}

/// Animation de match : courte, élégante, jamais bloquante (fermeture possible à tout moment).
class _MatchOverlay extends StatelessWidget {
  const _MatchOverlay({required this.profile});
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    final reduced = ZMotion.reduced(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: ZColors.brandGradient),
        child: SafeArea(
          child: FillOrScroll(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
            child: Column(children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  // Les deux avatars glissent l'un vers l'autre, puis le cœur apparaît en rebondissant.
                  final gap = 150 * (1 - t);
                  final heart = Curves.easeOutBack.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0).toDouble());
                  return SizedBox(
                    height: 150,
                    child: Stack(alignment: Alignment.center, children: [
                      Transform.translate(
                        offset: Offset(-46 - gap, 0),
                        child:
                            Opacity(opacity: t, child: _ringed(ProfileAvatar(name: me?.displayName ?? '', size: 112))),
                      ),
                      Transform.translate(
                        offset: Offset(46 + gap, 0),
                        child: Opacity(
                            opacity: t,
                            child: _ringed(
                                RemoteAvatar(name: profile.displayName, photoPath: profile.photoPath, size: 112))),
                      ),
                      Transform.scale(
                        scale: heart,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.favorite, color: ZColors.primary, size: 28),
                        ),
                      ),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 32),
              FadeSlideIn(
                index: 2,
                child: Text('C’est un match !',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                index: 3,
                child: Text('${profile.displayName} et vous avez exprimé un intérêt réciproque.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withValues(alpha: 0.92), height: 1.4)),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ZColors.primaryDark),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Envoyer un message'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continuer à découvrir'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _ringed(Widget child) => Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: child,
      );
}
