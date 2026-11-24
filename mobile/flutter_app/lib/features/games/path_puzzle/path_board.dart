import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'path_puzzle.dart';

/// Grille de Connexion mystère : le doigt trace le chemin case par case.
///
/// - Poser le doigt sur une case déjà tracée reprend le chemin à cet endroit (tout ce qui suit est effacé).
/// - Glisser vers une case voisine prolonge le chemin ; revenir en arrière l'efface.
/// - Un simple appui sur une case voisine de l'extrémité prolonge aussi le chemin (utile sans glisser).
/// Les mouvements rapides qui sautent des cases sont décomposés pas à pas.
class PathBoardView extends StatefulWidget {
  const PathBoardView({
    super.key,
    required this.game,
    required this.onChanged,
    required this.onBlocked,
    this.hintCell,
    this.enabled = true,
  });

  final PathGame game;

  /// Le chemin a changé (le parent redessine et sauvegarde).
  final ValueChanged<PathStep> onChanged;

  /// Pas refusé vers [cell] (numéro hors d'ordre, arrivée atteinte trop tôt…), une fois par geste.
  final ValueChanged<int> onBlocked;

  final int? hintCell;
  final bool enabled;

  @override
  State<PathBoardView> createState() => _PathBoardViewState();
}

class _PathBoardViewState extends State<PathBoardView> {
  bool _tracking = false;
  int? _lastBlocked;

  int? _cellAt(Offset local, double side) {
    final n = widget.game.board.size;
    final cell = side / n;
    final c = (local.dx / cell).floor(), r = (local.dy / cell).floor();
    if (r < 0 || c < 0 || r >= n || c >= n) return null;
    return r * n + c;
  }

  /// Case voisine de [from] en direction de [to], d'abord sur l'axe le plus éloigné.
  int _toward(int from, int to, {required bool primary}) {
    final n = widget.game.board.size;
    final dr = to ~/ n - from ~/ n, dc = to % n - from % n;
    final horizontalFirst = dc.abs() >= dr.abs();
    final horizontal = primary ? horizontalFirst : !horizontalFirst;
    if (horizontal && dc != 0) return from + dc.sign;
    if (!horizontal && dr != 0) return from + dr.sign * n;
    return from;
  }

  void _moveTo(int target) {
    final game = widget.game;
    PathStep? last;
    for (var guard = 0; guard < game.board.cellCount && target != game.head; guard++) {
      if (game.contains(target)) {
        last = game.tryEnter(target);
        break;
      }
      var step = PathStep.blocked;
      var tried = game.head;
      for (final primary in const [true, false]) {
        final next = _toward(game.head, target, primary: primary);
        if (next == game.head) continue;
        tried = next;
        step = game.tryEnter(next);
        if (step == PathStep.extended || step == PathStep.solved) break;
      }
      if (step == PathStep.extended || step == PathStep.solved) {
        last = step;
        if (step == PathStep.solved) break;
        continue;
      }
      if (_lastBlocked != tried) {
        _lastBlocked = tried;
        widget.onBlocked(tried);
      }
      break;
    }
    if (last != null) {
      if (last == PathStep.extended) HapticFeedback.selectionClick();
      widget.onChanged(last);
    }
  }

  void _down(Offset position, double side) {
    if (!widget.enabled) return;
    final cell = _cellAt(position, side);
    if (cell == null) return;
    _tracking = true;
    _lastBlocked = null;
    _moveTo(cell);
  }

  void _move(Offset position, double side) {
    if (!_tracking || !widget.enabled) return;
    final cell = _cellAt(position, side);
    if (cell != null) _moveTo(cell);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.biggest.shortestSide;
      return SizedBox.square(
        dimension: side,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e.localPosition, side),
          onPointerMove: (e) => _move(e.localPosition, side),
          onPointerUp: (_) => _tracking = false,
          onPointerCancel: (_) => _tracking = false,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(side),
              painter: PathBoardPainter(
                board: widget.game.board,
                path: widget.game.path,
                hintCell: widget.hintCell,
                solved: widget.game.isSolved,
                numberStyle: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class PathBoardPainter extends CustomPainter {
  PathBoardPainter({
    required this.board,
    required this.path,
    required this.hintCell,
    required this.solved,
    required this.numberStyle,
  });

  final PathBoard board;
  final List<int> path;
  final int? hintCell;
  final bool solved;
  final TextStyle numberStyle;

  static const _gridLine = Color(0xFFEADFE6);

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final cell = size.width / n;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    Offset center(int c) => Offset((c % n + 0.5) * cell, (c ~/ n + 0.5) * cell);
    Rect rectOf(int c) => Rect.fromLTWH((c % n) * cell, (c ~/ n) * cell, cell, cell);

    // Cases déjà reliées.
    final filled = Paint()..color = solved ? const Color(0xFFE3F4EC) : ZColors.primarySoft;
    for (final c in path) {
      canvas.drawRect(rectOf(c), filled);
    }

    // Quadrillage.
    final grid = Paint()
      ..color = _gridLine
      ..strokeWidth = 1;
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid);
    }

    // Indice : la case à atteindre.
    final hint = hintCell;
    if (hint != null) {
      canvas.drawCircle(
        center(hint),
        cell * 0.42,
        Paint()
          ..color = ZColors.success
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Le chemin.
    if (path.length > 1) {
      final line = Path()..moveTo(center(path.first).dx, center(path.first).dy);
      for (final c in path.skip(1)) {
        line.lineTo(center(c).dx, center(c).dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = solved ? ZColors.success : ZColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.32
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Murs.
    final wall = Paint()
      ..color = ZColors.ink
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in board.wallPairs) {
      final r = a ~/ n, c = a % n;
      if (b == a + 1) {
        canvas.drawLine(Offset((c + 1) * cell, r * cell + 3), Offset((c + 1) * cell, (r + 1) * cell - 3), wall);
      } else {
        canvas.drawLine(Offset(c * cell + 3, (r + 1) * cell), Offset((c + 1) * cell - 3, (r + 1) * cell), wall);
      }
    }

    // Numéros : sombres à atteindre, roses une fois atteints.
    final reached = path.toSet();
    for (var i = 0; i < board.clueCells.length; i++) {
      final c = board.clueCells[i];
      final o = center(c);
      canvas.drawCircle(
        o,
        cell * 0.31,
        Paint()..color = reached.contains(c) ? (solved ? ZColors.success : ZColors.primaryDark) : ZColors.ink,
      );
      final text = TextPainter(
        text: TextSpan(text: '${i + 1}', style: numberStyle.copyWith(fontSize: cell * 0.3)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, o - Offset(text.width / 2, text.height / 2));
    }

    // Extrémité du chemin (hors numéro) : point blanc cerclé.
    if (path.length > 1 && !board.clueAt.containsKey(path.last)) {
      final o = center(path.last);
      canvas.drawCircle(o, cell * 0.13, Paint()..color = Colors.white);
    }
    canvas.restore();

    canvas.drawRRect(
      outer.deflate(0.75),
      Paint()
        ..color = ZColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(PathBoardPainter old) =>
      !listEquals(old.path, path) ||
      old.hintCell != hintCell ||
      old.solved != solved ||
      old.board != board;
}
