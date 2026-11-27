import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

/// Plays bundled sound assets through the Web Audio API on web builds.
class WebSound {
  _WebAudio get _audio => _sharedWebAudio;

  void play(String assetKey, double volume) => _audio.play(assetKey, volume);

  /// Starts [assetKey] on repeat from the beginning. Completes with false
  /// when Web Audio or the asset is unavailable.
  Future<bool> loop(String assetKey, double volume) =>
      _audio.startLoop(assetKey, volume, fromStart: true);

  /// Stops the loop and rewinds it.
  void stopLoop() => _audio.stopLoop();

  /// Pauses the loop, keeping its position.
  void pauseLoop() => _audio.pauseLoop();

  /// Continues a paused loop. False when no loop was started.
  Future<bool> resumeLoop() => _audio.resumeLoop();
}

// One context per page: browsers cap the number of contexts, and each one
// would need its own unlock.
final _WebAudio _sharedWebAudio = _WebAudio();

/// Web Audio playback shared by the [WebSound] wrapper above.
///
/// Each effect is a short-lived buffer source over a decoded buffer. Reusing
/// one HTML `Audio` element per effect (rewind, then play) restarts a media
/// pipeline on every action, which stalled frames on mobile browsers.
class _WebAudio {
  _WebAudio() {
    try {
      if (!globalContext.has('AudioContext')) return;
      final ctx = _AudioContext();
      _ctx = ctx;
      // Browsers start the context only from a user gesture; resume it on
      // every gesture so it also recovers from interruptions (calls, Siri).
      final unlock = ((JSAny? _) {
        _lastGesture = DateTime.now();
        _resume(ctx);
      }).toJS;
      for (final type in const [
        'pointerdown',
        'pointerup',
        'touchend',
        'keydown',
      ]) {
        _document.addEventListener(type, unlock, true.toJS);
      }
    } catch (_) {
      _ctx = null;
    }
  }

  // A first play waits for fetch and decode; past this it would sound late.
  static const Duration _lateLimit = Duration(milliseconds: 400);

  _AudioContext? _ctx;
  DateTime? _lastGesture;
  // The one effect allowed to wait for a locked context (see [play]).
  _SourceNode? _lockedEffect;
  final Map<String, Future<_AudioBuffer?>> _buffers =
      <String, Future<_AudioBuffer?>>{};

  _SourceNode? _loopSource;
  _GainNode? _loopGain;
  _AudioBuffer? _loopBuffer;
  String? _loopKey;
  double _loopVolume = 1;
  double _loopOffset = 0;
  double _loopStartedAt = 0;
  int _loopGeneration = 0;

  static void _resume(_AudioContext ctx) {
    if (ctx.state == 'running') return;
    try {
      ctx.resume().toDart.ignore();
    } catch (_) {}
  }

  // Effects requested while the context is locked would all burst out once it
  // starts, so they are dropped unless a gesture is starting it right now.
  bool _canPlayEffects(_AudioContext ctx) {
    if (ctx.state == 'running') return true;
    final gesture = _lastGesture;
    return gesture != null &&
        DateTime.now().difference(gesture) < const Duration(seconds: 1);
  }

  Future<_AudioBuffer?> _buffer(_AudioContext ctx, String assetKey) =>
      _buffers.putIfAbsent(assetKey, () async {
        // Yield first so a failure below can never run before putIfAbsent
        // stores this future (which would keep the failure cached).
        await null;
        try {
          final response = await _fetch(
            ui_web.assetManager.getAssetUrl(assetKey),
          ).toDart;
          if (!response.ok) throw StateError('HTTP error');
          final data = await response.arrayBuffer().toDart;
          return await ctx.decodeAudioData(data).toDart;
        } catch (_) {
          // Allow a later retry, for example after a network hiccup.
          _buffers.remove(assetKey);
          return null;
        }
      });

  (_SourceNode, _GainNode) _start(
    _AudioContext ctx,
    _AudioBuffer buffer,
    double volume, {
    bool loop = false,
    double offset = 0,
  }) {
    final gain = ctx.createGain();
    gain.gain.value = volume;
    gain.connect(ctx.destination);
    final source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = loop;
    source.connect(gain);
    source.start(0, offset);
    return (source, gain);
  }

  void play(String assetKey, double volume) {
    final ctx = _ctx;
    if (ctx == null || !_canPlayEffects(ctx)) return;
    final requested = DateTime.now();
    _buffer(ctx, assetKey).then((buffer) {
      if (buffer == null) return;
      if (DateTime.now().difference(requested) > _lateLimit) return;
      try {
        // While the context clock is stopped (for example an interrupted
        // iOS context that a gesture failed to resume), keep at most one
        // effect waiting so they cannot all burst out at the next resume.
        final locked = ctx.state != 'running';
        if (locked) {
          try {
            _lockedEffect?.stop();
          } catch (_) {}
        }
        final (source, _) = _start(ctx, buffer, volume);
        _lockedEffect = locked ? source : null;
      } catch (_) {}
    }).ignore();
  }

  /// Plays [assetKey] on repeat, from the start when [fromStart] or when the
  /// track changes, otherwise from where it was paused. While the browser
  /// keeps audio locked the loop is scheduled and starts with the first
  /// gesture. False when Web Audio or the asset is unavailable.
  Future<bool> startLoop(
    String assetKey,
    double volume, {
    required bool fromStart,
  }) async {
    try {
      final ctx = _ctx;
      if (ctx == null) return false;
      _resume(ctx);
      final sameTrack = _loopKey == assetKey;
      _loopVolume = volume;
      if (sameTrack && !fromStart && _loopSource != null) {
        _loopGain?.gain.value = volume;
        return true;
      }
      final generation = ++_loopGeneration;
      _halt();
      _loopKey = assetKey;
      if (!sameTrack || fromStart) _loopOffset = 0;
      final buffer = await _buffer(ctx, assetKey);
      if (buffer == null || generation != _loopGeneration) return false;
      final duration = buffer.duration;
      final offset = duration > 0 ? _loopOffset % duration : 0.0;
      final (source, gain) = _start(
        ctx,
        buffer,
        volume,
        loop: true,
        offset: offset,
      );
      _loopSource = source;
      _loopGain = gain;
      _loopBuffer = buffer;
      _loopStartedAt = ctx.currentTime - offset;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops the loop and keeps its position for [resumeLoop].
  void pauseLoop() {
    _loopGeneration++;
    final ctx = _ctx;
    final buffer = _loopBuffer;
    if (_loopSource != null && ctx != null && buffer != null) {
      final duration = buffer.duration;
      _loopOffset = duration > 0
          ? (ctx.currentTime - _loopStartedAt) % duration
          : 0;
    }
    _halt();
  }

  /// Stops the loop and rewinds it.
  void stopLoop() {
    _loopGeneration++;
    _halt();
    _loopOffset = 0;
  }

  /// Continues the last loop. False when no loop was ever started.
  Future<bool> resumeLoop() async {
    final key = _loopKey;
    if (key == null) return false;
    return startLoop(key, _loopVolume, fromStart: false);
  }

  void _halt() {
    final source = _loopSource;
    _loopSource = null;
    _loopGain = null;
    try {
      source?.stop();
    } catch (_) {}
  }
}

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external factory _AudioContext();
  external String get state;
  external double get currentTime;
  external JSObject get destination;
  external JSPromise<JSAny?> resume();
  external JSPromise<_AudioBuffer> decodeAudioData(JSArrayBuffer data);
  external _SourceNode createBufferSource();
  external _GainNode createGain();
}

extension type _AudioBuffer._(JSObject _) implements JSObject {
  external double get duration;
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(double value);
}

extension type _GainNode._(JSObject _) implements JSObject {
  external _AudioParam get gain;
  external JSObject connect(JSObject destination);
}

extension type _SourceNode._(JSObject _) implements JSObject {
  external set buffer(_AudioBuffer value);
  external set loop(bool value);
  external JSObject connect(JSObject destination);
  external void start(double when, double offset);
  external void stop();
}

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _EventTarget._(JSObject _) implements JSObject {
  external void addEventListener(
    String type,
    JSFunction listener,
    JSBoolean useCapture,
  );
}

@JS('fetch')
external JSPromise<_Response> _fetch(String url);

@JS('document')
external _EventTarget get _document;
