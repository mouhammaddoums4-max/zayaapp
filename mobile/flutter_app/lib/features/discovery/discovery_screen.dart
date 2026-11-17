import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../boost/boost_button.dart';
import '../notifications/notifications_screen.dart';
import '../profile/preferences_screen.dart';
import '../profile/verification_screen.dart';
import '../safety/safety_sheets.dart';
import 'like_actions.dart';
import 'profile_detail_screen.dart';
import 'profile_widgets.dart';

/// Onglet Découvrir : une carte de profil à la fois. On glisse à droite pour aimer, à gauche pour passer ;
/// les boutons offrent la même chose sans geste, et un appui sur la carte ouvre la fiche complète.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fly = AnimationController(vsync: this, duration: ZMotion.medium);
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _fly.addListener(_onFly);
    final feed = Session.read(context).feed;
    if (!feed.loaded && !feed.loading) {
      // Après la première image, pour ne pas notifier les écouteurs pendant la construction.
      WidgetsBinding.instance.addPostFrameCallback((_) => feed.load());
    }
  }

  @override
  void dispose() {
    _fly.removeListener(_onFly);
    _fly.dispose();
    super.dispose();
  }

  void _onFly() {
    setState(() => _drag = Offset.lerp(_from, _to, ZMotion.emphasized.transform(_fly.value))!);
  }

  /// Anime la carte vers [target] (sortie d'écran ou retour au centre).
  Future<void> _animateTo(Offset target) async {
    if (!mounted) return;
    if (ZMotion.reduced(context)) {
      setState(() => _drag = target);
      return;
    }
    _from = _drag;
    _to = target;
    try {
      await _fly.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Écran fermé pendant l'animation : rien à faire.
    }
  }

  Offset _exit(int direction) => Offset(MediaQuery.of(context).size.width * 1.4 * direction, 30);

  Future<void> _pass(DiscoveryProfile profile) async {
    if (_acting) return;
    final session = Session.read(context);
    setState(() => _acting = true);
    // Sans réseau, le profil pourra simplement être proposé à nouveau plus tard.
    session.repo.pass(profile.id).then((_) {}, onError: (_) {});
    await _animateTo(_exit(-1));
    if (!mounted) return;
    _drag = Offset.zero;
    _acting = false;
    session.feed.remove(profile.id);
  }

  Future<void> _like(DiscoveryProfile profile) async {
    if (_acting) return;
    setState(() => _acting = true);
    HapticFeedback.lightImpact();
    final flight = _animateTo(_exit(1));
    final result = await sendLike(context, profile);
    await flight;
    if (!mounted) return;
    final refused = result == null || result.status == LikeStatus.quotaReached;
    if (refused) {
      // Like non pris en compte (quota atteint ou erreur) : la carte revient à sa place.
      await _animateTo(Offset.zero);
      if (!mounted) return;
    } else {
      _drag = Offset.zero;
    }
    setState(() => _acting = false);
    if (result != null) await applyLikeResult(context, profile, result);
  }

  void _onDragEnd(DiscoveryProfile profile) {
    final threshold = MediaQuery.of(context).size.width * 0.28;
    if (_drag.dx > threshold) {
      _like(profile);
    } else if (_drag.dx < -threshold) {
      _pass(profile);
    } else {
      _animateTo(Offset.zero);
    }
  }

  Future<void> _openProfile(DiscoveryProfile profile) async {
    if (_acting) return;
    final action = await Navigator.of(context).push<String>(zRoute<String>(ProfileDetailScreen(
      userId: profile.id,
      name: profile.displayName,
      preview: profile,
      heroTag: 'discover-${profile.id}',
      showActions: true,
    )));
    if (!mounted) return;
    if (action == 'like') {
      await _like(profile);
    } else if (action == 'pass') {
      await _pass(profile);
    } else if (action == 'blocked') {
      Session.read(context).feed.remove(profile.id);
    }
  }

  Future<void> _openFilters() async {
    final changed = await Navigator.of(context).push<bool>(zRoute<bool>(const PreferencesScreen()));
    if (changed == true && mounted) Session.read(context).feed.load();
  }

  void _showCardMenu(DiscoveryProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: ZColors.danger),
            title: const Text('Signaler ce profil'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showReportSheet(context, userId: profile.id, name: profile.displayName, reportContext: 'profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: ZColors.danger),
            title: const Text('Bloquer'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final feed = Session.read(context).feed;
              if (await confirmBlock(context, userId: profile.id, name: profile.displayName)) feed.remove(profile.id);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.of(context);
    final me = session.me;
    return Scaffold(
      // En-tête : filtres à gauche ; à droite, likes restants, Boost (flamme animée) puis notifications.
      appBar: AppBar(
        leading:
            IconButton(icon: const Icon(Icons.tune), tooltip: 'Préférences de découverte', onPressed: _openFilters),
        titleSpacing: 0,
        title: Text('Découvrir', overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
        actions: [
          ListenableBuilder(
            listenable: session.feed,
            builder: (context, _) {
              final quota = session.feed.quota;
              if (quota == null) return const SizedBox.shrink();
              return Center(child: _QuotaChip(remaining: quota.remaining));
            },
          ),
          const BoostButton(),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(zRoute<void>(const NotificationsScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        if (me != null && !me.isVerified)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.verified_outlined,
              text: me.verificationStatus == 'pending'
                  ? 'Vérification en cours. Votre profil sera visible dès qu’elle sera validée.'
                  : 'Votre profil n’est pas encore visible des autres membres. Ajoutez 3 photos et faites-le vérifier.',
              action: me.verificationStatus == 'pending'
                  ? null
                  : TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          foregroundColor: const Color(0xFF5C4100)),
                      onPressed: () => Navigator.of(context).push(zRoute<void>(const VerificationScreen())),
                      child: const Text('Vérifier mon profil  →', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
            ),
          ),
        Expanded(
          child: ListenableBuilder(listenable: session.feed, builder: (context, _) => _body(context, session)),
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, Session session) {
    final feed = session.feed;
    final me = session.me;
    if (me != null && (me.status == 'paused' || me.status == 'hidden')) {
      return EmptyState(
        icon: Icons.pause_circle_outline,
        title: me.deletionScheduledFor != null ? 'Suppression du compte demandée' : 'Votre profil est en pause',
        message: me.deletionScheduledFor != null
            ? 'Votre profil n’est plus proposé. Vous pouvez annuler la suppression depuis l’onglet Profil.'
            : 'Réactivez votre profil depuis l’onglet Profil pour découvrir de nouvelles personnes.',
      );
    }
    if (feed.loading && feed.profiles.isEmpty) {
      return const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 104), child: Skeleton(radius: 28));
    }
    if (feed.error != null && feed.profiles.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off,
        title: 'Connexion interrompue',
        message: feed.error!,
        action: FilledButton(onPressed: feed.load, child: const Text('Réessayer')),
      );
    }
    if (feed.profiles.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        title: 'Plus de profils pour le moment',
        message: 'De nouveaux membres rejoignent ZAYA chaque jour. Élargissez vos préférences ou revenez plus tard.',
        action: Column(mainAxisSize: MainAxisSize.min, children: [
          FilledButton(onPressed: _openFilters, child: const Text('Modifier mes préférences')),
          const SizedBox(height: 8),
          TextButton(onPressed: feed.load, child: const Text('Actualiser')),
        ]),
      );
    }

    final top = feed.profiles.first;
    final next = feed.profiles.length > 1 ? feed.profiles[1] : null;
    final width = MediaQuery.of(context).size.width;
    final progress = (_drag.dx.abs() / (width * 0.28)).clamp(0.0, 1.0).toDouble();
    final swipe = (_drag.dx / (width * 0.28)).clamp(-1.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(children: [
        Expanded(
          child: Stack(children: [
            if (next != null)
              Positioned.fill(
                // La carte suivante grandit à mesure que la première s'éloigne.
                child: Transform.scale(
                  scale: 0.94 + 0.06 * progress,
                  child: Opacity(opacity: 0.6 + 0.4 * progress, child: _ProfileCard(profile: next)),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _openProfile(top),
                onPanUpdate: _acting ? null : (details) => setState(() => _drag += details.delta),
                onPanEnd: _acting ? null : (_) => _onDragEnd(top),
                child: Transform.translate(
                  offset: _drag,
                  child: Transform.rotate(
                    angle: _drag.dx / width * 0.3,
                    child: _ProfileCard(
                      key: ValueKey<String>(top.id),
                      profile: top,
                      swipe: swipe,
                      heroTag: 'discover-${top.id}',
                      onMore: () => _showCardMenu(top),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
          _RoundAction(icon: Icons.close, label: 'Passer', color: ZColors.ink, onTap: () => _pass(top)),
          const SizedBox(width: 22),
          _RoundAction(
              icon: Icons.person_outline,
              label: 'Voir le profil',
              color: ZColors.muted,
              small: true,
              onTap: () => _openProfile(top)),
          const SizedBox(width: 22),
          _RoundAction(
              icon: Icons.favorite, label: 'Aimer', color: ZColors.primary, filled: true, onTap: () => _like(top)),
        ]),
      ]),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  const _QuotaChip({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Likes gratuits restants aujourd’hui',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.favorite, size: 14, color: ZColors.primary),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: ZMotion.of(context, ZMotion.fast),
              child: Text('$remaining',
                  key: ValueKey<int>(remaining),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
            ),
          ]),
        ),
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({super.key, required this.profile, this.swipe = 0, this.heroTag, this.onMore});
  final DiscoveryProfile profile;

  /// Avancement du geste : -1 (passer) … 1 (aimer).
  final double swipe;
  final String? heroTag;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    Widget photo = ProfilePhotoView(name: p.displayName, photoPath: p.photoPath, initialSize: 150);
    final tag = heroTag;
    if (tag != null) photo = Hero(tag: tag, child: photo);
    final tags = <String>[...p.languages, ...p.interests].take(4).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(fit: StackFit.expand, children: [
        photo,
        const PhotoScrim(start: 0.35),
        if (onMore != null)
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35)),
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              tooltip: 'Signaler ou bloquer',
              onPressed: onMore,
            ),
          ),
        if (swipe.abs() > 0.12)
          Positioned(
            top: 30,
            left: swipe > 0 ? 24 : null,
            right: swipe < 0 ? 24 : null,
            child: Opacity(
              opacity: swipe.abs(),
              child: Transform.rotate(
                angle: swipe > 0 ? -0.2 : 0.2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: swipe > 0 ? ZColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(swipe > 0 ? Icons.favorite : Icons.close,
                        size: 20, color: swipe > 0 ? Colors.white : ZColors.ink),
                    const SizedBox(width: 6),
                    Text(swipe > 0 ? 'J’aime' : 'Passer',
                        style: GoogleFonts.sora(
                            fontSize: 18, fontWeight: FontWeight.w700, color: swipe > 0 ? Colors.white : ZColors.ink)),
                  ]),
                ),
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(
                child: Text('${p.displayName}, ${p.age}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 27, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              if (p.isVerified) ...[const SizedBox(width: 8), const VerifiedBadge(size: 24)],
              if (p.isPremium) ...[const SizedBox(width: 8), const PremiumBadge()],
            ]),
            const SizedBox(height: 6),
            if (p.city != null) _InfoLine(icon: Icons.place_outlined, text: p.city!),
            if (p.profession != null) _InfoLine(icon: Icons.work_outline, text: p.profession!),
            if (p.horizon != null)
              _InfoLine(icon: Icons.favorite_border, text: 'Mariage : ${horizonLabels[p.horizon] ?? ''}'),
            if (p.bio != null && p.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.bio!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.92), height: 1.4)),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tags) ZTag(t, onDark: true)]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
        ]),
      );
}

/// Bouton rond d'action (alternative accessible au geste de glissement).
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.small = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 50.0 : (filled ? 72.0 : 62.0);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: PressScale(
          pressedScale: 0.88,
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: filled ? ZColors.brandGradient : null,
              color: filled ? null : Colors.white,
              border: filled ? null : Border.all(color: ZColors.line, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: (filled ? ZColors.primary : Colors.black).withValues(alpha: filled ? 0.35 : 0.06),
                  blurRadius: filled ? 18 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: small ? 24 : (filled ? 34 : 28), color: filled ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}
