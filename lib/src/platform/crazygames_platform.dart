import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'crazygames_prefs_store.dart';
import 'game_platform.dart';

/// CrazyGames HTML5 SDK v3 adapter. The SDK script is injected into the
/// bundle by `tool/build_crazygames.sh`.
///
/// Any SDK failure downgrades to no-op behaviour so the game stays playable.
class CrazyGamesPlatform extends GamePlatform {
  CrazyGamesPlatform();

  static const Duration _initTimeout = Duration(seconds: 5);

  _Sdk? _sdk;

  /// Replaces the page reload done on a login/logout (tests only).
  @visibleForTesting
  void Function()? reloadOverride;
  bool _settingsMuted = false;
  void Function()? _muteListener;

  @override
  Future<void> initialize() async {
    late final _Sdk sdk;
    try {
      final found = _findSdk();
      if (found == null) {
        debugPrint('CrazyGames SDK not found; running without it.');
        return;
      }
      sdk = found;
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
      return;
    }
    // Cloud storage is optional; its failure must not disable gameplay events.
    await _useCloudSave(sdk);
  }

  /// Routes shared_preferences through the SDK Data module so logged-in
  /// players keep progress across devices. Any failure keeps localStorage.
  Future<void> _useCloudSave(_Sdk sdk) async {
    if (SharedPreferencesStorePlatform.instance is CloudPrefsStore) return;
    try {
      final data = sdk.data;
      final user = sdk.user;
      if (data == null || user == null) return;
      // A login or logout swaps the Data module to another player's data;
      // reload so stale in-memory values never overwrite it. The listener is
      // registered before the initial user is known so no switch is missed;
      // early events are compared once the cloud store is active. Without an
      // active cloud store there is nothing to protect, so no reload.
      var cloudActive = false;
      String? initialName;
      var sawEarlyEvent = false;
      String? earlyName;
      user.addAuthListener(
        ((_User? changed) {
          final name = changed?.username;
          if (!cloudActive) {
            sawEarlyEvent = true;
            earlyName = name;
            return;
          }
          if (name != initialName) _reload();
        }).toJS,
      );
      final initial = await user.getUser().toDart.timeout(_initTimeout);
      initialName = initial?.username;
      SharedPreferencesStorePlatform.instance = await CloudPrefsStore.load(
        cloud: _JsCloudData(data),
        local: SharedPreferencesStorePlatform.instance,
        localStamp: _LocalStorageData(),
        owner: initialName,
      );
      cloudActive = true;
      if (sawEarlyEvent && earlyName != initialName) _reload();
    } catch (error) {
      debugPrint('CrazyGames data module unavailable: $error');
    }
  }

  void _reload() {
    final reload = reloadOverride;
    if (reload != null) {
      reload();
      return;
    }
    globalContext
        .getProperty<JSObject>('location'.toJS)
        .callMethod<JSAny?>('reload'.toJS);
  }

  @override
  void gameplayStart() => _call((sdk) => sdk.game.gameplayStart());

  @override
  void gameplayStop() => _call((sdk) => sdk.game.gameplayStop());

  @override
  bool get isAudioMuted => _settingsMuted;

  /// The CrazyGames game page reported by the SDK (`game.link`), accepted
  /// only as an https URL on a CrazyGames host so a copied result never
  /// points off-portal. Null when the SDK is off or has no link.
  @override
  String? get shareLink {
    final sdk = _sdk;
    if (sdk == null) return null;
    try {
      final link = sdk.game.getProperty<JSAny?>('link'.toJS);
      if (!link.isA<JSString>()) return null;
      return crazyGamesLinkOrNull((link as JSString).toDart);
    } catch (error) {
      debugPrint('CrazyGames SDK link unavailable: $error');
      return null;
    }
  }

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

  @override
  void setAudioMuteListener(void Function()? listener) {
    _muteListener = listener;
  }

  void _applySettings(_Settings? settings) {
    final muted = settings?.muteAudio ?? false;
    if (muted == _settingsMuted) return;
    _settingsMuted = muted;
    try {
      _muteListener?.call();
    } catch (error) {
      debugPrint('Audio mute listener failed: $error');
    }
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

/// [raw] when it is an https URL on crazygames.com (or a country domain such
/// as crazygames.fr), otherwise null.
@visibleForTesting
String? crazyGamesLinkOrNull(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final ok = RegExp(
    r'^([a-z0-9-]+\.)?crazygames\.(com|[a-z]{2}|co\.[a-z]{2}|com\.[a-z]{2})$',
  ).hasMatch(host);
  if (!ok) return null;
  return uri.toString();
}

extension type _Sdk._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external String get environment;
  external _GameModule get game;
  external _DataModule? get data;
  external _UserModule? get user;
}

extension type _DataModule._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

extension type _UserModule._(JSObject _) implements JSObject {
  external JSPromise<_User?> getUser();
  external void addAuthListener(JSFunction listener);
}

extension type _User._(JSObject _) implements JSObject {
  external String? get username;
}

class _LocalStorageData implements CloudData {
  JSObject get _storage =>
      globalContext.getProperty<JSObject>('localStorage'.toJS);

  @override
  String? getItem(String key) =>
      _storage.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;

  @override
  void setItem(String key, String value) =>
      _storage.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
}

class _JsCloudData implements CloudData {
  _JsCloudData(this._data);

  final _DataModule _data;

  @override
  String? getItem(String key) => _data.getItem(key);

  @override
  void setItem(String key, String value) => _data.setItem(key, value);
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
