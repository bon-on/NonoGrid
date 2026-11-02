import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Small vector shapes shared by the board, panels and overlays.
class Shapes {
  /// Five-point star path centered at [c] with outer radius [r].
  static Path star(Offset c, double r, {double inner = 0.48}) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * inner;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  /// Draws a filled or hollow star with a darker outline.
  static void paintStar(
    Canvas canvas,
    Offset c,
    double r, {
    required bool filled,
    required Color fill,
    required Color outline,
  }) {
    final path = star(c, r);
    if (filled) {
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        star(c + Offset(-r * 0.12, -r * 0.14), r * 0.42),
        Paint()..color = const Color(0x55FFFFFF),
      );
    } else {
      canvas.drawPath(path, Paint()..color = outline.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, r * 0.16),
    );
  }

  /// A hand-drawn check mark inside [box]; [t] 0..1 draws it progressively.
  static void paintCheck(Canvas canvas, Rect box, Color color, {double t = 1}) {
    if (t <= 0) return;
    final a = Offset(box.left + box.width * 0.18, box.top + box.height * 0.55);
    final b = Offset(box.left + box.width * 0.42, box.top + box.height * 0.8);
    final c = Offset(box.left + box.width * 0.85, box.top + box.height * 0.22);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.5, box.shortestSide * 0.16);
    final path = Path()..moveTo(a.dx, a.dy);
    final first = (t / 0.4).clamp(0.0, 1.0);
    final ab = Offset.lerp(a, b, first)!;
    path.lineTo(ab.dx, ab.dy);
    if (t > 0.4) {
      final bc = Offset.lerp(b, c, ((t - 0.4) / 0.6).clamp(0.0, 1.0))!;
      path.lineTo(bc.dx, bc.dy);
    }
    canvas.drawPath(path, paint);
  }

  /// A small padlock inside [box].
  static void paintLock(Canvas canvas, Rect box, Color color) {
    final w = box.width;
    final body = Rect.fromLTWH(
      box.left + w * 0.2,
      box.top + box.height * 0.45,
      w * 0.6,
      box.height * 0.45,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        box.left + w * 0.3,
        box.top + box.height * 0.12,
        w * 0.4,
        box.height * 0.6,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.08)),
      Paint()..color = color,
    );
  }

  /// A strip of masking tape centered at [c], rotated by [angle].
  static void paintTape(
    Canvas canvas,
    Offset c,
    double w,
    double h,
    double angle,
    Color color,
    Color stripe,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final path = Path();
    // Torn ends: small zigzags on the short sides.
    const teeth = 5;
    path.moveTo(-w / 2, -h / 2);
    path.lineTo(w / 2, -h / 2);
    for (var i = 1; i <= teeth; i++) {
      final y = -h / 2 + h * i / teeth;
      path.lineTo(w / 2 + (i.isOdd ? h * 0.08 : 0), y);
    }
    path.lineTo(-w / 2, h / 2);
    for (var i = teeth - 1; i >= 0; i--) {
      final y = -h / 2 + h * i / teeth;
      path.lineTo(-w / 2 - (i.isOdd ? h * 0.08 : 0), y);
    }
    path.close();
    canvas.drawPath(
      path.shift(const Offset(0, 1.5)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawPath(path, Paint()..color = color);
    final sp = Paint()
      ..color = stripe
      ..strokeWidth = h * 0.12;
    for (var x = -w / 2 + h * 0.4; x < w / 2; x += h * 0.55) {
      canvas.drawLine(Offset(x, -h / 2), Offset(x - h * 0.3, h / 2), sp);
    }
    canvas.restore();
  }
}
