import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/paper_palette.dart';
import '../art/shapes.dart';
import '../meta/daily.dart';
import '../storage.dart';
import 'overlays.dart';
import 'paper_ui.dart';

/// Today's daily puzzle state shown on the card and the overlay.
enum DailyState { fresh, inProgress, done }

/// Everything the daily card and overlay show, derived from storage.
class DailyInfo {
  DailyInfo._({
    required this.day,
    required this.size,
    required this.state,
    required this.result,
    required this.elapsed,
    required this.streak,
    required this.best,
    required this.graceReady,
    required this.refillLeft,
    required this.total,
    required this.lastWeek,
  });

  /// [liveElapsed] is the running clock when today's board is open.
  factory DailyInfo.of(GameStorage storage, int today, {int? liveElapsed}) {
    final data = storage.daily;
    final result = storage.dailyResultFor(today);
    final saved = storage.dailyProgressFor(today);
    final state = result != null
        ? DailyState.done
        : (liveElapsed != null || saved != null)
        ? DailyState.inProgress
        : DailyState.fresh;
    final solved = data.days.toSet();
    return DailyInfo._(
      day: today,
      size: dailySize(today),
      state: state,
      result: result,
      elapsed: liveElapsed ?? saved?.elapsedSeconds,
      streak: streakOn(data.streak, today),
      best: data.streak.best,
      graceReady: data.streak.graceReady,
      refillLeft: data.streak.refillLeft,
      total: data.streak.total,
      lastWeek: [for (var i = 6; i >= 0; i--) solved.contains(today - i)],
    );
  }

  final int day;
  final int size;
  final DailyState state;
  final DailyResult? result;
  final int? elapsed;
  final StreakView streak;
  final int best;
  final bool graceReady;
  final int refillLeft;
  final int total;

  /// Solved flags for the last 7 days, oldest first, today last.
  final List<bool> lastWeek;

  String get stateLabel => switch (state) {
    DailyState.fresh => 'New puzzle',
    DailyState.inProgress => 'In progress ${formatTime(elapsed ?? 0)}',
    DailyState.done => 'Solved in ${formatTime(result!.seconds)}',
  };

  String get streakNote => switch (streak.status) {
    StreakStatus.none => 'Solve today to start a streak',
    StreakStatus.safe => 'Streak safe today',
    StreakStatus.pending => 'Solve today to keep your streak',
    StreakStatus.graceCovers => 'Your grace covers yesterday - solve today',
  };

  String get graceLabel => graceReady
      ? 'Grace ready: one missed day is forgiven'
      : 'Grace refills in $refillLeft daily '
            '${refillLeft == 1 ? 'solve' : 'solves'}';
}

class _Flame extends StatelessWidget {
  const _Flame({required this.count, required this.palette, this.size = 15});
  final int count;
  final PaperPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.local_fire_department_rounded,
        size: size + 3,
        color: count > 0 ? const Color(0xFFF07A2B) : palette.panelSubtle,
      ),
      Text(
        '$count',
        style: TextStyle(
          color: palette.panelText,
          fontSize: size,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// Daily card on the main screen. [compact] is a single row for phones.
class DailyCard extends StatelessWidget {
  const DailyCard({
    super.key,
    required this.palette,
    required this.info,
    required this.onTap,
    this.compact = false,
    this.playing = false,
  });

  final PaperPalette palette;
  final DailyInfo info;
  final VoidCallback onTap;
  final bool compact;

  /// The daily board is the one on screen.
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final done = info.state == DailyState.done;
    final badge = done
        ? 'Done'
        : info.state == DailyState.inProgress
        ? 'In progress'
        : 'New';
    final badgeColor = done ? const Color(0xFF2E9E5B) : p.accent;
    Widget chip() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.7)),
      ),
      child: Text(
        badge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: done ? badgeColor : p.panelText,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final decoration = BoxDecoration(
      color: p.panel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: playing ? p.accent : p.panelBorder.withValues(alpha: 0.8),
        width: playing ? 2.4 : 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: p.panelBorder.withValues(alpha: 0.6),
          offset: const Offset(0, 2),
        ),
      ],
    );
    final Widget body;
    if (compact) {
      final shortBadge = done
          ? 'Done'
          : info.state == DailyState.inProgress
          ? 'Playing'
          : 'New';
      body = LayoutBuilder(
        builder: (context, c) {
          final roomy = c.maxWidth >= 240;
          return Row(
            children: [
              Icon(Icons.today_rounded, size: 18, color: p.panelText),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: roomy
                            ? 'Daily ${info.size}x${info.size}  '
                            : 'Daily  ',
                        style: TextStyle(
                          color: p.panelText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: shortBadge,
                        style: TextStyle(
                          color: done ? badgeColor : p.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              _Flame(count: info.streak.current, palette: p, size: 14),
              if (roomy) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: p.panelSubtle,
                ),
              ],
            ],
          );
        },
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded, size: 18, color: p.panelText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Daily puzzle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.panelText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Flame(count: info.streak.current, palette: p),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(child: chip()),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${dayLabel(info.day)}  ${info.size}x${info.size}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.panelSubtle, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            done ? info.stateLabel : '${info.stateLabel}  (D)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.panelText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      label: 'Daily puzzle, $badge, streak ${info.streak.current}',
      child: GestureDetector(
        key: const Key('daily-card'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: decoration,
          child: body,
        ),
      ),
    );
  }
}

/// Seven dots for the last week, today last.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.solved, required this.palette});
  final List<bool> solved;
  final PaperPalette palette;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(7 * 26, 26),
    painter: _WeekPainter(solved, palette),
  );
}

class _WeekPainter extends CustomPainter {
  _WeekPainter(this.solved, this.p);
  final List<bool> solved;
  final PaperPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / math.max(1, solved.length);
    final r = math.min(step, size.height) * 0.36;
    for (var i = 0; i < solved.length; i++) {
      final c = Offset(step * (i + 0.5), size.height / 2);
      final today = i == solved.length - 1;
      if (solved[i]) {
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF07A2B));
        Shapes.paintCheck(
          canvas,
          Rect.fromCircle(center: c, radius: r * 0.7),
          Colors.white,
        );
      } else {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = p.panelBorder.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = today ? 2.6 : 1.6,
        );
      }
      if (today) {
        canvas.drawCircle(
          c,
          r + 3,
          Paint()
            ..color = p.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WeekPainter old) =>
      old.p != p || old.solved.toString() != solved.toString();
}

/// Daily overlay: today's state, streak, grace, rule and actions.
class DailyOverlay extends StatelessWidget {
  const DailyOverlay({
    super.key,
    required this.palette,
    required this.info,
    required this.playing,
    required this.onPlay,
    required this.onBack,
    required this.onCopy,
    required this.onClose,
  });

  final PaperPalette palette;
  final DailyInfo info;

  /// Today's daily board is the one behind the overlay.
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onBack;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final sub = TextStyle(color: p.panelSubtle, fontSize: 12, height: 1.3);
    final strong = TextStyle(
      color: p.panelText,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    );
    final done = info.state == DailyState.done;
    final playLabel = done
        ? 'Close'
        : playing
        ? 'Resume'
        : info.state == DailyState.inProgress
        ? 'Continue'
        : 'Play';
    final keys = [
      'Enter: ${playLabel.toLowerCase()}',
      if (done) 'C: copy',
      if (playing) 'L: levels',
      'Esc: close',
    ].join('  -  ');
    return OverlayFrame(
      palette: p,
      maxWidth: 440,
      cardKey: const Key('daily-overlay'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily puzzle',
                    style: TextStyle(
                      color: p.panelText,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('overlay-close'),
                  tooltip: 'Close (Esc)',
                  color: p.panelText,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayLabel(info.day)}  -  ${info.size}x${info.size}  '
                      '-  same puzzle for everyone today',
                      style: sub,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.stateLabel,
                            key: const Key('daily-state'),
                            style: strong,
                          ),
                        ),
                        if (done)
                          StarRow(
                            count: info.result!.stars,
                            palette: p,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Flame(
                          count: info.streak.current,
                          palette: p,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Streak ${info.streak.current}  -  '
                            'Best ${info.best}',
                            key: const Key('daily-streak'),
                            style: strong,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(info.streakNote, style: sub),
                    const SizedBox(height: 8),
                    WeekStrip(solved: info.lastWeek, palette: p),
                    const SizedBox(height: 8),
                    Text(info.graceLabel, style: sub),
                    const SizedBox(height: 6),
                    Text(kStreakRule, style: sub),
                    const SizedBox(height: 6),
                    Text(
                      'Reward: stars and puzzle XP plus a daily bonus of '
                      '10-30 XP that grows with your streak.',
                      style: sub,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (playing)
                    PaperButton(
                      key: const Key('daily-back'),
                      palette: p,
                      label: 'Back to levels',
                      icon: Icons.map_outlined,
                      compact: true,
                      onPressed: onBack,
                    ),
                  if (done)
                    PaperButton(
                      key: const Key('daily-copy'),
                      palette: p,
                      label: 'Copy result',
                      icon: Icons.copy_rounded,
                      compact: true,
                      onPressed: onCopy,
                    ),
                  PaperButton(
                    key: const Key('daily-play'),
                    palette: p,
                    label: playLabel,
                    icon: done ? Icons.check_rounded : Icons.play_arrow_rounded,
                    primary: true,
                    compact: true,
                    onPressed: onPlay,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                keys,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
