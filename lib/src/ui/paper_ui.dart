import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/paper_palette.dart';
import '../art/shapes.dart';
import '../meta/progress_rules.dart';

/// A paper card with an inked outline and a soft offset shadow.
class PaperPanel extends StatelessWidget {
  const PaperPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.tape = false,
  });

  final PaperPalette palette;
  final Widget child;
  final EdgeInsets padding;

  /// Draws a strip of masking tape across the top edge.
  final bool tape;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.panelBorder.withValues(alpha: 0.85),
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(3, 5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!tape) return panel;
    return CustomPaint(foregroundPainter: _TapePainter(palette), child: panel);
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.p);
  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    Shapes.paintTape(
      canvas,
      Offset(size.width / 2, 0),
      size.width.clamp(40, 90).toDouble(),
      16,
      -0.04,
      p.tape,
      p.tapeStripe,
    );
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.p != p;
}

/// A stamped paper button: inked border, offset shadow that presses in.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.primary = false,
    this.compact = false,
    this.expand = false,
  });

  final PaperPalette palette;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Toggle state (tool buttons).
  final bool selected;

  /// Accent-filled call to action.
  final bool primary;
  final bool compact;

  /// Fill the available width.
  final bool expand;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final enabled = widget.onPressed != null;
    final filled = widget.primary || widget.selected;
    final bg = filled ? p.accent : p.panel;
    final fg = filled ? p.accentInk : p.panelText;
    final depth = _down || !enabled ? 1.0 : 3.0;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.compact ? 17 : 19, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: widget.compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        selected: widget.selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            margin: EdgeInsets.only(top: 3 - depth, bottom: depth),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 14,
              vertical: widget.compact ? 7 : 10,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.panelBorder, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: p.panelBorder.withValues(alpha: 0.9),
                  offset: Offset(0, depth),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Up to three stars, filled for [count].
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.count,
    required this.palette,
    this.size = 18,
    this.total = 3,
  });

  final int count;
  final int total;
  final double size;
  final PaperPalette palette;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * total + (total - 1) * size * 0.15, size),
    painter: _StarsPainter(count, total, palette),
  );
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.count, this.total, this.p);
  final int count;
  final int total;
  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height;
    for (var i = 0; i < total; i++) {
      Shapes.paintStar(
        canvas,
        Offset(s / 2 + i * s * 1.15, s / 2),
        s * 0.48,
        filled: i < count,
        fill: const Color(0xFFFFC93C),
        outline: p.panelBorder,
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) =>
      old.count != count || old.total != total || old.p != p;
}

/// "Lv N" badge plus an XP progress bar.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.level,
    required this.palette,
    this.fraction,
  });

  final PainterLevel level;
  final PaperPalette palette;

  /// Overrides the bar fill (summary animation).
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final f = (fraction ?? level.fraction).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: p.panelBorder,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Lv ${level.level}',
            style: TextStyle(
              color: p.panel,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: p.panelBorder.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: p.panelBorder, width: 1.2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: f,
              child: Container(
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The game wordmark: "Nono" in ink and "Grid" on a little stamped tile.
class NonoLogo extends StatelessWidget {
  const NonoLogo({super.key, required this.palette, this.size = 24});

  final PaperPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    'NonoGrid',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: palette.panelText,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
      shadows: [
        Shadow(
          color: palette.accent.withValues(alpha: 0.9),
          offset: const Offset(2, 2),
        ),
      ],
    ),
  );
}

/// Small preview swatch of a theme (desk, paper, ink cells).
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({super.key, required this.theme});
  final NonoTheme theme;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SwatchPainter(PaperPalette.of(theme)));
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.p);
  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [p.deskTop, p.deskBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    final paper = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.62,
      height: size.height * 0.7,
    );
    canvas.drawRect(
      paper.shift(const Offset(2, 3)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRect(paper, Paint()..color = p.paper);
    const n = 4;
    final cell = paper.width / n;
    final rows = (paper.height / cell).floor();
    final top = paper.top + (paper.height - rows * cell) / 2;
    const pattern = [0x6, 0xF, 0x9, 0x6, 0xF];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < n; x++) {
        if ((pattern[y % pattern.length] >> x) & 1 == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              paper.left + x * cell,
              top + y * cell,
              cell,
              cell,
            ).deflate(1.5),
            Paint()..color = p.ink,
          );
        }
      }
    }
    Shapes.paintTape(
      canvas,
      Offset(paper.left + 4, paper.top + 2),
      size.width * 0.3,
      8,
      -0.6,
      p.tape,
      p.tapeStripe,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.p != p;
}

/// Gold "complete" seal for finished album sets, drawn in code.
class CompletionSeal extends StatelessWidget {
  const CompletionSeal({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SealPainter());
}

class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path();
    const points = 12;
    for (var i = 0; i < points * 2; i++) {
      final a = i * math.pi / points - math.pi / 2;
      final rr = i.isEven ? r : r * 0.82;
      final o = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE8A317));
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..color = const Color(0xFFFFD45C)
        ..style = PaintingStyle.fill,
    );
    Shapes.paintCheck(
      canvas,
      Rect.fromCircle(center: c, radius: r * 0.42),
      const Color(0xFF8A5A00),
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => false;
}
