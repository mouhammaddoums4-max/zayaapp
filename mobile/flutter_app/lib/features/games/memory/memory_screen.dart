import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/games_strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../game_widgets.dart';
import '../games_progress.dart';
import 'memory_game.dart';

const _symbolIcons = <String, IconData>{
  'heart': Icons.favorite_border,
  'ring': Icons.diamond_outlined,
  'home': Icons.home_outlined,
  'travel': Icons.flight_takeoff,
  'coffee': Icons.local_cafe_outlined,
  'book': Icons.menu_book_outlined,
  'moon': Icons.nights_stay_outlined,
  'sun': Icons.wb_sunny_outlined,
  'flower': Icons.spa_outlined,
  'music': Icons.music_note_outlined,
  'meal': Icons.restaurant_outlined,
  'nature': Icons.park_outlined,
  'beach': Icons.beach_access_outlined,
  'star': Icons.star_outline,
  'gift': Icons.card_giftcard,
  'family': Icons.family_restroom,
};

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, this.random});

  /// Tirage des cartes (fixé dans les tests).
  final Random? random;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  MemoryLevel _level = MemoryLevel.easy;
  late MemoryGame _game = MemoryGame(_level, random: widget.random);
  final Stopwatch _clock = Stopwatch();
  bool _showTimer = false;
  int? _best;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final timer = await GamesProgress.timerEnabled();
    final best = await GamesProgress.memoryBest(_level.name);
    if (mounted) {
      setState(() {
        _showTimer = timer;
        _best = best;
      });
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _newGame([MemoryLevel? level]) async {
    _hide?.cancel();
    _clock
      ..stop()
      ..reset();
    setState(() {
      _level = level ?? _level;
      _game = MemoryGame(_level, random: widget.random);
    });
    final best = await GamesProgress.memoryBest(_level.name);
    if (mounted) setState(() => _best = best);
  }

  void _tap(int index) {
    _hide?.cancel();
    final result = _game.flip(index);
    if (result == MemoryFlip.ignored) {
      setState(() {}); // un essai raté a pu être recaché
      return;
    }
    if (!_clock.isRunning) _clock.start();
    HapticFeedback.selectionClick();
    setState(() {});
    switch (result) {
      case MemoryFlip.mismatch:
        _hide = Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(_game.hideMismatch);
        });
      case MemoryFlip.match:
        if (_game.isComplete) _finished();
      case MemoryFlip.first:
      case MemoryFlip.ignored:
        break;
    }
  }

  Future<void> _finished() async {
    _clock.stop();
    HapticFeedback.mediumImpact();
    final record = await GamesProgress.recordMemoryScore(_level.name, _game.moves);
    final best = await GamesProgress.memoryBest(_level.name);
    if (!mounted) return;
    setState(() => _best = best);
    final gs = context.gs;
    await showGameSuccess(
      context,
      title: gs.wellDone,
      body: gs.memorySolvedBody(_game.moves),
      details: [
        formatGameDuration(_clock.elapsed),
        if (record) gs.memoryNewBest else if (best != null) gs.memoryBest(best),
      ],
      primaryLabel: gs.playAgain,
      onPrimary: _newGame,
      secondaryLabel: gs.backToGames,
      onSecondary: () => Navigator.of(context).pop(),
    );
  }

  Future<void> _toggleTimer() async {
    setState(() => _showTimer = !_showTimer);
    await GamesProgress.setTimerEnabled(_showTimer);
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return Scaffold(
      appBar: AppBar(
        title: Text(gs.gameName('memory')),
        actions: [
          IconButton(
            tooltip: _showTimer ? gs.timerOff : gs.timerOn,
            icon: Icon(_showTimer ? Icons.timer : Icons.timer_outlined),
            onPressed: _toggleTimer,
          ),
          IconButton(tooltip: gs.restart, icon: const Icon(Icons.restart_alt), onPressed: _newGame),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(children: [
            DifficultyPicker(
              levels: {for (final l in MemoryLevel.values) l.name: gs.memoryPairs(l.pairs)},
              selected: _level.name,
              onSelected: (name) => _newGame(MemoryLevel.values.byName(name)),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              GameStatChip(icon: Icons.touch_app_outlined, label: gs.memoryMoves(_game.moves)),
              GameStatChip(
                icon: Icons.favorite_border,
                label: gs.memoryFound(_game.pairsFound, _level.pairs),
                highlighted: _game.isComplete,
              ),
              if (_showTimer) GameClock(stopwatch: _clock),
            ]),
            if (_best != null) ...[
              const SizedBox(height: 6),
              Text(gs.memoryBest(_best!), style: GoogleFonts.inter(fontSize: 12.5, color: ZColors.muted)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                const gap = 10.0;
                final columns = _level.columns, rows = _level.rows;
                final byWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                final byHeight = (constraints.maxHeight - gap * (rows - 1)) / rows / 1.2;
                final width = min(byWidth, byHeight).clamp(44.0, 120.0);
                final height = width * 1.2;
                return Center(
                  child: SizedBox(
                    width: width * columns + gap * (columns - 1),
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < _game.cards.length; i++)
                          SizedBox(
                            key: ValueKey<String>('memory-card-$i'),
                            width: width,
                            height: height,
                            child: _MemoryCardView(
                              card: _game.cards[i],
                              label: gs.memorySymbol(_game.cards[i].symbol),
                              hiddenLabel: gs.memoryHiddenCard,
                              onTap: () => _tap(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MemoryCardView extends StatelessWidget {
  const _MemoryCardView({required this.card, required this.label, required this.hiddenLabel, required this.onTap});
  final MemoryCard card;
  final String label;
  final String hiddenLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visible = card.faceUp || card.matched;
    return Semantics(
      button: !visible,
      label: visible ? label : hiddenLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: visible ? 1 : 0),
          duration: ZMotion.of(context, ZMotion.medium),
          curve: Curves.easeInOut,
          builder: (context, t, _) {
            final showFront = t >= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(pi * t + (showFront ? pi : 0)),
              child: showFront ? _front(context) : _back(),
            );
          },
        ),
      ),
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, c) => Text('Z',
              style: GoogleFonts.sora(
                  fontSize: c.maxWidth * 0.36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.92))),
        ),
      );

  Widget _front(BuildContext context) => AnimatedContainer(
        duration: ZMotion.of(context, ZMotion.fast),
        decoration: BoxDecoration(
          color: card.matched ? ZColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: card.matched ? ZColors.primary : ZColors.line, width: card.matched ? 1.5 : 1),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final showLabel = c.maxHeight >= 84;
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_symbolIcons[card.symbol] ?? Icons.help_outline, size: c.maxWidth * 0.42, color: ZColors.primaryDark),
            if (showLabel) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: ZColors.ink)),
              ),
            ],
          ]);
        }),
      );
}
