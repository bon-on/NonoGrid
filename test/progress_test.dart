import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/meta/progress_rules.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameStorage> _open(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return GameStorage.open();
}

void main() {
  group('stars and par', () {
    test('par time grows with the grid', () {
      expect(parSeconds(5), 58);
      expect(parSeconds(15), 358);
    });

    test('1 star for solving, +1 no mistakes, +1 within par', () {
      expect(starsFor(size: 5, seconds: 10, mistakes: false), 3);
      expect(starsFor(size: 5, seconds: 10, mistakes: true), 2);
      expect(starsFor(size: 5, seconds: 58, mistakes: false), 3);
      expect(starsFor(size: 5, seconds: 59, mistakes: false), 2);
      expect(starsFor(size: 5, seconds: 999, mistakes: true), 1);
    });
  });

  group('xp and painter level', () {
    test('first clear and replay xp', () {
      expect(clearXp(size: 5, stars: 3, previousStars: 0), 25);
      expect(clearXp(size: 5, stars: 3, previousStars: 1), 13);
      expect(clearXp(size: 5, stars: 1, previousStars: 3), 3);
    });

    test('level curve', () {
      expect(PainterLevel.fromXp(0).level, 1);
      expect(PainterLevel.fromXp(39).level, 1);
      expect(PainterLevel.fromXp(40).level, 2);
      expect(PainterLevel.fromXp(40).xpNeeded, 60);
      expect(PainterLevel.fromXp(100).level, 3);
      expect(PainterLevel.fromXp(-5).level, 1);
    });

    test('themes unlock at 1, 3, 6, 10', () {
      expect(
        [for (final t in NonoTheme.values) t.requiredLevel],
        [1, 3, 6, 10],
      );
      expect(NonoTheme.kraft.unlockedAt(2), isFalse);
      expect(NonoTheme.kraft.unlockedAt(3), isTrue);
      expect(NonoTheme.fromId('bogus'), NonoTheme.notebook);
    });
  });

  group('storage v2', () {
    test('defaults when nothing is stored', () async {
      final s = await _open({});
      expect(s.level, 1);
      expect(s.maxCleared, 0);
      expect(s.xp, 0);
      expect(s.theme, NonoTheme.notebook);
      expect(s.progress, isNull);
    });

    test('migrates v1 keys without losing progress', () async {
      final s = await _open({
        'level': 4,
        'maxCleared': 3,
        'best_1': 12,
        'best_3': 40,
        'progressLevel': 4,
        'progressCells': '#${'.' * 24}',
        'progressElapsed': 33,
      });
      expect(s.level, 4);
      expect(s.maxCleared, 3);
      expect(s.unlocked, 4);
      expect(s.bestSeconds(1), 12);
      expect(s.bestSeconds(2), isNull);
      expect(s.bestSeconds(3), 40);
      expect(s.stars(1), 1);
      expect(s.stars(3), 1);
      expect(s.stars(4), 0);
      expect(s.solvedLevels, [1, 2, 3]);
      expect(s.xp, 3 * clearXp(size: 5, stars: 1, previousStars: 0));
      expect(s.progress?.level, 4);
      expect(s.progress?.cells, '#${'.' * 24}');
      expect(s.progress?.elapsedSeconds, 33);
    });

    test('a write stores v2 and keeps v1 keys', () async {
      final s = await _open({'level': 2, 'maxCleared': 1});
      await s.setLevel(2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('maxCleared'), 1);
      final json = jsonDecode(prefs.getString(GameStorage.progressKey)!);
      expect(json['version'], 2);
      expect(json['maxCleared'], 1);
      final again = GameStorage.fromPrefs(prefs);
      expect(again.unlocked, 2);
    });

    test('corrupt v2 falls back to v1 keys, then defaults', () async {
      var s = await _open({
        GameStorage.progressKey: '{not json',
        'maxCleared': 2,
      });
      expect(s.maxCleared, 2);
      s = await _open({GameStorage.progressKey: '[1,2]'});
      expect(s.maxCleared, 0);
      s = await _open({
        GameStorage.progressKey: jsonEncode({
          'version': 2,
          'level': 'x',
          'maxCleared': -4,
          'records': {
            '1': 'bad',
            'zz': {},
            '2': {'best': 9, 'stars': 7},
          },
          'theme': 42,
          'progress': {'level': 0},
        }),
      });
      expect(s.level, 1);
      expect(s.maxCleared, 0);
      expect(s.stars(2), 3);
      expect(s.bestSeconds(2), 9);
      expect(s.theme, NonoTheme.notebook);
      expect(s.progress, isNull);
    });

    test('recordClear returns stars, best, xp and unlocks', () async {
      final s = await _open({});
      final first = await s.recordClear(1, 20);
      expect(first.stars, 3);
      expect(first.newBest, isTrue);
      expect(first.xpGained, 25);
      expect(s.stars(1), 3);
      expect(s.maxCleared, 1);
      final slower = await s.recordClear(1, 90, mistakes: true);
      expect(slower.stars, 1);
      expect(slower.previousStars, 3);
      expect(slower.newBest, isFalse);
      expect(slower.bestSeconds, 20);
      expect(s.stars(1), 3, reason: 'best stars are kept');
      // Enough first clears to reach painter level 3 unlock Kraft.
      ClearResult? r;
      var level = 2;
      while (s.painterLevel.level < 3) {
        r = await s.recordClear(level++, 10);
      }
      expect(r!.leveledUp, isTrue);
      expect(r.unlockedThemes, contains(NonoTheme.kraft));
      expect(s.setTheme(NonoTheme.kraft), isTrue);
      expect(s.setTheme(NonoTheme.midnight), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(GameStorage.fromPrefs(prefs).theme, NonoTheme.kraft);
    });

    test('saved progress keeps the mistakes flag', () async {
      final s = await _open({});
      await s.saveProgress(const SavedProgress(1, '.', 5, mistakes: true));
      final prefs = await SharedPreferences.getInstance();
      expect(GameStorage.fromPrefs(prefs).progress?.mistakes, isTrue);
      expect(sizeForLevel(1), 5);
    });
  });
}
