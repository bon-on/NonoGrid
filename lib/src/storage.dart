import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'logic/puzzle.dart';
import 'meta/progress_rules.dart';

/// Saved in-progress board for one level.
class SavedProgress {
  const SavedProgress(
    this.level,
    this.cells,
    this.elapsedSeconds, {
    this.mistakes = false,
  });
  final int level;
  final String cells;
  final int elapsedSeconds;

  /// Whether Check has found a wrong cell on this board (costs a star).
  final bool mistakes;

  Map<String, Object> toJson() => {
    'level': level,
    'cells': cells,
    'elapsed': elapsedSeconds,
    'mistakes': mistakes,
  };

  static SavedProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final level = json['level'];
    final cells = json['cells'];
    final elapsed = json['elapsed'];
    if (level is! int || cells is! String || level < 1) return null;
    return SavedProgress(
      level,
      cells,
      elapsed is int && elapsed >= 0 ? elapsed : 0,
      mistakes: json['mistakes'] == true,
    );
  }
}

/// Best result of one level.
class LevelRecord {
  const LevelRecord({this.bestSeconds, this.stars = 0});
  final int? bestSeconds;
  final int stars;
}

/// Everything NonoGrid remembers, stored as one JSON value under
/// [GameStorage.progressKey].
class NonoProgressData {
  NonoProgressData({
    this.level = 1,
    this.maxCleared = 0,
    Map<int, LevelRecord>? records,
    this.xp = 0,
    this.theme = NonoTheme.notebook,
    this.progress,
  }) : records = records ?? <int, LevelRecord>{};

  int level;
  int maxCleared;
  final Map<int, LevelRecord> records;
  int xp;
  NonoTheme theme;
  SavedProgress? progress;

  Map<String, Object?> toJson() => {
    'version': 2,
    'level': level,
    'maxCleared': maxCleared,
    'xp': xp,
    'theme': theme.id,
    'records': {
      for (final e in records.entries)
        '${e.key}': {
          if (e.value.bestSeconds != null) 'best': e.value.bestSeconds,
          'stars': e.value.stars,
        },
    },
    if (progress != null) 'progress': progress!.toJson(),
  };

  /// Parses [raw]; returns null when it is missing or malformed so the
  /// caller can fall back.
  static NonoProgressData? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['version'] != 2) return null;
      int intOr(Object? v, int fallback, {int min = 0}) =>
          v is int && v >= min ? v : fallback;
      final records = <int, LevelRecord>{};
      final rawRecords = json['records'];
      if (rawRecords is Map) {
        for (final e in rawRecords.entries) {
          final level = int.tryParse('${e.key}');
          final value = e.value;
          if (level == null || level < 1 || value is! Map) continue;
          final best = value['best'];
          records[level] = LevelRecord(
            bestSeconds: best is int && best >= 0 ? best : null,
            stars: intOr(value['stars'], 0).clamp(0, 3),
          );
        }
      }
      return NonoProgressData(
        level: intOr(json['level'], 1, min: 1),
        maxCleared: intOr(json['maxCleared'], 0),
        records: records,
        xp: intOr(json['xp'], 0),
        theme: NonoTheme.fromId(
          json['theme'] is String ? json['theme'] as String : null,
        ),
        progress: SavedProgress.fromJson(json['progress']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Builds v2 data from the v1 keys (`level`, `maxCleared`, `best_<n>`,
  /// `progress*`). Cleared levels count as one star and earn first-clear XP.
  static NonoProgressData fromLegacy(SharedPreferences prefs) {
    int? readInt(String key) {
      try {
        return prefs.getInt(key);
      } catch (_) {
        return null;
      }
    }

    final maxCleared = (readInt('maxCleared') ?? 0).clamp(0, 100000);
    final records = <int, LevelRecord>{};
    for (var l = 1; l <= maxCleared; l++) {
      records[l] = const LevelRecord(stars: 1);
    }
    try {
      for (final key in prefs.getKeys()) {
        final m = RegExp(r'^best_(\d+)$').firstMatch(key);
        if (m == null) continue;
        final level = int.parse(m.group(1)!);
        final best = readInt(key);
        if (level < 1 || best == null || best < 0) continue;
        final stars = records[level]?.stars ?? 1;
        records[level] = LevelRecord(bestSeconds: best, stars: stars);
      }
    } catch (_) {}
    var xp = 0;
    for (final level in records.keys) {
      xp += clearXp(size: sizeForLevel(level), stars: 1, previousStars: 0);
    }
    SavedProgress? progress;
    final pLevel = readInt('progressLevel');
    String? pCells;
    try {
      pCells = prefs.getString('progressCells');
    } catch (_) {}
    if (pLevel != null && pLevel >= 1 && pCells != null) {
      progress = SavedProgress(
        pLevel,
        pCells,
        (readInt('progressElapsed') ?? 0).clamp(0, 1 << 30),
      );
    }
    return NonoProgressData(
      level: (readInt('level') ?? 1).clamp(1, 1 << 30),
      maxCleared: maxCleared,
      records: records,
      xp: xp,
      progress: progress,
    );
  }
}

/// Local persistence: current level, cleared levels, best times, stars, XP,
/// theme and the in-progress board.
///
/// Everything is read once in [open] (before the app starts), so nothing is
/// ever saved before the stored value has loaded. Write failures are ignored.
class GameStorage {
  GameStorage._(this._prefs, this._data);

  static const progressKey = 'nonogrid_progress_v2';

  static Future<GameStorage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return GameStorage.fromPrefs(prefs);
  }

  factory GameStorage.fromPrefs(SharedPreferences prefs) {
    String? raw;
    try {
      raw = prefs.getString(progressKey);
    } catch (_) {}
    final data =
        NonoProgressData.tryParse(raw) ?? NonoProgressData.fromLegacy(prefs);
    return GameStorage._(prefs, data);
  }

  final SharedPreferences _prefs;
  final NonoProgressData _data;

  Future<void> _save() async {
    try {
      await _prefs.setString(progressKey, jsonEncode(_data.toJson()));
    } catch (_) {}
  }

  int get level => _data.level;
  Future<void> setLevel(int level) {
    _data.level = level;
    return _save();
  }

  int get maxCleared => _data.maxCleared;

  /// Highest level the player may open.
  int get unlocked => maxCleared + 1;

  int? bestSeconds(int level) => _data.records[level]?.bestSeconds;

  /// Best stars for [level] (0 = never solved).
  int stars(int level) => _data.records[level]?.stars ?? 0;

  /// Levels solved at least once, ascending.
  List<int> get solvedLevels =>
      (_data.records.entries
            .where((e) => e.value.stars > 0)
            .map((e) => e.key)
            .toList())
        ..sort();

  int get totalStars => _data.records.values.fold(0, (sum, r) => sum + r.stars);

  int get xp => _data.xp;
  PainterLevel get painterLevel => PainterLevel.fromXp(_data.xp);

  NonoTheme get theme => _data.theme;

  /// Selects [theme] when it is unlocked; returns whether it changed.
  bool setTheme(NonoTheme theme) {
    if (!theme.unlockedAt(painterLevel.level) || theme == _data.theme) {
      return false;
    }
    _data.theme = theme;
    _save();
    return true;
  }

  /// Records a clear of [level] in [seconds] and returns what changed.
  Future<ClearResult> recordClear(
    int level,
    int seconds, {
    bool mistakes = false,
  }) async {
    final size = sizeForLevel(level);
    final stars = starsFor(size: size, seconds: seconds, mistakes: mistakes);
    final old = _data.records[level];
    final previousStars = old?.stars ?? 0;
    final best = old?.bestSeconds;
    final newBest = best == null || seconds < best;
    final before = painterLevel;
    final xpGained = clearXp(
      size: size,
      stars: stars,
      previousStars: previousStars,
    );
    _data.xp += xpGained;
    final after = painterLevel;
    if (level > _data.maxCleared) _data.maxCleared = level;
    _data.records[level] = LevelRecord(
      bestSeconds: newBest ? seconds : best,
      stars: stars > previousStars ? stars : previousStars,
    );
    if (_data.progress?.level == level) _data.progress = null;
    await _save();
    return ClearResult(
      level: level,
      seconds: seconds,
      bestSeconds: newBest ? seconds : best,
      newBest: newBest,
      stars: stars,
      mistakes: mistakes,
      previousStars: previousStars,
      xpGained: xpGained,
      before: before,
      after: after,
      unlockedThemes: [
        for (final t in NonoTheme.values)
          if (!t.unlockedAt(before.level) && t.unlockedAt(after.level)) t,
      ],
    );
  }

  SavedProgress? get progress => _data.progress;

  Future<void> saveProgress(SavedProgress p) {
    _data.progress = p;
    return _save();
  }

  Future<void> clearProgress() {
    _data.progress = null;
    return _save();
  }
}
