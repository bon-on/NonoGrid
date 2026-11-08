import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/paper_palette.dart';
import '../art/picture_thumb.dart';
import '../art/shapes.dart';
import '../logic/puzzle.dart';
import '../meta/collection.dart';
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
    this.onCopy,
    this.today,
  });

  final PaperPalette palette;
  final ClearResult result;

  /// Today's day number, so a daily finished after midnight points to
  /// today's daily instead of tomorrow's.
  final int? today;

  /// Copies the daily result text; only used for daily solves.
  final VoidCallback? onCopy;
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

  /// The pinned next-goal line under the scrolling content.
  String? _goalText(ClearResult r) {
    final daily = r.daily;
    if (daily != null) {
      final late = widget.today != null && daily.day < widget.today!;
      if (late) {
        return daily.rewarded
            ? "Solve today's daily for streak ${daily.streak + 1}"
            : "Today's daily is waiting";
      }
      return daily.rewarded
          ? 'Come back tomorrow for streak ${daily.streak + 1}'
          : 'Come back tomorrow for a new daily';
    }
    final goal = r.setGoal;
    if (goal == null) return null;
    return 'Next: Level ${goal.level} - ${goal.missing} more to complete '
        '${goal.set.name} (+$kSetBonusXp XP)';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final r = widget.result;
    final daily = r.daily;
    final sub = TextStyle(color: p.panelSubtle, fontSize: 13);
    final strong = TextStyle(
      color: p.panelText,
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    final goal = _goalText(r);
    final buttons = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (daily == null)
          PaperButton(
            palette: p,
            label: 'Replay',
            icon: Icons.replay_rounded,
            compact: true,
            onPressed: widget.onReplay,
          ),
        if (daily != null && widget.onCopy != null)
          PaperButton(
            key: const Key('summary-copy'),
            palette: p,
            label: 'Copy result',
            icon: Icons.copy_rounded,
            compact: true,
            onPressed: widget.onCopy,
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
          label: daily == null ? 'Next' : 'Levels',
          icon: daily == null
              ? Icons.arrow_forward_rounded
              : Icons.map_outlined,
          primary: true,
          onPressed: widget.onNext,
        ),
      ],
    );
    return OverlayFrame(
      palette: p,
      maxWidth: 420,
      cardKey: const Key('level-summary'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => _content(p, r, sub, strong),
                ),
              ),
            ),
            if (goal != null) ...[
              const SizedBox(height: 8),
              Text(
                goal,
                key: const Key('summary-goal'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 10),
            buttons,
            const SizedBox(height: 6),
            Text(
              daily == null
                  ? 'Enter: next puzzle  -  Esc: look at the picture'
                  : 'Enter: levels  -  C: copy  -  Esc: look at the picture',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: sub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    PaperPalette p,
    ClearResult r,
    TextStyle sub,
    TextStyle strong,
  ) {
    final t = Curves.easeOut.transform(_c.value);
    final daily = r.daily;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          daily == null ? 'Puzzle solved!' : 'Daily solved!',
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
              child: PictureThumb(level: r.level, puzzle: widget.puzzle),
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
                  if (daily != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: Color(0xFFF07A2B),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            daily.rewarded
                                ? 'Streak ${daily.streak}  -  Best ${daily.best}'
                                : 'No reward: this daily was already counted',
                            key: const Key('summary-streak'),
                            maxLines: 2,
                            style: TextStyle(
                              color: daily.rewarded ? p.accent : p.panelSubtle,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
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
              ? (t < 1 ? r.before.fraction + (1 - r.before.fraction) * t : null)
              : r.before.fraction + (r.after.fraction - r.before.fraction) * t,
        ),
        for (final bonus in r.bonuses) ...[
          const SizedBox(height: 8),
          Row(
            key: Key('summary-bonus-${bonus.label}'),
            children: [
              if (bonus.label.startsWith('Set complete'))
                const CompletionSeal(size: 22)
              else
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 20,
                  color: Color(0xFFF07A2B),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${bonus.label}  +${bonus.xp} XP',
                  style: strong.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
        if (daily != null && daily.graceUsed) ...[
          const SizedBox(height: 6),
          Text(
            'Your grace saved the streak. It refills after '
            '${daily.refillLeft} more daily solves.',
            style: sub,
          ),
        ],
        for (final theme in r.unlockedThemes) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 44, height: 32, child: ThemeSwatch(theme: theme)),
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
      ],
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
    final par = parSeconds(result.size ?? sizeForLevel(result.level));
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
    this.sets = const [],
    this.goal,
    this.unlocked = 1,
    this.dailyTotal = 0,
    this.dailyBest = 0,
  });

  final PaperPalette palette;
  final List<int> solved;
  final int Function(int level) starsOf;
  final Puzzle Function(int level)? puzzleOf;
  final void Function(int level) onOpen;
  final VoidCallback onClose;

  /// Album sets to show, Set 1 first.
  final List<SetProgress> sets;

  /// Next picture that moves a set toward completion (Enter plays it).
  final SetGoal? goal;
  final int unlocked;
  final int dailyTotal;
  final int dailyBest;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final h = MediaQuery.sizeOf(context).height;
    final sub = TextStyle(color: p.panelSubtle, fontSize: 13);
    final complete = sets.where((s) => s.complete).length;
    final g = goal;
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
              style: sub,
            ),
            Text(
              'Sets complete: $complete  -  Daily solved: $dailyTotal  -  '
              'Best streak: $dailyBest',
              key: const Key('album-stats'),
              maxLines: 2,
              style: sub.copyWith(fontSize: 12),
            ),
            if (g != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.accent.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Next: Level ${g.level} - ${g.missing} more to '
                          'complete ${g.set.name} (+$kSetBonusXp XP)',
                          key: const Key('album-goal-text'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.panelText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PaperButton(
                        key: const Key('album-goal'),
                        palette: p,
                        label: 'Play',
                        icon: Icons.play_arrow_rounded,
                        primary: true,
                        compact: true,
                        onPressed: () => onOpen(g.level),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (sets.isNotEmpty)
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(110, h - 250),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(right: 10, bottom: 4),
                    itemCount: sets.length,
                    itemBuilder: (context, i) => _SetSection(
                      palette: p,
                      set: sets[i],
                      unlocked: unlocked,
                      starsOf: starsOf,
                      puzzleOf: puzzleOf,
                      onOpen: onOpen,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Text(
                g == null
                    ? 'Esc: close'
                    : 'Enter: play Level ${g.level}  -  Esc: close',
                style: sub.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetSection extends StatelessWidget {
  const _SetSection({
    required this.palette,
    required this.set,
    required this.unlocked,
    required this.starsOf,
    required this.puzzleOf,
    required this.onOpen,
  });

  final PaperPalette palette;
  final SetProgress set;
  final int unlocked;
  final int Function(int level) starsOf;
  final Puzzle Function(int level)? puzzleOf;
  final void Function(int level) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      key: Key('album-set-${set.index}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (set.complete) ...[
                const CompletionSeal(size: 20),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  'Set ${set.index + 1}: ${set.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.panelText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                set.complete ? 'Complete' : '${set.solved}/${set.total}',
                key: Key('album-set-count-${set.index}'),
                style: TextStyle(
                  color: set.complete ? const Color(0xFF2E9E5B) : p.panelSubtle,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: p.panelBorder.withValues(alpha: 0.15)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: set.fraction.clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: set.complete ? const Color(0xFFE8A317) : p.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var l = set.firstLevel; l <= set.lastLevel; l++)
                _AlbumTile(
                  palette: p,
                  level: l,
                  stars: starsOf(l),
                  locked: l > unlocked,
                  puzzle: starsOf(l) > 0 ? puzzleOf?.call(l) : null,
                  onOpen: onOpen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.palette,
    required this.level,
    required this.stars,
    required this.locked,
    required this.puzzle,
    required this.onOpen,
  });

  final PaperPalette palette;
  final int level;
  final int stars;
  final bool locked;
  final Puzzle? puzzle;
  final void Function(int level) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final solved = stars > 0;
    final name = solved ? (puzzle ?? cachedPuzzle(level)).name : null;
    return GestureDetector(
      key: Key('album-tile-$level'),
      onTap: locked ? null : () => onOpen(level),
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: solved
                    ? Colors.white.withValues(alpha: 0.6)
                    : p.panelBorder.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: p.panelBorder.withValues(alpha: solved ? 0.5 : 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: solved
                  ? PictureThumb(level: level, puzzle: puzzle)
                  : locked
                  ? CustomPaint(
                      size: const Size.square(20),
                      painter: _LockPainter(p.panelSubtle),
                    )
                  : Text(
                      '?',
                      style: TextStyle(
                        color: p.panelSubtle,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              name ?? '#$level',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: solved ? p.panelText : p.panelSubtle,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (solved)
              StarRow(count: stars, palette: p, size: 10)
            else
              const SizedBox(height: 10),
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
