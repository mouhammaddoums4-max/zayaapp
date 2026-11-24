import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/games_strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import 'would_you_rather.dart';

/// Retrouve le texte d'une question par son identifiant (`null` : question retirée du catalogue).
WyrText? wyrById(ZGameStrings gs, String id) {
  for (final q in gs.wyrQuestions) {
    if (q.id == id) return q;
  }
  return null;
}

/// Une question : deux grandes propositions séparées par « ou ».
/// En partie à deux, [partnerChoice] affiche le choix de l'autre (une fois que le membre a répondu).
class WyrQuestionCard extends StatelessWidget {
  const WyrQuestionCard({
    super.key,
    required this.question,
    required this.position,
    required this.total,
    required this.onChoose,
    this.selected,
    this.partnerChoice,
    this.partnerName,
  });

  final WyrText question;
  final int position;
  final int total;
  final String? selected;
  final String? partnerChoice;
  final String? partnerName;

  /// `null` : choix verrouillé (déjà répondu).
  final ValueChanged<String>? onChoose;

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        ZTag(gs.wyrTheme(question.theme), highlighted: true),
        const Spacer(),
        Text(gs.questionOf(position, total),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.muted)),
      ]),
      const SizedBox(height: 18),
      Text(gs.gameName('would_you_rather'), style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 18),
      _Option(
        text: question.a,
        selected: selected == wyrChoiceA,
        dimmed: selected != null && selected != wyrChoiceA,
        partner: partnerChoice == wyrChoiceA ? partnerName : null,
        onTap: onChoose == null ? null : () => onChoose!(wyrChoiceA),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(gs.wyrOr,
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: ZColors.muted)),
          ),
          const Expanded(child: Divider()),
        ]),
      ),
      _Option(
        text: question.b,
        selected: selected == wyrChoiceB,
        dimmed: selected != null && selected != wyrChoiceB,
        partner: partnerChoice == wyrChoiceB ? partnerName : null,
        onTap: onChoose == null ? null : () => onChoose!(wyrChoiceB),
      ),
    ]);
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.selected, required this.dimmed, this.partner, this.onTap});
  final String text;
  final bool selected;
  final bool dimmed;
  final String? partner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final duration = ZMotion.of(context, ZMotion.medium);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        pressedScale: 0.98,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: duration,
          opacity: dimmed ? 0.55 : 1,
          child: AnimatedContainer(
            duration: duration,
            curve: ZMotion.emphasized,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: selected ? ZColors.brandGradient : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: selected ? null : Border.all(color: ZColors.line, width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : ZColors.ink,
                ),
              ),
              if (selected || partner != null) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
                  if (selected) _Pill(label: context.gs.duoYourChoice, onBrand: true),
                  if (partner != null) _Pill(label: partner!, onBrand: selected),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onBrand});
  final String label;
  final bool onBrand;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: onBrand ? Colors.white.withValues(alpha: 0.22) : ZColors.primarySoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: onBrand ? Colors.white : ZColors.primaryDark)),
      );
}

/// Récapitulatif des choix d'une série (avec, à deux, ceux de l'autre membre).
class WyrSummaryList extends StatelessWidget {
  const WyrSummaryList({super.key, required this.ids, required this.mine, this.theirs, this.partnerName});
  final List<String> ids;
  final Map<int, String> mine;
  final Map<int, String>? theirs;
  final String? partnerName;

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return Column(children: [
      for (var i = 0; i < ids.length; i++)
        if (wyrById(gs, ids[i]) case final q?)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZColors.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(gs.wyrTheme(q.theme).toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: ZColors.muted)),
                const SizedBox(height: 6),
                _SummaryLine(label: gs.duoYourChoice, choice: _text(q, mine[i])),
                if (theirs != null) ...[
                  const SizedBox(height: 4),
                  _SummaryLine(
                    label: partnerName ?? '',
                    choice: _text(q, theirs![i]),
                    same: mine[i] != null && mine[i] == theirs![i],
                  ),
                ],
              ]),
            ),
          ),
    ]);
  }

  static String? _text(WyrText q, String? choice) => switch (choice) {
        wyrChoiceA => q.a,
        wyrChoiceB => q.b,
        _ => null,
      };
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.choice, this.same = false});
  final String label;
  final String? choice;
  final bool same;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 96,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.muted)),
        ),
        Expanded(
          child: Text(choice ?? '…',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: ZColors.ink, height: 1.3)),
        ),
        if (same) const Icon(Icons.favorite, size: 16, color: ZColors.primary),
      ]);
}
