import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/paper_palette.dart';
import '../art/picture_thumb.dart';
import '../art/shapes.dart';
import '../logic/puzzle.dart';
import '../meta/progress_rules.dart';
import 'paper_ui.dart';

String formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Scrim that swallows taps plus a centered paper card. Overlays are
/// stateless about keys: the game screen routes keyboard input.
class OverlayFrame extends StatelessWidget {
  const OverlayFrame({
    super.key,
    required this.palette,
    required this.child,
    this.maxWidth = 460,
    this.cardKey,
  });

  final PaperPalette palette;
  final Widget child;
  final double maxWidth;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const ColoredBox(color: Color(0x99000000)),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: PaperPanel(
              key: cardKey,
              palette: palette,
              tape: true,
              padding: EdgeInsets.zero,
              child: child,
            ),
          ),
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.palette, this.onClose);
  final String title;
  final PaperPalette palette;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.panelText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      IconButton(
        key: const Key('overlay-close'),
        tooltip: 'Close (Esc)',
        color: palette.panelText,
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Level summary

class SummaryOverlay extends StatefulWidget {
  const SummaryOverlay({
    super.key,
    required this.palette,
    required this.result,
    required this.title,
    required this.onNext,
    required this.onReplay,
    required this.onAlbum,
    required this.onClose,
    this.puzzle,
    this.onStar,
    this.onFinished,
  });

  final PaperPalette palette;
  final ClearResult result;
  final Puzzle? puzzle;
  final String title;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onAlbum;
  final VoidCallback onClose;

  /// Called as each earned star stamps in (for its sound).
  final void Function(int index)? onStar;

  /// Called once the stars and XP bar finished animating.
  final VoidCallback? onFinished;

  @override
  State<SummaryOverlay> createState() => _SummaryOverlayState();
}

class _SummaryOverlayState extends State<SummaryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();
  int _starsShown = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final shown = math.min(widget.result.stars, (_c.value * 4.2).floor());
      if (shown > _starsShown) {
        _starsShown = shown;
        widget.onStar?.call(shown - 1);
      }
    });
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final r = widget.result;
    final sub = TextStyle(color: p.panelSubtle, fontSize: 13);
    final strong = TextStyle(
      color: p.panelText,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    return OverlayFrame(
      palette: p,
      maxWidth: 420,
      cardKey: const Key('level-summary'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_c.value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Puzzle solved!',
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: PictureThumb(
                        level: r.level,
                        puzzle: widget.puzzle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.title}! Solved in ${formatTime(r.seconds)}',
                            style: strong,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.newBest
                                ? 'New best!'
                                : 'Best ${formatTime(r.bestSeconds)}',
                            key: const Key('summary-best'),
                            style: r.newBest
                                ? TextStyle(
                                    color: p.accent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  )
                                : sub,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _StampedStars(palette: p, stars: r.stars, t: _c.value),
                const SizedBox(height: 8),
                _StarReasons(palette: p, result: r),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('+${(r.xpGained * t).round()} XP', style: strong),
                    const Spacer(),
                    if (r.leveledUp)
                      Text(
                        'Level up!',
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                XpBar(
                  level: t < 1 && r.leveledUp ? r.before : r.after,
                  palette: p,
                  fraction: r.leveledUp
                      ? (t < 1
                            ? r.before.fraction + (1 - r.before.fraction) * t
                            : null)
                      : r.before.fraction +
                            (r.after.fraction - r.before.fraction) * t,
                ),
                for (final theme in r.unlockedThemes) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 32,
                        child: ThemeSwatch(theme: theme),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New theme unlocked: ${theme.label}',
                          style: strong.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PaperButton(
                      palette: p,
                      label: 'Replay',
                      icon: Icons.replay_rounded,
                      compact: true,
                      onPressed: widget.onReplay,
                    ),
                    PaperButton(
                      palette: p,
                      label: 'Album',
                      icon: Icons.photo_library_outlined,
                      compact: true,
                      onPressed: widget.onAlbum,
                    ),
                    PaperButton(
                      key: const Key('summary-next'),
                      palette: p,
                      label: 'Next',
                      icon: Icons.arrow_forward_rounded,
                      primary: true,
                      onPressed: widget.onNext,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter: next puzzle  -  Esc: look at the picture',
                  style: sub,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StampedStars extends StatelessWidget {
  const _StampedStars({
    required this.palette,
    required this.stars,
    required this.t,
  });
  final PaperPalette palette;
  final int stars;
  final double t;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(190, 54),
    painter: _StampedStarsPainter(palette, stars, t),
  );
}

class _StampedStarsPainter extends CustomPainter {
  _StampedStarsPainter(this.p, this.stars, this.t);
  final PaperPalette p;
  final int stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final c = Offset(
        size.width / 2 + (i - 1) * 62,
        size.height / 2 + (i == 1 ? -3 : 3),
      );
      final local = ((t * 4.2) - (i + 1)).clamp(0.0, 1.0);
      final earned = i < stars && local > 0;
      var r = 22.0;
      if (earned && local < 1) {
        // Stamp: drops in big, settles with a bounce.
        r *= 1 + 0.6 * (1 - local) * math.cos(local * math.pi * 1.5).abs();
      }
      Shapes.paintStar(
        canvas,
        c,
        r,
        filled: earned,
        fill: const Color(0xFFFFC93C),
        outline: p.panelBorder,
      );
    }
  }

  @override
  bool shouldRepaint(_StampedStarsPainter old) =>
      old.t != t || old.stars != stars || old.p != p;
}

class _StarReasons extends StatelessWidget {
  const _StarReasons({required this.palette, required this.result});
  final PaperPalette palette;
  final ClearResult result;

  @override
  Widget build(BuildContext context) {
    final par = parSeconds(sizeForLevel(result.level));
    final noMistakes = !result.mistakes;
    final inPar = result.seconds <= par;
    Widget item(bool ok, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: ok ? const Color(0xFF2E9E5B) : palette.panelSubtle,
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: palette.panelText, fontSize: 13)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        item(true, 'Solved'),
        item(noMistakes, 'No mistakes'),
        item(inPar, 'Under ${formatTime(par)}'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Album

class AlbumOverlay extends StatelessWidget {
  const AlbumOverlay({
    super.key,
    required this.palette,
    required this.solved,
    required this.starsOf,
    this.puzzleOf,
    required this.onOpen,
    required this.onClose,
  });

  final PaperPalette palette;
  final List<int> solved;
  final int Function(int level) starsOf;
  final Puzzle Function(int level)? puzzleOf;
  final void Function(int level) onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final h = MediaQuery.sizeOf(context).height;
    return OverlayFrame(
      palette: p,
      maxWidth: 640,
      cardKey: const Key('album'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header('Picture album', p, onClose),
            Text(
              solved.isEmpty
                  ? 'Solve a puzzle to start your album.'
                  : '${solved.length} ${solved.length == 1 ? 'picture' : 'pictures'} collected',
              style: TextStyle(color: p.panelSubtle, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (solved.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: math.max(120, h - 190)),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 10, bottom: 4),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 104,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: solved.length,
                  itemBuilder: (context, i) {
                    final level = solved[i];
                    final name =
                        (puzzleOf?.call(level) ?? cachedPuzzle(level)).name;
                    return GestureDetector(
                      onTap: () => onOpen(level),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: p.panelBorder.withValues(alpha: 0.5),
                                ),
                              ),
                              child: PictureThumb(
                                level: level,
                                puzzle: puzzleOf?.call(level),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name ?? '#$level',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.panelText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          StarRow(count: starsOf(level), palette: p, size: 12),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level map

const int kMapPageSize = 15;

class LevelMapOverlay extends StatelessWidget {
  const LevelMapOverlay({
    super.key,
    required this.palette,
    required this.page,
    required this.selected,
    required this.current,
    required this.unlocked,
    required this.starsOf,
    this.puzzleOf,
    required this.onSelect,
    required this.onPage,
    required this.onClose,
  });

  final PaperPalette palette;
  final int page;
  final int selected;
  final int current;
  final int unlocked;
  final int Function(int level) starsOf;
  final Puzzle Function(int level)? puzzleOf;
  final void Function(int level) onSelect;
  final void Function(int page) onPage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final first = page * kMapPageSize + 1;
    // One page of locked levels past the newest unlocked one is browsable.
    final maxPage = (unlocked - 1) ~/ kMapPageSize + 1;
    final screen = MediaQuery.sizeOf(context);
    final mapH = (screen.height - 210).clamp(200.0, 330.0);
    return OverlayFrame(
      palette: p,
      maxWidth: 560,
      cardKey: const Key('level-map'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header('Levels $first-${first + kMapPageSize - 1}', p, onClose),
            SizedBox(
              height: mapH,
              child: LayoutBuilder(
                builder: (context, c) {
                  final pts = _nodePositions(
                    Size(c.maxWidth - 10, c.maxHeight),
                  );
                  final node = math.min(
                    52.0,
                    math.min(c.maxWidth / 6.5, c.maxHeight / 4.6),
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _PathPainter(pts, p)),
                      ),
                      for (var i = 0; i < kMapPageSize; i++)
                        Positioned(
                          left: pts[i].dx - node / 2,
                          top: pts[i].dy - node / 2,
                          width: node,
                          height: node + 14,
                          child: _MapNode(
                            level: first + i,
                            puzzle: starsOf(first + i) > 0
                                ? puzzleOf?.call(first + i)
                                : null,
                            size: node,
                            palette: p,
                            stars: starsOf(first + i),
                            locked: first + i > unlocked,
                            selected: first + i == selected,
                            current: first + i == current,
                            onTap: () => onSelect(first + i),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  PaperButton(
                    palette: p,
                    label: 'Prev',
                    icon: Icons.chevron_left_rounded,
                    compact: true,
                    onPressed: page > 0 ? () => onPage(page - 1) : null,
                  ),
                  Expanded(
                    child: Text(
                      'Arrows to choose, Enter to play',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(color: p.panelSubtle, fontSize: 12),
                    ),
                  ),
                  PaperButton(
                    palette: p,
                    label: 'More',
                    icon: Icons.chevron_right_rounded,
                    compact: true,
                    onPressed: page < maxPage ? () => onPage(page + 1) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Snake path: 5 nodes per row, rows alternate direction, slight wave.
  static List<Offset> _nodePositions(Size s) {
    const cols = 5;
    const rows = kMapPageSize ~/ cols;
    final out = <Offset>[];
    for (var i = 0; i < kMapPageSize; i++) {
      final row = i ~/ cols;
      var col = i % cols;
      if (row.isOdd) col = cols - 1 - col;
      final x = s.width * (0.1 + 0.8 * col / (cols - 1));
      final y =
          s.height * (0.16 + 0.68 * row / (rows - 1)) +
          math.sin(i * 1.3) * s.height * 0.03;
      out.add(Offset(x, y));
    }
    return out;
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.pts, this.p);
  final List<Offset> pts;
  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final bend = a.dy == b.dy
          ? 0.0
          : (i ~/ 5).isOdd
          ? 40.0
          : -40.0;
      path.quadraticBezierTo(mid.dx + bend, mid.dy, b.dx, b.dy);
    }
    final dash = Paint()
      ..color = p.panelBorder.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 7), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.p != p || old.pts != pts;
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.level,
    this.puzzle,
    required this.size,
    required this.palette,
    required this.stars,
    required this.locked,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final int level;
  final Puzzle? puzzle;
  final double size;
  final PaperPalette palette;
  final int stars;
  final bool locked;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final solved = stars > 0;
    Widget face;
    if (locked) {
      face = CustomPaint(
        painter: _LockPainter(p.panelSubtle),
        size: Size.square(size * 0.5),
      );
    } else if (solved) {
      face = Padding(
        padding: EdgeInsets.all(size * 0.17),
        child: PictureThumb(level: level, puzzle: puzzle),
      );
    } else {
      face = Text(
        '$level',
        style: TextStyle(
          color: p.accentInk,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
        ),
      );
    }
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Column(
        children: [
          Container(
            key: Key('map-node-$level'),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: locked
                  ? p.panelBorder.withValues(alpha: 0.12)
                  : solved
                  ? Colors.white
                  : p.accent,
              border: Border.all(
                color: selected ? p.accent : p.panelBorder,
                width: selected ? 4 : (current ? 2.6 : 1.6),
              ),
              boxShadow: locked
                  ? null
                  : [
                      BoxShadow(
                        color: p.panelBorder,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: face,
          ),
          if (solved)
            StarRow(count: stars, palette: p, size: 11)
          else
            const SizedBox(height: 11),
        ],
      ),
    );
  }
}

class _LockPainter extends CustomPainter {
  _LockPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      Shapes.paintLock(canvas, Offset.zero & size, color);

  @override
  bool shouldRepaint(_LockPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Themes

class ThemeOverlay extends StatelessWidget {
  const ThemeOverlay({
    super.key,
    required this.palette,
    required this.current,
    required this.selected,
    required this.painterLevel,
    required this.onPick,
    required this.onClose,
  });

  final PaperPalette palette;
  final NonoTheme current;
  final NonoTheme selected;
  final int painterLevel;
  final void Function(NonoTheme theme) onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return OverlayFrame(
      palette: p,
      maxWidth: 520,
      cardKey: const Key('themes'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header('Paper themes', p, onClose),
            Text(
              'Earn XP by solving puzzles to unlock new paper.',
              style: TextStyle(color: p.panelSubtle, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in NonoTheme.values)
                  _ThemeCard(
                    theme: t,
                    palette: p,
                    locked: !t.unlockedAt(painterLevel),
                    active: t == current,
                    selected: t == selected,
                    onTap: () => onPick(t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.palette,
    required this.locked,
    required this.active,
    required this.selected,
    required this.onTap,
  });

  final NonoTheme theme;
  final PaperPalette palette;
  final bool locked;
  final bool active;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return GestureDetector(
      key: Key('theme-${theme.id}'),
      onTap: locked ? null : onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? p.accent : p.panelBorder.withValues(alpha: 0.5),
            width: selected ? 3 : 1.4,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ThemeSwatch(theme: theme),
                  if (locked)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x88000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size.square(26),
                          painter: _LockPainter(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              theme.label,
              style: TextStyle(
                color: p.panelText,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              locked
                  ? 'Unlocks at Lv ${theme.requiredLevel}'
                  : active
                  ? 'In use'
                  : 'Tap to use',
              style: TextStyle(color: p.panelSubtle, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
