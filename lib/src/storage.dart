import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'logic/game.dart';
import 'logic/puzzle.dart';
import 'logic/rng.dart';
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
    Map<int, int>? puzzleSeeds,
    this.legacyThrough = 0,
  }) : records = records ?? <int, LevelRecord>{},
       puzzleSeeds = puzzleSeeds ?? <int, int>{};

  int level;
  int maxCleared;
  final Map<int, LevelRecord> records;
  int xp;
  NonoTheme theme;
  SavedProgress? progress;
  final Map<int, int> puzzleSeeds;
  final int legacyThrough;

  Map<String, Object?> toJson() => {
    'version': 2,
    'level': level,
    'maxCleared': maxCleared,
    'xp': xp,
    'theme': theme.id,
    'legacyThrough': legacyThrough,
    'puzzleSeeds': {for (final e in puzzleSeeds.entries) '${e.key}': e.value},
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
      final level = intOr(json['level'], 1, min: 1);
      final maxCleared = intOr(json['maxCleared'], 0);
      var progress = SavedProgress.fromJson(json['progress']);
      final hasAssignments =
          json.containsKey('legacyThrough') || json.containsKey('puzzleSeeds');
      final legacyThrough = hasAssignments
          ? intOr(json['legacyThrough'], 0)
          : _exposedThrough(level, maxCleared, progress, records);
      final seeds = <int, int>{};
      final rawSeeds = json['puzzleSeeds'];
      if (rawSeeds is Map) {
        for (final e in rawSeeds.entries) {
          final l = int.tryParse('${e.key}');
          final seed = e.value;
          if (l != null &&
              l > legacyThrough &&
              l <= 1 << 30 &&
              seed is int &&
              seed > 0 &&
              seed <= 0xFFFFFFFF) {
            seeds[l] = seed;
          }
        }
      }
      // A missing/corrupt seed cannot safely identify the board these marks
      // belong to. Keep earned meta progress, but never apply those marks to
      // a newly generated puzzle.
      if (progress != null &&
          progress.level > legacyThrough &&
          !seeds.containsKey(progress.level)) {
        progress = null;
      }
      return NonoProgressData(
        level: level,
        maxCleared: maxCleared,
        records: records,
        xp: intOr(json['xp'], 0),
        theme: NonoTheme.fromId(
          json['theme'] is String ? json['theme'] as String : null,
        ),
        progress: progress,
        puzzleSeeds: seeds,
        legacyThrough: legacyThrough,
      );
    } catch (_) {
      return null;
    }
  }

  static int _exposedThrough(
    int level,
    int maxCleared,
    SavedProgress? progress,
    Map<int, LevelRecord> records,
  ) {
    var highest = maxCleared + 1;
    if (level > highest) highest = level;
    if (progress != null && progress.level > highest) highest = progress.level;
    for (final recorded in records.keys) {
      if (recorded > highest) highest = recorded;
    }
    return highest;
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
    final level = (readInt('level') ?? 1).clamp(1, 1 << 30);
    final legacyKeys = prefs.getKeys().any(
      (key) =>
          key == 'level' ||
          key == 'maxCleared' ||
          key.startsWith('progress') ||
          RegExp(r'^best_\d+$').hasMatch(key),
    );
    return NonoProgressData(
      level: level,
      maxCleared: maxCleared,
      records: records,
      xp: xp,
      progress: progress,
      legacyThrough: legacyKeys
          ? _exposedThrough(level, maxCleared, progress, records)
          : 0,
    );
  }
}

/// Local persistence: current level, cleared levels, best times, stars, XP,
/// theme and the in-progress board.
///
/// Everything is read once in [open] (before the app starts), so nothing is
/// ever saved before the stored value has loaded. Write failures are ignored.
class GameStorage {
  GameStorage._(this._prefs, this._data, this._seedSource);

  static const progressKey = 'nonogrid_progress_v2';

  static Future<GameStorage> open({int Function()? seedSource}) async {
    final prefs = await SharedPreferences.getInstance();
    return GameStorage.fromPrefs(prefs, seedSource: seedSource);
  }

  factory GameStorage.fromPrefs(
    SharedPreferences prefs, {
    int Function()? seedSource,
  }) {
    String? raw;
    try {
      raw = prefs.getString(progressKey);
    } catch (_) {}
    final data =
        NonoProgressData.tryParse(raw) ?? NonoProgressData.fromLegacy(prefs);
    final rng = SeededRng(DateTime.now().microsecondsSinceEpoch);
    return GameStorage._(prefs, data, seedSource ?? rng.nextUint32);
  }

  final SharedPreferences _prefs;
  final NonoProgressData _data;
  final int Function() _seedSource;
  final Map<int, Puzzle> _puzzles = {};
  Future<void> _pendingWrite = Future.value();

  Future<void> _save() {
    final snapshot = jsonEncode(_data.toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _prefs.setString(progressKey, snapshot);
      } catch (_) {}
    });
    return _pendingWrite;
  }

  /// Allocates one permanent puzzle on its first actual visit. Thumbnail
  /// rendering must use [previewPuzzle] instead.
  Puzzle puzzleFor(int level) {
    if (level < 1) throw ArgumentError.value(level, 'level');
    if (level > _data.legacyThrough && !_data.puzzleSeeds.containsKey(level)) {
      final seed = _seedSource() & 0xFFFFFFFF;
      _data.puzzleSeeds[level] = seed == 0 ? 1 : seed;
      _puzzles.remove(level);
      unawaited(_save());
    }
    return previewPuzzle(level);
  }

  /// Returns an existing assignment or a legacy placeholder without saving
  /// or consuming randomness for a locked/unopened level.
  Puzzle previewPuzzle(int level) => _puzzles.putIfAbsent(level, () {
    final seed = _data.puzzleSeeds[level];
    // A record with a damaged assignment cannot be reconstructed. Show an
    // empty placeholder instead of falsely presenting a legacy picture.
    if (seed == null &&
        level > _data.legacyThrough &&
        (_data.records[level]?.stars ?? 0) > 0) {
      final size = sizeForLevel(level);
      return Puzzle(
        level: level,
        size: size,
        solution: List<bool>.filled(size * size, false),
      );
    }
    return seed == null
        ? puzzleForLevel(level)
        : generatePuzzle(level, seed: seed);
  });

  /// Resume any valid unfinished board before considering advancement.
  int get startupLevel {
    final selected = level.clamp(1, unlocked);
    final saved = progress;
    if (saved != null &&
        saved.level >= 1 &&
        saved.level <= unlocked &&
        (saved.level <= _data.legacyThrough ||
            _data.puzzleSeeds.containsKey(saved.level))) {
      final game = NonoGame(previewPuzzle(saved.level));
      if (game.restore(saved.cells) && !game.isWon) return saved.level;
    }
    return selected <= maxCleared ? unlocked : selected;
  }

  int get level => _data.level;
  Future<void> setLevel(int level) {
    puzzleFor(level);
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
    puzzleFor(level);
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
    puzzleFor(p.level);
    _data.progress = p;
    return _save();
  }

  Future<void> clearProgress() {
    _data.progress = null;
    return _save();
  }
}
