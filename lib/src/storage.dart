import 'package:shared_preferences/shared_preferences.dart';

/// Saved in-progress board for one level.
class SavedProgress {
  const SavedProgress(this.level, this.cells, this.elapsedSeconds);
  final int level;
  final String cells;
  final int elapsedSeconds;
}

/// Local persistence: current level, cleared levels, best times, progress.
class GameStorage {
  GameStorage(this._prefs);

  static Future<GameStorage> open() async =>
      GameStorage(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kLevel = 'level';
  static const _kMaxCleared = 'maxCleared';
  static const _kProgressLevel = 'progressLevel';
  static const _kProgressCells = 'progressCells';
  static const _kProgressElapsed = 'progressElapsed';
  static String _bestKey(int level) => 'best_$level';

  int get level => _prefs.getInt(_kLevel) ?? 1;
  Future<void> setLevel(int level) => _prefs.setInt(_kLevel, level);

  int get maxCleared => _prefs.getInt(_kMaxCleared) ?? 0;

  /// Highest level the player may open.
  int get unlocked => maxCleared + 1;

  int? bestSeconds(int level) => _prefs.getInt(_bestKey(level));

  /// Records a clear; returns true when [seconds] is a new best time.
  Future<bool> recordClear(int level, int seconds) async {
    if (level > maxCleared) await _prefs.setInt(_kMaxCleared, level);
    final best = bestSeconds(level);
    if (best == null || seconds < best) {
      await _prefs.setInt(_bestKey(level), seconds);
      return true;
    }
    return false;
  }

  SavedProgress? get progress {
    final level = _prefs.getInt(_kProgressLevel);
    final cells = _prefs.getString(_kProgressCells);
    if (level == null || cells == null) return null;
    return SavedProgress(level, cells, _prefs.getInt(_kProgressElapsed) ?? 0);
  }

  Future<void> saveProgress(SavedProgress p) async {
    await _prefs.setInt(_kProgressLevel, p.level);
    await _prefs.setString(_kProgressCells, p.cells);
    await _prefs.setInt(_kProgressElapsed, p.elapsedSeconds);
  }

  Future<void> clearProgress() async {
    await _prefs.remove(_kProgressLevel);
    await _prefs.remove(_kProgressCells);
    await _prefs.remove(_kProgressElapsed);
  }
}
