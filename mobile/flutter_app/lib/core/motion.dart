import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Durées et courbes d'animation ZAYA.
/// Toutes les animations respectent le réglage système « réduire les animations ».
class ZMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  static bool reduced(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}

/// Transition de page ZAYA : fondu + léger glissement vertical.
Route<T> zRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: ZMotion.medium,
    reverseTransitionDuration: ZMotion.fast,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, _, child) {
      if (ZMotion.reduced(context)) return child;
      final curve = CurveTween(curve: ZMotion.emphasized);
      return FadeTransition(
        opacity: animation.drive(curve),
        child: SlideTransition(
          position: animation.drive(Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).chain(curve)),
          child: child,
        ),
      );
    },
  );
}

/// Apparition en fondu + glissement, décalée selon [index] pour un effet de cascade dans les listes.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.distance = 18});
  final Widget child;
  final int index;
  final double distance;

  @override
  Widget build(BuildContext context) {
    if (ZMotion.reduced(context)) return child;
    final step = index < 0 ? 0 : (index > 8 ? 8 : index);
    final total = 280 + 55 * step;
    final start = (55 * step) / total;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1, curve: ZMotion.emphasized),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, (1 - t) * distance), child: child),
      ),
      child: child,
    );
  }
}

/// Réduit légèrement l'élément pendant l'appui, pour un retour tactile immédiat.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, required this.onTap, this.pressedScale = 0.95});
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: ZMotion.of(context, const Duration(milliseconds: 110)),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Bloc de chargement animé (reflet qui traverse), utilisé à la place d'un indicateur tournant.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = 14});
  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ZMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shift = -2 + 4 * _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(shift - 1, 0),
              end: Alignment(shift + 1, 0),
              colors: const [ZColors.line, Color(0xFFFAF5F8), ZColors.line],
            ),
          ),
        );
      },
    );
  }
}
