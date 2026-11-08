import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/art/picture_thumb.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/collection.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameStorage> _launch(
  WidgetTester t, {
  Size size = const Size(1280, 720),
  required Map<String, Object> prefs,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await GameStorage.open();
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: true),
      clock: () => DateTime(2026, 11, 8, 12),
    ),
  );
  await t.pump();
  await t.pump();
  return storage;
}

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

void main() {
  testWidgets('album shows set progress and Enter plays the goal', (t) async {
    await _launch(t, prefs: {'level': 1, 'maxCleared': 7});
    await t.tap(find.byKey(const Key('open-album')));
    await t.pumpAndSettle();
    expect(find.text('Set 1: Sketchbook'), findsOneWidget);
    expect(find.text('7/10'), findsOneWidget);
    expect(
      find.text('Next: Level 8 - 3 more to complete Sketchbook (+50 XP)'),
      findsOneWidget,
    );
    // Unsolved tiles never show a picture: only the solved ones are thumbs.
    expect(find.byType(PictureThumb), findsNWidgets(7));
    expect(find.text('#8'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('album')), findsNothing);
    expect(find.text('Level 8'), findsOneWidget);
  });

  testWidgets('finishing a set shows the bonus on the summary', (t) async {
    final storage = await _launch(t, prefs: {'level': 10, 'maxCleared': 9});
    expect(find.text('Level 10'), findsOneWidget);
    final xpBefore = storage.xp;
    await _solve(t, storage.puzzleFor(10));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-summary')), findsOneWidget);
    expect(find.text('Set complete: Sketchbook  +50 XP'), findsOneWidget);
    expect(
      find.text('Next: Level 11 - 10 more to complete Garden (+50 XP)'),
      findsOneWidget,
    );
    expect(storage.xp - xpBefore, greaterThan(kSetBonusXp));
    await t.tap(find.text('Album').last);
    await t.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Set 2: Garden'), findsOneWidget);
  });

  for (final size in const [
    Size(390, 844),
    Size(1280, 720),
    Size(1366, 768),
    Size(844, 390),
  ]) {
    testWidgets('album with several sets fits $size', (t) async {
      await _launch(t, size: size, prefs: {'level': 1, 'maxCleared': 34});
      // Short landscape panels scroll to their meta buttons.
      await t.ensureVisible(find.byKey(const Key('open-album')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('open-album')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final card = t.getRect(find.byKey(const Key('album')));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(size.height));
      final goal = t.getRect(find.byKey(const Key('album-goal')));
      expect(goal.bottom, lessThanOrEqualTo(size.height));
      expect(find.byKey(const Key('album-set-0')), findsOneWidget);
    });
  }
}
