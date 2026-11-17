import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../safety/safety_sheets.dart';
import 'profile_widgets.dart';

/// Fiche complète d'un profil, dans les limites de ce que son propriétaire a choisi de montrer.
/// Avec [showActions], l'écran se ferme en renvoyant `'like'`, `'pass'` ou `'blocked'`.
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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final base = detail?.base ?? widget.preview;
    final name = base?.displayName ?? widget.name;
    final me = Session.of(context).me;

    Widget photo = ProfilePhotoView(name: name, photoPath: base?.photoPath, initialSize: 170);
    final tag = widget.heroTag;
    if (tag != null) photo = Hero(tag: tag, child: photo);

    return Scaffold(
      backgroundColor: ZColors.bg,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.5,
            backgroundColor: ZColors.primary,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _RoundIconButton(
                  icon: Icons.arrow_back, tooltip: 'Retour', onTap: () => Navigator.of(context).pop()),
            ),
            actions: [
              _RoundIconButton(icon: Icons.more_horiz, tooltip: 'Signaler ou bloquer', onTap: () => _openMenu(name)),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                photo,
                const PhotoScrim(start: 0.5),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Flexible(
                        child: Text(base == null ? name : '$name, ${base.age}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      if (base?.isVerified ?? false) ...[const SizedBox(width: 8), const VerifiedBadge(size: 24)],
                      if (base?.isPremium ?? false) ...[const SizedBox(width: 8), const PremiumBadge()],
                    ]),
                    if (base?.city != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 16, color: Colors.white),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(base!.city!,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, widget.showActions ? 124 : 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _sections(context, base, detail, me)),
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

  List<Widget> _sections(BuildContext context, DiscoveryProfile? base, ProfileDetail? detail, MyProfile? me) {
    if (base == null) {
      if (_error != null) {
        return [
          InfoBanner(text: _error!, tone: BannerTone.danger, icon: Icons.error_outline),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
        ];
      }
      return const [
        Skeleton(height: 90),
        SizedBox(height: 14),
        Skeleton(height: 60),
        SizedBox(height: 14),
        Skeleton(height: 120),
      ];
    }

    final sections = <Widget>[];
    void add(Widget section) => sections.add(FadeSlideIn(index: sections.length, child: section));

    final points = me == null ? const <String>[] : commonPoints(me, base);
    if (points.isNotEmpty) {
      add(_Card(
        tinted: true,
        title: 'Vos points communs',
        child: Column(children: [
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 2), child: Icon(Icons.favorite, size: 16, color: ZColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(point, style: Theme.of(context).textTheme.bodyLarge)),
              ]),
            ),
        ]),
      ));
    }

    if (base.bio != null && base.bio!.isNotEmpty) {
      add(_Card(title: 'À propos', child: Text(base.bio!, style: Theme.of(context).textTheme.bodyLarge)));
    }

    if (base.horizon != null) {
      add(_Card(
        title: 'Projet de mariage',
        child: Row(children: [
          const Icon(Icons.event_available_outlined, color: ZColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(horizonLabels[base.horizon] ?? '', style: Theme.of(context).textTheme.bodyLarge)),
        ]),
      ));
    }

    final facts = <Widget>[
      if (base.profession != null) ZTag(base.profession!, icon: Icons.work_outline),
      if (detail?.maritalStatus != null)
        ZTag(maritalLabels[detail!.maritalStatus] ?? detail.maritalStatus!, icon: Icons.people_outline),
      if (detail?.childrenCount != null) ZTag(_children(detail!.childrenCount!), icon: Icons.child_care_outlined),
      if (detail?.education != null) ZTag(detail!.education!, icon: Icons.school_outlined),
      if (detail?.heightCm != null) ZTag('${detail!.heightCm} cm', icon: Icons.height),
      if (detail?.confession != null)
        ZTag(confessionLabels[detail!.confession] ?? detail.confession!, icon: Icons.self_improvement),
      if (detail?.ethnicGroup != null) ZTag(detail!.ethnicGroup!, icon: Icons.public),
    ];
    if (facts.isNotEmpty) {
      add(_Card(title: 'En bref', child: Wrap(spacing: 8, runSpacing: 8, children: facts)));
    } else if (detail == null && _error == null) {
      add(const Skeleton(height: 90));
    }

    if (base.languages.isNotEmpty) {
      add(_Card(
        title: 'Langues parlées',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in base.languages) ZTag(l, highlighted: me?.languages.contains(l) ?? false),
        ]),
      ));
    }
    if (base.interests.isNotEmpty) {
      add(_Card(
        title: 'Centres d’intérêt',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final i in base.interests) ZTag(i, highlighted: me?.interests.contains(i) ?? false),
        ]),
      ));
    }

    if (detail != null && detail.hiddenPhotoCount > 0) {
      add(InfoBanner(
        icon: Icons.lock_outline,
        text: detail.hiddenPhotoCount == 1
            ? '1 photo est privée. Elle n’est visible que si ${base.displayName} vous y autorise.'
            : '${detail.hiddenPhotoCount} photos sont privées. Elles ne sont visibles que si ${base.displayName} vous y autorise.',
      ));
    }

    add(_Card(
      title: 'Vérifications',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CheckLine(
            done: base.isVerified,
            label: base.isVerified ? 'Profil vérifié (photo et selfie)' : 'Profil non vérifié',
            color: ZColors.verified),
        if (detail != null)
          _CheckLine(
              done: detail.isPhoneVerified,
              label: detail.isPhoneVerified ? 'Téléphone vérifié' : 'Téléphone non vérifié',
              color: ZColors.success),
        const SizedBox(height: 8),
        Text(
          'Ces badges indiquent uniquement les contrôles réalisés. Ils ne garantissent ni l’honnêteté ni les intentions d’une personne.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ]),
    ));

    if (_error != null && detail == null) {
      add(const InfoBanner(text: 'Certaines informations n’ont pas pu être chargées.', tone: BannerTone.warning));
    }
    return sections;
  }

  String _children(int count) => switch (count) {
        0 => 'Sans enfant',
        1 => '1 enfant',
        _ => '$count enfants',
      };
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.tinted = false});
  final String title;
  final Widget child;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tinted ? ZColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tinted ? ZColors.primarySoft : ZColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.done, required this.label, required this.color});
  final bool done;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(done ? Icons.verified : Icons.radio_button_unchecked, size: 20, color: done ? color : ZColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        ]),
      );
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

/// Barre d'actions en bas de la fiche : passer ou aimer.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onPass, required this.onLike});
  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.45],
            colors: [ZColors.bg.withValues(alpha: 0), ZColors.bg],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            child: Row(children: [
              Semantics(
                button: true,
                label: 'Passer',
                excludeSemantics: true,
                onTap: onPass,
                child: PressScale(
                  pressedScale: 0.9,
                  onTap: onPass,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: ZColors.line, width: 1.5),
                    ),
                    child: const Icon(Icons.close, color: ZColors.ink, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: GradientButton(label: 'J’aime ce profil', icon: Icons.favorite, onPressed: onLike)),
            ]),
          ),
        ),
      );
}
