/// « Mots mélangés » : remettre dans l'ordre les lettres d'un mot. Dart pur, testé dans
/// test/games/word_scramble_test.dart.
library;

import 'dart:math';

/// Réponses enregistrées pour chaque mot (`game_answers.answer`, migration 0080).
const wordFoundAnswer = 'found';
const wordSkippedAnswer = 'skipped';

/// Nombre de mots d'une série.
const wordSeriesLength = 6;

const _accents = {
  'À': 'A', 'Â': 'A', 'Ä': 'A', 'Ç': 'C', 'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
  'Î': 'I', 'Ï': 'I', 'Ô': 'O', 'Ö': 'O', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'Ÿ': 'Y', 'Œ': 'OE', 'Æ': 'AE',
};

/// Majuscules A–Z uniquement (accents retirés, espaces et signes supprimés).
String normalizeWord(String word) {
  final upper = word.toUpperCase();
  final out = StringBuffer();
  for (final ch in upper.split('')) {
    final mapped = _accents[ch] ?? ch;
    for (final c in mapped.split('')) {
      final code = c.codeUnitAt(0);
      if (code >= 65 && code <= 90) out.write(c);
    }
  }
  return out.toString();
}

/// Tire [count] mots, d'abord ceux qui n'ont pas encore été proposés.
List<String> pickWordSeries(List<String> allIds, Set<String> seen, Random random, {int count = wordSeriesLength}) {
  final fresh = allIds.where((id) => !seen.contains(id)).toList()..shuffle(random);
  final old = allIds.where(seen.contains).toList()..shuffle(random);
  return [...fresh, ...old].take(count).toList();
}

/// Un mot à reconstituer : des tuiles (lettres mélangées) et des cases à remplir.
class WordPuzzle {
  WordPuzzle(String word, {Random? random}) : answer = normalizeWord(word) {
    assert(answer.isNotEmpty);
    final letters = answer.split('');
    final rng = random ?? Random();
    // Jamais présenté déjà dans l'ordre (sauf mot d'une seule lettre répétée).
    for (var attempt = 0; attempt < 20; attempt++) {
      letters.shuffle(rng);
      if (letters.join() != answer) break;
    }
    tiles = List<String>.unmodifiable(letters);
    slots = List<int?>.filled(answer.length, null);
  }

  final String answer;
  late final List<String> tiles;

  /// Tuile posée dans chaque case (`null` : case vide).
  late final List<int?> slots;

  /// Cases données par un indice : elles ne se vident plus.
  final Set<int> locked = <int>{};

  bool isTileUsed(int tile) => slots.contains(tile);
  bool get isFull => !slots.contains(null);
  String get current => [for (final t in slots) t == null ? '' : tiles[t]].join();
  bool get isCorrect => isFull && current == answer;

  /// Pose la tuile dans la première case vide. `false` si la tuile est déjà posée ou s'il n'y a plus de place.
  bool place(int tile) {
    if (tile < 0 || tile >= tiles.length || isTileUsed(tile)) return false;
    final empty = slots.indexOf(null);
    if (empty < 0) return false;
    slots[empty] = tile;
    return true;
  }

  /// Vide une case (sauf si elle vient d'un indice).
  bool removeAt(int slot) {
    if (slot < 0 || slot >= slots.length || locked.contains(slot) || slots[slot] == null) return false;
    slots[slot] = null;
    return true;
  }

  void clear() {
    for (var i = 0; i < slots.length; i++) {
      if (!locked.contains(i)) slots[i] = null;
    }
  }

  /// Indice : place la bonne lettre dans la première case fausse ou vide, et la fixe. Retourne la case, ou `null`
  /// si le mot est déjà juste.
  int? hint() {
    var slot = -1;
    for (var i = 0; i < slots.length; i++) {
      final t = slots[i];
      if (!locked.contains(i) && (t == null || tiles[t] != answer[i])) {
        slot = i;
        break;
      }
    }
    if (slot < 0) return null;
    final letter = answer[slot];
    // Une tuile de la bonne lettre : libre de préférence, sinon reprise d'une case non fixée.
    var tile = -1;
    for (var t = 0; t < tiles.length; t++) {
      if (tiles[t] == letter && !isTileUsed(t)) {
        tile = t;
        break;
      }
    }
    if (tile < 0) {
      for (var s = 0; s < slots.length; s++) {
        final t = slots[s];
        if (s != slot && t != null && !locked.contains(s) && tiles[t] == letter && tiles[t] != answer[s]) {
          tile = t;
          slots[s] = null;
          break;
        }
      }
    }
    if (tile < 0) {
      for (var s = 0; s < slots.length; s++) {
        final t = slots[s];
        if (s != slot && t != null && !locked.contains(s) && tiles[t] == letter) {
          tile = t;
          slots[s] = null;
          break;
        }
      }
    }
    if (tile < 0) return null;
    slots[slot] = tile;
    locked.add(slot);
    return slot;
  }
}
