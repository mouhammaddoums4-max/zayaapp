import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/zaya_icons.dart';
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
    this.onEdge,
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

  /// Toucher au-delà de la première (-1) ou de la dernière (1) photo : la carte peut répondre par un petit rebond.
  final ValueChanged<int>? onEdge;

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
        if (url != null && mounted) {
          precacheImage(zayaPhoto(url, path, blurred: p.isBlurred), context, onError: (_, __) {});
        }
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
    if (next == _index) {
      widget.onEdge?.call(delta);
      return;
    }
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
    return Stack(
        fit: StackFit.expand,
        children: [image, _BlurredNotice(name: widget.name, photo: p, onUnlock: widget.onUnlock)]);
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
        // Zones de toucher : un tiers à gauche pour revenir, le reste pour avancer (avec une seule photo, seulement
        // pour le rebond de la carte).
        if (count > 1 || widget.onEdge != null)
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
        if (count > 1)
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

/// Prénom en gras et âge plus léger, comme une signature : « Awa 27 ». Lu « Awa, 27 ans » par le lecteur d'écran.
class ProfileNameAge extends StatelessWidget {
  const ProfileNameAge({super.key, required this.name, this.age, this.size = 32, this.color = Colors.white});
  final String name;
  final int? age;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: name,
              style: GoogleFonts.sora(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.1)),
          if (age != null)
            TextSpan(
                text: ' $age',
                style:
                    GoogleFonts.inter(fontSize: size * 0.92, fontWeight: FontWeight.w400, color: color, height: 1.1)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: age == null ? name : '$name, $age ans',
      );
}

/// Lignes d'informations sous le nom, sur la photo : ville, puis profession.
class ProfileCoverLines extends StatelessWidget {
  const ProfileCoverLines({super.key, required this.profile});
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    final lines = <(IconData, String)>[
      if (profile.city != null) (Icons.place_outlined, profile.city!),
      if (profile.profession != null) (Icons.work_outline_rounded, profile.profession!),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final (icon, text) in lines)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.92)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: const [Shadow(color: Color(0x55000000), blurRadius: 8)])),
            ),
          ]),
        ),
    ]);
  }
}

/// Pastille blanche posée sur la photo, au-dessus du nom (« Premium »).
class ProfileCoverBadge extends StatelessWidget {
  const ProfileCoverBadge({super.key, required this.icon, required this.text, this.color = ZColors.primary});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: ZColors.ink)),
        ]),
      );
}

/// Pastilles d'un profil posées sur sa photo, tirées de données réelles (Premium). Les points communs ne sont plus
/// affichés (demande du propriétaire).
List<Widget> profileCoverBadges(MyProfile? me, DiscoveryProfile p) => [
      if (p.isPremium)
        const ProfileCoverBadge(icon: Icons.workspace_premium_rounded, text: 'Premium', color: ZColors.premium),
    ];

/// Informations d'un profil sous ses photos, dans les limites de ce que son propriétaire a choisi de montrer, en
/// encadrés lisibles d'un coup d'œil : projet de mariage, présentation, l'essentiel, langues, centres d'intérêt,
/// photos privées, vérifications. Partagé par la carte de l'onglet Mariage (on la fait défiler) et par la fiche
/// profil. Les points communs ne sont plus affichés (demande du propriétaire), ni mis en avant dans les étiquettes.
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
    final detail = this.detail;
    final sections = <Widget>[];
    void add(Widget section) => sections.add(animate ? FadeSlideIn(index: sections.length, child: section) : section);

    if (base.horizon != null && horizonLabels[base.horizon] != null) {
      add(_InfoBox(
        leading: const ZIcon(ZGlyph.ring, size: 20, color: ZColors.muted),
        title: 'Projet de mariage',
        child: Text(horizonLabels[base.horizon]!,
            style: GoogleFonts.sora(fontSize: 23, fontWeight: FontWeight.w700, color: ZColors.ink, height: 1.25)),
      ));
    }

    if (base.bio != null && base.bio!.trim().isNotEmpty) {
      add(_InfoBox(
        icon: Icons.format_quote_rounded,
        title: 'À propos de moi',
        child: Text(base.bio!.trim(),
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w500, color: ZColors.ink, height: 1.45)),
      ));
    }

    final facts = <(IconData, String)>[
      if (base.city != null) (Icons.place_outlined, base.city!),
      if (base.profession != null) (Icons.work_outline_rounded, base.profession!),
      if (detail?.maritalStatus != null)
        (Icons.people_outline, maritalLabels[detail!.maritalStatus] ?? detail.maritalStatus!),
      if (detail?.childrenCount != null) (Icons.child_care_outlined, _children(detail!.childrenCount!)),
      if (detail?.education != null) (Icons.school_outlined, detail!.education!),
      if (detail?.heightCm != null) (Icons.height_rounded, '${detail!.heightCm} cm'),
      if (detail?.confession != null)
        (Icons.self_improvement, confessionLabels[detail!.confession] ?? detail.confession!),
      if (detail?.ethnicGroup != null) (Icons.public, detail!.ethnicGroup!),
    ];
    if (detail == null && error == null) {
      add(const Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 150, radius: 24)));
    } else if (facts.isNotEmpty) {
      add(_InfoBox(
        icon: Icons.badge_outlined,
        title: 'L’essentiel',
        child: Column(children: [for (final (icon, text) in facts) _FactLine(icon: icon, text: text)]),
      ));
    }

    if (base.languages.isNotEmpty) {
      add(_InfoBox(
        icon: Icons.translate_rounded,
        title: 'Langues parlées',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in base.languages) ZTag(l),
        ]),
      ));
    }
    if (base.interests.isNotEmpty) {
      add(_InfoBox(
        icon: Icons.interests_outlined,
        title: 'Centres d’intérêt',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final i in base.interests) ZTag(i),
        ]),
      ));
    }

    if (detail != null && detail.hiddenPhotoCount > 0) {
      add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InfoBanner(
          icon: Icons.lock_outline,
          text: detail.hiddenPhotoCount == 1
              ? '1 photo est privée. Elle n’est visible que si ${base.displayName} vous y autorise.'
              : '${detail.hiddenPhotoCount} photos sont privées. Elles ne sont visibles que si ${base.displayName} vous y autorise.',
        ),
      ));
    }

    add(_InfoBox(
      icon: Icons.verified_user_outlined,
      title: 'Vérifications',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FactLine(
          icon: base.isVerified ? Icons.verified : Icons.radio_button_unchecked,
          iconColor: base.isVerified ? ZColors.verified : ZColors.muted,
          text: base.isVerified ? 'Profil vérifié (photo et selfie)' : 'Profil non vérifié',
        ),
        if (detail != null)
          _FactLine(
            icon: detail.isPhoneVerified ? Icons.verified : Icons.radio_button_unchecked,
            iconColor: detail.isPhoneVerified ? ZColors.success : ZColors.muted,
            text: detail.isPhoneVerified ? 'Téléphone vérifié' : 'Téléphone non vérifié',
          ),
        const SizedBox(height: 10),
        Text(
          'Ces badges indiquent uniquement les contrôles réalisés. Ils ne garantissent ni l’honnêteté ni les intentions d’une personne.',
          style: Theme.of(context).textTheme.bodyMedium,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections);
  }

  static String _children(int count) => switch (count) {
        0 => 'Sans enfant',
        1 => '1 enfant',
        _ => '$count enfants',
      };
}

/// Encadré d'informations : une petite icône et un intitulé discret, puis le contenu, en grand.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.child, this.icon, this.leading});
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ZColors.line),
          boxShadow: const [BoxShadow(color: Color(0x0A1B1020), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            leading ?? Icon(icon, size: 20, color: ZColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: ZColors.muted)),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// Ligne « icône + texte » d'un encadré (l'essentiel, vérifications).
class _FactLine extends StatelessWidget {
  const _FactLine({required this.icon, required this.text, this.iconColor = ZColors.muted});
  final IconData icon;
  final String text;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 22, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:
                    GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w500, color: ZColors.ink, height: 1.35)),
          ),
        ]),
      );
}
