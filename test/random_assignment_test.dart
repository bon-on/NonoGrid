import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GameStorage> fresh(int seed) async {
    SharedPreferences.setMockInitialValues({});
    return GameStorage.open(seedSource: () => seed);
  }

  test(
    'fresh installs vary, but reopening and restarting retain assignment',
    () async {
      final first = await fresh(12345);
      final solution = first.puzzleFor(1).solution;
      expect(first.puzzleFor(1).name, isNull);
      await first.setLevel(1);
      final reopened = await GameStorage.open(seedSource: () => 98765);
      expect(reopened.puzzleFor(1).solution, solution);
      final other = await fresh(98765);
      expect(other.puzzleFor(1).solution, isNot(solution));
    },
  );

  test('all difficulty sizes remain line solvable with explicit seeds', () {
    for (final level in [1, 7, 13, 21, 31, 46]) {
      for (final seed in [1, 12345, 0xFFFFFFFF]) {
        final p = generatePuzzle(level, seed: seed);
        expect(p.size, sizeForLevel(level));
        expect(isLineSolvable(p.solution, p.size), isTrue);
        expect(generatePuzzle(level, seed: seed).solution, p.solution);
      }
    }
  });

  test('unfinished marks, time, mistakes and seed survive reopening', () async {
    final s = await fresh(12345);
    final original = s.puzzleFor(1).solution;
    await s.saveProgress(SavedProgress(1, '#${'.' * 24}', 72, mistakes: true));
    final reopened = await GameStorage.open(seedSource: () => 999);
    expect(reopened.startupLevel, 1);
    expect(reopened.puzzleFor(1).solution, original);
    expect(reopened.progress!.elapsedSeconds, 72);
    expect(reopened.progress!.mistakes, isTrue);
  });

  test(
    'clear without Next resumes next level; unfinished replay wins',
    () async {
      final s = await fresh(12345);
      await s.setLevel(1);
      await s.recordClear(1, 12);
      var reopened = await GameStorage.open();
      expect(reopened.startupLevel, 2);
      await reopened.saveProgress(SavedProgress(1, '#${'.' * 24}', 19));
      await reopened.setLevel(2);
      reopened = await GameStorage.open();
      expect(reopened.startupLevel, 1);
      expect(reopened.xp, s.xp);
    },
  );

  test('legacy v1 and v2 preserve exposed puzzles and records', () async {
    for (final data in <Map<String, Object>>[
      {'level': 2, 'maxCleared': 1, 'best_1': 12},
      {
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 2,
          'maxCleared': 1,
          'records': {
            '1': {'best': 12, 'stars': 2},
          },
          'xp': 20,
        }),
      },
    ]) {
      SharedPreferences.setMockInitialValues(data);
      final s = await GameStorage.open(seedSource: () => 999);
      expect(s.puzzleFor(1).solution, puzzleForLevel(1).solution);
      expect(s.puzzleFor(2).solution, puzzleForLevel(2).solution);
      expect(s.bestSeconds(1), 12);
      await s.setLevel(2);
      final again = await GameStorage.open();
      expect(again.previewPuzzle(1).name, 'Heart');
    }
  });

  test(
    'thumbnail preview consumes no seed and cannot pin an unopened level',
    () async {
      var draws = 0;
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(
        seedSource: () {
          draws++;
          return 12345;
        },
      );
      s.previewPuzzle(2);
      expect(draws, 0);
      final actual = s.puzzleFor(2);
      expect(draws, 1);
      expect(actual.solution, generatePuzzle(2, seed: 12345).solution);
    },
  );

  test(
    'corrupt seed rejects its saved marks while keeping earned metadata',
    () async {
      SharedPreferences.setMockInitialValues({
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 1,
          'maxCleared': 0,
          'xp': 20,
          'legacyThrough': 0,
          'puzzleSeeds': {'1': -1},
          'progress': {'level': 1, 'cells': '#${'.' * 24}', 'elapsed': 50},
        }),
      });
      final s = await GameStorage.open(seedSource: () => 12345);
      expect(s.progress, isNull);
      expect(s.xp, 20);
      expect(
        s.puzzleFor(1).solution,
        generatePuzzle(1, seed: friendlyFirstSeed(12345)).solution,
      );
    },
  );
  test(
    'a damaged solved assignment never displays the unrelated legacy picture',
    () async {
      SharedPreferences.setMockInitialValues({
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 2,
          'maxCleared': 1,
          'xp': 20,
          'legacyThrough': 0,
          'puzzleSeeds': {'1': -1},
          'records': {
            '1': {'stars': 3, 'best': 10},
          },
        }),
      });
      final s = await GameStorage.open(seedSource: () => 12345);
      expect(s.previewPuzzle(1).solution.every((c) => !c), isTrue);
      expect(s.xp, 20);
      expect(s.stars(1), 3);
    },
  );
}
