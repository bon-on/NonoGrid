import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/daily.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameStorage> _open(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return GameStorage.open(seedSource: () => 4242);
}

void main() {
  final today = dayIndexOf(DateTime(2026, 11, 8));

  group('date and puzzle', () {
    test('day index uses the calendar date only', () {
      expect(dayIndexOf(DateTime(1970, 1, 1)), 0);
      expect(dayIndexOf(DateTime(2026, 11, 8, 0, 0, 1)), today);
      expect(dayIndexOf(DateTime(2026, 11, 8, 23, 59, 59)), today);
      expect(dayIndexOf(DateTime(2026, 11, 9)), today + 1);
      expect(dayIndexOf(DateTime.utc(2026, 3, 29, 12)), isPositive);
      expect(dayLabel(today), '2026-11-08');
      expect(dayLabel(0), '1970-01-01');
    });

    test('size follows the weekday', () {
      // 2026-11-08 is a Sunday.
      expect(dailySize(today), 12);
      expect(dailySize(today + 1), 8); // Monday
      expect(dailySize(today + 2), 8);
      expect(dailySize(today + 3), 10);
      expect(dailySize(today + 5), 10);
      expect(dailySize(today + 6), 12);
    });

    test('same day gives the same puzzle, other days differ', () {
      final a = dailyPuzzle(today);
      final b = dailyPuzzle(today);
      expect(a.solution, b.solution);
      expect(dailySeed(today), isNonZero);
      expect(dailyPuzzle(today + 7).solution, isNot(a.solution));
      // Pinned so an accidental generator/seed change is noticed.
      expect(dailySeed(today), ((today * 7919) ^ 0x0DA11E5) & 0x7FFFFFFF);
    });

    test('a year of dailies is line-solvable without the fallback', () {
      for (var d = today; d < today + 366; d++) {
        final stats = GeneratorStats();
        final p = dailyPuzzle(d, stats: stats);
        expect(stats.usedFallback, isFalse, reason: dayLabel(d));
        expect(isLineSolvable(p.solution, p.size), isTrue);
      }
    });

    test('tampered clocks never break the seed', () {
      expect(dailySeed(-50000), isPositive);
      expect(dailySeed(1 << 40), isPositive);
      expect(dailyPuzzle(-3).size, greaterThan(0));
    });

    test('levels are unchanged', () {
      expect(puzzleForLevel(1).name, 'Heart');
      expect(generatePuzzle(10).solution, generatePuzzle(10).solution);
    });
  });

  group('streak rules', () {
    test('consecutive days extend, same day changes nothing', () {
      var s = const DailyStreak();
      var r = applySolve(s, 100);
      expect(r.rewarded, isTrue);
      s = r.state;
      expect(s.streak, 1);
      r = applySolve(s, 100);
      expect(r.rewarded, isFalse);
      s = applySolve(s, 101).state;
      expect(s.streak, 2);
      expect(s.best, 2);
      expect(s.total, 2);
    });

    test('one missed day uses the grace, which refills after 7 solves', () {
      var s = applySolve(const DailyStreak(), 100).state;
      s = applySolve(s, 101).state;
      final r = applySolve(s, 103);
      expect(r.graceUsed, isTrue);
      s = r.state;
      expect(s.streak, 3);
      expect(s.graceReady, isFalse);
      expect(s.refillLeft, kGraceRefillSolves);
      for (var i = 1; i <= kGraceRefillSolves; i++) {
        s = applySolve(s, 103 + i).state;
        expect(s.graceReady, i == kGraceRefillSolves, reason: 'solve $i');
      }
      expect(s.refillLeft, 0);
      expect(s.streak, 3 + kGraceRefillSolves);
    });

    test('a miss without grace or a two-day gap restarts at 1', () {
      var s = applySolve(const DailyStreak(), 100).state;
      s = applySolve(s, 101).state;
      s = applySolve(s, 103).state; // grace used
      s = applySolve(s, 105).state; // no grace left
      expect(s.streak, 1);
      expect(s.best, 3);
      var t = applySolve(const DailyStreak(), 100).state;
      t = applySolve(t, 103).state;
      expect(t.streak, 1);
      expect(t.graceReady, isTrue, reason: 'grace only covers one day');
    });

    test('a clock moved back earns nothing and keeps values', () {
      final s = applySolve(applySolve(const DailyStreak(), 100).state, 101);
      final r = applySolve(s.state, 90);
      expect(r.rewarded, isFalse);
      expect(r.state.streak, 2);
      final view = streakOn(s.state, 50);
      expect(view.current, 2);
      expect(view.current, isNonNegative);
    });

    test('streak view on a later day', () {
      final s = applySolve(applySolve(const DailyStreak(), 100).state, 101);
      expect(streakOn(s.state, 101).status, StreakStatus.safe);
      expect(streakOn(s.state, 102).status, StreakStatus.pending);
      expect(streakOn(s.state, 103).status, StreakStatus.graceCovers);
      expect(streakOn(s.state, 103).current, 2);
      expect(streakOn(s.state, 104).current, 0);
      expect(streakOn(const DailyStreak(), 5).status, StreakStatus.none);
    });

    test('bonus XP grows to 30', () {
      expect(dailyBonusXp(1), 10);
      expect(dailyBonusXp(2), 15);
      expect(dailyBonusXp(5), 30);
      expect(dailyBonusXp(40), 30);
      expect(dailyBonusXp(0), 10);
      expect(dailyBonusXp(-3), 10);
    });

    test('share text has the date, result and optional link', () {
      final text = dailyShareText(
        day: today,
        size: 12,
        seconds: 201,
        stars: 3,
        streak: 4,
        link: 'https://bon-on.github.io/NonoGrid/',
      );
      expect(
        text,
        'NonoGrid Daily 2026-11-08: 12x12 in 3:21, 3/3 stars, streak 4 '
        'https://bon-on.github.io/NonoGrid/',
      );
      expect(
        dailyShareText(day: today, size: 8, seconds: 5, stars: 1, streak: 1),
        'NonoGrid Daily 2026-11-08: 8x8 in 0:05, 1/3 stars, streak 1',
      );
    });
  });

  group('daily storage', () {
    test('first solve rewards stars, XP and the bonus once', () async {
      final s = await _open({});
      final r = await s.recordDailyClear(today, 60);
      expect(r.daily!.rewarded, isTrue);
      expect(r.daily!.streak, 1);
      expect(r.stars, 3);
      expect(r.xpGained, 12 * 2 + 3 * 5 + 10);
      expect(s.xp, r.xpGained);
      expect(s.dailyResultFor(today)!.seconds, 60);
      final again = await s.recordDailyClear(today, 30);
      expect(again.daily!.rewarded, isFalse);
      expect(again.xpGained, 0);
      expect(s.xp, r.xpGained);
      expect(s.dailyResultFor(today)!.seconds, 60);
    });

    test('daily and level boards are saved separately and reload', () async {
      final s = await _open({});
      await s.saveProgress(SavedProgress(1, '#${'.' * 24}', 12));
      await s.saveDailyProgress(DailyProgress(today, 'x' * 144, 40));
      final prefs = await SharedPreferences.getInstance();
      final reopened = GameStorage.fromPrefs(prefs);
      expect(reopened.progress!.level, 1);
      expect(reopened.dailyProgressFor(today)!.elapsedSeconds, 40);
      expect(reopened.dailyProgressFor(today + 1), isNull);
      await reopened.recordDailyClear(today, 100);
      expect(reopened.dailyProgressFor(today), isNull);
      expect(reopened.progress!.level, 1, reason: 'level board untouched');
    });

    test('streak and grace survive a reload', () async {
      final s = await _open({});
      await s.recordDailyClear(today, 50);
      await s.recordDailyClear(today + 1, 50);
      final r = await s.recordDailyClear(today + 3, 50);
      expect(r.daily!.graceUsed, isTrue);
      expect(r.daily!.streak, 3);
      final prefs = await SharedPreferences.getInstance();
      final d = GameStorage.fromPrefs(prefs).daily;
      expect(d.streak.streak, 3);
      expect(d.streak.graceReady, isFalse);
      expect(d.streak.refillLeft, kGraceRefillSolves);
      expect(d.days, [today, today + 1, today + 3]);
    });

    test('missing or damaged daily data keeps level progress', () async {
      for (final daily in <Object?>[
        null,
        'garbage',
        42,
        {'streak': -3, 'best': 'x', 'grace': 'yes', 'days': 'none'},
        {
          'last': -1,
          'streak': 2,
          'best': 1,
          'refill': 99,
          'days': [1, 'a', -5, 3],
          'result': {'day': 1, 'seconds': -2, 'stars': 9},
          'progress': {'day': 'x'},
        },
      ]) {
        final s = await _open({
          GameStorage.progressKey: jsonEncode({
            'version': 2,
            'level': 4,
            'maxCleared': 3,
            'legacyThrough': 4,
            'xp': 70,
            'daily': ?daily,
          }),
        });
        expect(s.level, 4, reason: '$daily');
        expect(s.maxCleared, 3);
        expect(s.xp, 70);
        final d = s.daily;
        expect(d.streak.streak, isNonNegative);
        expect(d.streak.best, greaterThanOrEqualTo(d.streak.streak));
        expect(d.result, isNull);
        expect(d.progress, isNull);
        expect(d.days.every((v) => v >= 0), isTrue);
      }
    });

    test('a board started before midnight counts for its own day', () async {
      final s = await _open({});
      final r = await s.recordDailyClear(today, 900);
      expect(r.daily!.day, today);
      expect(s.dailyResultFor(today + 1), isNull);
    });
  });
}
