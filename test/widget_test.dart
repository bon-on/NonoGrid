import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

MemoryTutorialStore seen() => MemoryTutorialStore(seen: true);

void main() {
  Future<GameStorage> storage([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return GameStorage.open();
  }

  for (final size in const [Size(390, 844), Size(1280, 720)]) {
    testWidgets('renders level 1 without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        NonoGridApp(storage: await storage(), tutorialStore: seen()),
      );
      await tester.pump();
      expect(find.text('NonoGrid'), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byType(NonoBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('15x15 board with two-digit clues fits at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Level 50 is 15x15 and has a two-digit clue (12).
      await tester.pumpWidget(
        NonoGridApp(
          storage: await storage({'level': 50, 'maxCleared': 49}),
          tutorialStore: seen(),
        ),
      );
      await tester.pump();
      expect(find.text('Level 50'), findsOneWidget);
      final paint = find.descendant(
        of: find.byType(NonoBoard),
        matching: find.byType(CustomPaint),
      );
      final rect = tester.getRect(paint.first);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a cell starts the game and saves progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await storage();
    await tester.pumpWidget(NonoGridApp(storage: s, tutorialStore: seen()));
    await tester.pump();
    final paint = find.descendant(
      of: find.byType(NonoBoard),
      matching: find.byType(CustomPaint),
    );
    final box = tester.getRect(paint.first);
    // Bottom-right cell of the grid.
    await tester.tapAt(box.bottomRight - const Offset(10, 10));
    await tester.pump();
    expect(s.progress?.cells, '${'.' * 24}#');
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('restores saved level and progress', (tester) async {
    final s = await storage({
      'level': 2,
      'maxCleared': 1,
      'progressLevel': 2,
      'progressCells': '#${'.' * 24}',
      'progressElapsed': 65,
    });
    await tester.pumpWidget(NonoGridApp(storage: s, tutorialStore: seen()));
    await tester.pump();
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('solving with the keyboard wins and unlocks the next level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await storage({'level': 1});
    await tester.pumpWidget(NonoGridApp(storage: s, tutorialStore: seen()));
    await tester.pump();
    final p = puzzleForLevel(1);
    var cr = 0, cc = 0;
    for (var r = 0; r < p.size; r++) {
      for (var c = 0; c < p.size; c++) {
        if (!p.filledAt(r, c)) continue;
        while (cr < r) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          cr++;
        }
        while (cc < c) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          cc++;
        }
        while (cc > c) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          cc--;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
      }
    }
    await tester.pumpAndSettle();
    expect(find.textContaining('Heart! Solved in'), findsOneWidget);
    expect(s.maxCleared, 1);
    expect(s.bestSeconds(1), isNotNull);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
  });
}
