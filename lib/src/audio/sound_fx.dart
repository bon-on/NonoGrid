import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// Sound effects; each value maps to a bundled `assets/audio/<file>.wav`.
enum Sfx {
  fill('fill', 0.6),
  mark('mark', 0.5),
  undo('undo', 0.5),
  levelClear('level_clear', 0.7);

  const Sfx(this.file, this.volume);

  final String file;
  final double volume;

  String get assetKey => 'assets/audio/$file.wav';
}

/// Plays short sound effects on web (HTML audio) and mobile (native channel).
///
/// [play] is fire-and-forget: it is a no-op while muted and never throws.
class SoundFx {
  SoundFx({bool Function()? isMuted, void Function(Sfx sfx)? onPlay})
    : _isMuted = isMuted ?? _never,
      _onPlay = onPlay;

  static const MethodChannel _channel = MethodChannel('nono_grid/audio');

  final bool Function() _isMuted;
  final void Function(Sfx sfx)? _onPlay;
  final WebSound _webSound = WebSound();

  static bool _never() => false;

  void play(Sfx sfx) {
    try {
      if (_isMuted()) return;
      _onPlay?.call(sfx);
      if (kIsWeb) {
        _webSound.play(sfx.assetKey, sfx.volume);
        return;
      }
      _channel
          .invokeMethod<void>('play', <String, Object>{
            'asset': sfx.assetKey,
            'volume': sfx.volume,
          })
          .catchError((Object _) {});
    } catch (_) {}
  }

  void dispose() {
    if (kIsWeb) return;
    try {
      _channel.invokeMethod<void>('disposeAudio').catchError((Object _) {});
    } catch (_) {}
  }
}
