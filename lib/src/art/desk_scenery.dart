import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'paper_palette.dart';

/// The craft desk behind everything: wood grain, paper specks and a few
/// props (pencil, ink bottle, paper crane, scraps) placed near the corners.
///
/// Static: it only repaints when the palette or size changes.
class DeskScenery extends StatelessWidget {
  const DeskScenery({super.key, required this.palette});

  final PaperPalette palette;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: DeskSceneryPainter(palette),
      child: const SizedBox.expand(),
    ),
  );
}

class DeskSceneryPainter extends CustomPainter {
  DeskSceneryPainter(this.p);

  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.deskTop, p.deskBottom],
        ).createShader(rect),
    );
    _grain(canvas, size);
    _specks(canvas, size);
    if (p.night) _night(canvas, size);
    final s = math.min(size.width, size.height);
    final unit = (s / 9).clamp(28.0, 90.0);
    _pencil(
      canvas,
      Offset(size.width - unit * 1.6, size.height - unit * 0.9),
      unit * 3.2,
      unit * 0.32,
      -0.5,
    );
    _inkBottle(canvas, Offset(unit * 1.0, size.height - unit * 1.05), unit);
    _crane(canvas, Offset(size.width - unit * 1.2, unit * 1.0), unit * 0.9);
    _scrap(canvas, Offset(unit * 0.9, unit * 0.9), unit * 0.9, 0.25);
    _scrap(
      canvas,
      Offset(size.width * 0.5 + unit * 4, size.height - unit * 0.35),
      unit * 0.6,
      -0.4,
    );
    // Soft vignette pulls the eye to the centre.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [const Color(0x00000000), const Color(0x33000000)],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
  }

  void _grain(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var y = 0.0; y < size.height; y += 9 + rng.nextDouble() * 14) {
      paint.color = p.grain.withValues(alpha: 0.12 + rng.nextDouble() * 0.16);
      final path = Path()..moveTo(0, y);
      final amp = 2 + rng.nextDouble() * 5;
      final freq = 0.004 + rng.nextDouble() * 0.006;
      final phase = rng.nextDouble() * 6;
      for (var x = 0.0; x <= size.width; x += 16) {
        path.lineTo(x, y + math.sin(x * freq + phase) * amp);
      }
      canvas.drawPath(path, paint);
    }
    // A few knots.
    for (var i = 0; i < 3; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      for (var k = 1; k <= 3; k++) {
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 14.0 * k, height: 6.0 * k),
          paint..color = p.grain.withValues(alpha: 0.18),
        );
      }
    }
  }

  void _specks(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final n = (size.width * size.height / 2600).clamp(80, 700).toInt();
    final light = Paint()..color = const Color(0x18FFFFFF);
    final dark = Paint()..color = const Color(0x14000000);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.6 + rng.nextDouble() * 1.4,
        i.isEven ? light : dark,
      );
    }
  }

  void _night(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.7, -0.9),
          radius: 0.9,
          colors: [const Color(0x40FFE3A0), const Color(0x00FFE3A0)],
        ).createShader(rect),
    );
    final rng = math.Random(23);
    for (var i = 0; i < 40; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height,
      );
      final r = 0.8 + rng.nextDouble() * 1.6;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Color.fromRGBO(
            255,
            240,
            200,
            0.25 + rng.nextDouble() * 0.5,
          ),
      );
    }
  }

  void _shadow(Canvas canvas, Path path, double blur) {
    canvas.drawPath(
      path.shift(Offset(blur * 0.4, blur * 0.6)),
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  void _pencil(Canvas canvas, Offset c, double len, double w, double angle) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final body = Rect.fromLTWH(-len / 2, -w / 2, len * 0.78, w);
    final outline = Path()
      ..addRect(body)
      ..moveTo(body.right, -w / 2)
      ..lineTo(len / 2, 0)
      ..lineTo(body.right, w / 2)
      ..close();
    _shadow(canvas, outline, 5);
    // Eraser and ferrule.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-len / 2 - w * 0.9, -w / 2, w * 0.9, w),
        topLeft: Radius.circular(w * 0.3),
        bottomLeft: Radius.circular(w * 0.3),
      ),
      Paint()..color = const Color(0xFFF08DA0),
    );
    canvas.drawRect(
      Rect.fromLTWH(-len / 2 - w * 0.15, -w / 2, w * 0.5, w),
      Paint()..color = const Color(0xFFC9CDD6),
    );
    canvas.drawRect(body, Paint()..color = const Color(0xFFF4C542));
    canvas.drawRect(
      Rect.fromLTWH(body.left, -w / 2, body.width, w * 0.3),
      Paint()..color = const Color(0xFFFAD970),
    );
    canvas.drawRect(
      Rect.fromLTWH(body.left, w * 0.2, body.width, w * 0.3),
      Paint()..color = const Color(0xFFDCA92E),
    );
    final wood = Path()
      ..moveTo(body.right, -w / 2)
      ..lineTo(len / 2, 0)
      ..lineTo(body.right, w / 2)
      ..close();
    canvas.drawPath(wood, Paint()..color = const Color(0xFFF2D3A6));
    final lead = Path()
      ..moveTo(len / 2 - len * 0.07, -w * 0.16)
      ..lineTo(len / 2, 0)
      ..lineTo(len / 2 - len * 0.07, w * 0.16)
      ..close();
    canvas.drawPath(lead, Paint()..color = const Color(0xFF3A3A44));
    canvas.restore();
  }

  void _inkBottle(Canvas canvas, Offset c, double u) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: u * 1.1, height: u * 0.95),
      Radius.circular(u * 0.22),
    );
    _shadow(canvas, Path()..addRRect(body), 6);
    canvas.drawRRect(body, Paint()..color = const Color(0xFF2B3550));
    // Ink level shine.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + u * 0.1,
          body.top + u * 0.12,
          u * 0.16,
          u * 0.6,
        ),
        Radius.circular(u * 0.08),
      ),
      Paint()..color = const Color(0x40FFFFFF),
    );
    // Label.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, u * 0.08),
          width: u * 0.7,
          height: u * 0.38,
        ),
        Radius.circular(u * 0.05),
      ),
      Paint()..color = const Color(0xFFF6EEDB),
    );
    canvas.drawCircle(
      c + Offset(0, u * 0.08),
      u * 0.09,
      Paint()..color = p.accent,
    );
    // Neck and cap.
    canvas.drawRect(
      Rect.fromCenter(
        center: c - Offset(0, u * 0.55),
        width: u * 0.42,
        height: u * 0.18,
      ),
      Paint()..color = const Color(0xFF2B3550),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c - Offset(0, u * 0.74),
          width: u * 0.56,
          height: u * 0.26,
        ),
        Radius.circular(u * 0.06),
      ),
      Paint()..color = const Color(0xFF1A1E2C),
    );
  }

  void _crane(Canvas canvas, Offset c, double u) {
    final light = Paint()..color = p.accent.withValues(alpha: 0.95);
    final mid = Paint()
      ..color = Color.lerp(p.accent, const Color(0xFF000000), 0.18)!;
    final dark = Paint()
      ..color = Color.lerp(p.accent, const Color(0xFF000000), 0.35)!;
    Path tri(Offset a, Offset b, Offset d) => Path()
      ..moveTo(c.dx + a.dx * u, c.dy + a.dy * u)
      ..lineTo(c.dx + b.dx * u, c.dy + b.dy * u)
      ..lineTo(c.dx + d.dx * u, c.dy + d.dy * u)
      ..close();
    final wingBack = tri(
      const Offset(-0.1, 0.1),
      const Offset(0.35, -0.85),
      const Offset(0.35, 0.15),
    );
    final bodyL = tri(
      const Offset(-0.9, -0.45),
      const Offset(-0.1, 0.1),
      const Offset(0.0, 0.35),
    );
    final bodyR = tri(
      const Offset(0.0, 0.35),
      const Offset(-0.1, 0.1),
      const Offset(0.95, -0.25),
    );
    final wingFront = tri(
      const Offset(-0.1, 0.1),
      const Offset(-0.35, -0.75),
      const Offset(0.3, 0.1),
    );
    _shadow(
      canvas,
      Path()
        ..addPath(bodyL, Offset.zero)
        ..addPath(bodyR, Offset.zero),
      5,
    );
    canvas.drawPath(wingBack, dark);
    canvas.drawPath(bodyL, mid);
    canvas.drawPath(bodyR, light);
    canvas.drawPath(wingFront, light);
    canvas.drawPath(
      tri(
        const Offset(-0.9, -0.45),
        const Offset(-1.05, -0.38),
        const Offset(-0.82, -0.36),
      ),
      dark,
    );
  }

  void _scrap(Canvas canvas, Offset c, double u, double angle) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final r = Rect.fromCenter(center: Offset.zero, width: u * 1.3, height: u);
    _shadow(canvas, Path()..addRect(r), 4);
    canvas.drawRect(r, Paint()..color = p.paper);
    final grid = Paint()
      ..color = p.gridThin
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = r.left + r.width * i / 4;
      final y = r.top + r.height * i / 4;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
    }
    final cell = Size(r.width / 4, r.height / 4);
    final ink = Paint()..color = p.ink.withValues(alpha: 0.85);
    for (final (cx, cy) in const [(0, 0), (1, 1), (2, 1), (1, 2), (3, 3)]) {
      canvas.drawRect(
        Rect.fromLTWH(
          r.left + cx * cell.width + 1.5,
          r.top + cy * cell.height + 1.5,
          cell.width - 3,
          cell.height - 3,
        ),
        ink,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DeskSceneryPainter old) => old.p != p;
}
