/// Connexion mystère : règles, état d'une partie, solveur et générateur de niveaux.
///
/// Règles : une grille carrée ; des cases portent les numéros 1, 2, … N. Le joueur part du 1 et trace un chemin
/// case par case (haut, bas, gauche, droite, jamais en diagonale ni à travers un mur), en passant par les numéros
/// dans l'ordre, jusqu'au dernier. Le chemin doit remplir **toutes** les cases, chacune une seule fois.
///
/// Dart pur (sans Flutter) : utilisé par l'écran du jeu, par les tests et par `tool/generate_path_levels.dart`.
library;

import 'dart:math';

enum PathDifficulty { easy, medium, hard }

/// Un niveau livré avec l'application. [solution] est l'unique chemin valable : les tests le vérifient pour chaque
/// niveau (chemin conforme aux règles, et le solveur n'en trouve aucun autre).
class PathLevel {
  const PathLevel({
    required this.id,
    required this.difficulty,
    required this.size,
    required this.clueCells,
    required this.solution,
    this.walls = const <int>[],
  });

  /// Identifiant stable (sauvegarde de la progression) : `e01`, `m04`, `h10`…
  final String id;
  final PathDifficulty difficulty;

  /// Côté de la grille (cases numérotées ligne par ligne : `ligne * size + colonne`).
  final int size;

  /// Case de chaque numéro : `clueCells[0]` porte le 1, `clueCells.last` le dernier numéro.
  final List<int> clueCells;

  /// Murs, par paires de cases voisines : `[a0, b0, a1, b1, …]`.
  final List<int> walls;

  final List<int> solution;

  PathBoard get board => PathBoard(size: size, clueCells: clueCells, walls: walls);
}

/// Géométrie d'une grille : voisins, murs, numéros.
class PathBoard {
  PathBoard({required this.size, required List<int> clueCells, List<int> walls = const <int>[]})
      : clueCells = List<int>.unmodifiable(clueCells),
        clueAt = <int, int>{for (var i = 0; i < clueCells.length; i++) clueCells[i]: i + 1},
        _walls = <int>{for (var i = 0; i + 1 < walls.length; i += 2) edgeKey(walls[i], walls[i + 1])} {
    assert(clueCells.length >= 2, 'Il faut au moins un départ et une arrivée.');
    neighbors = List<List<int>>.generate(cellCount, (cell) {
      final r = cell ~/ size, c = cell % size;
      return <int>[
        if (r > 0) cell - size,
        if (c < size - 1) cell + 1,
        if (r < size - 1) cell + size,
        if (c > 0) cell - 1,
      ].where((n) => !hasWall(cell, n)).toList(growable: false);
    }, growable: false);
  }

  final int size;
  final List<int> clueCells;

  /// Numéro (à partir de 1) porté par une case.
  final Map<int, int> clueAt;
  final Set<int> _walls;

  /// Cases atteignables en un pas depuis chaque case (murs exclus).
  late final List<List<int>> neighbors;

  int get cellCount => size * size;
  int get start => clueCells.first;
  int get end => clueCells.last;
  int get lastNumber => clueCells.length;

  static int edgeKey(int a, int b) => a < b ? a * 4096 + b : b * 4096 + a;

  bool hasWall(int a, int b) => _walls.contains(edgeKey(a, b));

  /// Les murs, chacun une fois, sous forme de paires `(a, b)` avec `a < b`.
  Iterable<(int, int)> get wallPairs => _walls.map((k) => (k ~/ 4096, k % 4096));

  bool isAdjacent(int a, int b) {
    if (a < 0 || b < 0 || a >= cellCount || b >= cellCount) return false;
    final dr = (a ~/ size - b ~/ size).abs(), dc = (a % size - b % size).abs();
    return dr + dc == 1;
  }

  bool canStep(int a, int b) => isAdjacent(a, b) && !hasWall(a, b);
}

/// Pourquoi un chemin complet n'est pas une solution (`null` : solution valable).
String? checkSolution(PathBoard board, List<int> path) {
  if (path.length != board.cellCount) return 'toutes les cases ne sont pas remplies';
  if (path.toSet().length != path.length) return 'une case est visitée deux fois';
  if (path.first != board.start) return 'le chemin ne part pas du 1';
  if (path.last != board.end) return 'le chemin ne finit pas sur le dernier numéro';
  var expected = 1;
  for (var i = 0; i < path.length; i++) {
    final cell = path[i];
    if (cell < 0 || cell >= board.cellCount) return 'case hors de la grille';
    if (i > 0 && !board.canStep(path[i - 1], cell)) return 'pas interdit entre ${path[i - 1]} et $cell';
    final number = board.clueAt[cell];
    if (number != null) {
      if (number != expected) return 'le $number est atteint avant le $expected';
      expected++;
    }
  }
  return expected == board.lastNumber + 1 ? null : 'numéros manquants';
}

/// Résultat d'une tentative d'entrer dans une case.
enum PathStep {
  /// Le chemin avance d'une case.
  extended,

  /// Le chemin revient en arrière jusqu'à cette case (retour du doigt, ou appui sur une case déjà tracée).
  backtracked,

  /// Dernière case posée : la grille est résolue.
  solved,

  /// Pas interdit (case non voisine, mur, numéro hors d'ordre, dernier numéro déjà atteint).
  blocked,

  /// Rien à faire (même case, partie terminée).
  ignored,
}

/// État d'une partie : le chemin tracé depuis le 1.
class PathGame {
  PathGame(this.board, {Iterable<int> restore = const <int>[]}) : _path = <int>[board.start] {
    // Reprise d'une partie sauvegardée : on rejoue chaque pas, et on s'arrête au premier pas invalide.
    for (final cell in restore.skip(1)) {
      final step = tryEnter(cell);
      if (step != PathStep.extended && step != PathStep.solved) break;
    }
  }

  final PathBoard board;
  final List<int> _path;

  List<int> get path => List<int>.unmodifiable(_path);
  int get head => _path.last;
  int get filled => _path.length;
  bool contains(int cell) => _path.contains(cell);

  /// Prochain numéro à atteindre.
  int get nextNumber {
    var reached = 0;
    for (final cell in _path) {
      final n = board.clueAt[cell];
      if (n != null) reached = n;
    }
    return reached + 1;
  }

  bool get isSolved => _path.length == board.cellCount && head == board.end;

  /// Le doigt (ou un appui) entre dans [cell].
  PathStep tryEnter(int cell) {
    if (isSolved || cell == head) return PathStep.ignored;
    final index = _path.indexOf(cell);
    if (index >= 0) {
      _path.removeRange(index + 1, _path.length);
      return PathStep.backtracked;
    }
    if (!board.canStep(head, cell) || head == board.end) return PathStep.blocked;
    final number = board.clueAt[cell];
    if (number != null && number != nextNumber) return PathStep.blocked;
    _path.add(cell);
    return isSolved ? PathStep.solved : PathStep.extended;
  }

  /// Annule le dernier pas. `false` s'il n'y a rien à annuler.
  bool undo() {
    if (_path.length <= 1 || isSolved) return false;
    _path.removeLast();
    return true;
  }

  void reset() => _path.removeRange(1, _path.length);

  /// Indice : retire la partie du chemin qui s'écarte de la solution, puis avance d'une case correcte.
  /// Retourne la case ajoutée (`null` si la grille est déjà résolue).
  int? applyHint(List<int> solution) {
    if (isSolved) return null;
    var common = 0;
    while (common < _path.length && common < solution.length && _path[common] == solution[common]) {
      common++;
    }
    _path.removeRange(common, _path.length);
    if (common >= solution.length) return null;
    final next = solution[common];
    _path.add(next);
    return next;
  }
}

/// Solveur par recherche en profondeur, avec élagage (cases isolées, impasses, connexité).
/// Sert aux tests (prouver qu'un niveau a exactement une solution) et au générateur.
class PathSolver {
  PathSolver(this.board, {this.maxNodes = 20000000});

  final PathBoard board;

  /// Au-delà, la recherche s'arrête et [aborted] passe à `true` (résultat non concluant).
  final int maxNodes;

  int nodes = 0;
  bool aborted = false;
  final List<List<int>> solutions = <List<int>>[];

  late final List<bool> _visited = List<bool>.filled(board.cellCount, false);
  final List<int> _path = <int>[];
  late final List<int> _queue = List<int>.filled(board.cellCount, 0);
  late final List<bool> _seen = List<bool>.filled(board.cellCount, false);

  /// Nombre de solutions, plafonné à [limit].
  int count({int limit = 2}) {
    nodes = 0;
    aborted = false;
    solutions.clear();
    _visited.fillRange(0, _visited.length, false);
    _path.clear();
    final start = board.start;
    _visited[start] = true;
    _path.add(start);
    if (board.cellCount == 1) {
      solutions.add(<int>[start]);
    } else {
      _search(start, 2, limit);
    }
    return solutions.length;
  }

  void _search(int head, int nextNumber, int limit) {
    if (++nodes > maxNodes) {
      aborted = true;
      return;
    }
    if (_path.length == board.cellCount) {
      if (head == board.end) solutions.add(List<int>.of(_path));
      return;
    }
    if (head == board.end) return;
    for (final v in board.neighbors[head]) {
      if (_visited[v]) continue;
      final number = board.clueAt[v];
      if (number != null && number != nextNumber) continue;
      _visited[v] = true;
      _path.add(v);
      if (_feasible(v, head)) _search(v, number == null ? nextNumber : nextNumber + 1, limit);
      _path.removeLast();
      _visited[v] = false;
      if (solutions.length >= limit || aborted) return;
    }
  }

  bool _feasible(int head, int previous) {
    final remaining = board.cellCount - _path.length;
    if (remaining == 0) return head == board.end;
    if (head == board.end) return false;
    // Toute case restante (sauf l'arrivée) doit garder deux issues ; l'arrivée, au moins une. Seuls les voisins de
    // l'ancienne tête ont perdu une issue à ce pas : il suffit de les contrôler.
    for (final u in board.neighbors[previous]) {
      if (_visited[u]) continue;
      var degree = 0;
      for (final w in board.neighbors[u]) {
        if (!_visited[w] || w == head) degree++;
      }
      if (degree < (u == board.end ? 1 : 2)) return false;
    }
    // Les cases restantes doivent former un seul bloc, accessible depuis la tête du chemin.
    _seen.fillRange(0, _seen.length, false);
    var size = 0, read = 0;
    for (final w in board.neighbors[head]) {
      if (!_visited[w] && !_seen[w]) {
        _seen[w] = true;
        _queue[size++] = w;
      }
    }
    while (read < size) {
      final u = _queue[read++];
      for (final w in board.neighbors[u]) {
        if (!_visited[w] && !_seen[w]) {
          _seen[w] = true;
          _queue[size++] = w;
        }
      }
    }
    return size == remaining;
  }
}

/// Réglages de fabrication d'un niveau selon la difficulté.
class PathRecipe {
  const PathRecipe({required this.size, required this.minClues, required this.walls, required this.minimize});
  final int size;

  /// Nombre de numéros minimal (des numéros sont ajoutés pour faciliter la lecture des grilles faciles).
  final int minClues;
  final int walls;

  /// Retirer les numéros superflus tant que la solution reste unique (grilles plus difficiles).
  final bool minimize;
}

/// Fabrique un niveau dont la solution est unique et prouvée par le solveur. `null` si la recherche n'a pas pu
/// conclure (le générateur essaie alors une autre graine).
PathLevel? generatePathLevel({
  required String id,
  required PathDifficulty difficulty,
  required PathRecipe recipe,
  required Random random,
  int maxNodes = 4000000,
}) {
  final n = recipe.size;
  final solution = randomHamiltonianPath(n, random);
  final pathIndex = <int, int>{for (var i = 0; i < solution.length; i++) solution[i]: i};

  // Murs : uniquement entre des cases voisines que la solution ne relie pas directement.
  final wallList = <int>[];
  if (recipe.walls > 0) {
    final candidates = <(int, int)>[];
    for (var cell = 0; cell < n * n; cell++) {
      for (final other in [if (cell % n < n - 1) cell + 1, if (cell ~/ n < n - 1) cell + n]) {
        if ((pathIndex[cell]! - pathIndex[other]!).abs() != 1) candidates.add((cell, other));
      }
    }
    candidates.shuffle(random);
    for (final (a, b) in candidates.take(recipe.walls)) {
      wallList
        ..add(a)
        ..add(b);
    }
  }

  final clueIndexes = <int>{0, solution.length - 1};
  PathBoard boardFor(Set<int> indexes) {
    final sorted = indexes.toList()..sort();
    return PathBoard(size: n, clueCells: [for (final i in sorted) solution[i]], walls: wallList);
  }

  // 1. Ajouter des numéros jusqu'à ce que la solution soit unique.
  while (true) {
    final solver = PathSolver(boardFor(clueIndexes), maxNodes: maxNodes);
    final found = solver.count(limit: 2);
    if (solver.aborted) return null;
    if (found == 1) break;
    // Un autre chemin existe : on fixe un numéro sur une case où il s'écarte de la solution voulue (et qui n'en
    // porte pas encore). Quand toutes ces cases sont numérotées, l'autre chemin devient impossible : la boucle finit.
    final other = solver.solutions.firstWhere((s) => !_sameList(s, solution));
    var d = 0;
    while (d < solution.length && (other[d] == solution[d] || clueIndexes.contains(d))) {
      d++;
    }
    if (d >= solution.length) return null;
    clueIndexes.add(d);
  }

  // 2. Grilles faciles : quelques repères de plus, répartis le long du chemin.
  final free = [for (var i = 1; i < solution.length - 1; i++) if (!clueIndexes.contains(i)) i]..shuffle(random);
  while (clueIndexes.length < recipe.minClues && free.isNotEmpty) {
    clueIndexes.add(free.removeLast());
  }

  // 3. Grilles plus difficiles : retirer chaque numéro superflu.
  if (recipe.minimize) {
    final middle = clueIndexes.where((i) => i != 0 && i != solution.length - 1).toList()..shuffle(random);
    for (final i in middle) {
      if (clueIndexes.length <= recipe.minClues) break;
      final trial = {...clueIndexes}..remove(i);
      // Recherche non concluante : on garde le numéro (le niveau reste prouvé unique).
      final solver = PathSolver(boardFor(trial), maxNodes: maxNodes ~/ 4);
      if (solver.count(limit: 2) == 1 && !solver.aborted) clueIndexes.remove(i);
    }
  }

  final board = boardFor(clueIndexes);
  return PathLevel(
    id: id,
    difficulty: difficulty,
    size: n,
    clueCells: board.clueCells,
    walls: wallList,
    solution: solution,
  );
}

/// Chemin passant par toutes les cases d'une grille n × n, tiré au hasard (méthode du « backbite » : on part d'un
/// serpentin, puis on reconnecte de nombreuses fois une extrémité à une case voisine).
List<int> randomHamiltonianPath(int n, Random random) {
  final path = <int>[
    for (var r = 0; r < n; r++)
      for (var c = 0; c < n; c++) r * n + (r.isEven ? c : n - 1 - c),
  ];
  final steps = 40 * n * n * n;
  for (var s = 0; s < steps; s++) {
    if (random.nextBool()) {
      final reversed = path.reversed.toList();
      path
        ..clear()
        ..addAll(reversed);
    }
    final end = path.first;
    final r = end ~/ n, c = end % n;
    final options = <int>[
      if (r > 0) end - n,
      if (r < n - 1) end + n,
      if (c > 0) end - 1,
      if (c < n - 1) end + 1,
    ];
    final v = options[random.nextInt(options.length)];
    final i = path.indexOf(v);
    if (i <= 1) continue;
    // Relier l'extrémité à v, couper v de son prédécesseur : on retourne le début du chemin jusqu'à i - 1.
    final head = path.sublist(0, i).reversed.toList();
    path.replaceRange(0, i, head);
  }
  return path;
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
