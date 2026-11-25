import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../premium/premium_screens.dart';
import '../safety/safety_sheets.dart';
import 'photo_viewer.dart';
import 'profile_sections.dart';
import 'profile_widgets.dart';
import 'swipe_buttons.dart';

/// Fiche complète d'un profil, dans les limites de ce que son propriétaire a choisi de montrer.
/// Les photos défilent dans l'en-tête (glisser, ou toucher à droite / à gauche) ; le bouton « Agrandir » les ouvre en
/// plein écran avec le zoom. Avec [showActions], l'écran se ferme en renvoyant `'like'`, `'pass'` ou `'blocked'`.
class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({
    super.key,
    required this.userId,
    required this.name,
    this.preview,
    this.heroTag,
    this.showActions = false,
  });

  final String userId;
  final String name;
  final DiscoveryProfile? preview;
  final String? heroTag;
  final bool showActions;

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  ProfileDetail? _detail;
  String? _error;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = Session.read(context).repo;
    try {
      final detail = await repo.profileDetail(widget.userId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  void _openMenu(String name) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: ZColors.danger),
            title: Text('Signaler $name'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showReportSheet(context, userId: widget.userId, name: name, reportContext: 'profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: ZColors.danger),
            title: Text('Bloquer $name'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final navigator = Navigator.of(context);
              if (await confirmBlock(context, userId: widget.userId, name: name)) navigator.pop('blocked');
            },
          ),
        ]),
      ),
    );
  }

  void _openPremium() => Navigator.of(context).push(zRoute<void>(const PremiumScreen()));

  /// Photos en plein écran (zoom, sans enregistrement), à partir de celle affichée dans l'en-tête.
  void _openPhotos() {
    final detail = _detail;
    if (detail == null) return;
    final visible = PhotoViewerScreen.viewable(detail.photos);
    if (visible.isEmpty) return;
    Navigator.of(context).push(zRoute<void>(PhotoViewerScreen(
      name: detail.base.displayName,
      photos: detail.photos,
      initialPhotoId: visible[_photoIndex.clamp(0, visible.length - 1)].id,
      onUnlock: _openPremium,
    )));
  }

  /// En-tête : photos qui défilent, voile, puis nom, âge, badges et principales informations.
  Widget _header(String name, DiscoveryProfile? base) {
    final detail = _detail;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(fit: StackFit.expand, children: [
      ProfilePhotoPager(
        name: name,
        photos: detail?.photos ?? const <ProfilePhoto>[],
        fallbackPath: base?.photoPath,
        heroTag: widget.heroTag,
        swipeable: true,
        topInset: top + 4,
        onUnlock: _openPremium,
        onIndexChanged: (i) => _photoIndex = i,
      ),
      const IgnorePointer(child: PhotoScrim(start: 0.5)),
      Positioned(
        left: 20,
        right: 20,
        bottom: 20,
        child: IgnorePointer(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (base != null) ...[
              Builder(builder: (context) {
                final badges = profileCoverBadges(Session.of(context).me, base);
                if (badges.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(spacing: 6, runSpacing: 6, children: badges),
                );
              }),
            ],
            Row(children: [
              Flexible(child: ProfileNameAge(name: name, age: base?.age, size: 30)),
              if (base?.isVerified ?? false) ...[const SizedBox(width: 8), const VerifiedBadge(size: 24)],
            ]),
            if (base != null) ProfileCoverLines(profile: base),
          ]),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final base = detail?.base ?? widget.preview;
    final name = base?.displayName ?? widget.name;
    final canZoom = detail != null && PhotoViewerScreen.viewable(detail.photos).isNotEmpty;

    return Scaffold(
      backgroundColor: ZColors.bg,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.62,
            backgroundColor: ZColors.primary,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child:
                  _RoundIconButton(icon: Icons.arrow_back, tooltip: 'Retour', onTap: () => Navigator.of(context).pop()),
            ),
            actions: [
              if (canZoom) ...[
                _RoundIconButton(icon: Icons.zoom_out_map, tooltip: 'Agrandir les photos', onTap: _openPhotos),
                const SizedBox(width: 6),
              ],
              _RoundIconButton(icon: Icons.more_horiz, tooltip: 'Signaler ou bloquer', onTap: () => _openMenu(name)),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _header(name, base)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, widget.showActions ? 124 : 32),
              child: base == null
                  ? _placeholder()
                  : ProfileInfoSections(base: base, detail: detail, error: _error, onRetry: _load),
            ),
          ),
        ]),
        if (widget.showActions)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionBar(
              onPass: () => Navigator.of(context).pop('pass'),
              onLike: () => Navigator.of(context).pop('like'),
            ),
          ),
      ]),
    );
  }

  Widget _placeholder() {
    if (_error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InfoBanner(text: _error!, tone: BannerTone.danger, icon: Icons.error_outline),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
      ]);
    }
    return const Column(children: [
      Skeleton(height: 90),
      SizedBox(height: 14),
      Skeleton(height: 60),
      SizedBox(height: 14),
      Skeleton(height: 120),
    ]);
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35)),
          icon: Icon(icon, color: Colors.white),
          tooltip: tooltip,
          onPressed: onTap,
        ),
      );
}

/// Barre d'actions en bas de la fiche : passer ou aimer, avec les mêmes boutons animés que la carte.
/// L'écran se ferme juste après le début de l'animation de l'appui, pour qu'on la voie ; un seul choix est pris en
/// compte (un second appui pendant la fermeture refermerait l'écran d'en dessous).
class _ActionBar extends StatefulWidget {
  const _ActionBar({required this.onPass, required this.onLike});
  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  bool _chosen = false;

  void _choose(VoidCallback action) {
    if (_chosen) return;
    _chosen = true;
    final wait = ZMotion.of(context, const Duration(milliseconds: 220));
    if (wait == Duration.zero) {
      action();
    } else {
      Future<void>.delayed(wait, () {
        if (mounted) action();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.5],
          colors: [ZColors.bg.withValues(alpha: 0), ZColors.bg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SwipeActionButton(action: SwipeAction.pass, label: 'Passer', onTap: () => _choose(widget.onPass)),
            const SizedBox(width: 28),
            SwipeActionButton(action: SwipeAction.like, label: 'Aimer', onTap: () => _choose(widget.onLike)),
          ]),
        ),
      ),
    );
  }
}
