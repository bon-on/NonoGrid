import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// Sound effects; each value maps to a bundled `assets/audio/<file>.wav`.
enum Sfx {
  fill('fill', 0.6),
  mark('mark', 0.5),
  undo('undo', 0.5),
  levelClear('level_clear', 0.7),
  lineDone('line_done', 0.45),
  mistake('mistake', 0.6),
  star('star', 0.55),
  levelUp('level_up', 0.65);

  const Sfx(this.file, this.volume);

  final String file;
  final double volume;

  String get assetKey => 'assets/audio/$file.wav';
}

/// Plays short sound effects and the background music loop on web (HTML
/// audio) and mobile (native channel).
///
/// [play] is fire-and-forget: it is a no-op while muted and never throws.
/// Music has a wanted state ([startMusic] / [stopMusic]) separate from
/// whether it actually plays: mute, a hidden app or tab, and (on web) a
/// missing first user input all hold it back until they clear.
class SoundFx {
  SoundFx({
    bool Function()? isMuted,
    void Function(Sfx sfx)? onPlay,
    WebSound? webSound,
    bool? isWeb,
    MethodChannel? channel,
  }) : _isMuted = isMuted ?? _never,
       _onPlay = onPlay,
       _webSound = webSound ?? WebSound(),
       _isWeb = isWeb ?? kIsWeb,
       _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel('nono_grid/audio');

  static const String musicAsset = 'assets/audio/music_loop.wav';
  static const double musicVolume = 0.4;

  final bool Function() _isMuted;
  final void Function(Sfx sfx)? _onPlay;
  final WebSound _webSound;
  final bool _isWeb;
  final MethodChannel _channel;

  bool _musicWanted = false;
  bool _musicPlaying = false;
  bool _musicStarting = false;
  bool _webLoopStarted = false;
  bool _appVisible = true;
  bool _userInteracted = false;

  static bool _never() => false;

  bool get _muted {
    try {
      return _isMuted();
    } catch (_) {
      return false;
    }
  }

  /// True while the music loop is (believed to be) audible.
  bool get isMusicPlaying => _musicPlaying;

  /// True after [startMusic] until [stopMusic], even while held back.
  bool get isMusicWanted => _musicWanted;

  void play(Sfx sfx) {
    try {
      if (_muted) return;
      _onPlay?.call(sfx);
      if (_isWeb) {
        _webSound.play(sfx.assetKey, sfx.volume);
        return;
      }
      _invoke('play', <String, Object>{
        'asset': sfx.assetKey,
        'volume': sfx.volume,
      });
    } catch (_) {}
  }

  /// Requests background music. It plays once nothing holds it back.
  void startMusic() {
    _musicWanted = true;
    _applyMusic();
  }

  /// Stops the music and forgets the request.
  void stopMusic() {
    _musicWanted = false;
    _applyMusic();
  }

  /// Call when the app or browser tab is hidden or shown again.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _applyMusic();
  }

  /// Call on pointer or key input. Browsers only allow music after the first
  /// one; a request made earlier starts now.
  void onUserInput() {
    if (_userInteracted) {
      // Retry a loop the browser refused earlier.
      if (_isWeb && _musicWanted && !_musicPlaying) _applyMusic();
      return;
    }
    _userInteracted = true;
    _applyMusic();
  }

  /// Call after the mute state may have changed.
  void refreshMute() => _applyMusic();

  bool get _musicAllowed =>
      _musicWanted && !_muted && _appVisible && (!_isWeb || _userInteracted);

  void _applyMusic() {
    try {
      if (!_musicAllowed) {
        _holdMusicBack();
        return;
      }
      if (_musicPlaying || _musicStarting) return;
      if (_isWeb) {
        _startWebMusic();
      } else {
        _musicPlaying = true;
        _invoke('startLoop', <String, Object>{
          'asset': musicAsset,
          'volume': musicVolume,
        });
      }
    } catch (_) {
      // Music is optional and must never break the game.
    }
  }

  void _holdMusicBack() {
    if (_isWeb) {
      if (!_musicWanted) {
        if (_webLoopStarted) {
          _webSound.stopLoop();
          _webLoopStarted = false;
        }
      } else if (_musicPlaying) {
        _webSound.pauseLoop();
      }
      _musicPlaying = false;
      return;
    }
    if (_musicPlaying) {
      _musicPlaying = false;
      _invoke('stopLoop');
    }
  }

  void _startWebMusic() {
    _musicStarting = true;
    final Future<bool> started = _webLoopStarted
        ? _webSound.resumeLoop()
        : _webSound.loop(musicAsset, musicVolume);
    started.then<bool>((ok) => ok, onError: (Object _) => false).then((ok) {
      _musicStarting = false;
      if (!ok) return;
      _webLoopStarted = true;
      _musicPlaying = true;
      // State may have changed while the browser was starting playback.
      _applyMusic();
    });
  }

  void dispose() {
    _musicWanted = false;
    _musicPlaying = false;
    _musicStarting = false;
    if (_isWeb) {
      _webSound.stopLoop();
      _webLoopStarted = false;
      return;
    }
    _invoke('disposeAudio');
  }

  void _invoke(String method, [Object? arguments]) {
    if (_isWeb) return;
    try {
      _channel.invokeMethod<void>(method, arguments).catchError((Object _) {});
    } catch (_) {}
  }
}
