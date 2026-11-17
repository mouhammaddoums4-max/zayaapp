import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Bouton « Booster mon profil » de l'en-tête de Découvrir.
///
/// La flamme (rappel du logo ZAYA) s'anime brièvement de temps en temps pour signaler la fonction.
/// L'animation ne bloque jamais l'interaction et reste immobile quand le système demande de
/// réduire les animations (CDC §13).
class BoostButton extends StatefulWidget {
  const BoostButton({super.key});

  @override
  State<BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<BoostButton> with SingleTickerProviderStateMixin {
  /// Une flambée dure un peu plus d'une seconde et revient toutes les 7 secondes.
  static const _burn = Duration(milliseconds: 1100);
  static const _every = Duration(seconds: 7);
  static const _firstDelay = Duration(milliseconds: 1500);

  late final AnimationController _flame = AnimationController(vsync: this, duration: _burn);
  Timer? _timer;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = ZMotion.reduced(context);
    if (reduced == _reduced && (_timer != null || reduced)) return;
    _reduced = reduced;
    _timer?.cancel();
    _timer = null;
    if (reduced) {
      _flame.value = 0;
      return;
    }
    Future<void>.delayed(_firstDelay, _burnOnce);
    _timer = Timer.periodic(_every, (_) => _burnOnce());
  }

  void _burnOnce() {
    if (mounted && !_reduced) _flame.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Booster mon profil',
      onPressed: () => showBoostSheet(context),
      icon: AnimatedBuilder(
        animation: _flame,
        builder: (context, child) {
          final t = _flame.value;
          // La flamme gonfle puis revient, avec un vacillement qui s'amortit.
          final scale = 1 + 0.2 * math.sin(math.pi * t);
          final angle = 0.12 * math.sin(4 * math.pi * t) * (1 - t);
          return Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
          );
        },
        child: const _Flame(size: 26),
      ),
    );
  }
}

/// Icône de flamme aux couleurs du dégradé de marque.
class _Flame extends StatelessWidget {
  const _Flame({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => ZColors.brandGradient.createShader(bounds),
        child: Icon(Icons.local_fire_department_rounded, size: size, color: Colors.white),
      );
}

/// Explique le Boost. L'achat reste fermé tant que le prix, la durée et les paiements ne sont pas
/// activés depuis l'administration (CDC §22.6, décision C7 : `payments_enabled = false`) :
/// aucun prix ni aucune durée n'est écrit dans l'application.
Future<void> showBoostSheet(BuildContext context) {
  final verified = Session.read(context).me?.isVerified ?? false;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: ZColors.primarySoft, shape: BoxShape.circle),
              child: const Center(child: _Flame(size: 38)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Booster mon profil', textAlign: TextAlign.center, style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Pendant une durée limitée, votre profil gagne en visibilité auprès des membres qui correspondent '
            'à vos préférences. Le Boost ne contourne jamais leurs filtres, leurs blocages ni leurs réglages '
            'de confidentialité.',
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const InfoBanner(
            icon: Icons.schedule,
            text: 'Bientôt disponible : le prix et les moyens de paiement ne sont pas encore activés.',
          ),
          if (!verified) ...[
            const SizedBox(height: 8),
            const InfoBanner(
              tone: BannerTone.warning,
              icon: Icons.verified_outlined,
              text: 'Votre profil doit d’abord être vérifié pour apparaître dans Découvrir.',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Compris')),
        ]),
      ),
    ),
  );
}
