/// Jeu de mémoire : règles pures (sans Flutter), testées dans test/games/memory_game_test.dart.
library;

import 'dart:math';

/// Niveaux : nombre de paires et disposition de la grille (colonnes × lignes).
enum MemoryLevel {
  easy(pairs: 6, columns: 3),
  medium(pairs: 8, columns: 4),
  hard(pairs: 10, columns: 4);

  const MemoryLevel({required this.pairs, required this.columns});
  final int pairs;
  final int columns;
  int get rows => (pairs * 2 / columns).ceil();
}

/// Symboles des cartes (identifiants traduits par `ZGameStrings.memorySymbol`, icônes dans l'écran).
const memorySymbols = <String>[
  'heart', 'ring', 'home', 'travel', 'coffee', 'book', 'moon', 'sun',
  'flower', 'music', 'meal', 'nature', 'beach', 'star', 'gift', 'family',
];

class MemoryCard {
  MemoryCard(this.symbol);
  final String symbol;
  bool faceUp = false;
  bool matched = false;
}

enum MemoryFlip {
  /// Carte déjà visible ou trouvée, ou partie finie : rien ne se passe.
  ignored,

  /// Première carte d'un essai.
  first,

  /// Deuxième carte : même symbole, la paire reste visible.
  match,

  /// Deuxième carte : symboles différents, les deux cartes seront recachées.
  mismatch,
}

class MemoryGame {
  MemoryGame(this.level, {Random? random})
      : cards = _deal(level.pairs, random ?? Random());

  final MemoryLevel level;
  final List<MemoryCard> cards;

  /// Un coup = deux cartes retournées.
  int moves = 0;
  int _firstIndex = -1;

  /// Les deux cartes d'un essai raté, visibles jusqu'à [hideMismatch].
  final List<int> mismatched = <int>[];

  static List<MemoryCard> _deal(int pairs, Random random) {
    final symbols = [...memorySymbols]..shuffle(random);
    final chosen = symbols.take(pairs).toList();
    return [for (final s in [...chosen, ...chosen]) MemoryCard(s)]..shuffle(random);
  }

  int get pairsFound => cards.where((c) => c.matched).length ~/ 2;
  bool get isComplete => cards.every((c) => c.matched);

  MemoryFlip flip(int index) {
    if (index < 0 || index >= cards.length || isComplete) return MemoryFlip.ignored;
    // Une nouvelle carte touchée pendant qu'un essai raté est encore visible : on le recache d'abord.
    if (mismatched.isNotEmpty) hideMismatch();
    final card = cards[index];
    if (card.faceUp || card.matched) return MemoryFlip.ignored;
    card.faceUp = true;
    if (_firstIndex < 0) {
      _firstIndex = index;
      return MemoryFlip.first;
    }
    final first = cards[_firstIndex];
    final firstIndex = _firstIndex;
    _firstIndex = -1;
    moves++;
    if (first.symbol == card.symbol) {
      first.matched = true;
      card.matched = true;
      return MemoryFlip.match;
    }
    mismatched
      ..clear()
      ..addAll([firstIndex, index]);
    return MemoryFlip.mismatch;
  }

  void hideMismatch() {
    for (final i in mismatched) {
      cards[i].faceUp = false;
    }
    mismatched.clear();
  }
}
