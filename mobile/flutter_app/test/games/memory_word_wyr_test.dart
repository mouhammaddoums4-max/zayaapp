import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/core/l10n/games_strings.dart';
import 'package:zaya/core/l10n/games_strings_en.dart';
import 'package:zaya/core/l10n/games_strings_fr.dart';
import 'package:zaya/features/games/memory/memory_game.dart';
import 'package:zaya/features/games/word_scramble/word_scramble.dart';
import 'package:zaya/features/games/would_you_rather/would_you_rather.dart';

void main() {
  group('Mémoire', () {
    test('chaque niveau distribue des paires complètes', () {
      for (final level in MemoryLevel.values) {
        final game = MemoryGame(level, random: Random(1));
        expect(game.cards, hasLength(level.pairs * 2));
        final counts = <String, int>{};
        for (final c in game.cards) {
          counts[c.symbol] = (counts[c.symbol] ?? 0) + 1;
        }
        expect(counts.values.every((n) => n == 2), isTrue);
        expect(level.columns * level.rows, greaterThanOrEqualTo(level.pairs * 2));
      }
    });

    test('une paire trouvée reste visible ; un essai raté se recache ; un coup = deux cartes', () {
      final game = MemoryGame(MemoryLevel.easy, random: Random(2));
      final symbols = [for (final c in game.cards) c.symbol];
      final a = 0, pair = symbols.indexOf(symbols[0], 1);
      final other = symbols.indexWhere((s) => s != symbols[0]);

      expect(game.flip(a), MemoryFlip.first);
      expect(game.flip(a), MemoryFlip.ignored, reason: 'déjà visible');
      expect(game.flip(other), MemoryFlip.mismatch);
      expect(game.moves, 1);
      expect(game.mismatched, [a, other]);
      game.hideMismatch();
      expect(game.cards[a].faceUp || game.cards[other].faceUp, isFalse);

      expect(game.flip(a), MemoryFlip.first);
      expect(game.flip(pair), MemoryFlip.match);
      expect(game.moves, 2);
      expect(game.pairsFound, 1);
      expect(game.flip(pair), MemoryFlip.ignored, reason: 'paire déjà trouvée');
    });

    test('toucher une carte pendant qu’un essai raté est visible le recache d’abord', () {
      final game = MemoryGame(MemoryLevel.easy, random: Random(3));
      final symbols = [for (final c in game.cards) c.symbol];
      final other = symbols.indexWhere((s) => s != symbols[0]);
      game
        ..flip(0)
        ..flip(other);
      final third = List<int>.generate(12, (i) => i).firstWhere((i) => i != 0 && i != other);
      expect(game.flip(third), MemoryFlip.first);
      expect(game.cards[0].faceUp, isFalse);
      expect(game.cards[other].faceUp, isFalse);
    });

    test('la partie se termine quand toutes les paires sont trouvées', () {
      final game = MemoryGame(MemoryLevel.medium, random: Random(4));
      final bySymbol = <String, List<int>>{};
      for (var i = 0; i < game.cards.length; i++) {
        bySymbol.putIfAbsent(game.cards[i].symbol, () => <int>[]).add(i);
      }
      for (final pair in bySymbol.values) {
        game.flip(pair[0]);
        expect(game.flip(pair[1]), MemoryFlip.match);
      }
      expect(game.isComplete, isTrue);
      expect(game.moves, MemoryLevel.medium.pairs);
      expect(game.flip(0), MemoryFlip.ignored);
    });
  });

  group('Mots mélangés', () {
    test('normalisation : majuscules A–Z sans accent', () {
      expect(normalizeWord('Fidélité'), 'FIDELITE');
      expect(normalizeWord('cœur'), 'COEUR');
      expect(normalizeWord(' à-deux '), 'ADEUX');
    });

    test('les lettres ne sont jamais présentées dans l’ordre', () {
      for (var seed = 0; seed < 50; seed++) {
        final p = WordPuzzle('MAISON', random: Random(seed));
        expect(p.tiles.join(), isNot('MAISON'));
        expect([...p.tiles]..sort(), [...'MAISON'.split('')]..sort());
      }
    });

    test('poser, retirer, effacer, puis trouver le mot', () {
      final p = WordPuzzle('AVION', random: Random(1));
      int tileOf(String letter) =>
          List<int>.generate(p.tiles.length, (i) => i).firstWhere((i) => p.tiles[i] == letter && !p.isTileUsed(i));
      expect(p.place(tileOf('A')), isTrue);
      final usedA = p.slots[0]!;
      expect(p.place(usedA), isFalse, reason: 'tuile déjà posée');
      expect(p.removeAt(0), isTrue);
      expect(p.current, '');
      for (final l in 'AVINO'.split('')) {
        p.place(tileOf(l));
      }
      expect(p.isFull, isTrue);
      expect(p.isCorrect, isFalse);
      p.clear();
      for (final l in 'AVION'.split('')) {
        p.place(tileOf(l));
      }
      expect(p.isCorrect, isTrue);
    });

    test('l’indice place la bonne lettre, la fixe, et finit par donner le mot', () {
      final p = WordPuzzle('PATIENCE', random: Random(5));
      // Une mauvaise lettre en première case.
      final wrong = List<int>.generate(p.tiles.length, (i) => i).firstWhere((i) => p.tiles[i] != 'P');
      p.place(wrong);
      expect(p.hint(), 0);
      expect(p.tiles[p.slots[0]!], 'P');
      expect(p.locked, contains(0));
      expect(p.removeAt(0), isFalse, reason: 'case donnée par un indice');
      while (p.hint() != null) {}
      expect(p.isCorrect, isTrue);
      expect(p.current, 'PATIENCE');
    });

    test('une série propose d’abord des mots jamais vus', () {
      final ids = [for (var i = 0; i < 10; i++) 'w$i'];
      final series = pickWordSeries(ids, {'w0', 'w1', 'w2', 'w3', 'w4'}, Random(1), count: 5);
      expect(series.toSet(), {'w5', 'w6', 'w7', 'w8', 'w9'});
    });
  });

  group('Tu préfères ?', () {
    test('une série propose d’abord les questions sans réponse', () {
      final ids = [for (var i = 0; i < 12; i++) 'q$i'];
      final series = pickWyrSeries(ids, {for (var i = 0; i < 8; i++) 'q$i'}, Random(1), count: 6);
      expect(series.take(4).toSet(), {'q8', 'q9', 'q10', 'q11'});
      expect(series, hasLength(6));
    });

    test('déroulement : réponses dans l’ordre, choix invalide refusé, fin de série', () {
      final round = WyrRound(const ['a1', 'a2']);
      expect(round.currentId, 'a1');
      expect(round.choose('c'), isFalse);
      expect(round.choose(wyrChoiceA), isTrue);
      expect(round.currentId, 'a2');
      expect(round.choose(wyrChoiceB), isTrue);
      expect(round.isDone, isTrue);
      expect(round.choose(wyrChoiceA), isFalse);
      expect(round.answers, {0: 'a', 1: 'b'});
    });

    test('choix en commun', () {
      expect(wyrCommonChoices({0: 'a', 1: 'b', 2: 'a'}, {0: 'a', 1: 'a'}), 1);
    });
  });

  group('contenus (français et anglais)', () {
    const ZGameStrings fr = ZGameStringsFr(), en = ZGameStringsEn();

    test('mêmes questions et mêmes mots dans les deux langues (identifiants et thèmes)', () {
      expect([for (final q in en.wyrQuestions) '${q.id}/${q.theme}'],
          [for (final q in fr.wyrQuestions) '${q.id}/${q.theme}']);
      expect([for (final w in en.words) '${w.id}/${w.theme}'], [for (final w in fr.words) '${w.id}/${w.theme}']);
    });

    test('identifiants uniques, textes non vides, thèmes traduits', () {
      for (final s in [fr, en]) {
        expect(s.wyrQuestions.map((q) => q.id).toSet(), hasLength(s.wyrQuestions.length));
        expect(s.words.map((w) => w.id).toSet(), hasLength(s.words.length));
        for (final q in s.wyrQuestions) {
          expect(q.a.trim(), isNotEmpty);
          expect(q.b.trim(), isNotEmpty);
          expect(s.wyrTheme(q.theme), isNot(q.theme), reason: 'thème ${q.theme} non traduit');
        }
        expect(s.wyrQuestions.length, greaterThanOrEqualTo(wyrSeriesLength));
        expect(s.words.length, greaterThanOrEqualTo(wordSeriesLength));
      }
    });

    test('les mots sont des majuscules A–Z de 4 à 10 lettres', () {
      for (final s in [fr, en]) {
        for (final w in s.words) {
          expect(normalizeWord(w.word), w.word, reason: w.word);
          expect(w.word.length, inInclusiveRange(4, 10), reason: w.word);
        }
      }
    });

    test('chaque symbole de la mémoire a un nom', () {
      for (final s in [fr, en]) {
        for (final id in memorySymbols) {
          expect(s.memorySymbol(id), isNot(id));
        }
      }
    });
  });
}
