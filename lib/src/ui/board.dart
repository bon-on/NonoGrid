import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../art/paper_palette.dart';
import '../art/shapes.dart';
import '../logic/game.dart';
import 'board_fx.dart';

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

  /// Large enough that a 5x5 fills most of a desktop window.
  static const double maxCell = 84;

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
      font = (cellFor(font) * 0.5).clamp(minFont, 20.0);
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

/// Space around the board for its paper card and tape.
const double kBoardCardPad = 14;

/// The clue + grid board on a taped paper card. Owns no game state; reports
/// pointer strokes and paints [fx] on top of the current marks.
class NonoBoard extends StatefulWidget {
  const NonoBoard({
    super.key,
    required this.game,
    required this.tool,
    required this.cursor,
    required this.showCursor,
    required this.reveal,
    required this.palette,
    required this.picture,
    required this.mistakes,
    required this.fx,
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
  final PaperPalette palette;
  final PicturePalette picture;
  final Set<int> mistakes;
  final BoardFx fx;
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
    return Padding(
      padding: const EdgeInsets.all(kBoardCardPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final m = BoardMetrics.fit(
            n: widget.game.size,
            rowSlots: clues.maxRowClueCount,
            colSlots: clues.maxColClueCount,
            maxDigits: maxDigits,
            space: constraints.biggest,
          );
          // Tiny spaces (very short windows, big boards) cannot keep the
          // minimum clue font and cell size; scale the whole board down so
          // it never paints past its box onto neighbouring controls.
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Listener(
                onPointerDown: (e) {
                  if (_pointer != null) return;
                  final (r, c) = _cellAt(m, e.localPosition);
                  if (!widget.game.inBounds(r, c)) return;
                  _pointer = e.pointer;
                  final secondary =
                      e.kind == PointerDeviceKind.mouse &&
                      (e.buttons & kSecondaryMouseButton) != 0;
                  widget.onStrokeStart(
                    r,
                    c,
                    secondary ? Tool.cross : widget.tool,
                  );
                },
                onPointerMove: (e) {
                  if (e.pointer != _pointer) return;
                  final (r, c) = _cellAt(m, e.localPosition);
                  widget.onStrokeMove(r, c);
                },
                onPointerUp: (e) => _end(e.pointer),
                onPointerCancel: (e) => _end(e.pointer),
                child: CustomPaint(
                  key: const Key('board-canvas'),
                  size: m.size,
                  painter: BoardPainter(
                    game: widget.game,
                    metrics: m,
                    palette: widget.palette,
                    picture: widget.picture,
                    cursor: widget.showCursor ? widget.cursor : null,
                    reveal: widget.reveal,
                    mistakes: widget.mistakes,
                    fx: widget.fx,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _end(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    widget.onStrokeEnd();
  }
}

double _easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = t - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/// Paints the paper card, clues, marks, effects and the win bloom.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.game,
    required this.metrics,
    required this.palette,
    required this.picture,
    required this.cursor,
    required this.reveal,
    required this.mistakes,
    required this.fx,
  }) : super(repaint: Listenable.merge([reveal, fx]));

  final NonoGame game;
  final BoardMetrics metrics;
  final PaperPalette palette;
  final PicturePalette picture;
  final (int, int)? cursor;
  final Animation<double> reveal;
  final Set<int> mistakes;
  final BoardFx fx;

  PaperPalette get p => palette;

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    final rv = reveal.value;
    canvas.save();
    final shake = fx.shakeStart;
    if (shake != null) {
      final t = fx.progress(shake, BoardFx.shakeLength).clamp(0.0, 1.0);
      final amp = math.min(9.0, m.cell * 0.22) * (1 - t);
      canvas.translate(math.sin(t * math.pi * 7) * amp, 0);
    }
    _card(canvas, size);
    _clueBands(canvas, rv);
    _paper(canvas, rv);
    _clues(canvas, rv);
    _cells(canvas, rv);
    _lineFx(canvas);
    _gridLines(canvas, rv);
    final cur = cursor;
    if (cur != null && rv == 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            m.gridOrigin.dx + cur.$2 * m.cell,
            m.gridOrigin.dy + cur.$1 * m.cell,
            m.cell,
            m.cell,
          ).deflate(1.5),
          Radius.circular(m.cell * 0.12),
        ),
        Paint()
          ..color = p.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.restore();
    _confetti(canvas, size);
  }

  void _card(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(kBoardCardPad - 4),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      card.shift(const Offset(3, 6)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      card,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.paper, Color.lerp(p.paper, p.paperShade, 0.6)!],
        ).createShader(card.outerRect),
    );
    final tw = math.min(84.0, size.width * 0.22);
    Shapes.paintTape(
      canvas,
      card.outerRect.topLeft + Offset(tw * 0.35, 2),
      tw,
      18,
      -0.6,
      p.tape,
      p.tapeStripe,
    );
    Shapes.paintTape(
      canvas,
      card.outerRect.topRight + Offset(-tw * 0.35, 2),
      tw,
      18,
      0.6,
      p.tape,
      p.tapeStripe,
    );
  }

  void _clueBands(Canvas canvas, double rv) {
    final m = metrics;
    final o = m.gridOrigin;
    final gs = m.gridSize;
    final band = Paint()..color = p.clueBand;
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
    final done = Paint()
      ..color = p.flash.withValues(alpha: p.night ? 0.16 : 0.32);
    for (var i = 0; i < m.n; i++) {
      if (rv == 0 && game.rowSatisfied(i)) {
        canvas.drawRect(
          Rect.fromLTWH(2, o.dy + i * m.cell + 1, m.clueW - 6, m.cell - 2),
          done,
        );
      }
      if (rv == 0 && game.colSatisfied(i)) {
        canvas.drawRect(
          Rect.fromLTWH(o.dx + i * m.cell + 1, 2, m.cell - 2, m.clueH - 6),
          done,
        );
      }
    }
    final cur = cursor;
    if (cur != null && rv == 0) {
      final hi = Paint()..color = p.clueHighlight;
      canvas.drawRect(
        Rect.fromLTWH(0, o.dy + cur.$1 * m.cell, m.clueW - 2, m.cell),
        hi,
      );
      canvas.drawRect(
        Rect.fromLTWH(o.dx + cur.$2 * m.cell, 0, m.cell, m.clueH - 2),
        hi,
      );
    }
  }

  void _paper(Canvas canvas, double rv) {
    final m = metrics;
    final o = m.gridOrigin;
    final grid = Rect.fromLTWH(o.dx, o.dy, m.gridSize, m.gridSize);
    canvas.drawRect(grid, Paint()..color = p.paper);
    // Alternate 5x5 blocks are shaded a little to help counting.
    if (m.n > 5) {
      final shade = Paint()
        ..color = p.paperShade.withValues(alpha: 0.55 * (1 - rv));
      for (var br = 0; br * 5 < m.n; br++) {
        for (var bc = 0; bc * 5 < m.n; bc++) {
          if ((br + bc).isOdd) {
            canvas.drawRect(
              Rect.fromLTWH(
                o.dx + bc * 5 * m.cell,
                o.dy + br * 5 * m.cell,
                math.min(5, m.n - bc * 5) * m.cell,
                math.min(5, m.n - br * 5) * m.cell,
              ),
              shade,
            );
          }
        }
      }
    }
    if (rv > 0) {
      canvas.drawRect(
        grid,
        Paint()
          ..color = picture.background.withValues(
            alpha: (rv / 0.5).clamp(0.0, 1.0),
          ),
      );
    }
  }

  void _clues(Canvas canvas, double rv) {
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

  void _cells(Canvas canvas, double rv) {
    final m = metrics;
    final n = m.n;
    final o = m.gridOrigin;
    final cell = m.cell;
    final pad = math.max(1.0, cell * 0.08);
    final fill = Paint();
    final sheen = Paint()..color = p.inkHighlight.withValues(alpha: 0.55);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final i = r * n + c;
        final rect = Rect.fromLTWH(
          o.dx + c * cell,
          o.dy + r * cell,
          cell,
          cell,
        );
        if (rv > 0) {
          if (!game.puzzle.solution[i]) continue;
          final delay = (r + c) / (2 * n - 2).clamp(1, 1000) * 0.6;
          final t = ((rv - delay) / 0.4).clamp(0.0, 1.0);
          final color = Color.lerp(p.ink, picture.cellColor(r, c, n), t)!;
          final inset = pad * (1 - t);
          final pop = t > 0 && t < 1 ? math.sin(t * math.pi) * cell * 0.1 : 0.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.deflate(inset - pop),
              Radius.circular(cell * 0.12 * (1 - t)),
            ),
            fill..color = color,
          );
          continue;
        }
        final pop = fx.pops[i];
        var t = 1.0;
        if (pop != null) {
          t = fx.progress(pop.start, BoardFx.popLength).clamp(0.0, 1.0);
          if (pop.after == Mark.empty && t < 1) {
            _ghost(canvas, rect, pop.before, 1 - t, pad);
          }
        }
        switch (game.cells[i]) {
          case Mark.filled:
            if (t <= 0) break;
            final s = _easeOutBack(t);
            final inner = rect.deflate(pad);
            final scaled = Rect.fromCenter(
              center: inner.center,
              width: inner.width * (0.35 + 0.65 * s),
              height: inner.height * (0.35 + 0.65 * s),
            );
            final wrong = mistakes.contains(i);
            canvas.drawRRect(
              RRect.fromRectAndRadius(scaled, Radius.circular(cell * 0.14)),
              fill..color = wrong ? p.mistake : p.ink,
            );
            if (!wrong && cell >= 14) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                    scaled.left + scaled.width * 0.14,
                    scaled.top + scaled.height * 0.14,
                    scaled.width * 0.5,
                    scaled.height * 0.14,
                  ),
                  Radius.circular(cell * 0.06),
                ),
                sheen,
              );
            }
          case Mark.crossed:
            _cross(canvas, rect, t, 1);
          case Mark.empty:
            break;
        }
      }
    }
  }

  void _ghost(Canvas canvas, Rect rect, Mark before, double a, double pad) {
    if (before == Mark.filled) {
      final s = 0.4 + 0.6 * a;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: (rect.width - 2 * pad) * s,
            height: (rect.height - 2 * pad) * s,
          ),
          Radius.circular(rect.width * 0.14),
        ),
        Paint()..color = p.ink.withValues(alpha: a * 0.7),
      );
    } else if (before == Mark.crossed) {
      _cross(canvas, rect, 1, a);
    }
  }

  void _cross(Canvas canvas, Rect rect, double t, double alpha) {
    if (t <= 0) return;
    final d = rect.deflate(rect.width * 0.27);
    final paint = Paint()
      ..color = p.cross.withValues(alpha: alpha)
      ..strokeWidth = math.max(1.5, rect.width * 0.09)
      ..strokeCap = StrokeCap.round;
    final a = (t / 0.5).clamp(0.0, 1.0);
    canvas.drawLine(
      d.topLeft,
      Offset.lerp(d.topLeft, d.bottomRight, a)!,
      paint,
    );
    if (t > 0.5) {
      final b = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
      canvas.drawLine(
        d.topRight,
        Offset.lerp(d.topRight, d.bottomLeft, b)!,
        paint,
      );
    }
  }

  void _lineFx(Canvas canvas) {
    final m = metrics;
    final o = m.gridOrigin;
    for (final l in fx.lines) {
      final t = fx.progress(l.start, BoardFx.lineLength).clamp(0.0, 1.0);
      final fade = 1 - t;
      final lineRect = l.isRow
          ? Rect.fromLTWH(o.dx, o.dy + l.index * m.cell, m.gridSize, m.cell)
          : Rect.fromLTWH(o.dx + l.index * m.cell, o.dy, m.cell, m.gridSize);
      final clueRect = l.isRow
          ? Rect.fromLTWH(0, o.dy + l.index * m.cell, m.clueW - 2, m.cell)
          : Rect.fromLTWH(o.dx + l.index * m.cell, 0, m.cell, m.clueH - 2);
      if (l.error) {
        final pulse = 0.5 + 0.5 * math.cos(t * math.pi * 4);
        final red = Paint()
          ..color = p.mistake.withValues(
            alpha: 0.32 * fade * pulse + 0.1 * fade,
          );
        canvas.drawRect(lineRect, red);
        canvas.drawRect(clueRect, red);
        continue;
      }
      // A bright band sweeps along the finished line, then a check pops on
      // its clue.
      final sweep = Paint()
        ..shader = LinearGradient(
          begin: l.isRow ? Alignment.centerLeft : Alignment.topCenter,
          end: l.isRow ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [
            p.flash.withValues(alpha: 0),
            p.flash.withValues(alpha: 0.75 * fade),
            p.flash.withValues(alpha: 0),
          ],
          stops: [
            (t * 1.4 - 0.4).clamp(0.0, 1.0),
            (t * 1.4 - 0.2).clamp(0.0, 1.0),
            (t * 1.4).clamp(0.0, 1.0),
          ],
        ).createShader(lineRect);
      canvas.drawRect(lineRect, sweep);
      canvas.drawRect(
        clueRect,
        Paint()..color = p.flash.withValues(alpha: 0.5 * fade),
      );
      final side = math.min(clueRect.shortestSide, 34.0);
      final s = _easeOutBack((t / 0.35).clamp(0.0, 1.0));
      final box = Rect.fromCenter(
        center: clueRect.center,
        width: side * s,
        height: side * s,
      );
      canvas.drawCircle(
        box.center,
        box.width * 0.55,
        Paint()..color = p.paper.withValues(alpha: 0.9 * fade),
      );
      Shapes.paintCheck(
        canvas,
        box,
        Color.lerp(
          p.ink,
          const Color(0xFF2E9E5B),
          0.6,
        )!.withValues(alpha: fade),
        t: (t / 0.3).clamp(0.0, 1.0),
      );
    }
  }

  void _gridLines(Canvas canvas, double rv) {
    final m = metrics;
    final n = m.n;
    final o = m.gridOrigin;
    final gs = m.gridSize;
    final a = 1 - rv;
    final thin = Paint()
      ..color = p.gridThin.withValues(alpha: a)
      ..strokeWidth = 1;
    final border = Paint()
      ..color = p.gridBold
      ..strokeWidth = 2;
    final five = Paint()
      ..color = p.gridBold.withValues(alpha: 0.7 * a)
      ..strokeWidth = 2;
    for (var i = 0; i <= n; i++) {
      final paint = (i == 0 || i == n) ? border : (i % 5 == 0 ? five : thin);
      canvas.drawLine(
        Offset(o.dx + i * m.cell, o.dy),
        Offset(o.dx + i * m.cell, o.dy + gs),
        paint,
      );
      canvas.drawLine(
        Offset(o.dx, o.dy + i * m.cell),
        Offset(o.dx + gs, o.dy + i * m.cell),
        paint,
      );
    }
  }

  void _confetti(Canvas canvas, Size size) {
    final start = fx.confettiStart;
    if (start == null) return;
    final t = fx.progress(start, BoardFx.confettiLength);
    if (t < 0 || t > 1) return;
    final rng = math.Random(fx.confettiSeed);
    final colors = [
      ...picture.colors,
      p.accent,
      p.flash,
      p.tape.withAlpha(255),
    ];
    final secs = t * BoardFx.confettiLength.inMilliseconds / 1000;
    final origin = Offset(
      metrics.gridOrigin.dx + metrics.gridSize / 2,
      metrics.gridOrigin.dy + metrics.gridSize * 0.45,
    );
    final scale = math.max(size.width, size.height);
    final paint = Paint();
    final alpha = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    for (var i = 0; i < 90; i++) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.5;
      final speed = scale * (0.7 + rng.nextDouble() * 0.9);
      final vx = math.cos(angle) * speed;
      final vy = math.sin(angle) * speed;
      final drag = 1 - math.exp(-2.4 * secs);
      final x = origin.dx + vx / 2.4 * drag;
      final y = origin.dy + vy / 2.4 * drag + 0.5 * scale * 0.9 * secs * secs;
      final spin = rng.nextDouble() * 10 + secs * (4 + rng.nextDouble() * 8);
      final w = 5 + rng.nextDouble() * 6;
      paint.color = colors[i % colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin);
      canvas.scale(1, math.cos(spin * 1.3).abs() * 0.8 + 0.2);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, w * 0.45, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55),
          paint,
        );
      }
      canvas.restore();
    }
  }

  /// Laid-out clue labels, shared across paints: effects repaint every frame
  /// and laying out every clue each frame would be wasteful.
  static final Map<String, TextPainter> _textCache = <String, TextPainter>{};

  TextPainter _label(String s, Color color, double font, bool dim) {
    final key = '$s|${color.toARGB32()}|$font|$dim';
    final hit = _textCache[key];
    if (hit != null) return hit;
    if (_textCache.length > 400) {
      for (final tp in _textCache.values) {
        tp.dispose();
      }
      _textCache.clear();
    }
    return _textCache[key] = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: color,
          fontSize: font,
          fontWeight: dim ? FontWeight.w500 : FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _text(Canvas canvas, String s, bool dim, Rect box) {
    final tp = _label(s, dim ? p.clueDone : p.clueText, metrics.font, dim);
    tp.paint(
      canvas,
      Offset(box.center.dx - tp.width / 2, box.center.dy - tp.height / 2),
    );
  }

  // The game is mutated in place, so always repaint when rebuilt.
  @override
  bool shouldRepaint(BoardPainter old) => true;
}
