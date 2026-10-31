import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

/// Plays bundled sound assets with browser audio elements on web builds.
class WebSound {
  final Map<String, _Audio> _cache = <String, _Audio>{};

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
}

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio(String src);
  external JSPromise<JSAny?> play();
  external set currentTime(num value);
  external set volume(num value);
}
