import 'package:material_ui/material_ui.dart';

/// Les jeux de ZAYA. [id] est l'identifiant partagé avec le serveur (`game_sessions.game`, migration 0060).
enum ZGame {
  pathPuzzle('path_puzzle', Icons.route, duo: false),
  memory('memory', Icons.style_outlined, duo: false),
  wouldYouRather('would_you_rather', Icons.call_split, duo: true),
  wordScramble('word_scramble', Icons.abc, duo: true);

  const ZGame(this.id, this.icon, {required this.duo});
  final String id;
  final IconData icon;

  /// Jouable à deux depuis une conversation.
  final bool duo;

  static ZGame? fromId(String? id) {
    for (final g in ZGame.values) {
      if (g.id == id) return g;
    }
    return null;
  }

  static List<ZGame> get duoGames => [for (final g in ZGame.values) if (g.duo) g];
}
