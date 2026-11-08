import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/meta/collection.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameStorage> _open(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return GameStorage.open(seedSource: () => 777);
}

/// A v2 save with levels 1..[cleared] solved (1 star each).
Map<String, Object> _save(int cleared, {Object? setsAwarded, int xp = 0}) => {
  GameStorage.progressKey: jsonEncode({
    'version': 2,
    'level': cleared + 1,
    'maxCleared': cleared,
    'xp': xp,
    'legacyThrough': cleared + 1,
    'records': {
      for (var l = 1; l <= cleared; l++) '$l': {'stars': 1, 'best': 30},
    },
    'setsAwarded': ?setsAwarded,
  }),
};

void main() {
  group('sets', () {
    test('ranges and names', () {
      expect(setOfLevel(1), 0);
      expect(setOfLevel(10), 0);
      expect(setOfLevel(11), 1);
      expect(setOfLevel(0), 0);
      expect(firstLevelOfSet(2), 21);
      expect(setName(0), 'Sketchbook');
      expect(setName(9), 'Festival');
      expect(setName(10), 'Sketchbook II');
      expect(setName(21), 'Garden III');
      expect(setName(-1), 'Sketchbook');
    });

    test('progress and visible sets', () {
      bool solved(int l) => l <= 13;
      final p = setProgress(1, solved);
      expect(p.solved, 3);
      expect(p.complete, isFalse);
      expect(setProgress(0, solved).complete, isTrue);
      final sets = visibleSets(14, solved);
      expect(sets.map((s) => s.index), [0, 1]);
    });

    test('next goal: fewest missing, ties to the earlier set', () {
      // Set 1 misses level 4 only; set 2 misses 15..20 -> set 1 wins.
      final solved = {for (var l = 1; l <= 14; l++) l}..remove(4);
      var goal = nextSetGoal(15, solved.contains)!;
      expect(goal.set.index, 0);
      expect(goal.level, 4);
      expect(goal.missing, 1);
      // Sequential play: the current set and the next open level.
      goal = nextSetGoal(8, (l) => l <= 7)!;
      expect(goal.level, 8);
      expect(goal.missing, 3);
      // Locked levels are never suggested.
      expect(nextSetGoal(1, (_) => false)!.level, 1);
      expect(nextSetGoal(10, (l) => l <= 10), isNull);
    });

    test('newly complete sets skip awarded ones', () {
      bool solved(int l) => l <= 20;
      expect(newlyCompleteSets([1, 15], solved, {}), [0, 1]);
      expect(newlyCompleteSets([1, 15], solved, {0}), [1]);
      expect(newlyCompleteSets([1, 15], (l) => l <= 19, {}), [0]);
    });
  });

  group('set rewards in storage', () {
    test('finishing a set grants 50 XP once and persists it', () async {
      final s = await _open(_save(9, setsAwarded: <int>[]));
      final r = await s.recordClear(10, 30);
      expect(r.completedSets.map((c) => c.index), [0]);
      expect(r.bonuses.single.xp, kSetBonusXp);
      expect(r.bonuses.single.label, 'Set complete: Sketchbook');
      final puzzleXp = r.xpGained - kSetBonusXp;
      expect(puzzleXp, greaterThan(0));
      expect(s.xp, r.xpGained);
      final replay = await s.recordClear(10, 20);
      expect(replay.completedSets, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final reopened = GameStorage.fromPrefs(prefs);
      final again = await reopened.recordClear(3, 10);
      expect(again.completedSets, isEmpty);
      expect(again.setGoal!.level, 11);
    });

    test('sets completed before this feature pay out on the next clear', () {
      return () async {
        final s = await _open(_save(12));
        final r = await s.recordClear(13, 30);
        expect(r.completedSets.map((c) => c.name), ['Sketchbook']);
        expect(s.albumSets.first.complete, isTrue);
        expect(s.setGoal!.level, 14);
        expect(r.setGoal!.missing, 7);
      }();
    });

    test('huge or extra record keys never blow up the album', () async {
      SharedPreferences.setMockInitialValues({
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 3,
          'maxCleared': 2,
          'legacyThrough': 3,
          'records': {
            '1': {'stars': 1},
            '2': {'stars': 1},
            '99999999999': {'stars': 3},
            '5000000': {'stars': 2},
          },
        }),
      });
      final s = await GameStorage.open(seedSource: () => 1);
      expect(s.maxCleared, 2);
      expect(s.albumSets.length, 1, reason: 'bounded by the open level');
      expect(s.stars(99999999999), 0, reason: 'out-of-range key dropped');
      final r = await s.recordClear(3, 20);
      expect(r.setGoal!.level, 4);
    });

    test('damaged setsAwarded values never break progress', () async {
      for (final bad in <Object>[
        'all',
        42,
        {'0': true},
        [-1, 'x', 0.5, null],
      ]) {
        final s = await _open(_save(10, setsAwarded: bad, xp: 90));
        expect(s.maxCleared, 10, reason: '$bad');
        expect(s.xp, 90);
        expect(s.albumSets.first.complete, isTrue);
      }
    });
  });
}
