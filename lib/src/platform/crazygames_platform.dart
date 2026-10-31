import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'game_platform.dart';

/// CrazyGames HTML5 SDK v3 adapter. The SDK script is injected into the
/// bundle by `tool/build_crazygames.sh`.
///
/// Any SDK failure downgrades to no-op behaviour so the game stays playable.
class CrazyGamesPlatform extends GamePlatform {
  CrazyGamesPlatform();

  static const Duration _initTimeout = Duration(seconds: 5);

  _Sdk? _sdk;
  bool _settingsMuted = false;

  @override
  Future<void> initialize() async {
    try {
      final sdk = _findSdk();
      if (sdk == null) {
        debugPrint('CrazyGames SDK not found; running without it.');
        return;
      }
      // A hung init (blocked SDK requests) must not keep the game from starting.
      await sdk.init().toDart.timeout(_initTimeout);
      final environment = sdk.environment;
      if (environment != 'crazygames' && environment != 'local') {
        debugPrint('CrazyGames SDK environment "$environment"; disabled.');
        return;
      }
      _sdk = sdk;
      _watchSettings(sdk);
    } catch (error) {
      debugPrint('CrazyGames SDK init failed: $error');
      _sdk = null;
    }
  }

  @override
  void gameplayStart() => _call((sdk) => sdk.game.gameplayStart());

  @override
  void gameplayStop() => _call((sdk) => sdk.game.gameplayStop());

  @override
  bool get isAudioMuted => _settingsMuted;

  /// Settings are optional: older SDK builds without them stay playable.
  void _watchSettings(_Sdk sdk) {
    try {
      _applySettings(sdk.game.settings);
      sdk.game.addSettingsChangeListener(
        ((_Settings? settings) => _applySettings(settings)).toJS,
      );
    } catch (error) {
      debugPrint('CrazyGames SDK settings unavailable: $error');
    }
  }

  void _applySettings(_Settings? settings) {
    _settingsMuted = settings?.muteAudio ?? false;
  }

  void _call(void Function(_Sdk sdk) action) {
    final sdk = _sdk;
    if (sdk == null) {
      return;
    }
    try {
      action(sdk);
    } catch (error) {
      debugPrint('CrazyGames SDK call failed: $error');
    }
  }

  static _Sdk? _findSdk() {
    final crazyGames = globalContext.getProperty<JSObject?>('CrazyGames'.toJS);
    return crazyGames?.getProperty<_Sdk?>('SDK'.toJS);
  }
}

extension type _Sdk._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external String get environment;
  external _GameModule get game;
}

extension type _GameModule._(JSObject _) implements JSObject {
  external void gameplayStart();
  external void gameplayStop();
  external _Settings? get settings;
  external void addSettingsChangeListener(JSFunction listener);
}

extension type _Settings._(JSObject _) implements JSObject {
  external bool? get muteAudio;
}
