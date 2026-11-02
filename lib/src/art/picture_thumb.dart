import 'package:flutter/material.dart';

import '../logic/puzzle.dart';
import 'paper_palette.dart';

/// Puzzles are cheap to generate but album/map pages show many of them, so
/// recently used ones are cached.
final Map<int, Puzzle> _puzzleCache = <int, Puzzle>{};

Puzzle cachedPuzzle(int level) {
  final hit = _puzzleCache.remove(level);
  if (hit != null) return _puzzleCache[level] = hit;
  if (_puzzleCache.length >= 120) _puzzleCache.remove(_puzzleCache.keys.first);
  return _puzzleCache[level] = puzzleForLevel(level);
}

/// A solved puzzle drawn as its coloured picture.
class PictureThumb extends StatelessWidget {
  const PictureThumb({super.key, required this.level, this.hidden = false});

  final int level;

  /// Draws a question-mark silhouette instead of the picture.
  final bool hidden;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: PictureThumbPainter(cachedPuzzle(level), hidden: hidden),
  );
}

class PictureThumbPainter extends CustomPainter {
  PictureThumbPainter(this.puzzle, {this.hidden = false});

  final Puzzle puzzle;
  final bool hidden;

  @override
  void paint(Canvas canvas, Size size) {
    final pal = PicturePalette.forLevel(puzzle.level);
    final n = puzzle.size;
    final side = size.shortestSide;
    final cell = side / n;
    final o = Offset((size.width - side) / 2, (size.height - side) / 2);
    final r = RRect.fromRectAndRadius(
      o & Size(side, side),
      Radius.circular(side * 0.06),
    );
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(r, Paint()..color = pal.background);
    final paint = Paint();
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        if (!puzzle.filledAt(row, col)) continue;
        paint.color = hidden
            ? const Color(0x22000000)
            : pal.cellColor(row, col, n);
        canvas.drawRect(
          Rect.fromLTWH(
            o.dx + col * cell,
            o.dy + row * cell,
            cell + 0.4,
            cell + 0.4,
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PictureThumbPainter old) =>
      old.puzzle.level != puzzle.level || old.hidden != hidden;
}
