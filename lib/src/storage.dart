import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'logic/game.dart';
import 'logic/puzzle.dart';
import 'logic/rng.dart';
import 'meta/collection.dart';
import 'meta/daily.dart';
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

int? _intIn(Object? v, {int min = 0, int max = 1 << 30}) =>
    v is int && v >= min && v <= max ? v : null;

/// Saved in-progress board of one day's daily puzzle.
class DailyProgress {
  const DailyProgress(
    this.day,
    this.cells,
    this.elapsedSeconds, {
    this.mistakes = false,
  });
  final int day;
  final String cells;
  final int elapsedSeconds;
  final bool mistakes;

  Map<String, Object> toJson() => {
    'day': day,
    'cells': cells,
    'elapsed': elapsedSeconds,
    'mistakes': mistakes,
  };

  static DailyProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final day = _intIn(json['day']);
    final cells = json['cells'];
    if (day == null || cells is! String) return null;
    return DailyProgress(
      day,
      cells,
      _intIn(json['elapsed']) ?? 0,
      mistakes: json['mistakes'] == true,
    );
  }
}

/// Result of the most recently solved daily.
class DailyResult {
  const DailyResult(this.day, this.seconds, this.stars);
  final int day;
  final int seconds;
  final int stars;

  Map<String, Object> toJson() => {
    'day': day,
    'seconds': seconds,
    'stars': stars,
  };

  static DailyResult? fromJson(Object? json) {
    if (json is! Map) return null;
    final day = _intIn(json['day']);
    final seconds = _intIn(json['seconds']);
    final stars = _intIn(json['stars'], min: 1, max: 3);
    if (day == null || seconds == null || stars == null) return null;
    return DailyResult(day, seconds, stars);
  }
}

/// Everything about daily puzzles, stored under `daily` in the v2 JSON.
class DailyData {
  DailyData({
    this.streak = const DailyStreak(),
    List<int>? days,
    this.result,
    this.progress,
  }) : days = days ?? <int>[];

  /// Recent solved days kept for the calendar strip.
  static const int keepDays = 30;

  DailyStreak streak;
  final List<int> days;
  DailyResult? result;
  DailyProgress? progress;

  Map<String, Object?> toJson() => {
    if (streak.lastDay != null) 'last': streak.lastDay,
    'streak': streak.streak,
    'best': streak.best,
    'grace': streak.graceReady,
    'refill': streak.refillLeft,
    'total': streak.total,
    'days': days,
    if (result != null) 'result': result!.toJson(),
    if (progress != null) 'progress': progress!.toJson(),
  };

  /// Field-by-field parse; anything damaged falls back to its default.
  static DailyData parse(Object? json) {
    if (json is! Map) return DailyData();
    try {
      final grace = json['grace'];
      final graceReady = grace is bool ? grace : true;
      final refill = _intIn(json['refill'], max: kGraceRefillSolves) ?? 0;
      final streak = _intIn(json['streak']) ?? 0;
      final best = _intIn(json['best']) ?? 0;
      final days = <int>{};
      final rawDays = json['days'];
      if (rawDays is List) {
        for (final d in rawDays) {
          final v = _intIn(d);
          if (v != null) days.add(v);
        }
      }
      final sorted = days.toList()..sort();
      return DailyData(
        streak: DailyStreak(
          lastDay: _intIn(json['last']),
          streak: streak,
          best: best < streak ? streak : best,
          graceReady: graceReady || refill == 0,
          refillLeft: graceReady || refill == 0 ? 0 : refill,
          total: _intIn(json['total']) ?? 0,
        ),
        days: sorted.length > keepDays
            ? sorted.sublist(sorted.length - keepDays)
            : sorted,
        result: DailyResult.fromJson(json['result']),
        progress: DailyProgress.fromJson(json['progress']),
      );
    } catch (_) {
      return DailyData();
    }
  }
}

Set<int> _parseSets(Object? json) {
  final out = <int>{};
  if (json is! List) return out;
  for (final v in json) {
    final i = _intIn(v, max: 1 << 26);
    if (i != null) out.add(i);
  }
  return out;
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
    Map<int, int>? puzzleSizes,
    this.legacyThrough = 0,
    DailyData? daily,
    Set<int>? setsAwarded,
  }) : records = records ?? <int, LevelRecord>{},
       puzzleSeeds = puzzleSeeds ?? <int, int>{},
       puzzleSizes = puzzleSizes ?? <int, int>{},
       daily = daily ?? DailyData(),
       setsAwarded = setsAwarded ?? <int>{};

  int level;
  int maxCleared;
  final Map<int, LevelRecord> records;
  int xp;
  NonoTheme theme;
  SavedProgress? progress;
  final Map<int, int> puzzleSeeds;

  /// Grid size of each assigned level, recorded when it is assigned. A level
  /// without an entry keeps the size it had before the 6x6 step.
  final Map<int, int> puzzleSizes;
  final int legacyThrough;
  final DailyData daily;

  /// Album sets whose completion bonus was granted.
  final Set<int> setsAwarded;

  Map<String, Object?> toJson() => {
    'version': 2,
    'level': level,
    'maxCleared': maxCleared,
    'xp': xp,
    'theme': theme.id,
    'legacyThrough': legacyThrough,
    'puzzleSeeds': {for (final e in puzzleSeeds.entries) '${e.key}': e.value},
    'puzzleSizes': {for (final e in puzzleSizes.entries) '${e.key}': e.value},
    'records': {
      for (final e in records.entries)
        '${e.key}': {
          if (e.value.bestSeconds != null) 'best': e.value.bestSeconds,
          'stars': e.value.stars,
        },
    },
    if (progress != null) 'progress': progress!.toJson(),
    'daily': daily.toJson(),
    'setsAwarded': setsAwarded.toList()..sort(),
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
          if (level == null || level < 1 || level > 1 << 30 || value is! Map) {
            continue;
          }
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
      final sizes = <int, int>{};
      final rawSizes = json['puzzleSizes'];
      if (rawSizes is Map) {
        for (final e in rawSizes.entries) {
          final l = int.tryParse('${e.key}');
          final size = e.value;
          if (l != null &&
              seeds.containsKey(l) &&
              size is int &&
              (size == sizeForLevel(l) || size == legacySizeForLevel(l))) {
            sizes[l] = size;
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
        puzzleSizes: sizes,
        legacyThrough: legacyThrough,
        daily: DailyData.parse(json['daily']),
        setsAwarded: _parseSets(json['setsAwarded']),
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
      xp += clearXp(
        size: legacySizeForLevel(level),
        stars: 1,
        previousStars: 0,
      );
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
      final drawn = _seedSource() & 0xFFFFFFFF;
      final seed = drawn == 0 ? 1 : drawn;
      // A new player's very first puzzle gets an obvious opening move.
      _data.puzzleSizes[level] = sizeOf(level);
      _data.puzzleSeeds[level] = level == 1 ? friendlyFirstSeed(seed) : seed;
      _puzzles.remove(level);
      unawaited(_save());
    }
    return previewPuzzle(level);
  }

  /// Grid size of [level]: the recorded size, the pre-6x6 size for a level the
  /// player already holds (assigned, legacy or solved), else the current ramp.
  int sizeOf(int level) {
    final recorded = _data.puzzleSizes[level];
    if (recorded != null) return recorded;
    final held =
        _data.puzzleSeeds.containsKey(level) ||
        level <= _data.legacyThrough ||
        (_data.records[level]?.stars ?? 0) > 0;
    return held ? legacySizeForLevel(level) : sizeForLevel(level);
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
      final size = sizeOf(level);
      return Puzzle(
        level: level,
        size: size,
        solution: List<bool>.filled(size * size, false),
      );
    }
    return seed == null
        ? puzzleForLevel(level, sizeOverride: sizeOf(level))
        : generatePuzzle(level, seed: seed, sizeOverride: sizeOf(level));
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

  bool _isSolved(int level) => (_data.records[level]?.stars ?? 0) > 0;

  /// Album sets from Set 1 through the one holding the newest open level.
  List<SetProgress> get albumSets => visibleSets(unlocked, _isSolved);

  /// Next picture that moves an album set toward completion.
  SetGoal? get setGoal => nextSetGoal(unlocked, _isSolved);

  List<NonoTheme> _themesBetween(PainterLevel before, PainterLevel after) => [
    for (final t in NonoTheme.values)
      if (!t.unlockedAt(before.level) && t.unlockedAt(after.level)) t,
  ];

  /// Records a clear of [level] in [seconds] and returns what changed.
  Future<ClearResult> recordClear(
    int level,
    int seconds, {
    bool mistakes = false,
  }) async {
    puzzleFor(level);
    final size = sizeOf(level);
    final stars = starsFor(size: size, seconds: seconds, mistakes: mistakes);
    final old = _data.records[level];
    final previousStars = old?.stars ?? 0;
    final best = old?.bestSeconds;
    final newBest = best == null || seconds < best;
    final before = painterLevel;
    var xpGained = clearXp(
      size: size,
      stars: stars,
      previousStars: previousStars,
    );
    if (level > _data.maxCleared) _data.maxCleared = level;
    _data.records[level] = LevelRecord(
      bestSeconds: newBest ? seconds : best,
      stars: stars > previousStars ? stars : previousStars,
    );
    // Every complete set not rewarded yet pays out now, including sets
    // completed before this feature existed.
    final completed = <SetProgress>[];
    final bonuses = <XpBonus>[];
    for (final index in newlyCompleteSets(
      _data.records.keys,
      _isSolved,
      _data.setsAwarded,
    )) {
      _data.setsAwarded.add(index);
      final set = setProgress(index, _isSolved);
      completed.add(set);
      bonuses.add(XpBonus('Set complete: ${set.name}', kSetBonusXp));
      xpGained += kSetBonusXp;
    }
    _data.xp += xpGained;
    final after = painterLevel;
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
      unlockedThemes: _themesBetween(before, after),
      size: size,
      bonuses: bonuses,
      completedSets: completed,
      setGoal: setGoal,
    );
  }

  // ---- Daily puzzle ------------------------------------------------------

  final Map<int, Puzzle> _dailyPuzzles = {};

  DailyData get daily => _data.daily;

  /// The daily puzzle of [day] (cached; never saved).
  Puzzle dailyPuzzleFor(int day) {
    if (_dailyPuzzles.length > 8) _dailyPuzzles.clear();
    return _dailyPuzzles.putIfAbsent(day, () => dailyPuzzle(day));
  }

  /// Saved daily board of [day], if any.
  DailyProgress? dailyProgressFor(int day) {
    final p = _data.daily.progress;
    return p != null && p.day == day ? p : null;
  }

  /// Result of [day]'s daily when it was solved.
  DailyResult? dailyResultFor(int day) {
    final r = _data.daily.result;
    return r != null && r.day == day ? r : null;
  }

  Future<void> saveDailyProgress(DailyProgress p) {
    _data.daily.progress = p;
    return _save();
  }

  Future<void> clearDailyProgress() {
    if (_data.daily.progress == null) return _pendingWrite;
    _data.daily.progress = null;
    return _save();
  }

  /// Records a solve of [day]'s daily. The first solve of a day later than
  /// the last solved one earns stars, first-clear XP and the daily bonus;
  /// anything else (replay, clock moved back) earns nothing.
  Future<ClearResult> recordDailyClear(
    int day,
    int seconds, {
    bool mistakes = false,
  }) async {
    final size = dailySize(day);
    final stars = starsFor(size: size, seconds: seconds, mistakes: mistakes);
    final before = painterLevel;
    final daily = _data.daily;
    final solve = applySolve(daily.streak, day);
    var xp = 0;
    final bonuses = <XpBonus>[];
    if (solve.rewarded) {
      daily.streak = solve.state;
      xp = clearXp(size: size, stars: stars, previousStars: 0);
      final bonus = dailyBonusXp(solve.state.streak);
      bonuses.add(XpBonus('Daily bonus (streak ${solve.state.streak})', bonus));
      xp += bonus;
      _data.xp += xp;
      if (!daily.days.contains(day)) {
        daily.days
          ..add(day)
          ..sort();
        if (daily.days.length > DailyData.keepDays) {
          daily.days.removeRange(0, daily.days.length - DailyData.keepDays);
        }
      }
    }
    final previous = dailyResultFor(day);
    // A reward-free solve of an earlier date (clock moved back) must not
    // replace the result of a later day, or that day would look unsolved.
    final latest = daily.result;
    if (previous == null &&
        (solve.rewarded || latest == null || day > latest.day)) {
      daily.result = DailyResult(day, seconds, stars);
    }
    if (daily.progress?.day == day) daily.progress = null;
    final after = painterLevel;
    await _save();
    final state = daily.streak;
    return ClearResult(
      level: 0,
      seconds: seconds,
      bestSeconds: previous == null || seconds < previous.seconds
          ? seconds
          : previous.seconds,
      newBest: false,
      stars: stars,
      mistakes: mistakes,
      previousStars: 0,
      xpGained: xp,
      before: before,
      after: after,
      unlockedThemes: _themesBetween(before, after),
      size: size,
      bonuses: bonuses,
      daily: DailyOutcome(
        day: day,
        streak: streakOn(state, day).current,
        best: state.best,
        rewarded: solve.rewarded,
        graceUsed: solve.graceUsed,
        graceReady: state.graceReady,
        refillLeft: state.refillLeft,
      ),
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
