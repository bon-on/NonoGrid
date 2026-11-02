/// Non-web builds play sounds through the native shell audio channel.
class WebSound {
  void play(String assetKey, double volume) {}

  /// Starts [assetKey] on repeat. Completes with false when playback could
  /// not start (the stub never plays).
  Future<bool> loop(String assetKey, double volume) async => false;

  void stopLoop() {}

  void pauseLoop() {}

  /// Resumes a paused loop. Completes with false when it could not.
  Future<bool> resumeLoop() async => false;
}
