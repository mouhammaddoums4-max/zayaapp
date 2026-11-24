import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/games_strings.dart';
import '../../../core/motion.dart';
import '../../../core/widgets.dart';
import '../games_progress.dart';
import 'would_you_rather.dart';
import 'would_you_rather_widgets.dart';

/// « Tu préfères ? » en solo : une série de questions, puis le récapitulatif des choix.
/// Les réponses restent sur le téléphone ; une série commencée reprend là où elle s'est arrêtée.
class WouldYouRatherScreen extends StatefulWidget {
  const WouldYouRatherScreen({super.key, this.random});
  final Random? random;

  @override
  State<WouldYouRatherScreen> createState() => _WouldYouRatherScreenState();
}

class _WouldYouRatherScreenState extends State<WouldYouRatherScreen> {
  WyrRound? _round;
  String? _justChosen;
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _start(resume: true);
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  Future<void> _start({bool resume = false}) async {
    final gs = context.gs;
    final ids = [for (final q in gs.wyrQuestions) q.id];
    final answered = await GamesProgress.wyrAnswers();
    var series = resume ? await GamesProgress.wyrSeries() : const <String>[];
    series = series.where(ids.contains).toList();
    final Map<int, String> resumed = {
      for (var i = 0; i < series.length; i++)
        if (answered[series[i]] != null) i: answered[series[i]]!,
    };
    // Une série reprise n'est valable que si ses réponses se suivent depuis le début et qu'elle n'est pas finie.
    final valid = series.isNotEmpty && resumed.length < series.length && resumed.keys.every((i) => i < resumed.length);
    if (!valid) {
      series = pickWyrSeries(ids, answered.keys.toSet(), widget.random ?? Random());
      await GamesProgress.saveWyrSeries(series);
    }
    if (!mounted) return;
    setState(() {
      _round = WyrRound(series, answers: valid ? resumed : const <int, String>{});
      _justChosen = null;
    });
  }

  Future<void> _choose(String choice) async {
    final round = _round;
    if (round == null || _justChosen != null) return;
    final id = round.currentId;
    if (id == null) return;
    HapticFeedback.selectionClick();
    final delay = ZMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 450);
    setState(() => _justChosen = choice);
    await GamesProgress.saveWyrAnswer(id, choice);
    if (!mounted) return;
    _advance = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        round.choose(choice);
        _justChosen = null;
      });
      if (round.isDone) GamesProgress.saveWyrSeries(const <String>[]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    final round = _round;
    return Scaffold(
      appBar: AppBar(title: Text(gs.gameName('would_you_rather'))),
      body: SafeArea(
        top: false,
        child: round == null
            ? const Center(child: CircularProgressIndicator())
            : round.isDone
                ? _summary(round)
                : _question(round),
      ),
    );
  }

  Widget _question(WyrRound round) {
    final gs = context.gs;
    final question = wyrById(gs, round.currentId!)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: round.index / round.ids.length,
            minHeight: 6,
            backgroundColor: const Color(0xFFF3E8EE),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: ZMotion.of(context, ZMotion.medium),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: WyrQuestionCard(
            key: ValueKey<String>(question.id),
            question: question,
            position: round.index + 1,
            total: round.ids.length,
            selected: _justChosen,
            onChoose: _justChosen == null ? _choose : null,
          ),
        ),
      ]),
    );
  }

  Widget _summary(WyrRound round) {
    final gs = context.gs;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Text(gs.wyrSummaryTitle, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(gs.wyrSummaryBody, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 16),
      WyrSummaryList(ids: round.ids, mine: round.answers),
      const SizedBox(height: 8),
      InfoBanner(icon: Icons.chat_bubble_outline, text: gs.gamesDuoExplain),
      const SizedBox(height: 20),
      GradientButton(label: gs.playAgain, icon: Icons.refresh, onPressed: () => _start()),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(gs.backToGames)),
    ]);
  }
}
