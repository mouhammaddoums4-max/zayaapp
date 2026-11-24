import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/games_strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../game_widgets.dart';
import '../games_progress.dart';
import 'path_board.dart';
import 'path_levels.dart';
import 'path_puzzle.dart';

List<PathLevel> levelsOf(PathDifficulty difficulty) =>
    [for (final l in pathLevels) if (l.difficulty == difficulty) l];

/// Un niveau est ouvert s'il est le premier de sa difficulté, s'il est déjà réussi, ou si le précédent l'est.
bool isPathLevelUnlocked(List<PathLevel> levels, int index, Set<String> done) =>
    index == 0 || done.contains(levels[index].id) || done.contains(levels[index - 1].id);

/// Liste des niveaux de Connexion mystère, par difficulté.
class PathLevelsScreen extends StatefulWidget {
  const PathLevelsScreen({super.key});

  @override
  State<PathLevelsScreen> createState() => _PathLevelsScreenState();
}

class _PathLevelsScreenState extends State<PathLevelsScreen> {
  PathDifficulty _difficulty = PathDifficulty.easy;
  Set<String> _done = const <String>{};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload(pickDifficulty: true);
  }

  Future<void> _reload({bool pickDifficulty = false}) async {
    final done = await GamesProgress.pathCompleted();
    if (!mounted) return;
    setState(() {
      _done = done;
      _loaded = true;
      // À l'ouverture : la première difficulté qui n'est pas entièrement réussie.
      if (pickDifficulty) {
        _difficulty = PathDifficulty.values.firstWhere(
          (d) => levelsOf(d).any((l) => !done.contains(l.id)),
          orElse: () => PathDifficulty.easy,
        );
      }
    });
  }

  Future<void> _open(List<PathLevel> levels, int index) async {
    await Navigator.of(context).push(zRoute<void>(PathPuzzleScreen(levels: levels, index: index)));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    final levels = levelsOf(_difficulty);
    final doneHere = levels.where((l) => _done.contains(l.id)).length;
    final nextIndex = levels.indexWhere((l) => !_done.contains(l.id));
    return Scaffold(
      appBar: AppBar(title: Text(gs.gameName('path_puzzle'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        InfoBanner(icon: Icons.route, text: gs.pathRules),
        const SizedBox(height: 16),
        DifficultyPicker(
          levels: {
            for (final d in PathDifficulty.values) d.name: '${levelsOf(d).first.size} × ${levelsOf(d).last.size}',
          },
          selected: _difficulty.name,
          onSelected: (name) => setState(() => _difficulty = PathDifficulty.values.byName(name)),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: SectionTitle(gs.difficulty(_difficulty.name))),
          if (_loaded) GameStatChip(icon: Icons.check_circle_outline, label: gs.pathLevelsDone(doneHere, levels.length)),
        ]),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 76,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: levels.length,
          itemBuilder: (context, i) {
            final done = _done.contains(levels[i].id);
            final locked = !isPathLevelUnlocked(levels, i, _done);
            return FadeSlideIn(
              index: i,
              child: _LevelTile(
                number: i + 1,
                done: done,
                locked: locked,
                current: i == nextIndex,
                onTap: locked ? () => showZayaSnack(context, gs.pathLocked) : () => _open(levels, i),
              ),
            );
          },
        ),
        if (_loaded && doneHere == levels.length) ...[
          const SizedBox(height: 16),
          InfoBanner(icon: Icons.emoji_events_outlined, text: gs.pathAllDone),
        ],
      ]),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.done,
    required this.locked,
    required this.current,
    required this.onTap,
  });
  final int number;
  final bool done;
  final bool locked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = done ? ZColors.primary : (locked ? const Color(0xFFF6F1F4) : Colors.white);
    final Color foreground = done ? Colors.white : (locked ? ZColors.muted : ZColors.ink);
    return Semantics(
      button: true,
      label: context.gs.pathLevelLabel(number, done: done, locked: locked),
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: current ? ZColors.primary : (done ? ZColors.primary : ZColors.line),
              width: current ? 2 : 1,
            ),
          ),
          child: Stack(alignment: Alignment.center, children: [
            locked
                ? Icon(Icons.lock_outline, color: foreground, size: 20)
                : Text('$number', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: foreground)),
            if (done)
              const Positioned(right: 6, top: 6, child: Icon(Icons.check_circle, size: 14, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

/// Une grille de Connexion mystère.
class PathPuzzleScreen extends StatefulWidget {
  const PathPuzzleScreen({super.key, required this.levels, required this.index});
  final List<PathLevel> levels;
  final int index;

  @override
  State<PathPuzzleScreen> createState() => _PathPuzzleScreenState();
}

class _PathPuzzleScreenState extends State<PathPuzzleScreen> {
  late final PathLevel _level = widget.levels[widget.index];
  late PathGame _game = PathGame(_level.board);
  final Stopwatch _clock = Stopwatch();
  bool _showTimer = false;
  int _hints = 0;
  int? _hintCell;
  String? _message;
  Timer? _saveDebounce;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await GamesProgress.pathInProgress(_level.id);
    final timer = await GamesProgress.timerEnabled();
    if (!mounted) return;
    setState(() {
      if (saved.isNotEmpty) _game = PathGame(_level.board, restore: saved);
      _showTimer = timer;
    });
    _clock.start();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _messageTimer?.cancel();
    // Partie en cours conservée en quittant l'écran (retour arrière, fermeture).
    if (!_game.isSolved) GamesProgress.savePathInProgress(_level.id, _game.path);
    super.dispose();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      GamesProgress.savePathInProgress(_level.id, _game.path);
    });
  }

  void _say(String? message) {
    _messageTimer?.cancel();
    setState(() => _message = message);
    if (message != null) {
      _messageTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _message = null);
      });
    }
  }

  void _changed(PathStep step) {
    setState(() {
      if (_hintCell != null && _game.contains(_hintCell!)) _hintCell = null;
      _message = null;
    });
    if (step == PathStep.solved) {
      _solved();
    } else {
      if (_game.head == _game.board.end && !_game.isSolved) _say(context.gs.pathFillEverything);
      _scheduleSave();
    }
  }

  void _blocked(int cell) {
    final gs = context.gs;
    final number = _game.board.clueAt[cell];
    if (number != null && number != _game.nextNumber && !_game.contains(cell)) {
      HapticFeedback.lightImpact();
      _say(gs.pathGoThrough(_game.nextNumber));
    } else if (_game.head == _game.board.end) {
      HapticFeedback.lightImpact();
      _say(gs.pathFillEverything);
    }
  }

  Future<void> _solved() async {
    _clock.stop();
    _saveDebounce?.cancel();
    HapticFeedback.mediumImpact();
    await GamesProgress.markPathCompleted(_level.id);
    if (!mounted) return;
    final gs = context.gs;
    final hasNext = widget.index + 1 < widget.levels.length;
    await showGameSuccess(
      context,
      title: gs.wellDone,
      body: gs.pathSolvedBody(formatGameDuration(_clock.elapsed)),
      details: [gs.pathLevel(widget.index + 1), gs.hintsUsed(_hints)],
      primaryLabel: hasNext ? gs.nextLevel : gs.allLevels,
      onPrimary: () {
        if (hasNext) {
          Navigator.of(context)
              .pushReplacement(zRoute<void>(PathPuzzleScreen(levels: widget.levels, index: widget.index + 1)));
        } else {
          Navigator.of(context).pop();
        }
      },
      secondaryLabel: hasNext ? gs.allLevels : null,
      onSecondary: () => Navigator.of(context).pop(),
    );
  }

  void _undo() {
    if (_game.undo()) {
      setState(() => _message = null);
      _scheduleSave();
    }
  }

  void _reset() {
    _game.reset();
    setState(() {
      _message = null;
      _hintCell = null;
    });
    _scheduleSave();
  }

  void _hint() {
    final cell = _game.applyHint(_level.solution);
    if (cell == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _hints++;
      _hintCell = cell;
      _message = null;
    });
    if (_game.isSolved) {
      _solved();
    } else {
      _scheduleSave();
    }
  }

  Future<void> _toggleTimer() async {
    setState(() => _showTimer = !_showTimer);
    await GamesProgress.setTimerEnabled(_showTimer);
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    final board = _game.board;
    return Scaffold(
      appBar: AppBar(
        title: Text(gs.gameName('path_puzzle')),
        actions: [
          IconButton(
            tooltip: _showTimer ? gs.timerOff : gs.timerOn,
            icon: Icon(_showTimer ? Icons.timer : Icons.timer_outlined),
            onPressed: _toggleTimer,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(children: [
            Row(children: [
              GameStatChip(
                icon: Icons.flag_outlined,
                label: '${gs.difficulty(_level.difficulty.name)} · ${gs.pathLevel(widget.index + 1)}',
              ),
              const Spacer(),
              if (_showTimer) ...[GameClock(stopwatch: _clock), const SizedBox(width: 8)],
              GameStatChip(
                icon: Icons.grid_on,
                label: gs.pathFilled(_game.filled, board.cellCount),
                highlighted: _game.isSolved,
              ),
            ]),
            const SizedBox(height: 12),
            Text(gs.pathRules,
                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: ZColors.muted)),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      label: gs.pathBoardLabel(board.size, _game.filled, board.cellCount),
                      child: PathBoardView(
                        game: _game,
                        hintCell: _hintCell,
                        enabled: !_game.isSolved,
                        onChanged: _changed,
                        onBlocked: _blocked,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: AnimatedSwitcher(
                duration: ZMotion.of(context, ZMotion.fast),
                child: _message == null
                    ? const SizedBox.shrink()
                    : Center(
                        key: ValueKey<String>(_message!),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: ZColors.primaryDark),
                        ),
                      ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              GameToolButton(
                icon: Icons.undo,
                label: gs.undo,
                onPressed: _game.filled > 1 && !_game.isSolved ? _undo : null,
              ),
              GameToolButton(
                icon: Icons.restart_alt,
                label: gs.restart,
                onPressed: _game.filled > 1 && !_game.isSolved ? _reset : null,
              ),
              GameToolButton(
                icon: Icons.lightbulb_outline,
                label: gs.hint,
                onPressed: _game.isSolved ? null : _hint,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
