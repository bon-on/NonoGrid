import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/audio/sound_mute_store.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/daily_ui.dart';
import 'package:nono_grid/src/ui/game_screen.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:nono_grid/src/ui/paper_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// feature-large-screen-scale: the wide layout grows with big windows.

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

bool _undoEnabled(WidgetTester t) =>
    t
        .widget<PaperButton>(
          find.ancestor(
            of: find.text('Undo'),
            matching: find.byType(PaperButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  test('scale is 1 up to the design size and capped above it', () {
    expect(wideScaleFor(const Size(1100, 620)), 1);
    expect(wideScaleFor(const Size(1280, 720)), 1);
    expect(wideScaleFor(const Size(1920, 1080)), 1.5);
    expect(wideScaleFor(const Size(2560, 1440)), kMaxWideScale);
    expect(wideScaleFor(const Size(2560, 1080)), 1.5);
  });

  testWidgets('1920x1080 is the 1280x720 layout at 1.5x', (t) async {
    await _launch(t, const Size(1280, 720));
    final small = _checkScreen(t, const Size(1280, 720));
    await _launch(t, const Size(1920, 1080));
    final big = _checkScreen(t, const Size(1920, 1080));
    expect(big.width, closeTo(small.width * 1.5, 1));
    expect(big.left, closeTo(small.left * 1.5, 1));
    expect(big.top, closeTo(small.top * 1.5, 1));
  });

  for (final size in const [
    Size(1100, 620),
    Size(1366, 768),
    Size(1600, 900),
    Size(2560, 1440),
    Size(2560, 1080),
    Size(3440, 1440),
  ]) {
    testWidgets('board and controls fit at $size', (t) async {
      await _launch(t, size);
      _checkScreen(t, size);
    });
  }

  for (final size in const [Size(1280, 720), Size(1100, 620)]) {
    testWidgets('$size keeps its unscaled board', (t) async {
      await _launch(t, size);
      final board = _checkScreen(t, size);
      final raw = t.getSize(_canvas);
      expect(board.width, closeTo(raw.width, 0.5));
      expect(board.height, closeTo(raw.height, 0.5));
    });
  }

  testWidgets('going fullscreen and back keeps the board state', (t) async {
    await _launch(t, const Size(1280, 720));
    final before = t.state(find.byType(NonoBoard));
    for (final size in const [Size(1920, 1080), Size(1100, 620)]) {
      t.view.physicalSize = size;
      await t.pump();
      expect(identical(t.state(find.byType(NonoBoard)), before), isTrue);
    }
  });

  NonoGame game(WidgetTester t) =>
      t.widget<NonoBoard>(find.byType(NonoBoard)).game;

  testWidgets('tap, drag and right click hit the cells under the pointer', (
    t,
  ) async {
    await _launch(t, const Size(1920, 1080));
    final n = game(t).size;
    final before = [for (var i = 0; i < n * n; i++) game(t).cells[i]];
    final board = t.getRect(_canvas);
    // The grid is the bottom-right square of the canvas.
    final corner = board.bottomRight - const Offset(8, 8);

    // A tap fills the last cell.
    await t.tapAt(corner);
    await t.pump();
    expect(game(t).at(n - 1, n - 1), Mark.filled);
    expect(_undoEnabled(t), isTrue);
    await t.tap(find.text('Undo'));
    await t.pump();
    expect(game(t).at(n - 1, n - 1), before[n * n - 1]);

    // A drag left along the last row fills a run of cells ending at the
    // last column and touches no other row.
    final g = await t.startGesture(corner);
    await t.pump();
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(corner - Offset(i * board.width * 0.02, 0));
      await t.pump();
    }
    await g.up();
    await t.pump();
    final row = [for (var c = 0; c < n; c++) game(t).at(n - 1, c)];
    expect(row[n - 1], Mark.filled);
    expect(row[n - 2], Mark.filled);
    final first = row.indexOf(Mark.filled);
    expect(row.sublist(first).every((m) => m == Mark.filled), isTrue);
    for (var r = 0; r < n - 1; r++) {
      for (var c = 0; c < n; c++) {
        expect(game(t).at(r, c), before[r * n + c], reason: 'cell $r,$c');
      }
    }

    // A right click crosses the last cell of the row above.
    // One cell is a little under board.height / n (the clue header takes the
    // rest), so 0.9 of that lands in the row above.
    final above = corner - Offset(0, board.height / n * 0.9);
    final r = await t.startGesture(
      above,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await r.up();
    await t.pump();
    expect(game(t).at(n - 2, n - 1), isNot(before[(n - 2) * n + n - 1]));
    expect(game(t).at(n - 2, n - 1), Mark.crossed);
  });
}
