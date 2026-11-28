// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/platform/crazygames_prefs_store.dart';
import 'package:nono_grid/src/platform/gamepix_platform.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Installs a fake `window.GamePix` (SDK v3) and records the calls it gets.
class _FakeGamePix {
  _FakeGamePix({this.adSuccess = true, this.loaded, this.adResult}) {
    final lifecycle = JSObject()
      ..setProperty(
        'loaded'.toJS,
        (() {
          calls.add('loaded');
          return (loaded ?? Future<JSAny?>.value()).toJS;
        }).toJS,
      )
      ..setProperty('gameStart'.toJS, (() => calls.add('gameStart')).toJS);
    final events = JSObject()
      ..setProperty(
        'on'.toJS,
        ((JSString name, JSFunction callback) {
          handlers[name.toDart] = callback;
        }).toJS,
      );
    JSPromise<JSAny?> ad(String kind) {
      calls.add(kind);
      handlers['pause']?.callAsFunction();
      mutedDuringAd = platformMuted?.call();
      handlers['resume']?.callAsFunction();
      final custom = adResult;
      if (custom != null) return custom().toJS;
      return Future<JSAny?>.value(
        JSObject()..setProperty('success'.toJS, adSuccess.toJS),
      ).toJS;
    }

    final ads = JSObject()
      ..setProperty('interstitial'.toJS, (() => ad('interstitial')).toJS);
    globalContext.setProperty(
      'GamePix'.toJS,
      JSObject()
        ..setProperty('lifecycle'.toJS, lifecycle)
        ..setProperty('events'.toJS, events)
        ..setProperty('ads'.toJS, ads),
    );
  }

  final bool adSuccess;
  final Future<JSAny?>? loaded;
  final Future<JSAny?> Function()? adResult;
  final List<String> calls = <String>[];
  final Map<String, JSFunction> handlers = <String, JSFunction>{};
  bool Function()? platformMuted;
  bool? mutedDuringAd;
}

const String _saveKey = 'nonogrid.prefs_v1';

JSObject get _localStorage =>
    globalContext.getProperty<JSObject>('localStorage'.toJS);

void main() {
  var clock = DateTime(2026, 11, 28, 12);
  GamePixPlatform newPlatform({
    Future<void> Function()? firstFrame,
    Duration adTimeout = const Duration(seconds: 120),
  }) => GamePixPlatform(
    firstFrame: firstFrame ?? () async {},
    now: () => clock,
    adTimeout: adTimeout,
  );

  setUp(() {
    clock = DateTime(2026, 11, 28, 12);
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    _localStorage.callMethod<JSAny?>('removeItem'.toJS, _saveKey.toJS);
  });
  tearDown(() => globalContext.delete('GamePix'.toJS));

  test('missing SDK falls back to no-op behaviour', () async {
    final platform = newPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(platform.showsRunBreakAds, isFalse);
    await platform.showRunBreakAd();
    expect(platform.isAudioMuted, isFalse);
    expect(platform.allowsResultRegistration, isFalse);
  });

  test('sends loaded after the first frame and gameStart after it', () async {
    final sdk = _FakeGamePix();
    final platform = newPlatform();
    await platform.initialize();
    platform.gameplayStart();
    await Future<void>.delayed(Duration.zero);

    expect(sdk.calls, <String>['loaded', 'gameStart']);
    expect(sdk.handlers.keys, containsAll(<String>['pause', 'resume']));
  });

  test(
    'a Player that never answers loaded() does not block ads',
    () async {
      final sdk = _FakeGamePix(loaded: Completer<JSAny?>().future);
      final platform = newPlatform();
      await platform.initialize();
      clock = clock.add(GamePixPlatform.adCooldown);

      await platform.showRunBreakAd();
      expect(sdk.calls, <String>['loaded', 'interstitial']);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('pause mutes audio and resume restores it', () async {
    final sdk = _FakeGamePix();
    final platform = newPlatform();
    var changes = 0;
    platform.setAudioMuteListener(() => changes++);
    await platform.initialize();

    sdk.handlers['pause']!.callAsFunction();
    expect(platform.isAudioMuted, isTrue);
    sdk.handlers['pause']!.callAsFunction();
    sdk.handlers['resume']!.callAsFunction();
    expect(platform.isAudioMuted, isFalse);
    expect(changes, 2);
  });

  test('pause and resume reach the pause listener once each', () async {
    final sdk = _FakeGamePix();
    final platform = newPlatform();
    final events = <bool>[];
    platform.setPauseListener(events.add);
    await platform.initialize();

    sdk.handlers['pause']!.callAsFunction();
    sdk.handlers['pause']!.callAsFunction();
    sdk.handlers['resume']!.callAsFunction();
    expect(events, <bool>[true, false]);
  });

  test('the first run break may show an ad, then the cooldown holds', () async {
    final sdk = _FakeGamePix();
    final platform = newPlatform();
    sdk.platformMuted = () => platform.isAudioMuted;
    await platform.initialize();

    await platform.showRunBreakAd();
    expect(sdk.calls.where((c) => c == 'interstitial'), hasLength(1));
    expect(sdk.mutedDuringAd, isTrue);
    expect(platform.isAudioMuted, isFalse);

    clock = clock.add(const Duration(seconds: 30));
    await platform.showRunBreakAd();
    expect(sdk.calls.where((c) => c == 'interstitial'), hasLength(1));

    clock = clock.add(GamePixPlatform.adCooldown);
    await platform.showRunBreakAd();
    expect(sdk.calls.where((c) => c == 'interstitial'), hasLength(2));
  });

  test('the legacy GamePix.soundOff/soundOn functions are declared', () async {
    _FakeGamePix();
    final platform = newPlatform();
    await platform.initialize();
    final sdk = globalContext.getProperty<JSObject>('GamePix'.toJS);

    sdk.getProperty<JSFunction>('soundOff'.toJS).callAsFunction();
    expect(platform.isAudioMuted, isTrue);
    sdk.getProperty<JSFunction>('soundOn'.toJS).callAsFunction();
    expect(platform.isAudioMuted, isFalse);
  });

  test('the Player sound off and on mute and restore audio', () async {
    final sdk = _FakeGamePix();
    final platform = newPlatform();
    var changes = 0;
    platform.setAudioMuteListener(() => changes++);
    await platform.initialize();

    sdk.handlers['soundOff']!.callAsFunction();
    expect(platform.isAudioMuted, isTrue);
    sdk.handlers['soundOn']!.callAsFunction();
    expect(platform.isAudioMuted, isFalse);
    expect(changes, 2);
  });

  test('an unfilled interstitial still lets the game go on', () async {
    final sdk = _FakeGamePix(adSuccess: false);
    final platform = newPlatform();
    await platform.initialize();
    clock = clock.add(GamePixPlatform.adCooldown);

    await platform.showRunBreakAd();
    expect(sdk.calls, contains('interstitial'));
    expect(platform.isAudioMuted, isFalse);
  });

  test('preferences live in one named localStorage item', () async {
    _localStorage.callMethod<JSAny?>(
      'setItem'.toJS,
      _saveKey.toJS,
      '{"rev":4,"owner":null,"values":{"flutter.best":42}}'.toJS,
    );
    await newPlatform().initialize();

    final store = SharedPreferencesStorePlatform.instance;
    expect(store, isA<CloudPrefsStore>());
    expect(await store.getAll(), <String, Object>{'flutter.best': 42});
    await store.setValue('Int', 'flutter.best', 50);
    final saved = _localStorage
        .callMethod<JSString?>('getItem'.toJS, _saveKey.toJS)
        ?.toDart;
    expect(saved, '{"rev":5,"owner":null,"values":{"flutter.best":50}}');
  });

  test('first GamePix session keeps progress saved before the SDK', () async {
    final local = InMemorySharedPreferencesStore.withData(<String, Object>{
      'flutter.best': 7,
    });
    SharedPreferencesStorePlatform.instance = local;
    await newPlatform().initialize();

    expect(
      await SharedPreferencesStorePlatform.instance.getAll(),
      <String, Object>{'flutter.best': 7},
    );
  });

  test('loaded() waits for the first frame', () async {
    final sdk = _FakeGamePix();
    final frame = Completer<void>();
    final platform = newPlatform(firstFrame: () => frame.future);
    await platform.initialize();
    platform.gameplayStart();
    await Future<void>.delayed(Duration.zero);
    expect(sdk.calls, isEmpty);

    frame.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(sdk.calls, <String>['loaded', 'gameStart']);
  });

  test('a second ad request while one runs never reaches the SDK', () async {
    final pending = Completer<JSAny?>();
    final sdk = _FakeGamePix(adResult: () => pending.future);
    final platform = newPlatform();
    await platform.initialize();
    clock = clock.add(GamePixPlatform.adCooldown);

    final first = platform.showRunBreakAd();
    await Future<void>.delayed(Duration.zero);
    await platform.showRunBreakAd();
    expect(sdk.calls.where((c) => c == 'interstitial'), hasLength(1));

    pending.complete(JSObject()..setProperty('success'.toJS, true.toJS));
    await first;
  });

  test('a rejected ad continues unmuted', () async {
    final sdk = _FakeGamePix(adResult: () => Future<JSAny?>.error('ad error'));
    final platform = newPlatform();
    await platform.initialize();
    sdk.handlers['pause']!.callAsFunction();
    clock = clock.add(GamePixPlatform.adCooldown);

    await platform.showRunBreakAd();
    expect(platform.isAudioMuted, isFalse);
  });

  test('a hung ad times out and continues unmuted', () async {
    _FakeGamePix(adResult: () => Completer<JSAny?>().future);
    final platform = newPlatform(adTimeout: const Duration(milliseconds: 50));
    await platform.initialize();
    clock = clock.add(GamePixPlatform.adCooldown);

    await platform.showRunBreakAd();
    expect(platform.isAudioMuted, isFalse);
  });

  test(
    'other keys on a shared origin survive the move to the save item',
    () async {
      _localStorage.callMethod<JSAny?>(
        'setItem'.toJS,
        'flutter.other_game_v1'.toJS,
        '1'.toJS,
      );
      addTearDown(
        () => _localStorage.callMethod<JSAny?>(
          'removeItem'.toJS,
          'flutter.other_game_v1'.toJS,
        ),
      );
      _localStorage.callMethod<JSAny?>(
        'setItem'.toJS,
        _saveKey.toJS,
        '{"rev":1,"owner":null,"values":{"flutter.best":3}}'.toJS,
      );
      await newPlatform().initialize();
      await SharedPreferencesStorePlatform.instance.setValue(
        'Int',
        'flutter.best',
        4,
      );

      expect(
        _localStorage
            .callMethod<JSString?>('getItem'.toJS, 'flutter.other_game_v1'.toJS)
            ?.toDart,
        '1',
      );
    },
  );

  test('a pause before the screen registers still reaches it', () async {
    final sdk = _FakeGamePix();
    final platform = newPlatform();
    await platform.initialize();
    sdk.handlers['pause']!.callAsFunction();

    final events = <bool>[];
    platform.setPauseListener(events.add);
    expect(events, <bool>[true]);
  });
}
