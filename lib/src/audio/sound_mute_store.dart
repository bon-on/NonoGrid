import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the player's own sound on/off choice.
///
/// Storage failures never break play: a read failure reports "sound on" and a
/// write failure is ignored. Tests subclass this.
class SoundMuteStore {
  const SoundMuteStore();

  static const String mutedKey = 'sound_muted_v1';

  Future<bool> loadMuted() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(mutedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveMuted(bool muted) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(mutedKey, muted);
    } catch (_) {
      return;
    }
  }
}
