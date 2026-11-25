import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';

/// Les actions proposées sous la carte de l'onglet Mariage.
enum SwipeAction { rewind, pass, like, flower }

/// Fond des boutons d'action : aubergine très sombre, lisible sur la photo comme sur la fiche.
const _buttonFill = Color(0xF0231A27);

/// Or du bouton « Revenir », éclairci pour rester lisible sur fond sombre.
const _rewindGold = Color(0xFFF2C25C);

/// Bouton rond d'action, alternative accessible au geste de glissement.
///
/// [highlight] (0 à 1) suit le geste : quand la carte part vers ce bouton, il grossit et se remplit de sa couleur ;
/// [dim] (0 à 1) l'efface quand la carte part de l'autre côté. Chaque appui a sa propre animation : rebond et éclat
/// de cœurs pour « J'aime », croix qui pivote pour « Passer », flèche qui fait un tour à l'envers pour « Revenir »,
/// fleur qui s'épanouit (Premium). Tout reste immobile quand le système demande de réduire les animations.
class SwipeActionButton extends StatefulWidget {
  const SwipeActionButton({
    super.key,
    required this.action,
    required this.label,
    required this.onTap,
    this.highlight = 0,
    this.dim = 0,
  });

  final SwipeAction action;
  final String label;
  final VoidCallback onTap;
  final double highlight;
  final double dim;

  bool get large => action == SwipeAction.pass || action == SwipeAction.like;

  @override
  State<SwipeActionButton> createState() => _SwipeActionButtonState();
}

class _SwipeActionButtonState extends State<SwipeActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _tap = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  bool _down = false;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  void _press() {
    switch (widget.action) {
      case SwipeAction.like:
        HapticFeedback.mediumImpact();
      case SwipeAction.pass:
      case SwipeAction.flower:
        HapticFeedback.lightImpact();
      case SwipeAction.rewind:
        HapticFeedback.selectionClick();
    }
    if (!ZMotion.reduced(context)) _tap.forward(from: 0);
    widget.onTap();
  }

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  /// Rebond de l'appui : le bouton se tasse, dépasse un peu sa taille, puis se repose.
  static final Animatable<double> _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.84).chain(CurveTween(curve: Curves.easeOut)), weight: 18),
    TweenSequenceItem(tween: Tween(begin: 0.84, end: 1.14).chain(CurveTween(curve: Curves.easeOut)), weight: 34),
    TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 48),
  ]);

  @override
  Widget build(BuildContext context) {
    final size = widget.large ? 68.0 : 50.0;
    final iconSize = widget.large ? 34.0 : 24.0;
    final h = widget.highlight.clamp(0.0, 1.0).toDouble();
    final d = widget.dim.clamp(0.0, 1.0).toDouble();
    final action = widget.action;

    return Semantics(
      // Chaque bouton a son propre nœud d'accessibilité (jamais fusionné avec un voisin).
      container: true,
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: _press,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          onTap: _press,
          child: Opacity(
            opacity: 1 - 0.55 * d,
            child: AnimatedScale(
              scale: _down ? 0.9 : 1,
              duration: ZMotion.of(context, const Duration(milliseconds: 110)),
              curve: Curves.easeOut,
              child: AnimatedBuilder(
                animation: _tap,
                builder: (context, _) {
                  final t = _tap.value;
                  final pop = _tap.isAnimating ? _pop.transform(t) : 1.0;
                  final scale = pop * (1 + 0.16 * h - 0.12 * d);
                  return Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Stack(clipBehavior: Clip.none, children: [
                        // Éclat autour du bouton pendant l'animation d'appui.
                        if (_tap.isAnimating && action != SwipeAction.pass)
                          Positioned(
                            left: -size * 0.7,
                            top: -size * 0.7,
                            right: -size * 0.7,
                            bottom: -size * 0.7,
                            child: IgnorePointer(
                              child: CustomPaint(painter: _BurstPainter(t: t, action: action)),
                            ),
                          ),
                        _disc(size, h),
                        Center(child: _icon(iconSize, h, t)),
                        if (action == SwipeAction.flower)
                          const Positioned(
                            top: 0,
                            right: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: ZColors.premium, shape: BoxShape.circle),
                              child: Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Disque du bouton : fond sombre, puis la couleur de l'action qui monte avec [h].
  Widget _disc(double size, double h) {
    final action = widget.action;
    final glow = switch (action) {
      SwipeAction.like => ZColors.primary,
      SwipeAction.flower => ZColors.premium,
      SwipeAction.rewind => _rewindGold,
      SwipeAction.pass => Colors.white,
    };
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _buttonFill,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 5)),
            if (h > 0) BoxShadow(color: glow.withValues(alpha: 0.55 * h), blurRadius: 26, spreadRadius: 1),
          ],
        ),
      ),
      if (h > 0)
        Opacity(
          opacity: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: action == SwipeAction.like || action == SwipeAction.flower ? ZColors.brandGradient : null,
              color: switch (action) {
                SwipeAction.pass => Colors.white,
                SwipeAction.rewind => _rewindGold,
                _ => null,
              },
            ),
          ),
        ),
    ]);
  }

  Widget _icon(double size, double h, double t) {
    final animating = _tap.isAnimating;
    switch (widget.action) {
      case SwipeAction.like:
        return _onFill(h, Icons.favorite_rounded, size, rest: _BrandIcon(Icons.favorite_rounded, size: size));
      case SwipeAction.flower:
        final bloom = animating ? math.sin(math.pi * t) : 0.0;
        return Transform.scale(
          scale: 1 + 0.18 * bloom,
          child: Transform.rotate(
            angle: animating ? 0.12 * math.sin(2 * math.pi * t) : 0,
            child: _onFill(h, Icons.local_florist_rounded, size,
                rest: _BrandIcon(Icons.local_florist_rounded, size: size)),
          ),
        );
      case SwipeAction.pass:
        // La croix fait un quart de tour en rebondissant.
        final turn = animating ? Curves.easeOutBack.transform(t) * math.pi / 2 : 0.0;
        return Transform.rotate(
          angle: turn,
          child: Icon(Icons.close_rounded, size: size, color: Color.lerp(Colors.white, ZColors.ink, h)),
        );
      case SwipeAction.rewind:
        // La flèche fait un tour complet à l'envers : on « rembobine ».
        final turn = animating ? -Curves.easeInOutCubic.transform(t) * 2 * math.pi : 0.0;
        return Transform.rotate(
          angle: turn,
          child: Icon(Icons.replay_rounded, size: size, color: Color.lerp(_rewindGold, Colors.white, h)),
        );
    }
  }

  /// Icône au dégradé de marque au repos, blanche quand le bouton se remplit.
  Widget _onFill(double h, IconData icon, double size, {required Widget rest}) {
    if (h <= 0) return rest;
    return Stack(alignment: Alignment.center, children: [
      Opacity(opacity: 1 - h, child: rest),
      Opacity(opacity: h, child: Icon(icon, size: size, color: Colors.white)),
    ]);
  }
}

/// Icône peinte avec le dégradé de marque.
class _BrandIcon extends StatelessWidget {
  const _BrandIcon(this.icon, {required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => ZColors.brandGradient.createShader(bounds),
        child: Icon(icon, size: size, color: Colors.white),
      );
}

/// Éclat d'un appui : un anneau qui s'élargit en s'effaçant, et de petites particules qui s'envolent
/// (des cœurs pour « J'aime », des éclats pour la fleur et le retour).
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.action});
  final double t;
  final SwipeAction action;

  static const _likeColors = [ZColors.gradientStart, ZColors.gradientEnd, Color(0xFFFF7AA2)];
  static const _flowerColors = [ZColors.premium, Color(0xFFFFD27A), ZColors.gradientStart];
  static const _rewindColors = [_rewindGold, Color(0xFFFFE3A3)];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final colors = switch (action) {
      SwipeAction.like => _likeColors,
      SwipeAction.flower => _flowerColors,
      _ => _rewindColors,
    };
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 / 2.4; // rayon du bouton (la zone déborde de 0,7 × sa taille de chaque côté)
    final grow = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();

    canvas.drawCircle(
      center,
      radius * (1 + 0.55 * grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * fade
        ..color = colors.first.withValues(alpha: 0.85 * fade),
    );

    final hearts = action == SwipeAction.like;
    final count = hearts ? 8 : 7;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / count + (i.isEven ? 0.18 : -0.12);
      final distance = radius * (1.0 + (hearts ? 0.95 : 0.75) * grow) + (i.isEven ? 4 : 0);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: fade);
      final s = (hearts ? 6.0 : 3.2) * (1 - 0.45 * t);
      if (hearts) {
        canvas.drawPath(_heart(p, s), paint);
      } else {
        canvas.drawCircle(p, s, paint);
      }
    }
  }

  static Path _heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s * 0.9)
    ..cubicTo(c.dx - s * 1.5, c.dy - s * 0.1, c.dx - s * 0.75, c.dy - s * 1.25, c.dx, c.dy - s * 0.45)
    ..cubicTo(c.dx + s * 0.75, c.dy - s * 1.25, c.dx + s * 1.5, c.dy - s * 0.1, c.dx, c.dy + s * 0.9)
    ..close();

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.action != action;
}
