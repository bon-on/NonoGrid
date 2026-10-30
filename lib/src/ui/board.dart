import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../logic/game.dart';

/// Palette shared by the board and the screen.
class NonoColors {
  static const background = Color(0xFF161925);
  static const paper = Color(0xFFF5F0E6);
  static const clueBand = Color(0xFFE9E2D3);
  static const clueHighlight = Color(0xFFDCD2BE);
  static const ink = Color(0xFF242638);
  static const inkDim = Color(0x55242638);
  static const cross = Color(0xFF8C8478);
  static const mistake = Color(0xFFE05D5D);
  static const accent = Color(0xFFF2A65A);
  static const thinLine = Color(0xFFC9BFAE);
}

/// Sizes of the clue areas and cells for a given space.
class BoardMetrics {
  BoardMetrics._(
    this.n,
    this.cell,
    this.font,
    this.rowSlotW,
    this.colSlotH,
    this.rowSlots,
    this.colSlots,
  );

  static const double minFont = 11;
  static const double maxCell = 64;

  factory BoardMetrics.fit({
    required int n,
    required int rowSlots,
    required int colSlots,
    required int maxDigits,
    required Size space,
  }) {
    double rowSlotW(double f) => f * 0.62 * maxDigits + f * 0.45;
    double colSlotH(double f) => f * 1.2;
    double cellFor(double f) {
      final byW = (space.width - rowSlots * rowSlotW(f) - 6) / n;
      final byH = (space.height - colSlots * colSlotH(f) - 4) / n;
      return math.min(maxCell, math.min(byW, byH));
    }

    // Font follows cell size, cell size depends on clue slots sized by font:
    // iterate a few times, then derive the cell from the final font.
    var font = 16.0;
    for (var i = 0; i < 4; i++) {
      font = (cellFor(font) * 0.5).clamp(minFont, 18.0);
    }
    var cell = cellFor(font);
    cell = math.max(cell, 8);
    return BoardMetrics._(
      n,
      cell,
      font,
      rowSlotW(font),
      colSlotH(font),
      rowSlots,
      colSlots,
    );
  }

  final int n;
  final double cell;
  final double font;
  final double rowSlotW;
  final double colSlotH;
  final int rowSlots;
  final int colSlots;

  double get clueW => rowSlots * rowSlotW + 6;
  double get clueH => colSlots * colSlotH + 4;
  double get gridSize => n * cell;
  Size get size => Size(clueW + gridSize, clueH + gridSize);
  Offset get gridOrigin => Offset(clueW, clueH);
}

typedef StrokeStart = void Function(int row, int col, Tool tool);
typedef StrokeMove = void Function(int row, int col);

/// The clue + grid board. Owns no game state; reports pointer strokes.
class NonoBoard extends StatefulWidget {
  const NonoBoard({
    super.key,
    required this.game,
    required this.tool,
    required this.cursor,
    required this.showCursor,
    required this.reveal,
    required this.revealColor,
    required this.mistakes,
    required this.onStrokeStart,
    required this.onStrokeMove,
    required this.onStrokeEnd,
  });

  final NonoGame game;
  final Tool tool;
  final (int, int) cursor;
  final bool showCursor;

  /// Win reveal progress 0..1 (0 while playing).
  final Animation<double> reveal;
  final Color revealColor;
  final Set<int> mistakes;
  final StrokeStart onStrokeStart;
  final StrokeMove onStrokeMove;
  final VoidCallback onStrokeEnd;

  @override
  State<NonoBoard> createState() => _NonoBoardState();
}

class _NonoBoardState extends State<NonoBoard> {
  int? _pointer;

  (int, int) _cellAt(BoardMetrics m, Offset local) {
    final p = local - m.gridOrigin;
    return ((p.dy / m.cell).floor(), (p.dx / m.cell).floor());
  }

  @override
  Widget build(BuildContext context) {
    final clues = widget.game.puzzle.clues;
    var maxDigits = 1;
    for (final line in [...clues.rows, ...clues.cols]) {
      for (final v in line) {
        if (v >= 10) maxDigits = 2;
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = BoardMetrics.fit(
          n: widget.game.size,
          rowSlots: clues.maxRowClueCount,
          colSlots: clues.maxColClueCount,
          maxDigits: maxDigits,
          space: constraints.biggest,
        );
        return Center(
          child: Listener(
            onPointerDown: (e) {
              if (_pointer != null) return;
              final (r, c) = _cellAt(m, e.localPosition);
              if (!widget.game.inBounds(r, c)) return;
              _pointer = e.pointer;
              final secondary =
                  e.kind == PointerDeviceKind.mouse &&
                  (e.buttons & kSecondaryMouseButton) != 0;
              widget.onStrokeStart(r, c, secondary ? Tool.cross : widget.tool);
            },
            onPointerMove: (e) {
              if (e.pointer != _pointer) return;
              final (r, c) = _cellAt(m, e.localPosition);
              widget.onStrokeMove(r, c);
            },
            onPointerUp: (e) => _end(e.pointer),
            onPointerCancel: (e) => _end(e.pointer),
            child: AnimatedBuilder(
              animation: widget.reveal,
              builder: (context, _) => CustomPaint(
                size: m.size,
                painter: _BoardPainter(
                  game: widget.game,
                  metrics: m,
                  cursor: widget.showCursor ? widget.cursor : null,
                  reveal: widget.reveal.value,
                  revealColor: widget.revealColor,
                  mistakes: widget.mistakes,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    widget.onStrokeEnd();
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.metrics,
    required this.cursor,
    required this.reveal,
    required this.revealColor,
    required this.mistakes,
  });

  final NonoGame game;
  final BoardMetrics metrics;
  final (int, int)? cursor;
  final double reveal;
  final Color revealColor;
  final Set<int> mistakes;

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    final n = m.n;
    final o = m.gridOrigin;
    final gs = m.gridSize;
    final cell = m.cell;

    // Clue bands.
    final band = Paint()..color = NonoColors.clueBand;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, o.dy, m.clueW - 2, gs),
        const Radius.circular(6),
      ),
      band,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(o.dx, 0, gs, m.clueH - 2),
        const Radius.circular(6),
      ),
      band,
    );
    final cur = cursor;
    if (cur != null && reveal == 0) {
      final hi = Paint()..color = NonoColors.clueHighlight;
      canvas.drawRect(
        Rect.fromLTWH(0, o.dy + cur.$1 * cell, m.clueW - 2, cell),
        hi,
      );
      canvas.drawRect(
        Rect.fromLTWH(o.dx + cur.$2 * cell, 0, cell, m.clueH - 2),
        hi,
      );
    }

    // Grid paper.
    canvas.drawRect(
      Rect.fromLTWH(o.dx, o.dy, gs, gs),
      Paint()..color = NonoColors.paper,
    );

    _paintClues(canvas);

    // Cells.
    final fillPaint = Paint();
    final crossPaint = Paint()
      ..color = NonoColors.cross.withValues(alpha: 1 - reveal)
      ..strokeWidth = math.max(1.5, cell * 0.08)
      ..strokeCap = StrokeCap.round;
    final pad = math.max(1.0, cell * 0.08);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final i = r * n + c;
        final rect = Rect.fromLTWH(
          o.dx + c * cell,
          o.dy + r * cell,
          cell,
          cell,
        );
        if (reveal > 0) {
          if (!game.puzzle.solution[i]) continue;
          final delay = (r + c) / (2 * n - 2).clamp(1, 1000) * 0.6;
          final t = ((reveal - delay) / 0.4).clamp(0.0, 1.0);
          final color = Color.lerp(NonoColors.ink, revealColor, t)!;
          final inset = pad * (1 - t);
          final pop = t > 0 && t < 1
              ? math.sin(t * math.pi) * cell * 0.08
              : 0.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.deflate(inset - pop),
              Radius.circular(cell * 0.12 * (1 - t)),
            ),
            fillPaint..color = color,
          );
          continue;
        }
        switch (game.cells[i]) {
          case Mark.filled:
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                rect.deflate(pad),
                Radius.circular(cell * 0.12),
              ),
              fillPaint
                ..color = mistakes.contains(i)
                    ? NonoColors.mistake
                    : NonoColors.ink,
            );
          case Mark.crossed:
            final d = rect.deflate(cell * 0.28);
            canvas.drawLine(d.topLeft, d.bottomRight, crossPaint);
            canvas.drawLine(d.topRight, d.bottomLeft, crossPaint);
          case Mark.empty:
            break;
        }
      }
    }

    // Grid lines: thin per cell, thick every 5 cells and on the border.
    final lineAlpha = 1 - reveal;
    final thin = Paint()
      ..color = NonoColors.thinLine.withValues(alpha: lineAlpha)
      ..strokeWidth = 1;
    final border = Paint()
      ..color = NonoColors.ink
      ..strokeWidth = 2;
    final five = Paint()
      ..color = NonoColors.ink.withValues(alpha: 0.75 * lineAlpha)
      ..strokeWidth = 2;
    for (var i = 0; i <= n; i++) {
      final p = (i == 0 || i == n) ? border : (i % 5 == 0 ? five : thin);
      canvas.drawLine(
        Offset(o.dx + i * cell, o.dy),
        Offset(o.dx + i * cell, o.dy + gs),
        p,
      );
      canvas.drawLine(
        Offset(o.dx, o.dy + i * cell),
        Offset(o.dx + gs, o.dy + i * cell),
        p,
      );
    }

    // Keyboard cursor.
    if (cur != null && reveal == 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          o.dx + cur.$2 * cell,
          o.dy + cur.$1 * cell,
          cell,
          cell,
        ).deflate(1.5),
        Paint()
          ..color = NonoColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _paintClues(Canvas canvas) {
    final m = metrics;
    final o = m.gridOrigin;
    final clues = game.puzzle.clues;
    for (var r = 0; r < m.n; r++) {
      final done = game.isWon || game.rowSatisfied(r);
      final line = clues.rows[r].isEmpty ? const [0] : clues.rows[r];
      for (var k = 0; k < line.length; k++) {
        final slotRight = m.clueW - 6 - (line.length - 1 - k) * m.rowSlotW;
        _text(
          canvas,
          '${line[k]}',
          done,
          Rect.fromLTWH(
            slotRight - m.rowSlotW,
            o.dy + r * m.cell,
            m.rowSlotW,
            m.cell,
          ),
        );
      }
    }
    for (var c = 0; c < m.n; c++) {
      final done = game.isWon || game.colSatisfied(c);
      final line = clues.cols[c].isEmpty ? const [0] : clues.cols[c];
      for (var k = 0; k < line.length; k++) {
        final slotBottom = m.clueH - 4 - (line.length - 1 - k) * m.colSlotH;
        _text(
          canvas,
          '${line[k]}',
          done,
          Rect.fromLTWH(
            o.dx + c * m.cell,
            slotBottom - m.colSlotH,
            m.cell,
            m.colSlotH,
          ),
        );
      }
    }
  }

  void _text(Canvas canvas, String s, bool dim, Rect box) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: dim ? NonoColors.inkDim : NonoColors.ink,
          fontSize: metrics.font,
          fontWeight: dim ? FontWeight.w500 : FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(box.center.dx - tp.width / 2, box.center.dy - tp.height / 2),
    );
  }

  // The game is mutated in place, so always repaint when rebuilt.
  @override
  bool shouldRepaint(_BoardPainter old) => true;
}
