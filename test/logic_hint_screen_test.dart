import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 720)]) {
    for (final mistake in [false, true]) {
      testWidgets(
        'preview/apply/undo preserves stars and resume at $size ($mistake)',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          SharedPreferences.setMockInitialValues({'level': 1});
          final storage = await GameStorage.open();
          await storage.saveProgress(
            SavedProgress(1, '.' * 25, 10, mistakes: mistake),
          );
          await t.pumpWidget(
            NonoGridApp(
              storage: storage,
              tutorialStore: MemoryTutorialStore(seen: true),
            ),
          );
          await t.pump();
          final game = t.widget<NonoBoard>(find.byType(NonoBoard)).game;
          final before = game.encode();
          final puzzle = game.puzzle.solution.toList();
          await t.tap(find.byKey(const Key('logic-hint')));
          await t.pump();
          expect(find.textContaining('every placement'), findsOneWidget);
          expect(find.textContaining('do not cost stars'), findsOneWidget);
          expect(game.encode(), before);
          expect(storage.progress!.mistakes, mistake);
          await t.pump(const Duration(seconds: 5));
          await t.tap(find.text('Close'));
          await t.pump();
          expect(game.encode(), before);
          await t.tap(find.byKey(const Key('logic-hint')));
          await t.pump();
          await t.tap(find.byKey(const Key('apply-logic-hint')));
          await t.pump();
          expect(game.cells.where((m) => m != Mark.empty).length, 1);
          expect(storage.progress!.cells, game.encode());
          expect(storage.progress!.mistakes, mistake);
          expect(storage.progress!.elapsedSeconds, lessThan(12));
          final reopened = await GameStorage.open();
          expect(reopened.progress!.cells, game.encode());
          expect(reopened.puzzleFor(1).solution, puzzle);
          await t.tap(find.text('Undo'));
          await t.pump();
          expect(game.encode(), before);
          expect(storage.progress!.mistakes, mistake);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
