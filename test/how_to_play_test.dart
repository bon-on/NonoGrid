import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BrokenTutorialStore implements TutorialStore {
  @override
  Future<bool> isSeen() async => throw StateError('no prefs');
  @override
  Future<void> markSeen() async => throw StateError('disk full');
}

final _overlay = find.byKey(const Key('how-to-play'));
final _text = find.byKey(const Key('how-to-play-text'));
String? _stepText(WidgetTester t) => (t.widget(_text) as Text).data;

Future<GameStorage> _launch(
  WidgetTester t,
  TutorialStore tutorial, {
  Size size = const Size(1280, 720),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final s = await GameStorage.open();
  await t.pumpWidget(
    NonoGridApp(key: UniqueKey(), storage: s, tutorialStore: tutorial),
  );
  await t.pump();
  await t.pump();
  return s;
}

final _coach = find.byKey(const Key('coach-strip'));

/// Opens the full How to play card with the "?" button.
Future<void> _openCard(WidgetTester t) async {
  await t.tap(find.byKey(const Key('how-to-play-button')));
  await t.pump();
}

Offset _lastCell(WidgetTester t) {
  final paint = find.descendant(
    of: find.byType(NonoBoard),
    matching: find.byType(CustomPaint),
  );
  return t.getRect(paint.first).bottomRight - const Offset(10, 10);
}

void main() {
  testWidgets('first launch shows the tip strip, no card, board playable', (
    t,
  ) async {
    final store = MemoryTutorialStore();
    final s = await _launch(t, store);
    expect(_overlay, findsNothing);
    expect(_coach, findsOneWidget);
    await t.tapAt(_lastCell(t));
    await t.pump();
    expect(s.progress, isNotNull, reason: 'the strip never blocks the board');
    expect(store.seen, isFalse);
    await t.tap(find.byKey(const Key('coach-dismiss')));
    await t.pump();
    expect(_coach, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('open card blocks taps and game keys', (t) async {
    final s = await _launch(t, MemoryTutorialStore());
    await _openCard(t);
    expect(_overlay, findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);

    await t.tapAt(_lastCell(t));
    await t.pump();
    expect(s.progress, isNull);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.pump();
    expect(s.progress, isNull);
    expect(_overlay, findsOneWidget);
    expect(_stepText(t), isNotNull);
  });

  testWidgets('Next walks steps, Play closes and stores the flag', (t) async {
    final store = MemoryTutorialStore();
    await _launch(t, store);
    await _openCard(t);
    final t0 = _stepText(t);
    expect(find.text('Next'), findsOneWidget);
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pump();
    expect(_stepText(t), isNot(t0));
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(store.seen, isFalse);
    await t.tap(find.byKey(const Key('how-to-play-next')));
    await t.pump();
    expect(_overlay, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip closes and stores the flag; Escape also skips', (t) async {
    final store = MemoryTutorialStore();
    await _launch(t, store);
    await _openCard(t);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    expect(_overlay, findsNothing);
    expect(store.seen, isTrue);
    expect(_coach, findsNothing, reason: 'reading the card ends the tips');

    final store2 = MemoryTutorialStore();
    await _launch(t, store2);
    await _openCard(t);
    expect(_overlay, findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(_overlay, findsNothing);
    expect(store2.seen, isTrue);
  });

  testWidgets('Enter, Space and arrows navigate without reaching the game', (
    t,
  ) async {
    final store = MemoryTutorialStore();
    final s = await _launch(t, store);
    await _openCard(t);
    final t0 = _stepText(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_stepText(t), isNot(t0));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump();
    expect(_stepText(t), t0);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(find.text('Play'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(_overlay, findsNothing);
    expect(store.seen, isTrue);
    expect(s.progress, isNull); // Space did not fill a cell.
  });

  testWidgets('neither card nor tips appear when the flag is set', (t) async {
    await _launch(t, MemoryTutorialStore(seen: true));
    expect(_overlay, findsNothing);
    expect(_coach, findsNothing);
  });

  testWidgets('storage failures never break play', (t) async {
    await _launch(t, _BrokenTutorialStore());
    expect(_coach, findsOneWidget, reason: 'a read failure shows the tips');
    await t.tap(find.byKey(const Key('coach-dismiss')));
    await t.pump();
    expect(_coach, findsNothing);
    await _openCard(t);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    expect(_overlay, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('? reopens at step 1 without resetting the game', (t) async {
    final s = await _launch(t, MemoryTutorialStore(seen: true));
    await t.tapAt(_lastCell(t));
    await t.pump();
    final cells = s.progress?.cells;
    expect(cells, '${'.' * 24}#');

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    expect(_overlay, findsOneWidget);
    final t0 = _stepText(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_stepText(t), isNot(t0));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(_overlay, findsNothing);
    expect(s.progress?.cells, cells);

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    expect(_stepText(t), t0);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    // Game keys work again: U undoes the filled cell.
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.pump();
    expect(find.text('Undo'), findsOneWidget);
    expect(s.progress?.cells, '.' * 25);
  });

  testWidgets('timer does not count while open and resumes on close', (
    t,
  ) async {
    await _launch(t, MemoryTutorialStore(seen: true));
    await t.tapAt(_lastCell(t));
    await t.pump();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1100)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('0:01'), findsOneWidget);

    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 2300)));
    await t.pump(const Duration(milliseconds: 600));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.text('0:01'), findsOneWidget);

    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1100)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('0:02'), findsOneWidget);
  });

  testWidgets('background/resume while open does not restart the clock', (
    t,
  ) async {
    await _launch(t, MemoryTutorialStore(seen: true));
    await t.tapAt(_lastCell(t));
    await t.pump();
    await t.tap(find.byKey(const Key('how-to-play-button')));
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1300)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('0:00'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1100)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('0:01'), findsOneWidget);
  });

  testWidgets('first run: the clock waits for the first move', (t) async {
    await _launch(t, MemoryTutorialStore());
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1300)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('0:00'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(844, 390),
    Size(1280, 720),
    Size(320, 640),
  ]) {
    testWidgets('tips, overlay and header fit $size', (t) async {
      await _launch(t, MemoryTutorialStore(), size: size);
      expect(_coach, findsOneWidget);
      final strip = t.getRect(_coach);
      expect(strip.left, greaterThanOrEqualTo(0));
      expect(strip.right, lessThanOrEqualTo(size.width));
      expect(strip.top, greaterThanOrEqualTo(0));
      // The board keeps room below the strip.
      expect(t.getRect(find.byType(NonoBoard)).height, greaterThan(150));
      expect(t.takeException(), isNull);
      await _openCard(t);
      expect(_overlay, findsOneWidget);
      final r = t.getRect(_overlay);
      expect(r.width, lessThanOrEqualTo(360));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(size.height));
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('browser keys and shortcuts stay unhandled while open', (
    t,
  ) async {
    final seen = <LogicalKeyboardKey>[];
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = await GameStorage.open();
    await t.pumpWidget(
      Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent) seen.add(e.logicalKey);
          return KeyEventResult.ignored;
        },
        child: NonoGridApp(
          key: UniqueKey(),
          storage: s,
          tutorialStore: MemoryTutorialStore(),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    await _openCard(t);

    await t.sendKeyEvent(LogicalKeyboardKey.f5);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(seen, contains(LogicalKeyboardKey.f5));
    expect(seen, contains(LogicalKeyboardKey.enter));
    expect(_overlay, findsOneWidget, reason: 'Ctrl+Enter must not advance');
    expect(_stepText(t), nonoGridSteps.first.text);
  });

  testWidgets('key repeat does not paint after the card closes', (t) async {
    final s = await _launch(t, MemoryTutorialStore());
    await _openCard(t);
    // Space is held while the card is open, then the card closes.
    await t.sendKeyDownEvent(LogicalKeyboardKey.space);
    await t.tap(find.byKey(const Key('how-to-play-skip')));
    await t.pump();
    await t.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(s.progress, isNull);
    await t.sendKeyUpEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(s.progress, isNotNull, reason: 'a fresh press still paints');
  });

  testWidgets('tips follow real play: fill, cross, Logic hint', (t) async {
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Legacy level 1 is the heart: row 1 is a full line.
    SharedPreferences.setMockInitialValues({'level': 1});
    final s = await GameStorage.open();
    final store = MemoryTutorialStore();
    await t.pumpWidget(NonoGridApp(storage: s, tutorialStore: store));
    await t.pump();
    await t.pump();
    expect(find.textContaining('A 5 fills the whole line'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('to cross out cells'), findsOneWidget);
    // Undo does not move the tips back or forward.
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('to cross out cells'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Logic hint shows'), findsOneWidget);
    expect(store.seen, isFalse);

    await t.tap(find.byKey(const Key('logic-hint')));
    await t.pump(const Duration(milliseconds: 300));
    expect(_coach, findsNothing);
    expect(store.seen, isTrue);
  });
}
