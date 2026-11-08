import 'dart:math' as math;

import 'collection.dart';

/// Cosmetic paper/ink themes, unlocked by painter level. Themes never change
/// any rule.
enum NonoTheme {
  notebook('notebook', 'Notebook', 1),
  kraft('kraft', 'Kraft', 3),
  washi('washi', 'Washi', 6),
  midnight('midnight', 'Midnight', 10);

  const NonoTheme(this.id, this.label, this.requiredLevel);

  final String id;
  final String label;

  /// Painter level that unlocks the theme.
  final int requiredLevel;

  static NonoTheme fromId(String? id) => NonoTheme.values.firstWhere(
    (t) => t.id == id,
    orElse: () => NonoTheme.notebook,
  );

  bool unlockedAt(int painterLevel) => painterLevel >= requiredLevel;
}

/// Par time for the third star: 1.5 s per cell plus 20 s, rounded.
int parSeconds(int size) => (size * size * 1.5).round() + 20;

/// Stars for a solve: 1 for solving, +1 when Check never found a wrong
/// cell, +1 when solved within [parSeconds].
int starsFor({
  required int size,
  required int seconds,
  required bool mistakes,
}) {
  var stars = 1;
  if (!mistakes) stars++;
  if (seconds <= parSeconds(size)) stars++;
  return stars;
}

/// XP for clearing a level of [size] with [stars] when the best stars so far
/// were [previousStars] (0 = first clear).
int clearXp({
  required int size,
  required int stars,
  required int previousStars,
}) {
  if (previousStars <= 0) return size * 2 + stars * 5;
  return 3 + math.max(0, stars - previousStars) * 5;
}

/// XP needed to go from painter level [level] to [level] + 1.
int xpToNext(int level) => 40 + 20 * (level - 1);

/// Painter level reached with [totalXp], and progress inside that level.
class PainterLevel {
  const PainterLevel(this.level, this.xpInto, this.xpNeeded);

  factory PainterLevel.fromXp(int totalXp) {
    var level = 1;
    var rest = math.max(0, totalXp);
    while (rest >= xpToNext(level)) {
      rest -= xpToNext(level);
      level++;
    }
    return PainterLevel(level, rest, xpToNext(level));
  }

  final int level;
  final int xpInto;
  final int xpNeeded;

  double get fraction => xpNeeded == 0 ? 0 : xpInto / xpNeeded;
}

/// Outcome of recording a clear, for the summary screen.
class ClearResult {
  const ClearResult({
    required this.level,
    required this.seconds,
    required this.bestSeconds,
    required this.newBest,
    required this.stars,
    required this.mistakes,
    required this.previousStars,
    required this.xpGained,
    required this.before,
    required this.after,
    required this.unlockedThemes,
    this.size,
    this.bonuses = const [],
    this.completedSets = const [],
    this.setGoal,
    this.daily,
  });

  final int level;
  final int seconds;
  final int bestSeconds;
  final bool newBest;
  final int stars;

  /// Whether Check found a wrong cell during this solve.
  final bool mistakes;
  final int previousStars;
  final int xpGained;
  final PainterLevel before;
  final PainterLevel after;
  final List<NonoTheme> unlockedThemes;

  /// Grid size of the solved puzzle (null: derived from [level]).
  final int? size;

  /// Extra XP included in [xpGained] (daily bonus, set completion).
  final List<XpBonus> bonuses;

  /// Album sets completed (and rewarded) by this clear.
  final List<SetProgress> completedSets;

  /// Next picture that moves an album set toward completion.
  final SetGoal? setGoal;

  /// Present for a daily puzzle solve.
  final DailyOutcome? daily;

  bool get leveledUp => after.level > before.level;
}

/// One labelled XP bonus shown on the summary.
class XpBonus {
  const XpBonus(this.label, this.xp);
  final String label;
  final int xp;
}

/// Daily-specific part of a [ClearResult].
class DailyOutcome {
  const DailyOutcome({
    required this.day,
    required this.streak,
    required this.best,
    required this.rewarded,
    required this.graceUsed,
    required this.graceReady,
    required this.refillLeft,
  });

  final int day;

  /// Streak after this solve.
  final int streak;
  final int best;

  /// False when the solve earned nothing (already solved, clock moved back).
  final bool rewarded;
  final bool graceUsed;
  final bool graceReady;
  final int refillLeft;
}
