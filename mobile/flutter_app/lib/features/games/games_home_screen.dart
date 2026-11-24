import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/games_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'game_catalog.dart';
import 'games_progress.dart';
import 'memory/memory_screen.dart';
import 'path_puzzle/path_levels.dart';
import 'path_puzzle/path_puzzle_screen.dart';
import 'word_scramble/word_scramble_screen.dart';
import 'would_you_rather/would_you_rather_screen.dart';

/// Ouvre le jeu en solo.
Widget soloScreenFor(ZGame game) => switch (game) {
      ZGame.pathPuzzle => const PathLevelsScreen(),
      ZGame.memory => const MemoryScreen(),
      ZGame.wouldYouRather => const WouldYouRatherScreen(),
      ZGame.wordScramble => const WordScrambleScreen(),
    };

/// Espace Jeux : les jeux en solo, et comment jouer à deux depuis une conversation.
class GamesHomeScreen extends StatefulWidget {
  const GamesHomeScreen({super.key});

  @override
  State<GamesHomeScreen> createState() => _GamesHomeScreenState();
}

class _GamesHomeScreenState extends State<GamesHomeScreen> {
  int _pathDone = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await GamesProgress.pathCompleted();
    if (mounted) setState(() => _pathDone = done.length);
  }

  Future<void> _open(ZGame game) async {
    await Navigator.of(context).push(zRoute<void>(soloScreenFor(game)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return Scaffold(
      appBar: AppBar(title: Text(gs.gamesTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
        Text(gs.gamesIntro, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ZColors.muted)),
        const SizedBox(height: 20),
        SectionTitle(gs.gamesSoloSection),
        const SizedBox(height: 4),
        for (final (i, game) in ZGame.values.indexed)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GameCard(
                game: game,
                progress: game == ZGame.pathPuzzle && _pathDone > 0
                    ? gs.pathLevelsDone(_pathDone, pathLevels.length)
                    : null,
                onTap: () => _open(game),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SectionTitle(gs.gamesDuoSection),
        const SizedBox(height: 4),
        FadeSlideIn(
          index: ZGame.values.length,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: ZColors.brandGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final g in ZGame.duoGames) ZTag(gs.gameName(g.id), onDark: true),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Text(gs.gamesDuoExplain,
                  style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: Colors.white, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: ZColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(gs.gamesLocalNote, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      ]),
    );
  }
}

/// Carte d'un jeu dans l'espace Jeux.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap, this.progress, this.trailing});
  final ZGame game;
  final VoidCallback onTap;
  final String? progress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    return Semantics(
      button: true,
      label: '${gs.gameName(game.id)}. ${gs.gameTagline(game.id)}',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        pressedScale: 0.98,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZColors.line),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(16)),
              child: Icon(game.icon, color: ZColors.primaryDark, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(gs.gameName(game.id),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ZColors.ink)),
                  ),
                  if (game.duo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: ZColors.primarySoft, borderRadius: BorderRadius.circular(99)),
                      child: Text(gs.gameDuoBadge,
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(gs.gameTagline(game.id),
                    style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: ZColors.muted)),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  Text(progress!,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ZColors.primaryDark)),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            trailing ?? const Icon(Icons.chevron_right, color: ZColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Entrée de l'espace Jeux (onglet Explorer).
class GamesEntryCard extends StatelessWidget {
  const GamesEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.gs;
    void open() => Navigator.of(context).push(zRoute<void>(const GamesHomeScreen()));
    return Semantics(
      button: true,
      label: '${gs.gamesTitle}. ${gs.gamesEntrySubtitle}',
      excludeSemantics: true,
      onTap: open,
      child: PressScale(
        pressedScale: 0.97,
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZColors.line),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: ZColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.extension_outlined, color: ZColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(gs.gamesTitle, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(gs.gamesEntrySubtitle, style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: ZColors.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: ZColors.muted),
          ]),
        ),
      ),
    );
  }
}
