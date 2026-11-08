import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/daily.dart';
import 'package:nono_grid/src/platform/game_platform.dart';
import 'package:nono_grid/src/share/result_copy.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlatform extends GamePlatform {
  _FakePlatform({this.link});
  final String? link;
  final List<String> events = <String>[];
  @override
  Future<void> initialize() async {}
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
  @override
  String? get shareLink => link;
}

class _FakeCopier extends ResultCopier {
  _FakeCopier({this.ok = true, this.throws = false});
  final bool ok;
  final bool throws;
  final List<String> texts = <String>[];
  @override
  Future<bool> copyText(String text) async {
    texts.add(text);
    if (throws) throw StateError('blocked');
    return ok;
  }
}

final DateTime _now = DateTime(2026, 11, 8, 15, 30);
final int _today = dayIndexOf(_now);

Future<(GameStorage, _FakePlatform, _FakeCopier)> _launch(
  WidgetTester t, {
  DateTime Function()? clock,
  Size size = const Size(1280, 720),
  Map<String, Object> prefs = const {},
  String? link = pagesShareLink,
  _FakeCopier? copier,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({'level': 1, ...prefs});
  final storage = await GameStorage.open();
  final platform = _FakePlatform(link: link);
  final fake = copier ?? _FakeCopier();
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: true),
      platform: platform,
      clock: clock ?? () => _now,
      copier: fake,
    ),
  );
  await t.pump();
  await t.pump();
  return (storage, platform, fake);
}

/// Fills every solution cell with the keyboard, starting from (0, 0).
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

void _expectInside(WidgetTester t, Finder f, Size size) {
  final r = t.getRect(f);
  expect(r.top, greaterThanOrEqualTo(0), reason: '$f top');
  expect(r.left, greaterThanOrEqualTo(0), reason: '$f left');
  expect(r.bottom, lessThanOrEqualTo(size.height), reason: '$f bottom');
  expect(r.right, lessThanOrEqualTo(size.width), reason: '$f right');
}

void main() {
  testWidgets('keyboard: open, play, solve, copy and return', (t) async {
    final (storage, platform, copier) = await _launch(t);
    expect(find.byKey(const Key('daily-card')), findsOneWidget);
    expect(find.text('New'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-overlay')), findsOneWidget);
    expect(find.text('New puzzle'), findsOneWidget);
    expect(platform.events.last, 'stop');

    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-overlay')), findsNothing);
    expect(find.byKey(const Key('daily-title')), findsOneWidget);
    final puzzle = storage.dailyPuzzleFor(_today);
    expect(_board(t).puzzle.solution, puzzle.solution);
    expect(_board(t).size, dailySize(_today));

    await _solve(t, puzzle);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-summary')), findsOneWidget);
    expect(find.text('Daily solved!'), findsOneWidget);
    expect(find.text('Streak 1  -  Best 1'), findsOneWidget);
    expect(
      find.byKey(const Key('summary-bonus-Daily bonus (streak 1)')),
      findsOneWidget,
    );
    expect(find.text('Come back tomorrow for streak 2'), findsOneWidget);
    expect(storage.daily.streak.streak, 1);
    expect(storage.xp, greaterThan(0));

    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.pump();
    expect(copier.texts.single, startsWith('NonoGrid Daily 2026-11-08: '));
    expect(copier.texts.single, contains('streak 1'));
    expect(copier.texts.single, endsWith(' $pagesShareLink'));
    expect(find.text('Copied!'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(platform.events.last, 'start');

    // A solved daily opens as a summary card: Enter closes, C copies.
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-copy')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.pump();
    expect(copier.texts, hasLength(2));
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-overlay')), findsNothing);
    expect(find.text('Level 1'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('daily and level boards keep their own marks', (t) async {
    final (storage, _, _) = await _launch(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyX); // level 1, cell (0,0)
    await t.pump();
    expect(_board(t).at(0, 0), Mark.crossed);

    await t.tap(find.byKey(const Key('daily-card')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('daily-play')));
    await t.pumpAndSettle();
    expect(_board(t).at(0, 0), Mark.empty);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.keyX); // daily, cell (0,1)
    await t.pump();
    expect(storage.dailyProgressFor(_today), isNotNull);

    // L in the overlay goes back to the level board.
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.keyL);
    await t.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);
    expect(_board(t).at(0, 0), Mark.crossed);
    expect(_board(t).at(0, 1), Mark.empty);
    expect(find.textContaining('In progress'), findsWidgets);

    await t.tap(find.byKey(const Key('daily-card')));
    await t.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(_board(t).at(0, 1), Mark.crossed);
    expect(_board(t).at(0, 0), Mark.empty);

    // The daily board survives an app restart.
    await t.pumpWidget(const SizedBox());
    final prefs = await SharedPreferences.getInstance();
    final reopened = GameStorage.fromPrefs(prefs);
    expect(reopened.dailyProgressFor(_today)!.cells, isNotEmpty);
    expect(reopened.progress!.level, 1);
  });

  testWidgets('copy without a link and copy failures only show a toast', (
    t,
  ) async {
    final copier = _FakeCopier(throws: true);
    final (storage, _, _) = await _launch(t, link: null, copier: copier);
    await storage.recordDailyClear(_today, 95);
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('daily-copy')));
    await t.pump();
    expect(copier.texts.single, isNot(contains('http')));
    expect(find.text('Could not copy'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('a refused copy shows Could not copy', (t) async {
    final copier = _FakeCopier(ok: false);
    final (storage, _, _) = await _launch(t, copier: copier);
    await storage.recordDailyClear(_today, 95);
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.pump();
    expect(copier.texts.single, endsWith(pagesShareLink));
    expect(find.text('Could not copy'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Could not copy'), findsNothing);
  });

  testWidgets('a daily finished after midnight counts for its day', (t) async {
    var now = _now;
    final (storage, _, _) = await _launch(t, clock: () => now);
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    now = DateTime(2026, 11, 9, 0, 10);
    await _solve(t, storage.dailyPuzzleFor(_today));
    await t.pumpAndSettle();
    expect(storage.dailyResultFor(_today), isNotNull);
    expect(storage.dailyResultFor(_today + 1), isNull);
    expect(find.text("Solve today's daily for streak 2"), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('New'), findsOneWidget, reason: 'next day is new');
  });

  testWidgets('a missed day shows the grace keeping the streak', (t) async {
    await _launch(
      t,
      prefs: {
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 1,
          'maxCleared': 0,
          'daily': {
            'last': _today - 2,
            'streak': 3,
            'best': 5,
            'grace': true,
            'days': [_today - 3, _today - 2],
          },
        }),
      },
    );
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    expect(find.text('Streak 3  -  Best 5'), findsOneWidget);
    expect(
      find.text('Your grace covers yesterday - solve today'),
      findsOneWidget,
    );
    expect(
      find.text('Grace ready: one missed day is forgiven'),
      findsOneWidget,
    );
  });

  testWidgets('a clock set before the last daily never crashes', (t) async {
    await _launch(
      t,
      prefs: {
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 1,
          'maxCleared': 0,
          'daily': {'last': _today + 40, 'streak': 2, 'best': 2},
        }),
      },
    );
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.pumpAndSettle();
    expect(find.text('Streak 2  -  Best 2'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final size in const [
    Size(390, 844),
    Size(1280, 720),
    Size(1366, 768),
    Size(844, 390),
  ]) {
    testWidgets('daily card, overlay and summary fit $size', (t) async {
      final (storage, _, _) = await _launch(t, size: size);
      expect(find.byKey(const Key('daily-card')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('daily-card')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      _expectInside(t, find.byKey(const Key('daily-overlay')), size);
      _expectInside(t, find.byKey(const Key('daily-play')), size);
      await t.tap(find.byKey(const Key('daily-play')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _solve(t, storage.dailyPuzzleFor(_today));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      _expectInside(t, find.byKey(const Key('level-summary')), size);
      _expectInside(t, find.byKey(const Key('summary-next')), size);
      _expectInside(t, find.byKey(const Key('summary-copy')), size);
      _expectInside(t, find.byKey(const Key('summary-goal')), size);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      _expectInside(t, find.byKey(const Key('win-next')), size);
      await t.tap(find.byKey(const Key('win-next')));
      await t.pumpAndSettle();
      expect(find.text('Level 1'), findsOneWidget);
      await t.tap(find.byKey(const Key('daily-card')));
      await t.pumpAndSettle();
      _expectInside(t, find.byKey(const Key('daily-overlay')), size);
      expect(t.takeException(), isNull);
    });
  }
}
