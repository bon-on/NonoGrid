import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/art/desk_scenery.dart';
import 'package:nono_grid/src/art/paper_palette.dart';
import 'package:nono_grid/src/art/picture_thumb.dart';
import 'package:nono_grid/src/audio/sound_fx.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/progress_rules.dart';
import 'package:nono_grid/src/platform/game_platform.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/board_fx.dart';
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

Future<(GameStorage, _FakePlatform, List<Sfx>)> _launch(
  WidgetTester t, {
  Size size = const Size(1280, 720),
  Map<String, Object> prefs = const {},
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await GameStorage.open();
  final platform = _FakePlatform();
  final played = <Sfx>[];
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: true),
      platform: platform,
      onSfxPlayed: played.add,
    ),
  );
  await t.pump();
  await t.pump();
  return (storage, platform, played);
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
}

void main() {
  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(390, 844),
    Size(844, 390),
    Size(320, 640),
  ]) {
    testWidgets('main screen and summary fit $size', (t) async {
      await _launch(t, size: size);
      expect(find.byType(NonoBoard), findsOneWidget);
      expect(find.byKey(const Key('open-levels')), findsOneWidget);
      expect(t.takeException(), isNull);
      await _solveLevel1(t);
      await t.pumpAndSettle();
      final card = find.byKey(const Key('level-summary'));
      expect(card, findsOneWidget);
      final r = t.getRect(card);
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(size.height));
      expect(t.takeException(), isNull);
      for (final key in ['open-levels', 'open-album', 'open-themes']) {
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: key);
      }
    });
  }

  testWidgets('win shows summary with stars, XP and Enter goes next', (
    t,
  ) async {
    final (storage, platform, played) = await _launch(t);
    await _solveLevel1(t);
    expect(played.last, Sfx.levelClear);
    expect(
      find.byKey(const Key('level-summary')),
      findsNothing,
      reason: 'the picture blooms first',
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-summary')), findsOneWidget);
    expect(find.text('New best!'), findsOneWidget);
    expect(find.textContaining('XP'), findsWidgets);
    expect(storage.stars(1), 3);
    expect(storage.xp, 25);
    expect(played.where((s) => s == Sfx.star).length, 3);
    // Board input is blocked while the summary is open.
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    expect(platform.events, ['start', 'stop']);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.byKey(const Key('level-summary')), findsNothing);
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('Esc closes the summary and keeps the Next bar', (t) async {
    await _launch(t);
    await _solveLevel1(t);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byKey(const Key('level-summary')), findsNothing);
    expect(find.textContaining('Heart! Solved in'), findsOneWidget);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('Check finding a wrong cell costs the second star', (t) async {
    final (storage, _, played) = await _launch(t);
    // (0,0) is empty in the Heart: fill it, Check, then clear it again.
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.tap(find.text('Check'));
    await t.pump();
    expect(played, contains(Sfx.mistake));
    expect(storage.progress?.mistakes, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await _solveLevel1(t);
    await t.pumpAndSettle();
    expect(storage.stars(1), 2);
  });

  testWidgets('a completed line plays its chime with the fill', (t) async {
    final (_, _, played) = await _launch(t);
    // Row 5 of the Heart is "..#..": fill (4,2).
    for (var i = 0; i < 4; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(played, [Sfx.fill, Sfx.lineDone]);
    await t.pumpAndSettle();
  });

  testWidgets('level map: locked levels cannot open, Enter opens', (t) async {
    final (storage, platform, _) = await _launch(
      t,
      prefs: {'level': 1, 'maxCleared': 2},
    );
    await t.tap(find.byKey(const Key('open-levels')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-map')), findsOneWidget);
    expect(platform.events.last, 'stop');
    await t.tap(find.byKey(const Key('map-node-5')));
    await t.pump();
    expect(find.byKey(const Key('level-map')), findsOneWidget);
    // Arrows clamp at the newest unlocked level (3).
    for (var i = 0; i < 5; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-map')), findsNothing);
    expect(find.text('Level 3'), findsOneWidget);
    expect(storage.level, 3);
    expect(platform.events.last, 'start');
  });

  testWidgets('album lists solved pictures only', (t) async {
    await _launch(t, prefs: {'maxCleared': 2});
    await t.tap(find.byKey(const Key('open-album')));
    await t.pumpAndSettle();
    expect(find.text('2 pictures collected'), findsOneWidget);
    expect(find.text('Heart'), findsOneWidget);
    expect(find.text('Arrow'), findsOneWidget);
    expect(find.text('House'), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byKey(const Key('album')), findsNothing);
  });

  testWidgets('themes: locked cannot be picked, unlocked persists', (t) async {
    final (storage, _, _) = await _launch(
      t,
      prefs: {
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 1,
          'maxCleared': 0,
          'xp': 100,
        }),
      },
    );
    expect(storage.painterLevel.level, 3);
    await t.tap(find.byKey(const Key('open-themes')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('theme-washi')));
    await t.pump();
    expect(storage.theme, NonoTheme.notebook);
    await t.tap(find.byKey(const Key('theme-kraft')));
    await t.pump();
    expect(storage.theme, NonoTheme.kraft);
    // Keyboard: right moves to Washi (locked), Enter does nothing.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(storage.theme, NonoTheme.kraft);
    final prefs = await SharedPreferences.getInstance();
    expect(GameStorage.fromPrefs(prefs).theme, NonoTheme.kraft);
  });

  testWidgets('v1 saves migrate into the screen', (t) async {
    final (storage, _, _) = await _launch(
      t,
      prefs: {
        'level': 3,
        'maxCleared': 2,
        'best_1': 14,
        'progressLevel': 3,
        'progressCells': '#${'.' * 24}',
        'progressElapsed': 65,
      },
    );
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(storage.stars(1), 1);
  });

  for (final theme in NonoTheme.values) {
    testWidgets('art paints every mark and effect in ${theme.label}', (
      t,
    ) async {
      final palette = PaperPalette.of(theme);
      final game = NonoGame(puzzleForLevel(4));
      game.tap(0, 0, Tool.fill);
      game.tap(0, 1, Tool.cross);
      game.tap(1, 1, Tool.fill);
      final fx = BoardFx()
        ..cellChanged(0, Mark.empty, Mark.filled)
        ..cellChanged(2, Mark.filled, Mark.empty)
        ..lineDone(true, 0)
        ..lineError(false, 1)
        ..shake()
        ..confetti();
      fx.tick(const Duration(milliseconds: 100));
      for (final reveal in [0.0, 0.5, 1.0]) {
        await t.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                Positioned.fill(child: DeskScenery(palette: palette)),
                Center(
                  child: SizedBox(
                    width: 400,
                    height: 400,
                    child: NonoBoard(
                      game: game,
                      tool: Tool.fill,
                      cursor: (1, 1),
                      showCursor: true,
                      reveal: AlwaysStoppedAnimation(reveal),
                      palette: palette,
                      picture: PicturePalette.forLevel(4),
                      mistakes: const {4},
                      fx: fx,
                      onStrokeStart: (_, _, _) {},
                      onStrokeMove: (_, _) {},
                      onStrokeEnd: () {},
                    ),
                  ),
                ),
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: PictureThumb(level: 4),
                ),
              ],
            ),
          ),
        );
        expect(t.takeException(), isNull);
      }
      fx.dispose();
    });
  }
}
