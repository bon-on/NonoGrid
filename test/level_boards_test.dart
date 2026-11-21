import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/audio/sound_mute_store.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/daily.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/daily_ui.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

// feature-next-session-hooks: per-level unfinished boards, the daily hook on
// the clear summary and the one-tap Next.

class _Muted extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => true;
  @override
  Future<void> saveMuted(bool value) async {}
}

String _marks(int size, {String first = '#'}) =>
    '$first${'.' * (size * size - 1)}';

/// Reopens storage from the JSON string actually written to prefs.
Future<GameStorage> _reopen({int seed = 999}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(GameStorage.progressKey)!;
  SharedPreferences.setMockInitialValues({GameStorage.progressKey: raw});
  return GameStorage.open(seedSource: () => seed);
}

Future<Map<String, dynamic>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString(GameStorage.progressKey)!)
      as Map<String, dynamic>;
}

Future<void> _solve(WidgetTester t, Puzzle p) async {
  var cr = 0, cc = 0;
  for (var r = 0; r < p.size; r++) {
    for (var c = 0; c < p.size; c++) {
      if (!p.filledAt(r, c)) continue;
      while (cr < r) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        cr++;
      }
      while (cc < c) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        cc++;
      }
      while (cc > c) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        cc--;
      }
      await t.sendKeyEvent(LogicalKeyboardKey.space);
    }
  }
}

NonoGame _board(WidgetTester t) =>
    t.widget<NonoBoard>(find.byType(NonoBoard)).game;

final DateTime _now = DateTime(2026, 11, 8, 15, 30);

Future<GameStorage> _launch(
  WidgetTester t, {
  Size size = const Size(1280, 720),
  int seed = 4321,
  Future<void> Function(GameStorage)? setup,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = await GameStorage.open(seedSource: () => seed);
  await setup?.call(storage);
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: true),
      soundMuteStore: _Muted(),
      clock: () => _now,
    ),
  );
  await t.pump();
  await t.pump();
  return storage;
}

void main() {
  group('per-level boards in storage', () {
    test('boards of two levels survive a reopen through the JSON', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 777);
      await s.recordClear(1, 20);
      await s.recordClear(2, 20);
      final size3 = s.puzzleFor(3).size;
      final size2 = s.puzzleFor(2).size;
      await s.saveProgress(SavedProgress(3, _marks(size3), 41));
      await s.saveProgress(
        SavedProgress(2, _marks(size2, first: 'x'), 12, mistakes: true),
      );
      final reopened = await _reopen();
      expect(reopened.progressFor(3)?.elapsedSeconds, 41);
      expect(reopened.progressFor(2)?.cells, _marks(size2, first: 'x'));
      expect(reopened.progressFor(2)?.mistakes, isTrue);
      expect(reopened.progress?.level, 2, reason: 'most recent');
      expect(
        reopened.puzzleFor(3).solution,
        s.puzzleFor(3).solution,
        reason: 'same seed, same puzzle',
      );
    });

    test('an old single progress slot migrates into its level', () async {
      SharedPreferences.setMockInitialValues({
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 2,
          'maxCleared': 1,
          'legacyThrough': 0,
          'puzzleSeeds': {'1': 11, '2': 22},
          'puzzleSizes': {'1': 5, '2': 5},
          'progress': SavedProgress(2, _marks(5), 30).toJson(),
        }),
      });
      final s = await GameStorage.open(seedSource: () => 1);
      expect(s.progressFor(2)?.elapsedSeconds, 30);
      await s.saveProgress(SavedProgress(1, _marks(5, first: 'x'), 5));
      final json = await _stored();
      expect((json['boards'] as List).length, 2);
      final reopened = await _reopen();
      expect(reopened.progressFor(2)?.elapsedSeconds, 30);
      expect(reopened.progressFor(1)?.elapsedSeconds, 5);
    });

    test(
      'old clients still find the most recent board in `progress`',
      () async {
        SharedPreferences.setMockInitialValues({});
        final s = await GameStorage.open(seedSource: () => 4242);
        await s.recordClear(1, 20);
        await s.saveProgress(SavedProgress(2, _marks(5), 9));
        await s.saveProgress(SavedProgress(1, _marks(5, first: 'x'), 3));
        final json = await _stored();
        // An old client parses only `progress` and drops unknown keys when it
        // writes back.
        final progress = json['progress'] as Map<String, dynamic>;
        expect(progress['level'], 1);
        expect(progress['cells'], _marks(5, first: 'x'));
        expect(progress.keys.toSet(), {
          'level',
          'cells',
          'elapsed',
          'mistakes',
        });
        final oldWrite = Map<String, dynamic>.of(json)..remove('boards');
        SharedPreferences.setMockInitialValues({
          GameStorage.progressKey: jsonEncode(oldWrite),
        });
        final after = await GameStorage.open();
        expect(after.progressFor(1)?.elapsedSeconds, 3);
        expect(
          after.progressFor(2),
          isNull,
          reason: 'dropped by the old write',
        );
      },
    );

    test('keeps the five most recent boards', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 31337);
      for (var level = 1; level <= 5; level++) {
        await s.recordClear(level, 30);
      }
      for (var level = 1; level <= 5; level++) {
        final n = s.puzzleFor(level).size;
        await s.saveProgress(SavedProgress(level, _marks(n), level));
      }
      // Touching level 1 again makes level 2 the oldest.
      await s.saveProgress(SavedProgress(1, _marks(s.puzzleFor(1).size), 100));
      await s.saveProgress(SavedProgress(6, _marks(s.puzzleFor(6).size), 6));
      final reopened = await _reopen();
      expect(reopened.progressFor(2), isNull);
      for (final level in [1, 3, 4, 5, 6]) {
        expect(reopened.progressFor(level), isNotNull, reason: 'level $level');
      }
      expect(reopened.progressFor(1)?.elapsedSeconds, 100);
      final json = await _stored();
      expect((json['boards'] as List).length, NonoProgressData.maxBoards);
    });

    test('a board whose seed no longer matches is never applied', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 5150);
      await s.recordClear(1, 20);
      await s.saveProgress(SavedProgress(2, _marks(5), 8));
      await s.saveProgress(SavedProgress(1, _marks(5), 7));
      final json = await _stored();
      expect((json['progress'] as Map)['level'], 1);
      // Level 1 was reassigned and level 2 lost its seed. The unstamped
      // `progress` mirror of level 1 stays and must not bring it back.
      (json['puzzleSeeds'] as Map<String, dynamic>)
        ..['1'] = 999
        ..remove('2');
      SharedPreferences.setMockInitialValues({
        GameStorage.progressKey: jsonEncode(json),
      });
      final reopened = await GameStorage.open(seedSource: () => 1);
      expect(reopened.progressFor(1), isNull);
      expect(reopened.progressFor(2), isNull);
      expect(reopened.maxCleared, 1, reason: 'meta progress is kept');
    });

    test('a stamped seed on a legacy level is rejected', () async {
      SharedPreferences.setMockInitialValues({
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 3,
          'maxCleared': 2,
          'legacyThrough': 3,
          'puzzleSeeds': <String, int>{},
          'boards': [
            {...SavedProgress(2, _marks(5), 4).toJson(), 'seed': 12},
            SavedProgress(3, _marks(5), 6).toJson(),
          ],
        }),
      });
      final s = await GameStorage.open();
      expect(s.progressFor(2), isNull);
      expect(s.progressFor(3)?.elapsedSeconds, 6);
    });

    test('clearing a level drops only its own board', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 2024);
      await s.recordClear(1, 20);
      await s.saveProgress(SavedProgress(1, _marks(5), 3));
      await s.saveProgress(SavedProgress(2, _marks(5), 4));
      await s.recordClear(2, 50);
      final reopened = await _reopen();
      expect(reopened.progressFor(2), isNull);
      expect(reopened.progressFor(1)?.elapsedSeconds, 3);
    });

    test('startup opens the frontier and keeps lower boards', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 8080);
      await s.recordClear(1, 20);
      await s.recordClear(2, 20);
      await s.saveProgress(SavedProgress(3, _marks(5), 15));
      await s.saveProgress(SavedProgress(1, _marks(5), 9));
      await s.setLevel(1);
      final reopened = await _reopen();
      expect(reopened.startupLevel, 3);
      expect(reopened.progressFor(3)?.elapsedSeconds, 15);
      expect(reopened.progressFor(1)?.elapsedSeconds, 9);
    });

    test('daily board is independent of level boards', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 6060);
      final today = dayIndexOf(_now);
      await s.saveProgress(SavedProgress(1, _marks(5), 2));
      await s.saveDailyProgress(DailyProgress(today, 'x' * 64, 40));
      await s.clearProgress(1);
      final reopened = await _reopen();
      expect(reopened.progressFor(1), isNull);
      expect(reopened.dailyProgressFor(today)?.elapsedSeconds, 40);
    });
  });

  group('daily countdown', () {
    test('time until the next local date', () {
      expect(
        untilNextDaily(DateTime(2026, 11, 8, 15, 30)),
        const Duration(hours: 8, minutes: 30),
      );
      expect(formatCountdown(const Duration(hours: 5, minutes: 12)), '5h 12m');
      expect(formatCountdown(const Duration(minutes: 7, seconds: 1)), '8m');
      expect(formatCountdown(Duration.zero), '1m');
      expect(formatCountdown(const Duration(hours: 24)), '24h');
    });

    test('summary hook reflects streak and grace', () async {
      final today = dayIndexOf(_now);
      Future<String> hook(Map<String, Object?> daily) async {
        SharedPreferences.setMockInitialValues({
          GameStorage.progressKey: jsonEncode({
            'version': 2,
            'level': 1,
            'maxCleared': 0,
            'daily': daily,
          }),
        });
        final s = await GameStorage.open();
        return DailyInfo.of(s, today).summaryHook(_now);
      }

      expect(await hook({}), "Today's daily is waiting (8h 30m left)");
      expect(
        await hook({'last': today - 1, 'streak': 3, 'best': 3}),
        "Solve today's daily to keep streak 3 (8h 30m left)",
      );
      expect(
        await hook({'last': today - 2, 'streak': 3, 'best': 3}),
        "Your grace saves streak 3: solve today's daily (8h 30m left)",
      );
      expect(
        await hook({
          'last': today,
          'streak': 4,
          'best': 4,
          'grace': false,
          'refill': 2,
          'result': {'day': today, 'seconds': 80, 'stars': 3},
        }),
        'New daily in 8h 30m  -  Streak 4, grace refills in 2',
      );
    });
  });

  testWidgets('moving between levels keeps both unfinished boards', (t) async {
    final s = await _launch(t, setup: (s) => s.recordClear(1, 20));
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pumpAndSettle();
    final level2 = _board(t).encode();

    await t.tap(find.byTooltip('Previous level'));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await t.pumpAndSettle();
    final level1 = _board(t).encode();

    await t.tap(find.byTooltip('Next level'));
    await t.pumpAndSettle();
    expect(_board(t).encode(), level2, reason: 'level 2 board restored');
    expect(s.progressFor(1)?.cells, level1);
    expect(s.progressFor(2)?.cells, level2);
  });

  for (final size in const [
    Size(1280, 720),
    Size(390, 844),
    Size(640, 480),
    Size(620, 349),
    Size(560, 315),
  ]) {
    testWidgets('level summary shows the daily hook and Next at $size', (
      t,
    ) async {
      final s = await _launch(t, size: size);
      await _solve(t, _board(t).puzzle);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('level-summary')), findsOneWidget);
      expect(
        find.text("Today's daily is waiting (8h 30m left)"),
        findsOneWidget,
      );
      expect(find.byKey(const Key('summary-goal')), findsOneWidget);
      for (final key in [
        'summary-next',
        'summary-daily-hook',
        'summary-goal',
      ]) {
        final r = t.getRect(find.byKey(Key(key)));
        expect(r.top, greaterThanOrEqualTo(0), reason: key);
        expect(r.bottom, lessThanOrEqualTo(size.height), reason: key);
      }
      // The summary animation finished, so level 2 is already assigned.
      final json = await _stored();
      expect((json['puzzleSeeds'] as Map).containsKey('2'), isTrue);
      final warmed = s.previewPuzzle(2).solution;

      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('level-summary')), findsNothing);
      expect(_board(t).puzzle.solution, warmed);
    });
  }
}
