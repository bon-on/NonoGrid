import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

/// Plays bundled sound assets with browser audio elements on web builds.
class WebSound {
  final Map<String, _Audio> _cache = <String, _Audio>{};

  // Dedicated element for the music loop so effects never touch it.
  _Audio? _loopAudio;
  String? _loopKey;

  void play(String assetKey, double volume) {
    try {
      final audio = _cache.putIfAbsent(
        assetKey,
        () => _Audio(ui_web.assetManager.getAssetUrl(assetKey)),
      );
      audio.volume = volume;
      audio.currentTime = 0;
      // Rejections (autoplay policy, decode errors) must not break input.
      audio.play().toDart.ignore();
    } catch (_) {}
  }

  /// Starts [assetKey] on repeat. Completes with false when the browser
  /// refuses (autoplay policy), so the caller can retry after user input.
  Future<bool> loop(String assetKey, double volume) async {
    try {
      if (_loopKey != assetKey) {
        _loopAudio?.pause();
        _loopAudio = _Audio(ui_web.assetManager.getAssetUrl(assetKey));
        _loopKey = assetKey;
      }
      final audio = _loopAudio!;
      audio.loop = true;
      audio.volume = volume;
      audio.currentTime = 0;
      await audio.play().toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops the loop and rewinds it.
  void stopLoop() {
    try {
      final audio = _loopAudio;
      audio?.pause();
      audio?.currentTime = 0;
    } catch (_) {}
  }

  /// Pauses the loop, keeping its position.
  void pauseLoop() {
    try {
      _loopAudio?.pause();
    } catch (_) {}
  }

  /// Continues a paused loop. Completes with false when the browser refuses.
  Future<bool> resumeLoop() async {
    try {
      final audio = _loopAudio;
      if (audio == null) return false;
      await audio.play().toDart;
      return true;
    } catch (_) {
      return false;
    }
  }
}

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio(String src);
  external JSPromise<JSAny?> play();
  external void pause();
  external set currentTime(num value);
  external set volume(num value);
  external set loop(bool value);
}
