import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/games_strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../games_progress.dart';
import 'word_board.dart';
import 'word_scramble.dart';

/// « Mots mélangés » en solo : une série de mots sur les valeurs, la famille, les voyages, les projets, la relation.
class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key, this.random});
  final Random? random;

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

class _WordScrambleScreenState extends State<WordScrambleScreen> {
  late final Random _random = widget.random ?? Random();
  List<String> _series = const <String>[];
  final Map<int, String> _results = <int, String>{};
  WordPuzzle? _puzzle;
  int _index = 0;
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final gs = context.gs;
    final ids = [for (final w in gs.words) w.id];
    var seen = await GamesProgress.wordsSeen();
    if (seen.length >= ids.length) {
      await GamesProgress.resetWordsSeen();
      seen = const <String>{};
    }
    final series = pickWordSeries(ids, seen, _random);
    await GamesProgress.addWordsSeen(series);
    if (!mounted) return;
    setState(() {
      _series = series;
      _results.clear();
      _index = 0;
      _puzzle = _puzzleAt(0);
    });
  }

  WordPuzzle? _puzzleAt(int index) {
    if (index >= _series.length) return null;
    final word = wordById(context.gs, _series[index]);
    return word == null ? null : WordPuzzle(word.word, random: _random);
  }

  void _record(String result) {
    _results[_index] = result;
    _next?.cancel();
    _next = Timer(
      result == wordFoundAnswer && !ZMotion.reduced(context) ? const Duration(milliseconds: 800) : Duration.zero,
      () {
        if (!mounted) return;
        setState(() {
          _index++;
          _puzzle = _puzzleAt(_index);
        });
      },
    );
  }

  void _skip() {
    final answer = _puzzle?.answer;
    if (answer != null) showZayaSnack(context, context.gs.wordAnswerWas(answer));
    _record(wordSkippedAnswer);
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    final puzzle = _puzzle;
    final done = _series.isNotEmpty && _index >= _series.length;
    return Scaffold(
      appBar: AppBar(title: Text(gs.gameName('word_scramble'))),
      body: SafeArea(
        top: false,
        child: _series.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : done
                ? _summary()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _index / _series.length,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF3E8EE),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (puzzle != null)
                        WordBoard(
                          key: ValueKey<int>(_index),
                          puzzle: puzzle,
                          theme: wordById(gs, _series[_index])!.theme,
                          position: _index + 1,
                          total: _series.length,
                          onSolved: () => _record(wordFoundAnswer),
                          onSkip: _skip,
                        ),
                    ]),
                  ),
      ),
    );
  }

  Widget _summary() {
    final gs = context.gs;
    final found = _results.values.where((r) => r == wordFoundAnswer).length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Text(gs.wellDone, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(gs.wordSolvedBody(found, _series.length), style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 16),
      for (var i = 0; i < _series.length; i++)
        if (wordById(gs, _series[i]) case final w?)
          WordResultRow(word: w.word, found: _results[i] == wordFoundAnswer),
      const SizedBox(height: 8),
      InfoBanner(icon: Icons.chat_bubble_outline, text: gs.gamesDuoExplain),
      const SizedBox(height: 20),
      GradientButton(label: gs.playAgain, icon: Icons.refresh, onPressed: _start),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(gs.backToGames)),
    ]);
  }
}

/// Ligne du récapitulatif : le mot, trouvé ou passé (et, à deux, le résultat de l'autre).
class WordResultRow extends StatelessWidget {
  const WordResultRow({super.key, required this.word, required this.found, this.partnerFound, this.partnerName});
  final String word;
  final bool found;
  final bool? partnerFound;
  final String? partnerName;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ZColors.line),
          ),
          child: Row(children: [
            Expanded(
              child: Text(normalizeWord(word),
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ),
            _Mark(found: found, label: context.gs.duoYourChoice),
            if (partnerFound != null) ...[
              const SizedBox(width: 10),
              _Mark(found: partnerFound!, label: partnerName ?? ''),
            ],
          ]),
        ),
      );
}

class _Mark extends StatelessWidget {
  const _Mark({required this.found, required this.label});
  final bool found;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Icon(
          found ? Icons.check_circle : Icons.remove_circle_outline,
          color: found ? ZColors.success : ZColors.muted,
          size: 22,
        ),
      );
}
