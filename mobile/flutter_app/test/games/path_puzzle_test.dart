import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaya/features/games/path_puzzle/path_levels.dart';
import 'package:zaya/features/games/path_puzzle/path_puzzle.dart';

/// Grille 3 × 3 de démonstration :
///   1 . .        cases : 0 1 2
///   . . .                3 4 5
///   . . 2                6 7 8
/// Une solution : 0 1 2 5 4 3 6 7 8.
PathBoard smallBoard({List<int> walls = const <int>[]}) => PathBoard(size: 3, clueCells: const [0, 8], walls: walls);

void main() {
  group('niveaux livrés', () {
    test('30 niveaux : 10 par difficulté, identifiants uniques', () {
      expect(pathLevels, hasLength(30));
      for (final d in PathDifficulty.values) {
        expect(pathLevels.where((l) => l.difficulty == d), hasLength(10), reason: d.name);
      }
      expect(pathLevels.map((l) => l.id).toSet(), hasLength(30));
    });

    test('chaque niveau a une solution conforme aux règles', () {
      for (final level in pathLevels) {
        final board = level.board;
        expect(checkSolution(board, level.solution), isNull, reason: level.id);
        expect(level.clueCells.length, greaterThanOrEqualTo(2), reason: level.id);
        for (var i = 0; i + 1 < level.walls.length; i += 2) {
          expect(board.isAdjacent(level.walls[i], level.walls[i + 1]), isTrue, reason: '${level.id} : mur');
        }
      }
    });

    test('chaque niveau est résoluble et sa solution est unique (preuve par le solveur)', () {
      for (final level in pathLevels) {
        final solver = PathSolver(level.board);
        final count = solver.count(limit: 2);
        expect(solver.aborted, isFalse, reason: '${level.id} : recherche non concluante');
        expect(count, 1, reason: '${level.id} : $count solution(s)');
        expect(solver.solutions.single, level.solution, reason: level.id);
      }
    });

    test('la difficulté augmente : grilles plus grandes, murs seulement en difficile', () {
      for (final level in pathLevels) {
        switch (level.difficulty) {
          case PathDifficulty.easy:
            expect(level.size, inInclusiveRange(4, 5));
            expect(level.walls, isEmpty);
          case PathDifficulty.medium:
            expect(level.size, 6);
            expect(level.walls, isEmpty);
          case PathDifficulty.hard:
            expect(level.size, 7);
            expect(level.walls, isNotEmpty);
        }
      }
    });
  });

  group('règles d’une partie', () {
    test('le chemin part du 1 et avance case par case, jamais en diagonale ni en sautant', () {
      final game = PathGame(smallBoard());
      expect(game.path, [0]);
      expect(game.tryEnter(4), PathStep.blocked, reason: 'diagonale');
      expect(game.tryEnter(2), PathStep.blocked, reason: 'case non voisine');
      expect(game.tryEnter(1), PathStep.extended);
      expect(game.path, [0, 1]);
    });

    test('un mur interdit le passage', () {
      final game = PathGame(smallBoard(walls: const [0, 1]));
      expect(game.tryEnter(1), PathStep.blocked);
      expect(game.tryEnter(3), PathStep.extended);
    });

    test('les numéros se prennent dans l’ordre', () {
      final board = PathBoard(size: 3, clueCells: const [0, 4, 8]);
      final game = PathGame(board);
      expect(game.nextNumber, 2);
      game
        ..tryEnter(1)
        ..tryEnter(2)
        ..tryEnter(5);
      // 8 porte le 3 : interdit tant que le 2 (case 4) n'est pas atteint.
      expect(game.tryEnter(8), PathStep.blocked);
      expect(game.tryEnter(4), PathStep.extended);
      expect(game.nextNumber, 3);
    });

    test('revenir sur une case déjà tracée efface la suite ; annuler retire un pas', () {
      final game = PathGame(smallBoard());
      for (final c in [1, 2, 5, 4]) {
        game.tryEnter(c);
      }
      expect(game.tryEnter(5), PathStep.backtracked, reason: 'retour du doigt sur la case précédente');
      expect(game.path, [0, 1, 2, 5]);
      expect(game.tryEnter(1), PathStep.backtracked, reason: 'appui sur une case plus ancienne');
      expect(game.path, [0, 1]);
      expect(game.undo(), isTrue);
      expect(game.path, [0]);
      expect(game.undo(), isFalse, reason: 'le départ reste');
    });

    test('arriver au dernier numéro trop tôt bloque la suite ; la grille pleine est résolue', () {
      final game = PathGame(smallBoard());
      for (final c in [3, 6, 7, 8]) {
        game.tryEnter(c);
      }
      expect(game.isSolved, isFalse);
      expect(game.tryEnter(5), PathStep.blocked, reason: 'on ne dépasse pas le dernier numéro');
      game.reset();
      expect(game.path, [0]);
      final steps = [for (final c in [1, 2, 5, 4, 3, 6, 7, 8]) game.tryEnter(c)];
      expect(steps.last, PathStep.solved);
      expect(game.isSolved, isTrue);
      expect(game.tryEnter(7), PathStep.ignored, reason: 'partie terminée');
      expect(game.undo(), isFalse);
    });

    test('reprise d’une partie sauvegardée : on rejoue les pas valables et on s’arrête au premier invalide', () {
      final game = PathGame(smallBoard(), restore: const [0, 1, 2, 4, 5]);
      expect(game.path, [0, 1, 2], reason: '2 → 4 n’est pas un pas valable');
    });

    test('l’indice retire la partie fausse du chemin et avance d’une case correcte', () {
      const solution = [0, 1, 2, 5, 4, 3, 6, 7, 8];
      final board = PathBoard(size: 3, clueCells: const [0, 4, 8]);
      final game = PathGame(board)
        ..tryEnter(3)
        ..tryEnter(6);
      expect(game.applyHint(solution), 1);
      expect(game.path, [0, 1]);
      expect(game.applyHint(solution), 2);
      expect(game.path, [0, 1, 2]);
    });

    test('checkSolution refuse un chemin incomplet, un pas interdit, un ordre faux', () {
      final board = PathBoard(size: 3, clueCells: const [0, 4, 8]);
      expect(checkSolution(board, const [0, 1, 2, 5, 4, 3, 6, 7, 8]), isNull);
      expect(checkSolution(board, const [0, 1, 2, 5, 4, 3, 6, 7]), isNotNull);
      expect(checkSolution(board, const [0, 1, 2, 5, 4, 3, 7, 6, 8]), isNotNull);
      expect(checkSolution(PathBoard(size: 3, clueCells: const [0, 6, 8]), const [0, 1, 2, 5, 4, 3, 6, 7, 8]),
          isNull);
      expect(checkSolution(PathBoard(size: 3, clueCells: const [0, 7, 6, 8]), const [0, 1, 2, 5, 4, 3, 6, 7, 8]),
          isNotNull, reason: 'le 3 (case 6) est atteint avant le 2 (case 7)');
    });
  });

  group('générateur', () {
    test('un chemin tiré au hasard passe une fois par chaque case', () {
      for (final n in [3, 4, 6]) {
        final path = randomHamiltonianPath(n, Random(n));
        expect(path.toSet(), hasLength(n * n));
        final board = PathBoard(size: n, clueCells: [path.first, path.last]);
        expect(checkSolution(board, path), isNull);
      }
    });

    test('un niveau fabriqué a une solution unique', () {
      final level = generatePathLevel(
        id: 't01',
        difficulty: PathDifficulty.easy,
        recipe: const PathRecipe(size: 4, minClues: 4, walls: 2, minimize: true),
        random: Random(7),
      )!;
      final solver = PathSolver(level.board);
      expect(solver.count(limit: 2), 1);
      expect(solver.solutions.single, level.solution);
    });
  });
}
