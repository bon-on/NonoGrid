import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/audio/sound_fx.dart';
import 'package:nono_grid/src/audio/web_sound_stub.dart';

class _FakeWebSound extends WebSound {
  final List<String> calls = <String>[];
  bool allow = true;

  @override
  void play(String assetKey, double volume) => calls.add('play $assetKey');

  @override
  Future<bool> loop(String assetKey, double volume) async {
    calls.add('loop');
    return allow;
  }

  @override
  void stopLoop() => calls.add('stop');

  @override
  void pauseLoop() => calls.add('pause');

  @override
  Future<bool> resumeLoop() async {
    calls.add('resume');
    return allow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('music loop asset is 16 kHz mono 16-bit and under 1 MB', () {
    final file = File('assets/audio/music_loop.wav');
    final bytes = file.readAsBytesSync();
    expect(bytes.length, lessThan(1024 * 1024));
    final header = ByteData.sublistView(bytes, 0, 44);
    expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(34, Endian.little), 16);
  });

  test('web music waits for the first input, mute and hidden tab', () async {
    var muted = false;
    final web = _FakeWebSound();
    final fx = SoundFx(isMuted: () => muted, webSound: web, isWeb: true);
    fx.startMusic();
    await Future<void>.delayed(Duration.zero);
    expect(web.calls, isEmpty, reason: 'no autoplay before user input');
    fx.onUserInput();
    await Future<void>.delayed(Duration.zero);
    expect(web.calls, ['loop']);
    expect(fx.isMusicPlaying, isTrue);
    fx.setAppVisible(false);
    expect(web.calls.last, 'pause');
    expect(fx.isMusicPlaying, isFalse);
    fx.setAppVisible(true);
    await Future<void>.delayed(Duration.zero);
    expect(web.calls.last, 'resume');
    muted = true;
    fx.refreshMute();
    expect(web.calls.last, 'pause');
    muted = false;
    fx.refreshMute();
    await Future<void>.delayed(Duration.zero);
    expect(fx.isMusicPlaying, isTrue);
    fx.stopMusic();
    expect(web.calls.last, 'stop');
    expect(fx.isMusicWanted, isFalse);
  });

  test('a refused web loop retries on the next input', () async {
    final web = _FakeWebSound()..allow = false;
    final fx = SoundFx(webSound: web, isWeb: true);
    fx.startMusic();
    fx.onUserInput();
    await Future<void>.delayed(Duration.zero);
    expect(fx.isMusicPlaying, isFalse);
    web.allow = true;
    fx.onUserInput();
    await Future<void>.delayed(Duration.zero);
    expect(fx.isMusicPlaying, isTrue);
  });

  test('native music uses startLoop/stopLoop on the channel', () async {
    const channel = MethodChannel('test/audio');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    var muted = false;
    final fx = SoundFx(isMuted: () => muted, isWeb: false, channel: channel);
    fx.startMusic();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['startLoop'], reason: 'native needs no user gesture');
    muted = true;
    fx.refreshMute();
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['startLoop', 'stopLoop']);
    fx.play(Sfx.star);
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 2, reason: 'muted effects are silent');
    fx.dispose();
  });

  test('every new sound exists', () {
    for (final sfx in Sfx.values) {
      expect(File(sfx.assetKey).existsSync(), isTrue, reason: sfx.assetKey);
    }
  });
}
