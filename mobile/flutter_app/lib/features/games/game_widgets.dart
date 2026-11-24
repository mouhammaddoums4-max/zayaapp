import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/games_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Pastille d'information d'un jeu (coups, cases, chrono…).
class GameStatChip extends StatelessWidget {
  const GameStatChip({super.key, required this.icon, required this.label, this.highlighted = false});
  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: ZMotion.of(context, ZMotion.fast),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: highlighted ? ZColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: highlighted ? ZColors.primary : ZColors.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: highlighted ? ZColors.primaryDark : ZColors.muted),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? ZColors.primaryDark : ZColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

/// Bouton d'outil sous une grille (annuler, recommencer, indice) : grande zone tactile, icône et libellé.
class GameToolButton extends StatelessWidget {
  const GameToolButton({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? ZColors.ink : ZColors.muted.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onPressed,
        child: Container(
          width: 92,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: ZColors.line, width: 1.4),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

/// Chronomètre affiché (facultatif). Le temps est mesuré par le jeu ; ce widget ne fait que le rafraîchir.
class GameClock extends StatefulWidget {
  const GameClock({super.key, required this.stopwatch});
  final Stopwatch stopwatch;

  @override
  State<GameClock> createState() => _GameClockState();
}

class _GameClockState extends State<GameClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.stopwatch.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GameStatChip(icon: Icons.timer_outlined, label: formatGameDuration(widget.stopwatch.elapsed));
}

/// Fenêtre de réussite, commune à tous les jeux.
Future<void> showGameSuccess(
  BuildContext context, {
  required String title,
  required String body,
  List<String> details = const <String>[],
  required String primaryLabel,
  required VoidCallback onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: ZMotion.reduced(sheetContext) ? 1 : 0.6, end: 1),
            duration: ZMotion.of(sheetContext, ZMotion.slow),
            curve: ZMotion.spring,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(gradient: ZColors.brandGradient, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(sheetContext).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, height: 1.45, color: ZColors.ink)),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final d in details) ZTag(d)],
            ),
          ],
          const SizedBox(height: 24),
          GradientButton(
            label: primaryLabel,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onPrimary();
            },
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                onSecondary?.call();
              },
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: ZColors.ink),
              child: Text(secondaryLabel, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
    ),
  );
}

/// Sélecteur de difficulté (puces) commun aux jeux.
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({super.key, required this.levels, required this.selected, required this.onSelected});

  /// Identifiant (`easy`, `medium`, `hard`) → libellé complémentaire éventuel (« 6 paires »…).
  final Map<String, String?> levels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return Row(children: [
      for (final entry in levels.entries) ...[
        Expanded(
          child: Semantics(
            button: true,
            selected: entry.key == selected,
            child: PressScale(
              pressedScale: 0.97,
              onTap: () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: ZMotion.of(context, ZMotion.fast),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: entry.key == selected ? ZColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: entry.key == selected ? ZColors.primary : ZColors.line,
                    width: entry.key == selected ? 1.5 : 1,
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(gs.difficulty(entry.key),
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: entry.key == selected ? ZColors.primaryDark : ZColors.ink)),
                  if (entry.value != null)
                    Text(entry.value!, style: GoogleFonts.inter(fontSize: 11.5, color: ZColors.muted)),
                ]),
              ),
            ),
          ),
        ),
        if (entry.key != levels.keys.last) const SizedBox(width: 8),
      ],
    ]);
  }
}
