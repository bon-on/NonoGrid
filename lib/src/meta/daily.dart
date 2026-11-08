import 'dart:math' as math;

import '../logic/puzzle.dart';

// Daily puzzle rules (feature-daily-puzzle, adr-daily-puzzle). Widget-free.

/// Daily solves needed to refill a used grace.
const int kGraceRefillSolves = 7;

/// Day number of [local]'s calendar date: days since 1970-01-01. Uses the
/// date fields only, so the time zone offset and DST never matter.
int dayIndexOf(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
).difference(DateTime.utc(1970)).inDays;

DateTime _dateOf(int day) => DateTime.utc(1970).add(Duration(days: day));

/// `YYYY-MM-DD` label of [day].
String dayLabel(int day) {
  final d = _dateOf(day);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// Grid size of the daily puzzle: 8x8 Mon-Tue, 10x10 Wed-Fri, 12x12 Sat-Sun.
int dailySize(int day) => switch (_dateOf(day).weekday) {
  DateTime.monday || DateTime.tuesday => 8,
  DateTime.saturday || DateTime.sunday => 12,
  _ => 10,
};

/// Nonzero 32-bit seed for [day]. Only small products are used so the Dart
/// VM and dart2js compute the same value.
int dailySeed(int day) {
  final d = day.clamp(0, 1 << 18);
  final seed = ((d * 7919) ^ 0x0DA11E5) & 0x7FFFFFFF;
  return seed == 0 ? 1 : seed;
}

/// The line-solvable daily puzzle of [day] (same for every player).
Puzzle dailyPuzzle(int day, {GeneratorStats? stats}) => generatePuzzle(
  0,
  sizeOverride: dailySize(day),
  seed: dailySeed(day),
  stats: stats,
);

/// Bonus XP for a rewarded daily solve that brought the streak to [streak].
int dailyBonusXp(int streak) => 10 + 5 * math.min(math.max(streak, 1) - 1, 4);

/// Persisted streak counters. Immutable; [applySolve] returns a new value.
class DailyStreak {
  const DailyStreak({
    this.lastDay,
    this.streak = 0,
    this.best = 0,
    this.graceReady = true,
    this.refillLeft = 0,
    this.total = 0,
  });

  /// Last day whose daily was solved with a reward, null before the first.
  final int? lastDay;
  final int streak;
  final int best;

  /// Whether a missed day will be forgiven on the next solve.
  final bool graceReady;

  /// Solves still needed to refill the grace (0 when ready).
  final int refillLeft;

  /// Rewarded daily solves ever.
  final int total;
}

/// What one daily solve changed.
class DailySolve {
  const DailySolve(
    this.state, {
    required this.rewarded,
    this.graceUsed = false,
  });

  final DailyStreak state;

  /// False when the day was already solved or lies before the last solve.
  final bool rewarded;
  final bool graceUsed;
}

/// Applies a solve of [day] to [s].
DailySolve applySolve(DailyStreak s, int day) {
  final last = s.lastDay;
  if (last != null && day <= last) return DailySolve(s, rewarded: false);
  var streak = 1;
  var graceReady = s.graceReady;
  var refill = s.refillLeft;
  var graceUsed = false;
  if (last != null) {
    final gap = day - last;
    if (gap == 1) {
      streak = s.streak + 1;
    } else if (gap == 2 && graceReady) {
      streak = s.streak + 1;
      graceReady = false;
      graceUsed = true;
      refill = kGraceRefillSolves;
    }
  }
  if (!graceUsed && !graceReady) {
    refill = math.max(0, refill - 1);
    if (refill == 0) graceReady = true;
  }
  streak = math.max(1, streak);
  return DailySolve(
    DailyStreak(
      lastDay: day,
      streak: streak,
      best: math.max(s.best, streak),
      graceReady: graceReady,
      refillLeft: graceReady ? 0 : refill,
      total: s.total + 1,
    ),
    rewarded: true,
    graceUsed: graceUsed,
  );
}

/// How the streak looks on [today].
enum StreakStatus {
  /// No streak (never solved, or broken).
  none,

  /// Today's daily is solved.
  safe,

  /// Solved yesterday: solve today to extend.
  pending,

  /// Missed yesterday, the grace will cover it if today is solved.
  graceCovers,
}

class StreakView {
  const StreakView(this.current, this.status);
  final int current;
  final StreakStatus status;
}

/// Current streak on [today]. A clock set before the last solve keeps the
/// stored streak instead of breaking it.
StreakView streakOn(DailyStreak s, int today) {
  final last = s.lastDay;
  final streak = math.max(0, s.streak);
  if (last == null || streak == 0) {
    return const StreakView(0, StreakStatus.none);
  }
  final gap = today - last;
  if (gap <= 0) return StreakView(streak, StreakStatus.safe);
  if (gap == 1) return StreakView(streak, StreakStatus.pending);
  if (gap == 2 && s.graceReady) {
    return StreakView(streak, StreakStatus.graceCovers);
  }
  return const StreakView(0, StreakStatus.none);
}

/// One-line rule shown to the player.
const String kStreakRule =
    'Solve the daily each day to grow your streak. Miss one day and your '
    'grace keeps the streak alive; it refills after $kGraceRefillSolves '
    'daily solves.';

/// Copy-result text. [link] is appended when the build has one.
String dailyShareText({
  required int day,
  required int size,
  required int seconds,
  required int stars,
  required int streak,
  String? link,
}) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  final text =
      'NonoGrid Daily ${dayLabel(day)}: ${size}x$size in $m:$s, '
      '$stars/3 stars, streak $streak';
  return link == null || link.isEmpty ? text : '$text $link';
}
