import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/games_strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../game_widgets.dart';
import 'word_scramble.dart';

/// Retrouve un mot par son identifiant (`null` : mot retiré du catalogue).
WordText? wordById(ZGameStrings gs, String id) {
  for (final w in gs.words) {
    if (w.id == id) return w;
  }
  return null;
}

/// Un mot à reconstituer : cases en haut, lettres mélangées en dessous, puis Effacer / Indice / Passer.
/// Appelle [onSolved] quand le mot est juste, [onSkip] quand le membre passe.
class WordBoard extends StatefulWidget {
  const WordBoard({
    super.key,
    required this.puzzle,
    required this.theme,
    required this.position,
    required this.total,
    required this.onSolved,
    required this.onSkip,
  });

  final WordPuzzle puzzle;
  final String theme;
  final int position;
  final int total;
  final VoidCallback onSolved;
  final VoidCallback onSkip;

  @override
  State<WordBoard> createState() => _WordBoardState();
}

class _WordBoardState extends State<WordBoard> {
  int _shake = 0;
  bool _wrong = false;
  bool _found = false;

  WordPuzzle get _p => widget.puzzle;

  void _check() {
    if (!_p.isFull) {
      setState(() => _wrong = false);
      return;
    }
    if (_p.isCorrect) {
      HapticFeedback.mediumImpact();
      setState(() {
        _found = true;
        _wrong = false;
      });
      widget.onSolved();
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _wrong = true;
        _shake++;
      });
    }
  }

  void _tapTile(int tile) {
    if (_found || !_p.place(tile)) return;
    HapticFeedback.selectionClick();
    _check();
  }

  void _tapSlot(int slot) {
    if (_found || !_p.removeAt(slot)) return;
    setState(() => _wrong = false);
  }

  void _clear() {
    if (_found) return;
    setState(() {
      _p.clear();
      _wrong = false;
    });
  }

  void _hint() {
    if (_found || _p.hint() == null) return;
    _check();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 6.0;
      final n = _p.answer.length;
      final slotSize = min(48.0, (constraints.maxWidth - gap * (n - 1)) / n);
      return Column(children: [
        Row(children: [
          GameStatChip(icon: Icons.label_outline, label: gs.wordTheme(widget.theme), highlighted: true),
          const Spacer(),
          Text(gs.wordOf(widget.position, widget.total),
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: ZColors.muted)),
        ]),
        const SizedBox(height: 28),
        TweenAnimationBuilder<double>(
          key: ValueKey<int>(_shake),
          tween: Tween<double>(begin: _shake == 0 || ZMotion.reduced(context) ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 420),
          builder: (context, t, child) =>
              Transform.translate(offset: Offset(sin(t * pi * 4) * (1 - t) * 10, 0), child: child),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _Slot(
                size: slotSize,
                letter: _p.slots[i] == null ? null : _p.tiles[_p.slots[i]!],
                locked: _p.locked.contains(i),
                state: _found ? _SlotState.found : (_wrong ? _SlotState.wrong : _SlotState.normal),
                onTap: () => _tapSlot(i),
              ),
            ],
          ]),
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: AnimatedSwitcher(
              duration: ZMotion.of(context, ZMotion.fast),
              child: Text(
                _found ? gs.wordFound : (_wrong ? gs.wordWrong : ''),
                key: ValueKey<String>('msg-$_found-$_wrong'),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _found ? ZColors.success : ZColors.primaryDark),
              ),
            ),
          ),
        ),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (var t = 0; t < _p.tiles.length; t++)
            _Tile(
              key: ValueKey<String>('tile-$t'),
              letter: _p.tiles[t],
              used: _p.isTileUsed(t),
              onTap: () => _tapTile(t),
            ),
        ]),
        const SizedBox(height: 14),
        Text(gs.wordTapLetters,
            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: ZColors.muted)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          GameToolButton(icon: Icons.backspace_outlined, label: gs.clear, onPressed: _found ? null : _clear),
          GameToolButton(icon: Icons.lightbulb_outline, label: gs.hint, onPressed: _found ? null : _hint),
          GameToolButton(icon: Icons.skip_next_outlined, label: gs.skip, onPressed: _found ? null : widget.onSkip),
        ]),
      ]);
    });
  }
}

enum _SlotState { normal, wrong, found }

class _Slot extends StatelessWidget {
  const _Slot({required this.size, required this.letter, required this.locked, required this.state, required this.onTap});
  final double size;
  final String? letter;
  final bool locked;
  final _SlotState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = switch (state) {
      _SlotState.found => ZColors.success,
      _SlotState.wrong => ZColors.danger,
      _SlotState.normal => letter == null ? ZColors.line : ZColors.ink,
    };
    return Semantics(
      label: letter ?? '_',
      button: letter != null && !locked,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: ZMotion.of(context, ZMotion.fast),
          width: size,
          height: size * 1.15,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state == _SlotState.found
                ? const Color(0xFFE3F5EE)
                : (locked ? ZColors.primarySoft : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: letter == null ? 1.2 : 1.8),
          ),
          child: Text(letter ?? '',
              style: GoogleFonts.sora(fontSize: size * 0.48, fontWeight: FontWeight.w700, color: ZColors.ink)),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.letter, required this.used, required this.onTap});
  final String letter;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: !used,
        label: letter,
        excludeSemantics: true,
        child: PressScale(
          onTap: used ? null : onTap,
          child: AnimatedOpacity(
            duration: ZMotion.of(context, ZMotion.fast),
            opacity: used ? 0.25 : 1,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: used ? const Color(0xFFF6F1F4) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ZColors.line, width: 1.4),
                boxShadow: used
                    ? null
                    : const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text(letter,
                  style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: ZColors.ink)),
            ),
          ),
        ),
      );
}
