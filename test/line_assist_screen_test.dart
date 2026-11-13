import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/game_screen.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<HapticKind>> _launch(WidgetTester t) async {
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({'level': 1});
  final storage = await GameStorage.open(seedSource: () => 1234);
  final pulses = <HapticKind>[];
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: true),
      onHaptic: pulses.add,
    ),
  );
  await t.pump();
  await t.pump();
  return pulses;
}

// Seed 1234 gives the Heart: rows .#.#. / ##### / ##### / .###. / ..#..
Future<void> _fillSolution(WidgetTester t) async {
  const rows = ['.#.#.', '#####', '#####', '.###.', '..#..'];
  for (var r = 0; r < 5; r++) {
    for (var c = 0; c < 5; c++) {
      if (rows[r][c] == '#') await _key(t, LogicalKeyboardKey.space);
      if (c < 4) await _key(t, LogicalKeyboardKey.arrowRight);
    }
    if (r < 4) {
      for (var c = 0; c < 4; c++) {
        await _key(t, LogicalKeyboardKey.arrowLeft);
      }
      await _key(t, LogicalKeyboardKey.arrowDown);
    }
  }
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a finished line pulses lightly and an overfilled line firmly', (
    t,
  ) async {
    final pulses = await _launch(t);
    // Heart row 0 is '.#.#.' (clue 1 1): fill (0,1) and (0,3).
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space);
    expect(pulses, isEmpty);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space);
    expect(pulses, [HapticKind.light]);

    // Row 4 is '..#..' (clue 1): a second fill overfills it.
    for (var i = 0; i < 4; i++) {
      await _key(t, LogicalKeyboardKey.arrowDown);
    }
    await _key(t, LogicalKeyboardKey.space);
    await _key(t, LogicalKeyboardKey.arrowLeft);
    await _key(t, LogicalKeyboardKey.space);
    expect(pulses.last, HapticKind.medium);
  });

  testWidgets('one Undo reverts the fill and the auto-crosses', (t) async {
    final pulses = await _launch(t);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space);
    expect(pulses, [HapticKind.light]);
    await _key(t, LogicalKeyboardKey.keyU);
    // Only the first fill remains, so the line is no longer finished.
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space);
    expect(pulses, [HapticKind.light, HapticKind.light]);
  });

  testWidgets('a win pulses heavily', (t) async {
    final pulses = await _launch(t);
    await _fillSolution(t);
    expect(pulses.last, HapticKind.heavy);
  });

  testWidgets('Check that finds a wrong fill pulses firmly', (t) async {
    final pulses = await _launch(t);
    await _key(t, LogicalKeyboardKey.space); // (0,0) is empty in the Heart
    expect(pulses, isEmpty);
    await t.tap(find.text('Check'));
    await t.pump(const Duration(milliseconds: 50));
    expect(pulses, [HapticKind.medium]);
  });

  testWidgets('muting sound also silences haptics', (t) async {
    final pulses = await _launch(t);
    await t.tap(find.byTooltip('Sound on'));
    await t.pump();
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.space); // finishes row 0
    expect(pulses, isEmpty);
  });
}
