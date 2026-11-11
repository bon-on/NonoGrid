import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/art/desk_scenery.dart';
import 'package:nono_grid/src/art/paper_palette.dart';
import 'package:nono_grid/src/art/picture_thumb.dart';
import 'package:nono_grid/src/audio/sound_fx.dart';
import 'package:nono_grid/src/audio/sound_mute_store.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/progress_rules.dart';
import 'package:nono_grid/src/platform/game_platform.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/board_fx.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MutedStore extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => true;
  @override
  Future<void> saveMuted(bool value) async {}
}

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
  // These tests exercise the historical Heart/Arrow fixtures.
  SharedPreferences.setMockInitialValues({'level': 1, ...prefs});
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
    Size(667, 375),
    Size(320, 640),
    Size(620, 349),
    Size(560, 315),
    Size(640, 480),
    Size(320, 568),
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

  for (final (size, wide) in const [
    (Size(390, 844), false),
    (Size(360, 640), false),
    (Size(320, 640), false),
    (Size(800, 700), false),
    (Size(844, 390), true),
    (Size(1280, 720), true),
  ]) {
    testWidgets('desk props only beside side panels at $size', (t) async {
      await _launch(t, size: size);
      final desk = t.widget<DeskScenery>(find.byType(DeskScenery));
      expect(
        desk.showProps,
        wide,
        reason: 'stacked layouts keep props out from under the controls',
      );
    });
  }

  for (final size in const [Size(844, 390), Size(1280, 720), Size(1366, 768)]) {
    testWidgets('tool panel hint is never clipped at $size', (t) async {
      await _launch(t, size: size);
      final hint = find.byKey(const Key('panel-hint'));
      if (size.height < 500) {
        expect(hint, findsNothing, reason: 'short panels drop the hint');
      } else {
        expect(hint, findsOneWidget);
        final text = t.renderObject<RenderParagraph>(
          find.descendant(of: hint, matching: find.byType(RichText)),
        );
        expect(text.didExceedMaxLines, isFalse);
      }
      // Every tool-panel control stays inside the screen.
      for (final f in [
        find.text('Restart'),
        find.byKey(const Key('sound-toggle')),
      ]) {
        expect(
          t.getRect(f).bottom,
          lessThanOrEqualTo(size.height),
          reason: '$f',
        );
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

  testWidgets('overlays pause the clock and resume it on close', (t) async {
    // The clock is a real Stopwatch, so real time has to pass.
    Future<void> wait(int ms) async {
      await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await t.pump(const Duration(milliseconds: 600));
    }

    await _launch(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await wait(1100);
    expect(find.text('0:01'), findsOneWidget);
    await t.tap(find.byKey(const Key('open-album')));
    await t.pump();
    await wait(1200);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.text('0:01'), findsOneWidget, reason: 'paused while open');
    await wait(1100);
    expect(find.text('0:02'), findsOneWidget, reason: 'resumed on close');
  });

  testWidgets('opening a level from the map starts a fresh clock', (t) async {
    await _launch(t, prefs: {'maxCleared': 2});
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await t.tap(find.byKey(const Key('open-levels')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('map-node-2')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget, reason: 'no move yet');
  });

  testWidgets('restart during the bloom opens no summary', (t) async {
    await _launch(t);
    await _solveLevel1(t);
    await t.pump(const Duration(milliseconds: 300));
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-summary')), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('an overlay opened during the bloom defers the summary', (
    t,
  ) async {
    await _launch(t);
    await _solveLevel1(t);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const Key('open-album')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-summary')), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('level-summary')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('level-summary')),
      findsNothing,
      reason: 'Esc keeps it closed',
    );
  });

  testWidgets('a saved mute keeps native music from ever starting', (t) async {
    const channel = MethodChannel('nono_grid/audio');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = await GameStorage.open();
    await t.pumpWidget(
      NonoGridApp(
        storage: storage,
        tutorialStore: MemoryTutorialStore(seen: true),
        soundMuteStore: _MutedStore(),
      ),
    );
    await t.pump();
    await t.pump();
    expect(calls, isNot(contains('startLoop')));
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    expect(calls, contains('startLoop'));
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
