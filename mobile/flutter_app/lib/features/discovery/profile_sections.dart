import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'photo_viewer.dart';
import 'profile_widgets.dart';

/// Photos d'un profil, l'une après l'autre : toucher la droite de la photo passe à la suivante, la gauche revient à
/// la précédente (segments en haut). Avec [swipeable], on peut aussi les faire glisser du doigt (fiche profil) ; sur
/// une carte de Découvrir, le glissement horizontal reste réservé à « J'aime » / « Passer ».
///
/// Ce que montre chaque photo est décidé par le serveur (0009) : nette, floutée (version fabriquée par le serveur,
/// avec un libellé honnête) ou privée (jamais affichée). Tant que la fiche n'est pas chargée, seule la photo
/// principale ([fallbackPath]) est connue.
class ProfilePhotoPager extends StatefulWidget {
  const ProfilePhotoPager({
    super.key,
    required this.name,
    required this.photos,
    this.fallbackPath,
    this.heroTag,
    this.heroShuttle,
    this.swipeable = false,
    this.onUnlock,
    this.onIndexChanged,
    this.topInset = 10,
  });

  final String name;
  final List<ProfilePhoto> photos;
  final String? fallbackPath;

  /// Hero de la première photo (vol de la carte vers la fiche) : toujours sur la première, jamais déplacé.
  final String? heroTag;
  final HeroFlightShuttleBuilder? heroShuttle;
  final bool swipeable;

  /// Ouvre l'offre Premium depuis une photo floutée par la règle du forfait.
  final VoidCallback? onUnlock;
  final ValueChanged<int>? onIndexChanged;

  /// Marge au-dessus des segments (barre d'état sur la fiche plein écran).
  final double topInset;

  @override
  State<ProfilePhotoPager> createState() => ProfilePhotoPagerState();
}

class ProfilePhotoPagerState extends State<ProfilePhotoPager> {
  late final PageController _pages = PageController();
  int _index = 0;
  final Set<String> _precached = <String>{};

  int get index => _index;

  List<ProfilePhoto> get _visible => PhotoViewerScreen.viewable(widget.photos);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
  }

  @override
  void didUpdateWidget(ProfilePhotoPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos != widget.photos) _precache();
  }

  /// Prépare toutes les photos à l'avance : passer à la suivante est alors immédiat, sans fond provisoire.
  void _precache() {
    final repo = Session.read(context).repo;
    for (final p in _visible) {
      final path = p.isBlurred ? p.blurPath : p.path;
      if (path == null || !_precached.add(path)) continue;
      repo.photoUrl(path, blurred: p.isBlurred).then((url) {
        if (url != null && mounted) precacheImage(NetworkImage(url), context, onError: (_, __) {});
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta, int count) {
    final next = (_index + delta).clamp(0, count - 1);
    if (next == _index) return;
    if (widget.swipeable && _pages.hasClients) {
      _pages.jumpToPage(next);
    } else {
      setState(() => _index = next);
      widget.onIndexChanged?.call(next);
    }
  }

  Widget _photo(ProfilePhoto? p, int i) {
    Widget image = p == null
        ? ProfilePhotoView(name: widget.name, photoPath: widget.fallbackPath, initialSize: 170)
        : ProfilePhotoView(
            name: widget.name,
            photoPath: p.isBlurred ? p.blurPath : p.path,
            blurred: p.isBlurred,
            initialSize: 170,
          );
    final tag = widget.heroTag;
    if (i == 0 && tag != null) image = Hero(tag: tag, flightShuttleBuilder: widget.heroShuttle, child: image);
    if (p == null || !p.isBlurred) return image;
    return Stack(fit: StackFit.expand, children: [image, _BlurredNotice(name: widget.name, photo: p, onUnlock: widget.onUnlock)]);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final count = visible.isEmpty ? 1 : visible.length;
    final index = _index.clamp(0, count - 1);
    final pages = widget.swipeable
        ? PageView.builder(
            controller: _pages,
            itemCount: count,
            allowImplicitScrolling: true,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onIndexChanged?.call(i);
            },
            itemBuilder: (context, i) => _photo(visible.isEmpty ? null : visible[i], i),
          )
        // Toutes les photos restent construites (chargées), une seule est peinte.
        : IndexedStack(
            index: index,
            sizing: StackFit.expand,
            children: [for (var i = 0; i < count; i++) _photo(visible.isEmpty ? null : visible[i], i)],
          );

    return Semantics(
      label: count > 1 ? 'Photo ${index + 1} sur $count de ${widget.name}' : 'Photo de ${widget.name}',
      child: Stack(fit: StackFit.expand, children: [
        pages,
        if (count > 1) ...[
          // Zones de toucher : un tiers à gauche pour revenir, le reste pour avancer.
          Positioned.fill(
            child: Row(children: [
              Expanded(
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _go(-1, count)),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _go(1, count)),
              ),
            ]),
          ),
          Positioned(
            top: widget.topInset,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: Row(children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: ZMotion.of(context, ZMotion.fast),
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: i == index ? 0.95 : 0.4),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Photo floutée : cadenas et explication honnête. Floutée par le forfait → visible nette avec Premium ; floutée par
/// sa propriétaire → Premium ne la rend pas nette (addendum V6.4 §2.2).
class _BlurredNotice extends StatelessWidget {
  const _BlurredNotice({required this.name, required this.photo, this.onUnlock});
  final String name;
  final ProfilePhoto photo;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final premium = !photo.blurredByOwner;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            premium ? 'Photo visible nette avec ZAYA Premium' : '$name a choisi de flouter cette photo',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
            ),
          ),
          if (premium && onUnlock != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ZColors.premium,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: onUnlock,
              child: const Text('Découvrir Premium'),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Pastilles d'informations posées sur la photo (ville, profession, projet de mariage…).
class PhotoInfoChip extends StatelessWidget {
  const PhotoInfoChip({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      );
}

/// Pastilles principales d'un profil, dans l'ordre où elles sont affichées sur la photo.
List<PhotoInfoChip> profileChips(DiscoveryProfile p, {ProfileDetail? detail}) => [
      if (p.city != null) PhotoInfoChip(icon: Icons.place_outlined, text: p.city!),
      if (p.profession != null) PhotoInfoChip(icon: Icons.work_outline, text: p.profession!),
      if (p.horizon != null && horizonLabels[p.horizon] != null)
        PhotoInfoChip(icon: Icons.favorite_border, text: 'Mariage : ${horizonLabels[p.horizon]}'),
      if (detail?.maritalStatus != null && maritalLabels[detail!.maritalStatus] != null)
        PhotoInfoChip(icon: Icons.people_outline, text: maritalLabels[detail.maritalStatus]!),
    ];

/// Informations d'un profil sous ses photos, dans les limites de ce que son propriétaire a choisi de montrer :
/// points communs, présentation, projet, « en bref », langues, centres d'intérêt, photos privées, vérifications.
/// Partagé par la carte de Découvrir (on glisse vers le haut) et par la fiche profil.
class ProfileInfoSections extends StatelessWidget {
  const ProfileInfoSections({
    super.key,
    required this.base,
    this.detail,
    this.error,
    this.onRetry,
    this.animate = true,
  });

  final DiscoveryProfile base;
  final ProfileDetail? detail;
  final String? error;
  final VoidCallback? onRetry;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context).me;
    final detail = this.detail;
    final textTheme = Theme.of(context).textTheme;
    final sections = <Widget>[];
    void add(Widget section) =>
        sections.add(animate ? FadeSlideIn(index: sections.length, child: section) : section);

    final points = me == null ? const <String>[] : commonPoints(me, base);
    if (points.isNotEmpty) {
      add(_InfoCard(
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
                Expanded(child: Text(point, style: textTheme.bodyLarge)),
              ]),
            ),
        ]),
      ));
    }

    if (base.bio != null && base.bio!.isNotEmpty) {
      add(_InfoCard(title: 'À propos', child: Text(base.bio!, style: textTheme.bodyLarge)));
    }

    if (base.horizon != null) {
      add(_InfoCard(
        title: 'Projet de mariage',
        child: Row(children: [
          const Icon(Icons.event_available_outlined, color: ZColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(horizonLabels[base.horizon] ?? '', style: textTheme.bodyLarge)),
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
      add(_InfoCard(title: 'En bref', child: Wrap(spacing: 8, runSpacing: 8, children: facts)));
    } else if (detail == null && error == null) {
      add(const Padding(padding: EdgeInsets.only(bottom: 14), child: Skeleton(height: 90)));
    }

    if (base.languages.isNotEmpty) {
      add(_InfoCard(
        title: 'Langues parlées',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in base.languages) ZTag(l, highlighted: me?.languages.contains(l) ?? false),
        ]),
      ));
    }
    if (base.interests.isNotEmpty) {
      add(_InfoCard(
        title: 'Centres d’intérêt',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final i in base.interests) ZTag(i, highlighted: me?.interests.contains(i) ?? false),
        ]),
      ));
    }

    if (detail != null && detail.hiddenPhotoCount > 0) {
      add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InfoBanner(
          icon: Icons.lock_outline,
          text: detail.hiddenPhotoCount == 1
              ? '1 photo est privée. Elle n’est visible que si ${base.displayName} vous y autorise.'
              : '${detail.hiddenPhotoCount} photos sont privées. Elles ne sont visibles que si ${base.displayName} vous y autorise.',
        ),
      ));
    }

    add(_InfoCard(
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
          style: textTheme.bodyMedium,
        ),
      ]),
    ));

    if (error != null && detail == null) {
      add(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const InfoBanner(text: 'Certaines informations n’ont pas pu être chargées.', tone: BannerTone.warning),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }

  static String _children(int count) => switch (count) {
        0 => 'Sans enfant',
        1 => '1 enfant',
        _ => '$count enfants',
      };
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child, this.tinted = false});
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
