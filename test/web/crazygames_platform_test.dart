// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/platform/crazygames_platform.dart';

/// Installs a fake `window.CrazyGames.SDK` and records the calls it receives.
class _FakeSdk {
  _FakeSdk({this.environment = 'local', this.initResult, bool? muteAudio}) {
    final game = JSObject()
      ..setProperty(
        'gameplayStart'.toJS,
        (() => calls.add('gameplayStart')).toJS,
      )
      ..setProperty(
        'gameplayStop'.toJS,
        (() => calls.add('gameplayStop')).toJS,
      );
    if (muteAudio != null) {
      final settings = JSObject()
        ..setProperty('muteAudio'.toJS, muteAudio.toJS);
      game
        ..setProperty('settings'.toJS, settings)
        ..setProperty(
          'addSettingsChangeListener'.toJS,
          ((JSFunction listener) => this.listener = listener).toJS,
        );
    }
    final sdk = JSObject()
      ..setProperty('environment'.toJS, environment.toJS)
      ..setProperty('game'.toJS, game)
      ..setProperty(
        'init'.toJS,
        (() => (initResult ?? Future<void>.value()).toJS).toJS,
      );
    globalContext.setProperty(
      'CrazyGames'.toJS,
      JSObject()..setProperty('SDK'.toJS, sdk),
    );
  }

  final String environment;
  final Future<void>? initResult;
  final List<String> calls = <String>[];
  JSFunction? listener;
}

void _removeSdk() => globalContext.delete('CrazyGames'.toJS);

void main() {
  tearDown(_removeSdk);

  test(
    'platform mute follows settings.muteAudio and its change listener',
    () async {
      final sdk = _FakeSdk(muteAudio: true);
      final platform = CrazyGamesPlatform();
      await platform.initialize();
      expect(platform.isAudioMuted, isTrue);
      var changes = 0;
      platform.setAudioMuteListener(() => changes++);
      sdk.listener!.callAsFunction(
        null,
        JSObject()..setProperty('muteAudio'.toJS, false.toJS),
      );
      expect(platform.isAudioMuted, isFalse);
      expect(changes, 1, reason: 'music hears the portal mute change');
      sdk.listener!.callAsFunction(
        null,
        JSObject()..setProperty('muteAudio'.toJS, false.toJS),
      );
      expect(changes, 1, reason: 'unchanged settings do not notify');
      platform.setAudioMuteListener(null);
    },
  );

  test('SDK without settings is not muted and stays enabled', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();
    expect(platform.isAudioMuted, isFalse);
    platform.gameplayStart();
    expect(sdk.calls, contains('gameplayStart'));
  });

  test('missing SDK falls back to no-op', () async {
    _removeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
  });

  test('throwing SDK lookup falls back to no-op', () async {
    final host = JSObject();
    final descriptor = JSObject()
      ..setProperty(
        'get'.toJS,
        ((() => throw 'blocked SDK'.toJS) as JSAny? Function()).toJS,
      );
    globalContext
        .getProperty<JSObject>('Object'.toJS)
        .callMethod<JSAny?>(
          'defineProperty'.toJS,
          host,
          'SDK'.toJS,
          descriptor,
        );
    globalContext.setProperty('CrazyGames'.toJS, host);
    final platform = CrazyGamesPlatform();
    await platform.initialize();
    platform.gameplayStart();
    platform.gameplayStop();
  });

  test('unavailable cloud module preserves gameplay events', () async {
    final fake = _FakeSdk();
    final sdk = globalContext
        .getProperty<JSObject>('CrazyGames'.toJS)
        .getProperty<JSObject>('SDK'.toJS);
    final descriptor = JSObject()
      ..setProperty(
        'get'.toJS,
        ((() => throw 'blocked data'.toJS) as JSAny? Function()).toJS,
      );
    globalContext
        .getProperty<JSObject>('Object'.toJS)
        .callMethod<JSAny?>(
          'defineProperty'.toJS,
          sdk,
          'data'.toJS,
          descriptor,
        );
    final platform = CrazyGamesPlatform();
    await platform.initialize();
    platform.gameplayStart();
    platform.gameplayStop();
    expect(fake.calls, ['gameplayStart', 'gameplayStop']);
  });

  test('disabled environment never calls the SDK', () async {
    final sdk = _FakeSdk(environment: 'disabled');
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('rejected init falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Future<void>.error('init failed'));
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('hung init times out and falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Completer<void>().future);
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('gameplay events reach the SDK', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
    expect(sdk.calls, <String>['gameplayStart', 'gameplayStop']);
  });
}
