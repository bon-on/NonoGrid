import 'dart:async';

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

/// Break-ad platform like GamePix: the ad ends when [adDone] completes.
class _AdPlatform extends _FakePlatform {
  Completer<void>? adDone;
  int ads = 0;
  void Function(bool paused)? pauseListener;

  @override
  bool get showsRunBreakAds => true;

  @override
  Future<void> showRunBreakAd() {
    ads++;
    events.add('ad');
    return (adDone = Completer<void>()).future;
  }

  @override
  void setPauseListener(void Function(bool paused)? listener) {
    pauseListener = listener;
  }
}

Future<T> _launch<T extends _FakePlatform>(
  WidgetTester t, {
  required bool tutorialSeen,
  T? platform,
}) async {
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({'level': 1});
  final storage = await GameStorage.open();
  final fake = platform ?? _FakePlatform() as T;
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: tutorialSeen),
      platform: fake,
    ),
  );
  await t.pump();
  await t.pump();
  return fake;
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

// Mirror the browser's inactive transition on both sides of hidden.
void _setLifecycle(WidgetTester tester, AppLifecycleState state) {
  if ((state == AppLifecycleState.hidden &&
          tester.binding.lifecycleState == AppLifecycleState.resumed) ||
      (state == AppLifecycleState.resumed &&
          tester.binding.lifecycleState == AppLifecycleState.hidden)) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(state);
}

void main() {
  testWidgets('background pauses once and resume respects overlays', (
    tester,
  ) async {
    final platform = await _launch(tester, tutorialSeen: true);
    expect(platform.events, ['start']);
    addTearDown(() => _setLifecycle(tester, AppLifecycleState.resumed));
    _setLifecycle(tester, AppLifecycleState.inactive);
    await tester.pump();
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    expect(platform.events, ['start', 'stop']);
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start']);
    await tester.tap(find.byKey(const Key('how-to-play-button')));
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop']);
    _setLifecycle(tester, AppLifecycleState.hidden);
    await tester.pump();
    _setLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.events, [
      'start',
      'stop',
      'start',
      'stop',
    ], reason: 'an open tutorial stays stopped after resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop', 'start']);
  });

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

  testWidgets('first launch starts at once: tips never block play', (t) async {
    final platform = await _launch(t, tutorialSeen: false);
    expect(find.byKey(const Key('coach-strip')), findsOneWidget);
    expect(platform.events, ['start']);

    await t.tap(find.byKey(const Key('coach-dismiss')));
    await t.pump();
    expect(platform.events, ['start'], reason: 'hiding tips is no transition');
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

  testWidgets('break ad runs before the next puzzle, never mid-puzzle', (
    t,
  ) async {
    final platform = await _launch(
      t,
      tutorialSeen: true,
      platform: _AdPlatform(),
    );
    // Mid-puzzle actions never ask for an ad.
    await t.tap(find.text('Restart'));
    await t.pump();
    expect(platform.ads, 0);

    await _solveLevel1(t);
    expect(find.textContaining('Solved in'), findsOneWidget);
    expect(platform.ads, 0, reason: 'solving shows no ad');

    await t.tap(find.text('Next'));
    await t.pump();
    expect(platform.ads, 1);
    expect(find.text('Level 1'), findsOneWidget, reason: 'waits for the ad');

    // Double taps and keys during the ad neither repeat it nor skip it.
    await t.tap(find.text('Next'), warnIfMissed: false);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(platform.ads, 1);
    expect(find.text('Level 1'), findsOneWidget);

    platform.adDone!.complete();
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(platform.ads, 1);
    expect(platform.events, ['start', 'stop', 'ad', 'start']);
  });

  testWidgets('without break ads Next goes straight to the next puzzle', (
    t,
  ) async {
    final platform = await _launch(t, tutorialSeen: true);
    await _solveLevel1(t);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(platform.showsRunBreakAds, isFalse);
  });

  testWidgets('portal pause and resume stop and restart gameplay', (t) async {
    final platform = await _launch(
      t,
      tutorialSeen: true,
      platform: _AdPlatform(),
    );
    expect(platform.events, ['start']);
    platform.pauseListener!(true);
    await t.pump();
    expect(platform.events, ['start', 'stop']);
    platform.pauseListener!(false);
    await t.pump();
    expect(platform.events, ['start', 'stop', 'start']);
  });
}
