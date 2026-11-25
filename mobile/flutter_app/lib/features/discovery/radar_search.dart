import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import 'profile_widgets.dart';

/// Profil trouvé, affiché en petit autour du radar.
typedef RadarProfile = ({String id, String name, String? photoPath});

/// Recherche animée de l'onglet Mariage, avant l'affichage des profils : la photo du membre au centre, des ondes
/// qui s'élargissent, un balayage qui tourne, et les profils trouvés qui apparaissent un à un autour.
///
/// Le fond (anneaux, ondes, balayage, points) est dessiné par un seul peintre dans sa propre couche : l'animation
/// ne reconstruit aucun widget, ce qui la garde fluide sur les téléphones modestes. Avec « réduire les animations »,
/// l'image est fixe.
class RadarSearch extends StatefulWidget {
  const RadarSearch({
    super.key,
    required this.name,
    required this.title,
    required this.subtitle,
    this.photoPath,
    this.found = const <RadarProfile>[],
  });

  /// Prénom et photo principale du membre, au centre.
  final String name;
  final String? photoPath;

  /// Profils déjà trouvés : les cinq premiers apparaissent autour du centre.
  final List<RadarProfile> found;

  /// Textes de la pastille du bas (fournis par l'écran, depuis lib/core/l10n).
  final String title;
  final String subtitle;

  @override
  State<RadarSearch> createState() => _RadarSearchState();
}

class _RadarSearchState extends State<RadarSearch> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  // Places des profils trouvés : angle (radians, 0 = à droite) et distance au centre (part du rayon).
  static const _slots = <(double, double)>[
    (-2.25, 0.80), // en haut à gauche
    (-0.55, 0.86), // en haut à droite
    (2.75, 0.74), // à gauche
    (0.35, 0.70), // à droite
    (1.75, 0.88), // en bas
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ZMotion.reduced(context)) {
      _spin
        ..stop()
        ..value = 0.3;
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.title} ${widget.subtitle}',
      liveRegion: true,
      child: LayoutBuilder(builder: (context, box) {
        final side = math.min(box.maxWidth, box.maxHeight - 110).clamp(220.0, 420.0).toDouble();
        final radius = side / 2;
        final center = (side / 2) * 0.36 < 46 ? 46.0 : (side / 2) * 0.36; // rayon de la photo centrale
        final found = widget.found.take(_slots.length).toList();
        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: side,
            height: side,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _RadarPainter(_spin, inner: center / radius)),
                ),
              ),
              for (var i = 0; i < found.length; i++) _orbit(found[i], i, radius, side),
              _CenterPhoto(name: widget.name, photoPath: widget.photoPath, size: center * 2),
            ]),
          ),
          const SizedBox(height: 26),
          _StatusPill(title: widget.title, subtitle: widget.subtitle, animation: _spin),
        ]);
      }),
    );
  }

  Widget _orbit(RadarProfile p, int i, double radius, double side) {
    final (angle, distance) = _slots[i];
    final size = (side * 0.17).clamp(44.0, 64.0).toDouble();
    final dx = radius + math.cos(angle) * radius * distance - size / 2;
    final dy = radius + math.sin(angle) * radius * distance - size / 2;
    return Positioned(
      key: ValueKey<String>(p.id),
      left: dx,
      top: dy,
      child: _PopIn(
        delay: Duration(milliseconds: 160 * i),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: ZColors.primary.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 5))
            ],
          ),
          child: ClipOval(
            child: ProfilePhotoView(name: p.name, photoPath: p.photoPath, avatar: true, initialSize: size * 0.4),
          ),
        ),
      ),
    );
  }
}

/// Photo du membre au centre : anneau au dégradé de la marque, bord blanc, ombre douce.
class _CenterPhoto extends StatelessWidget {
  const _CenterPhoto({required this.name, required this.photoPath, required this.size});
  final String name;
  final String? photoPath;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ZColors.brandGradient,
          boxShadow: [
            BoxShadow(color: ZColors.primary.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 10))
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: ClipOval(
            child: ProfilePhotoView(name: name, photoPath: photoPath, avatar: true, initialSize: size * 0.4),
          ),
        ),
      );
}

/// Apparition d'un profil trouvé : léger rebond, après [delay].
class _PopIn extends StatefulWidget {
  const _PopIn({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _scale = CurvedAnimation(parent: _c, curve: ZMotion.spring);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ZMotion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: ScaleTransition(scale: _scale, child: widget.child));
}

/// Pastille du bas : icône, titre et sous-titre avec des points de suspension animés.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.title, required this.subtitle, required this.animation});
  final String title;
  final String subtitle;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 22, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(color: ZColors.primary.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: ZColors.primarySoft),
            child: const Icon(Icons.radar_rounded, color: ZColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ZColors.ink)),
            _Dots(text: subtitle, animation: animation),
          ]),
        ]),
      );
}

/// Sous-titre suivi de 1 à 3 points ; ne se reconstruit que lorsque le nombre de points change.
class _Dots extends StatefulWidget {
  const _Dots({required this.text, required this.animation});
  final String text;
  final Animation<double> animation;

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> {
  int _n = 3;

  int get _count => 1 + (widget.animation.value * 3).floor() % 3;

  void _tick() {
    final n = _count;
    if (n != _n) setState(() => _n = n);
  }

  @override
  void initState() {
    super.initState();
    _n = _count;
    widget.animation.addListener(_tick);
  }

  @override
  void dispose() {
    widget.animation.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: ZColors.primaryDark);
    // Largeur fixe pour les points : le texte ne bouge pas quand leur nombre change.
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.text, style: style),
      SizedBox(width: 16, child: Text('.' * _n, style: style)),
    ]);
  }
}

/// Anneaux, ondes qui s'élargissent, balayage qui tourne et points qui scintillent.
class _RadarPainter extends CustomPainter {
  _RadarPainter(this.animation, {required this.inner}) : super(repaint: animation);
  final Animation<double> animation;

  /// Rayon de la photo centrale, en part du rayon total (les ondes partent de son bord).
  final double inner;

  static const _dots = <(double, double, double)>[
    // angle, distance, phase
    (-1.2, 0.56, 0.0), (0.9, 0.93, 0.3), (2.2, 0.52, 0.55), (-2.8, 0.95, 0.8),
    (1.3, 0.40, 0.15), (-0.2, 0.42, 0.65), (2.9, 0.38, 0.4), (-1.75, 0.97, 0.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const color = ZColors.primary;

    // Fond doux, plus soutenu au centre.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0.03),
          color.withValues(alpha: 0),
        ], stops: const [
          0,
          0.6,
          1
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Anneaux fixes.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final k in const [0.48, 0.66, 0.84, 1.0]) {
      ring.color = color.withValues(alpha: 0.10 + 0.08 * (1 - k));
      canvas.drawCircle(c, r * k - 0.5, ring);
    }

    // Deux ondes décalées qui partent du bord de la photo et s'effacent en s'élargissent.
    for (var i = 0; i < 2; i++) {
      final p = (t * 2 + i / 2) % 1;
      final radius = r * (inner + (1 - inner) * p);
      canvas.drawCircle(c, radius, Paint()..color = color.withValues(alpha: 0.07 * (1 - p)));
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.30 * (1 - p)),
      );
    }

    // Balayage : un quart de cercle en dégradé qui tourne.
    final angle = t * 2 * math.pi;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0), color.withValues(alpha: 0.22)],
          stops: const [0, 0.72, 1],
          transform: GradientRotation(angle),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Points qui scintillent, plus brillants quand le balayage passe dessus.
    final dot = Paint();
    for (final (a, d, phase) in _dots) {
      final behind = ((angle - a) % (2 * math.pi)) / (2 * math.pi); // 0 = le balayage vient de passer
      final glow = behind < 0.25 ? 1 - behind / 0.25 : 0.0;
      final twinkle = 0.5 + 0.5 * math.sin((t + phase) * 2 * math.pi);
      dot.color = color.withValues(alpha: 0.25 + 0.25 * twinkle + 0.45 * glow);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r * d), 3 + 1.5 * glow, dot);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.inner != inner;
}
