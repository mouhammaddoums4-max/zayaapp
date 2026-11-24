// Fabrique les niveaux de « Connexion mystère » et écrit lib/features/games/path_puzzle/path_levels.dart.
//
//   cd mobile/flutter_app && dart run tool/generate_path_levels.dart
//
// Chaque niveau est tiré d'une graine fixe (résultat reproductible) et n'est retenu que si le solveur prouve que sa
// solution est unique. test/games/path_puzzle_test.dart refait cette preuve pour chaque niveau livré.
import 'dart:io';
import 'dart:math';

import 'package:zaya/features/games/path_puzzle/path_puzzle.dart';

const _perDifficulty = 10;

PathRecipe _recipe(PathDifficulty difficulty, int index) => switch (difficulty) {
      // Facile : trois grilles 4 × 4 pour apprendre, puis 5 × 5, avec de nombreux repères.
      PathDifficulty.easy => index < 3
          ? const PathRecipe(size: 4, minClues: 5, walls: 0, minimize: true)
          : const PathRecipe(size: 5, minClues: 7, walls: 0, minimize: true),
      PathDifficulty.medium => const PathRecipe(size: 6, minClues: 7, walls: 0, minimize: true),
      // Difficile : 7 × 7, quelques murs, peu de numéros.
      PathDifficulty.hard => const PathRecipe(size: 7, minClues: 6, walls: 6, minimize: true),
    };

String _prefix(PathDifficulty d) => switch (d) {
      PathDifficulty.easy => 'e',
      PathDifficulty.medium => 'm',
      PathDifficulty.hard => 'h',
    };

void main() {
  final out = StringBuffer()
    ..writeln('// Fichier généré par tool/generate_path_levels.dart — ne pas modifier à la main.')
    ..writeln('// Chaque solution est unique : vérifié par test/games/path_puzzle_test.dart.')
    ..writeln()
    ..writeln("import 'path_puzzle.dart';")
    ..writeln()
    ..writeln('const pathLevels = <PathLevel>[');
  for (final difficulty in PathDifficulty.values) {
    for (var i = 0; i < _perDifficulty; i++) {
      final id = '${_prefix(difficulty)}${(i + 1).toString().padLeft(2, '0')}';
      final recipe = _recipe(difficulty, i);
      PathLevel? level;
      var seed = 1000 * (difficulty.index + 1) + 17 * i;
      final watch = Stopwatch()..start();
      while (level == null) {
        level = generatePathLevel(id: id, difficulty: difficulty, recipe: recipe, random: Random(seed));
        if (level == null) seed++;
      }
      final check = PathSolver(level.board)..count(limit: 2);
      stdout.writeln('$id  ${recipe.size}×${recipe.size}  numéros: ${level.clueCells.length}  '
          'murs: ${level.walls.length ~/ 2}  graine: $seed  nœuds: ${check.nodes}  ${watch.elapsedMilliseconds} ms');
      out
        ..writeln('  // graine $seed')
        ..writeln('  PathLevel(')
        ..writeln("    id: '$id',")
        ..writeln('    difficulty: PathDifficulty.${difficulty.name},')
        ..writeln('    size: ${level.size},')
        ..writeln('    clueCells: <int>${level.clueCells},')
        ..writeln(level.walls.isEmpty ? '' : '    walls: <int>${level.walls},')
        ..writeln('    solution: <int>${level.solution},')
        ..writeln('  ),');
    }
  }
  out.writeln('];');
  final text = out.toString().replaceAll(RegExp(r'\n\n(?=    solution)'), '\n');
  File('lib/features/games/path_puzzle/path_levels.dart').writeAsStringSync(text);
  stdout.writeln('Écrit : lib/features/games/path_puzzle/path_levels.dart');
}
