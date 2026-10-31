import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/platform/game_platform.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlatform extends GamePlatform {
  final List<String> events = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');
}

Future<_FakePlatform> _launch(
  WidgetTester t, {
  required bool tutorialSeen,
}) async {
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = await GameStorage.open();
  final platform = _FakePlatform();
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: tutorialSeen),
      platform: platform,
    ),
  );
  await t.pump();
  await t.pump();
  return platform;
}

Future<void> _solveLevel1(WidgetTester t) async {
  final p = puzzleForLevel(1);
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
  await t.pumpAndSettle();
}

void main() {
  testWidgets('seen tutorial: start, overlay stop/start, restart no dupes', (
    t,
  ) async {
    final platform = await _launch(t, tutorialSeen: true);
    expect(platform.events, ['start']);

    await t.tap(find.text('Restart'));
    await t.pump();
    expect(platform.events, ['start'], reason: 'restart is not a transition');

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    expect(platform.events, ['start', 'stop']);

    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('first launch starts only after the tutorial closes', (t) async {
    final platform = await _launch(t, tutorialSeen: false);
    expect(platform.events, isEmpty);

    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    expect(platform.events, ['start']);
  });

  testWidgets('solving a puzzle stops, next puzzle starts', (t) async {
    final platform = await _launch(t, tutorialSeen: true);
    await _solveLevel1(t);
    expect(find.textContaining('Solved in'), findsOneWidget);
    expect(platform.events, ['start', 'stop']);

    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(platform.events, ['start', 'stop', 'start']);
  });
}
