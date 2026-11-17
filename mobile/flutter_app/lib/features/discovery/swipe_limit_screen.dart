import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../premium/premium_screens.dart';

/// Écran affiché quand le membre a utilisé ses swipes de la période (migration 0016 : 50 toutes les 8 h pour un
/// compte Gratuit). Compte à rebours réel jusqu'à la reprise (pas une offre limitée dans le temps) et accès à Premium.
class SwipeLimitScreen extends StatefulWidget {
  const SwipeLimitScreen({super.key, required this.resetsAt});
  final DateTime resetsAt;

  @override
  State<SwipeLimitScreen> createState() => _SwipeLimitScreenState();
}

class _SwipeLimitScreenState extends State<SwipeLimitScreen> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  static String _deux(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    _tick; // démarre le compte à rebours
    final reste = widget.resetsAt.difference(DateTime.now());
    final fini = reste.inSeconds <= 0;
    final secondes = fini ? 0 : reste.inSeconds;
    final h = secondes ~/ 3600, m = (secondes % 3600) ~/ 60, s = secondes % 60;
    final local = widget.resetsAt.toLocal();

    return Scaffold(
      backgroundColor: ZColors.bg,
      appBar: AppBar(
        backgroundColor: ZColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: ZColors.primarySoft,
              child: Icon(Icons.hourglass_bottom, color: ZColors.primary, size: 38),
            ),
          ),
          const SizedBox(height: 20),
          Text(fini ? 'Vos swipes sont de retour' : 'Vous avez utilisé tous vos swipes',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            fini
                ? 'Vous pouvez reprendre la découverte des profils.'
                : 'Ils reviennent dans',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (!fini) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Temps restant : $h heures $m minutes',
              child: ExcludeSemantics(
                child: Text('${_deux(h)}:${_deux(m)}:${_deux(s)}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: ZColors.primaryDark,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ),
            ),
            const SizedBox(height: 4),
            Text('Reprise à ${_deux(local.hour)} h ${_deux(local.minute)}',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 28),
          if (fini)
            GradientButton(label: 'Reprendre', icon: Icons.style, onPressed: () => Navigator.of(context).pop())
          else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ZColors.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.workspace_premium, color: ZColors.premium),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Sans attendre', style: Theme.of(context).textTheme.titleMedium)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Avec ZAYA Premium, vous disposez de beaucoup plus de swipes par période, '
                  'vous voyez qui vous a aimé et vous pouvez faire revenir plusieurs profils passés.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: 'Découvrir ZAYA Premium',
                  icon: Icons.workspace_premium,
                  onPressed: () => Navigator.of(context).push(zRoute<void>(const PremiumScreen())),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Revenir plus tard')),
          ],
        ]),
      ),
    );
  }
}
