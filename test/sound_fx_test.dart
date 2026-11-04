import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/main.dart';
import 'package:nono_grid/src/audio/sound_fx.dart';
import 'package:nono_grid/src/audio/sound_mute_store.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/platform/game_platform.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:nono_grid/src/ui/board.dart';
import 'package:nono_grid/src/ui/how_to_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryMuteStore extends SoundMuteStore {
  _MemoryMuteStore({this.muted = false});
  bool muted;
  @override
  Future<bool> loadMuted() async => muted;
  @override
  Future<void> saveMuted(bool value) async => muted = value;
}

class _ThrowingMuteStore extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => throw StateError('no prefs');
  @override
  Future<void> saveMuted(bool value) async => throw StateError('disk full');
}

class _MutedPlatform extends GamePlatform {
  bool mute = true;
  @override
  bool get isAudioMuted => mute;
  @override
  Future<void> initialize() async {}
  @override
  void gameplayStart() {}
  @override
  void gameplayStop() {}
}

Future<List<Sfx>> _launch(
  WidgetTester t, {
  SoundMuteStore? store,
  GamePlatform platform = const NoopGamePlatform(),
}) async {
  t.view.physicalSize = const Size(1280, 720);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({'level': 1});
  final storage = await GameStorage.open();
  final played = <Sfx>[];
  await t.pumpWidget(
    NonoGridApp(
      storage: storage,
      tutorialStore: MemoryTutorialStore(seen: true),
      platform: platform,
      soundMuteStore: store ?? _MemoryMuteStore(),
      onSfxPlayed: played.add,
    ),
  );
  await t.pump();
  await t.pump();
  return played;
}

void main() {
  test('every Sfx asset exists on disk and is covered by pubspec', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/audio/'),
    );
    for (final sfx in Sfx.values) {
      expect(File(sfx.assetKey).existsSync(), isTrue, reason: sfx.assetKey);
    }
  });

  test('SoundFx is silent while muted and never throws', () {
    var muted = true;
    final played = <Sfx>[];
    final fx = SoundFx(isMuted: () => muted, onPlay: played.add);
    fx.play(Sfx.fill);
    expect(played, isEmpty);
    muted = false;
    fx.play(Sfx.fill);
    expect(played, [Sfx.fill]);
    fx.dispose();
  });

  testWidgets('toggle flips icon, tooltip and persists', (t) async {
    final store = _MemoryMuteStore();
    await _launch(t, store: store);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byTooltip('Sound on'), findsOneWidget);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.byTooltip('Sound off'), findsOneWidget);
    expect(store.muted, isTrue);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    expect(store.muted, isFalse);
  });

  testWidgets('persisted mute is loaded on launch', (t) async {
    await _launch(t, store: _MemoryMuteStore(muted: true));
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  testWidgets('user mute silences input, unmute restores it', (t) async {
    final played = await _launch(t, store: _MemoryMuteStore(muted: true));
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(played, isEmpty);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(played, [Sfx.fill]);
  });

  testWidgets('platform mute silences input', (t) async {
    final platform = _MutedPlatform();
    final played = await _launch(t, platform: platform);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(played, isEmpty);
    platform.mute = false;
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    expect(played, [Sfx.mark]);
  });

  testWidgets('hook points: fill, mark, undo, level_clear', (t) async {
    final played = await _launch(t);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(
      LogicalKeyboardKey.space,
    ); // toggles off: still a change
    await t.sendKeyEvent(LogicalKeyboardKey.keyX);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    expect(played, [Sfx.fill, Sfx.fill, Sfx.mark, Sfx.undo]);
    played.clear();
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    expect(played, [Sfx.undo, Sfx.undo]); // nothing left to undo: silent
    played.clear();
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    expect(played, isEmpty);

    // Solve level 1 with the keyboard.
    final p = puzzleForLevel(1);
    var cr = 0, cc = 0;
    var fills = 0;
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
        fills++;
      }
    }
    expect(played.where((s) => s == Sfx.fill).length, fills - 1);
    expect(played.last, Sfx.levelClear);
    expect(played.where((s) => s == Sfx.levelClear).length, 1);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('storage failure keeps sound on', (t) async {
    final played = await _launch(t, store: _ThrowingMuteStore());
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    await t.tap(find.byKey(const Key('sound-toggle')));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(played, [Sfx.fill]);
  });

  testWidgets('a drag stroke plays one fill sound at its end', (t) async {
    final played = await _launch(t);
    final paint = find.descendant(
      of: find.byType(NonoBoard),
      matching: find.byType(CustomPaint),
    );
    final box = t.getRect(paint.first);
    final start = box.bottomRight - const Offset(10, 10);
    final g = await t.startGesture(start);
    await g.moveBy(const Offset(-40, 0));
    await g.moveBy(const Offset(-40, 0));
    await g.moveBy(const Offset(-40, 0));
    expect(played, isEmpty);
    await g.up();
    await t.pump();
    // Row 5 of the Heart has clue 1, so a three-cell stroke overfills it and
    // adds the mistake cue after the one fill sound.
    expect(played, [Sfx.fill, Sfx.mistake]);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('undo pressed during the winning stroke plays level_clear once', (
    t,
  ) async {
    final played = await _launch(t);
    final p = puzzleForLevel(1);
    final n = p.size;
    var lr = -1, lc = -1;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (p.filledAt(r, c)) {
          lr = r;
          lc = c;
        }
      }
    }
    var cr = 0, cc = 0;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (!p.filledAt(r, c) || (r == lr && c == lc)) continue;
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
    played.clear();
    final paint = find.descendant(
      of: find.byType(NonoBoard),
      matching: find.byType(CustomPaint),
    );
    final box = t.getRect(paint.first);
    // The grid is the bottom-right n x n square of the board paint.
    final lb = t.getSize(
      find
          .descendant(
            of: find.byType(NonoBoard),
            matching: find.byType(LayoutBuilder),
          )
          .first,
    );
    final cl = p.clues;
    var md = 1;
    for (final line in [...cl.rows, ...cl.cols]) {
      for (final v in line) {
        if (v >= 10) md = 2;
      }
    }
    final m = BoardMetrics.fit(
      n: n,
      rowSlots: cl.maxRowClueCount,
      colSlots: cl.maxColClueCount,
      maxDigits: md,
      space: lb,
    );
    final pos =
        box.bottomRight -
        Offset((n - lc - 0.5) * m.cell, (n - lr - 0.5) * m.cell);
    final g = await t.startGesture(pos);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.keyU);
    await g.up();
    await t.pump();
    expect(played, [Sfx.levelClear]);
    await t.pump(const Duration(seconds: 3));
  });
}
