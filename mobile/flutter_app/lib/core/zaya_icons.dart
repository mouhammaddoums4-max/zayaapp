import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Icônes dessinées pour ZAYA (barre d'onglets) : une bague pour « Mariage », deux cœurs pour « Explorer » et deux
/// bulles pour « Messages ». Dessins propres à ZAYA, sur une grille de 24 × 24 comme les icônes Material, en version
/// contour (onglet inactif) ou pleine (onglet actif). Les découpes sont transparentes : l'icône reste nette sur
/// n'importe quel fond (pastille rose de l'onglet actif, fond blanc).
enum ZGlyph { ring, hearts, chat }

class ZIcon extends StatelessWidget {
  const ZIcon(this.glyph, {super.key, this.filled = false, this.size = 24, this.color});
  final ZGlyph glyph;
  final bool filled;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF1B1020);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(glyph, filled, c)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.filled, this.color);
  final ZGlyph glyph;
  final bool filled;
  final Color color;

  Paint _stroke(double w) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  Paint get _fill => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  /// Efface (transparence) le tracé donné, pour séparer deux formes qui se chevauchent.
  static Paint _clear({double? stroke}) {
    final p = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;
    if (stroke != null) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round;
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.scale(s, s);
    switch (glyph) {
      case ZGlyph.ring:
        _ring(canvas);
      case ZGlyph.hearts:
        _hearts(canvas);
      case ZGlyph.chat:
        _chat(canvas);
    }
    canvas.restore();
  }

  // ── Bague : anneau surmonté d'une pierre taillée.
  void _ring(Canvas canvas) {
    const band = Offset(12, 15.2);
    canvas.drawCircle(band, 6.4, _stroke(filled ? 2.5 : 1.8));
    final gem = Path()
      ..moveTo(9.2, 2.6)
      ..lineTo(14.8, 2.6)
      ..lineTo(17, 5.4)
      ..lineTo(12, 10.4)
      ..lineTo(7, 5.4)
      ..close();
    // La pierre est posée sur l'anneau : on dégage sa place avant de la dessiner.
    canvas.drawPath(gem, _clear());
    canvas.drawPath(gem, _clear(stroke: filled ? 2.6 : 2.2));
    if (filled) {
      canvas.drawPath(gem, _fill);
      // Facettes en creux.
      final facets = Path()
        ..moveTo(7.6, 5.4)
        ..lineTo(16.4, 5.4)
        ..moveTo(10.6, 2.9)
        ..lineTo(9.6, 5.4)
        ..lineTo(12, 9.6)
        ..moveTo(13.4, 2.9)
        ..lineTo(14.4, 5.4)
        ..lineTo(12, 9.6);
      canvas.drawPath(facets, _clear(stroke: 0.9));
    } else {
      canvas.drawPath(gem, _stroke(1.6));
      canvas.drawPath(
          Path()
            ..moveTo(7.4, 5.4)
            ..lineTo(16.6, 5.4),
          _stroke(1.2));
    }
  }

  // ── Deux cœurs : un grand, et un petit qui s'envole en haut à droite.
  static Path _heart(Rect r) {
    double x(double v) => r.left + v * r.width;
    double y(double v) => r.top + v * r.height;
    return Path()
      ..moveTo(x(0.5), y(0.24))
      ..cubicTo(x(0.5), y(0.0), x(0.0), y(-0.02), x(0.0), y(0.3))
      ..cubicTo(x(0.0), y(0.56), x(0.3), y(0.74), x(0.5), y(0.94))
      ..cubicTo(x(0.7), y(0.74), x(1.0), y(0.56), x(1.0), y(0.3))
      ..cubicTo(x(1.0), y(-0.02), x(0.5), y(0.0), x(0.5), y(0.24))
      ..close();
  }

  void _hearts(Canvas canvas) {
    final big = _heart(const Rect.fromLTWH(1.4, 7.2, 15.2, 14.6));
    final small = _heart(const Rect.fromLTWH(-4.6, -4.4, 9.2, 8.8))
        .transform((Matrix4.identity()
              ..translateByDouble(17.6, 7.4, 0, 1)
              ..rotateZ(math.pi / 9))
            .storage);
    if (filled) {
      canvas.drawPath(big, _fill);
    } else {
      canvas.drawPath(big, _stroke(1.8));
    }
    canvas.drawPath(small, _clear());
    canvas.drawPath(small, _clear(stroke: filled ? 3.2 : 2.6));
    if (filled) {
      canvas.drawPath(small, _fill);
    } else {
      canvas.drawPath(small, _stroke(1.6));
    }
  }

  // ── Deux bulles : celle de devant (avec trois points quand l'onglet est actif) et une autre derrière.
  void _chat(Canvas canvas) {
    final back = Path()
      ..addRRect(RRect.fromLTRBR(8.2, 2.4, 22, 12.6, const Radius.circular(4.4)))
      ..moveTo(18.2, 12)
      ..lineTo(21.2, 15.6)
      ..lineTo(15.2, 12.4)
      ..close();
    final front = Path()
      ..addRRect(RRect.fromLTRBR(2, 7.4, 16.8, 18.2, const Radius.circular(4.6)))
      ..moveTo(4.6, 17.4)
      ..lineTo(3.2, 21.6)
      ..lineTo(9, 17.8)
      ..close();
    canvas.drawPath(back, _stroke(1.6));
    canvas.drawPath(front, _clear());
    canvas.drawPath(front, _clear(stroke: 3.2));
    if (filled) {
      canvas.drawPath(front, _fill);
      for (final dx in [5.9, 9.4, 12.9]) {
        canvas.drawCircle(Offset(dx, 12.8), 1.2, _clear());
      }
    } else {
      canvas.drawPath(front, _stroke(1.8));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.filled != filled || old.color != color;
}
