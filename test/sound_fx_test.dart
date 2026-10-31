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
  SharedPreferences.setMockInitialValues({});
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
}
