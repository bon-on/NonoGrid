import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/logic/rng.dart';
import 'package:nono_grid/src/meta/first_run_coach.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('friendly first puzzle', () {
    test('lineFixedByClue recognises lines the clue alone settles', () {
      expect(lineFixedByClue(const [], 5), isTrue);
      expect(lineFixedByClue(const [5], 5), isTrue);
      expect(lineFixedByClue(const [2, 2], 5), isTrue);
      expect(lineFixedByClue(const [1, 1, 1], 5), isTrue);
      expect(lineFixedByClue(const [3], 5), isFalse);
      expect(lineFixedByClue(const [1, 2], 5), isFalse);
    });

    test('isFriendlyFirstPuzzle needs a full line and three fixed lines', () {
      // Full top row; rows 0 (5), 3 (1 1 1) and 4 (empty) are fixed.
      final friendly = Puzzle.fromPicture(1, 'x', [
        '#####',
        '#....',
        '#.#..',
        '#.#.#',
        '.....',
      ]);
      expect(isFriendlyFirstPuzzle(friendly), isTrue);
      final noFullLine = Puzzle.fromPicture(1, 'x', [
        '.#.#.',
        '#.#.#',
        '.#.#.',
        '#.#.#',
        '.#.#.',
      ]);
      expect(isFriendlyFirstPuzzle(noFullLine), isFalse);
    });

    test('friendlyFirstSeed is deterministic and almost always friendly', () {
      final rng = SeededRng(2026);
      var friendly = 0;
      for (var i = 0; i < 200; i++) {
        final seed = rng.nextUint32() | 1;
        final picked = friendlyFirstSeed(seed);
        expect(friendlyFirstSeed(seed), picked);
        final p = generatePuzzle(1, seed: picked);
        expect(isLineSolvable(p.solution, p.size), isTrue);
        if (isFriendlyFirstPuzzle(p)) friendly++;
      }
      expect(friendly, 200);
    });

    test('a fresh install saves the friendly seed for level 1 only', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await GameStorage.open(seedSource: () => 777);
      final p1 = s.puzzleFor(1);
      expect(isFriendlyFirstPuzzle(p1), isTrue);
      expect(
        p1.solution,
        generatePuzzle(1, seed: friendlyFirstSeed(777)).solution,
      );
      // Reopening regenerates the same puzzle from the saved seed.
      final reopened = await GameStorage.open(seedSource: () => 1);
      expect(reopened.puzzleFor(1).solution, p1.solution);
      // Later levels keep the plain random assignment.
      expect(s.puzzleFor(2).solution, generatePuzzle(2, seed: 777).solution);
    });
  });

  group('FirstRunCoach', () {
    test('inactive coach is never visible', () {
      final c = FirstRunCoach(active: false);
      expect(c.visible, isFalse);
      expect(
        c.onBoardChange(filledAdded: 1, crossedAdded: 0, linesDone: 0),
        isFalse,
      );
    });

    test('tips advance on the action they teach', () {
      final c = FirstRunCoach(active: true);
      expect(c.step, CoachStep.clues);
      // A cross before any fill does not skip the first tip.
      expect(
        c.onBoardChange(filledAdded: 0, crossedAdded: 1, linesDone: 0),
        isFalse,
      );
      expect(
        c.onBoardChange(filledAdded: 2, crossedAdded: 0, linesDone: 0),
        isTrue,
      );
      expect(c.step, CoachStep.mark);
      expect(c.onHintOpened(), isFalse, reason: 'only ends the last tip');
      expect(
        c.onBoardChange(filledAdded: 1, crossedAdded: 0, linesDone: 1),
        isTrue,
      );
      expect(c.step, CoachStep.hint);
      expect(c.onHintOpened(), isTrue);
      expect(c.visible, isFalse);
    });

    test('solve and dismiss end coaching from any step', () {
      final a = FirstRunCoach(active: true);
      expect(a.onSolved(), isTrue);
      expect(a.visible, isFalse);
      expect(a.dismiss(), isFalse);
      final b = FirstRunCoach(active: true);
      expect(b.dismiss(), isTrue);
      expect(b.step, CoachStep.done);
    });

    test('tip text mentions the full line and fits the input method', () {
      expect(
        coachText(CoachStep.clues, fullLine: 5, pointer: true),
        contains('A 5 fills the whole line'),
      );
      expect(
        coachText(CoachStep.clues, pointer: true),
        contains('biggest clue'),
      );
      expect(coachText(CoachStep.mark, pointer: true), contains('Right-click'));
      expect(
        coachText(CoachStep.mark, pointer: false),
        isNot(contains('Right-click')),
      );
      expect(coachText(CoachStep.hint, pointer: false), contains('Logic hint'));
    });
  });
}
