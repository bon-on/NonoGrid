import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/audio/sound_mute_store.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/daily_ui.dart';
import 'package:nono_grid/src/ui/game_screen.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

// feature-short-viewport-layout: the board stays first and playable in short
// portal iframes (GamePix "Small" preview 620x349, 640x480 minimum) and on
// the sizes earlier passes covered.

class _MutedStore extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => true;
  @override
  Future<void> saveMuted(bool value) async {}
}

final _canvas = find.byKey(const Key('board-canvas'));
final _coach = find.byKey(const Key('coach-strip'));

Future<void> _launch(
  WidgetTester t,
  Size size, {
  bool tips = false,
  int level = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'level': level,
    if (level > 1) 'maxCleared': level - 1,
  });
  final storage = await GameStorage.open();
  await t.pumpWidget(
    NonoGridApp(
      key: UniqueKey(),
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: !tips),
      soundMuteStore: _MutedStore(),
    ),
  );
  await t.pump();
  await t.pump();
}

/// Controls that must stay on screen, reachable and clear of the board.
List<Finder> _controls() => [
  find.byKey(const Key('open-levels')),
  find.byKey(const Key('open-album')),
  find.byKey(const Key('open-themes')),
  find.byType(DailyCard),
  find.byKey(const Key('tool-fill')),
  find.byKey(const Key('tool-cross')),
  find.byKey(const Key('logic-hint')),
  find.byKey(const Key('how-to-play-button')),
];

void _expectInside(Rect r, Size size, String what) {
  expect(r.left, greaterThanOrEqualTo(-0.5), reason: '$what left');
  expect(r.top, greaterThanOrEqualTo(-0.5), reason: '$what top');
  expect(r.right, lessThanOrEqualTo(size.width + 0.5), reason: '$what right');
  expect(
    r.bottom,
    lessThanOrEqualTo(size.height + 0.5),
    reason: '$what bottom',
  );
}

void _expectClear(Rect a, Rect b, String what) {
  final i = a.intersect(b);
  expect(
    i.width <= 0.5 || i.height <= 0.5,
    isTrue,
    reason: 'board overlaps $what: $a vs $b',
  );
}

/// Checks the board against every control; returns the board canvas rect.
Rect _checkScreen(WidgetTester t, Size size) {
  expect(t.takeException(), isNull);
  expect(_canvas, findsOneWidget);
  final board = t.getRect(_canvas);
  _expectInside(board, size, 'board');
  for (final f in _controls()) {
    expect(f.hitTestable(), findsOneWidget, reason: '$f reachable');
    final r = t.getRect(f);
    _expectInside(r, size, '$f');
    _expectClear(board, r, '$f');
  }
  if (_coach.evaluate().isNotEmpty) {
    final r = t.getRect(_coach);
    _expectInside(r, size, 'coach strip');
    _expectClear(board, r, 'coach strip');
  }
  return board;
}

void main() {
  group('screenLayoutFor', () {
    for (final (size, layout) in const [
      (Size(620, 349), ScreenLayout.compact),
      (Size(640, 480), ScreenLayout.compact),
      (Size(600, 338), ScreenLayout.compact),
      (Size(560, 315), ScreenLayout.compact),
      (Size(667, 375), ScreenLayout.compact),
      (Size(844, 390), ScreenLayout.wide),
      (Size(932, 430), ScreenLayout.wide),
      (Size(870, 480), ScreenLayout.wide),
      (Size(1280, 720), ScreenLayout.wide),
      (Size(1366, 768), ScreenLayout.wide),
      (Size(800, 700), ScreenLayout.stacked),
      (Size(360, 640), ScreenLayout.stacked),
      (Size(390, 844), ScreenLayout.stacked),
      (Size(320, 568), ScreenLayout.stacked),
    ]) {
      test('$size is $layout', () => expect(screenLayoutFor(size), layout));
    }
  });

  // Minimum board canvas height (clues + grid) on a 5x5 level 1.
  for (final (size, minBoard) in const [
    (Size(620, 349), 240.0),
    (Size(600, 338), 230.0),
    (Size(560, 315), 210.0),
    (Size(640, 480), 260.0),
    (Size(667, 375), 260.0),
    (Size(844, 390), 300.0),
    (Size(932, 430), 340.0),
    (Size(870, 480), 380.0),
    (Size(360, 640), 280.0),
    (Size(390, 844), 320.0),
    (Size(320, 568), 210.0),
    (Size(1280, 720), 440.0),
    (Size(1366, 768), 440.0),
  ]) {
    testWidgets('board first and controls clear at $size', (t) async {
      await _launch(t, size);
      final board = _checkScreen(t, size);
      expect(board.height, greaterThanOrEqualTo(minBoard));
      // Unscaled: the clue font keeps its 11 px minimum.
      final raw = t.getSize(_canvas);
      expect(board.width, closeTo(raw.width, 0.5));
      expect(board.height, closeTo(raw.height, 0.5));
    });

    testWidgets('first-run tips leave the board playable at $size', (t) async {
      await _launch(t, size, tips: true);
      expect(_coach, findsOneWidget);
      final board = _checkScreen(t, size);
      expect(board.height, greaterThanOrEqualTo(minBoard * 0.75));
      // A tap on the bottom-right cell fills it.
      await t.tap(find.byKey(const Key('tool-fill')));
      await t.pump();
      await t.tapAt(board.bottomRight - const Offset(4, 4));
      await t.pump();
      final game = t.widget<NonoBoard>(find.byType(NonoBoard)).game;
      expect(game.at(game.size - 1, game.size - 1), Mark.filled);
      expect(t.takeException(), isNull);
    });
  }

  // 15x15 boards on short windows: small cells, but nothing overlaps.
  for (final size in const [
    Size(620, 349),
    Size(600, 338),
    Size(560, 315),
    Size(640, 480),
    Size(667, 375),
    Size(844, 390),
    Size(320, 568),
  ]) {
    testWidgets('15x15 board fits at $size', (t) async {
      await _launch(t, size, level: 60, tips: true);
      final game = t.widget<NonoBoard>(find.byType(NonoBoard)).game;
      expect(game.size, 15);
      final board = _checkScreen(t, size);
      expect(board.height, greaterThanOrEqualTo(150));
      // The board box clips nothing: the canvas stays inside it.
      final box = t.getRect(find.byType(NonoBoard));
      expect(box.contains(board.topLeft), isTrue);
      expect(box.contains(board.bottomRight - const Offset(1, 1)), isTrue);
    });
  }

  for (final size in const [Size(620, 349), Size(560, 315)]) {
    testWidgets('overlays open from the compact panel at $size', (t) async {
      await _launch(t, size);
      for (final key in ['open-levels', 'open-album', 'open-themes']) {
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: key);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
      }
      await t.tap(find.byType(DailyCard));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-overlay')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
