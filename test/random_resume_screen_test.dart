import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/art/picture_thumb.dart';
import 'package:nono_grid/src/audio/sound_mute_store.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Muted extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => true;
}

Future<void> launch(WidgetTester t, GameStorage s) async {
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    NonoGridApp(
      storage: s,
      tutorialStore: MemoryTutorialStore(seen: true),
      soundMuteStore: _Muted(),
    ),
  );
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets(
    'random assignment restarts unchanged and resumes after closing',
    (t) async {
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 12345);
      await launch(t, s);
      final solution = t
          .widget<NonoBoard>(find.byType(NonoBoard))
          .game
          .puzzle
          .solution;
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(s.progress, isNotNull);
      final marks = s.progress!.cells;
      await t.pumpWidget(const SizedBox());
      await t.pump();
      final reopened = await GameStorage.open(seedSource: () => 99999);
      await launch(t, reopened);
      var board = t.widget<NonoBoard>(find.byType(NonoBoard));
      expect(board.game.puzzle.solution, solution);
      expect(board.game.encode(), marks);
      await t.sendKeyEvent(LogicalKeyboardKey.keyR);
      await t.pump();
      board = t.widget<NonoBoard>(find.byType(NonoBoard));
      expect(board.game.puzzle.solution, solution);
      expect(board.game.cells.every((e) => e.name == 'empty'), isTrue);
    },
  );

  testWidgets('random solve shows its actual picture and reopen advances', (
    t,
  ) async {
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = await GameStorage.open(seedSource: () => 12345);
    await launch(t, s);
    final p = t.widget<NonoBoard>(find.byType(NonoBoard)).game.puzzle;
    var row = 0, col = 0;
    for (var r = 0; r < p.size; r++) {
      for (var c = 0; c < p.size; c++) {
        if (!p.filledAt(r, c)) continue;
        while (row < r) {
          await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          row++;
        }
        while (col < c) {
          await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          col++;
        }
        while (col > c) {
          await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          col--;
        }
        await t.sendKeyEvent(LogicalKeyboardKey.space);
      }
    }
    await t.pumpAndSettle();
    expect(s.stars(1), greaterThan(0));
    expect(
      t.widget<PictureThumb>(find.byType(PictureThumb).first).puzzle!.solution,
      p.solution,
    );
    await t.tap(find.text('Album').last);
    await t.pumpAndSettle();
    expect(
      t.widget<PictureThumb>(find.byType(PictureThumb).first).puzzle!.solution,
      p.solution,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump();
    final reopened = await GameStorage.open(seedSource: () => 98765);
    await launch(t, reopened);
    expect(find.text('Level 2'), findsOneWidget);
    expect(
      t.widget<NonoBoard>(find.byType(NonoBoard)).game.puzzle.solution,
      reopened.puzzleFor(2).solution,
    );
  });
}
