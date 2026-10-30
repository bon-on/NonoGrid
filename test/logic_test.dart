import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/clues.dart';
import 'package:nono_grid/src/logic/line_solver.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/logic/rng.dart';

const _ = kUnknown;
const o = kEmpty;
const X = kFilled;

/// Brute force: all fillings of [cells] consistent with [clue].
List<List<int>> _enumerate(List<int> clue, List<int> cells) {
  final n = cells.length;
  final out = <List<int>>[];
  for (var mask = 0; mask < (1 << n); mask++) {
    final line = [for (var i = 0; i < n; i++) (mask >> i) & 1];
    var ok = true;
    for (var i = 0; i < n; i++) {
      if (cells[i] != kUnknown && cells[i] != line[i]) ok = false;
    }
    if (ok && sameRuns(runsOf(line.map((v) => v == 1)), clue)) out.add(line);
  }
  return out;
}

List<int>? _bruteSolveLine(List<int> clue, List<int> cells) {
  final all = _enumerate(clue, cells);
  if (all.isEmpty) return null;
  return [
    for (var i = 0; i < cells.length; i++)
      all.every((l) => l[i] == 1)
          ? X
          : (all.every((l) => l[i] == 0) ? o : cells[i]),
  ];
}

/// Counts solutions of a size x size puzzle by row-wise backtracking (max 2).
int _countSolutions(Clues clues, int size) {
  final rowOptions = [
    for (final clue in clues.rows)
      _enumerate(clue, List.filled(size, kUnknown)),
  ];
  var count = 0;
  final chosen = <List<int>>[];
  bool colsPrefixOk() {
    for (var c = 0; c < size; c++) {
      final col =
          [for (final r in chosen) r[c]] +
          List.filled(size - chosen.length, kUnknown);
      if (solveLine(clues.cols[c], col) == null) return false;
    }
    return true;
  }

  void rec(int r) {
    if (count >= 2) return;
    if (r == size) {
      count++;
      return;
    }
    for (final opt in rowOptions[r]) {
      chosen.add(opt);
      if (colsPrefixOk()) rec(r + 1);
      chosen.removeLast();
    }
  }

  rec(0);
  return count;
}

void main() {
  group('clues', () {
    test('runsOf counts consecutive filled runs', () {
      bool b(String s) => s == '#';
      List<bool> line(String s) => s.split('').map(b).toList();
      expect(runsOf(line('.....')), isEmpty);
      expect(runsOf(line('#####')), [5]);
      expect(runsOf(line('##.#.')), [2, 1]);
      expect(runsOf(line('.#..###.#')), [1, 3, 1]);
    });

    test('Clues.fromSolution builds rows and columns', () {
      final p = Puzzle.fromPicture(0, 't', ['#.#', '###', '...']);
      expect(p.clues.rows, [
        [1, 1],
        [3],
        <int>[],
      ]);
      expect(p.clues.cols, [
        [2],
        [1],
        [2],
      ]);
      expect(p.clues.maxRowClueCount, 2);
      expect(p.clues.maxColClueCount, 1);
    });
  });

  group('line solver', () {
    test('full clue fills the line', () {
      expect(solveLine([5], [_, _, _, _, _]), [X, X, X, X, X]);
      expect(solveLine([2, 2], [_, _, _, _, _]), [X, X, o, X, X]);
    });

    test('empty clue empties the line', () {
      expect(solveLine([], [_, _, _]), [o, o, o]);
    });

    test('overlap of left-most and right-most placement', () {
      // 3 in 5: middle cell is forced.
      expect(solveLine([3], [_, _, _, _, _]), [_, _, X, _, _]);
      // 4 in 6: two middle cells forced.
      expect(solveLine([4], List.filled(6, _)), [_, _, X, X, _, _]);
    });

    test('known cells narrow placements', () {
      expect(solveLine([2], [X, _, _, _, _]), [X, X, o, o, o]);
      expect(solveLine([1, 1], [_, o, _]), [X, o, X]);
      expect(solveLine([1], [_, _, X, _]), [o, o, X, o]);
    });

    test('contradiction returns null', () {
      expect(solveLine([3], [_, o, _, o, _]), isNull);
      expect(solveLine([], [_, X]), isNull);
      expect(solveLine([1, 1], [X, X, _]), isNull);
    });

    test('matches brute-force enumeration on random lines', () {
      final rng = SeededRng(99);
      for (var t = 0; t < 400; t++) {
        final n = 1 + rng.nextInt(10);
        final truth = [for (var i = 0; i < n; i++) rng.nextInt(2) == 0];
        final clue = runsOf(truth);
        // Reveal some cells, sometimes wrongly to exercise contradictions.
        final cells = [
          for (var i = 0; i < n; i++)
            switch (rng.nextInt(5)) {
              0 => truth[i] ? X : o,
              1 when t.isOdd => rng.nextInt(2),
              _ => kUnknown,
            },
        ];
        expect(
          solveLine(clue, cells),
          _bruteSolveLine(clue, cells),
          reason: 'clue $clue cells $cells',
        );
      }
    });

    test('grid solver leaves ambiguous puzzles unsolved', () {
      // 2x2 diagonal has two solutions.
      final r = solveGrid(
        [
          [1],
          [1],
        ],
        [
          [1],
          [1],
        ],
      );
      expect(r.solved, isFalse);
      expect(r.cells, everyElement(kUnknown));
    });

    test('line-solved grids have exactly one solution', () {
      final rng = SeededRng(7);
      var solvedSeen = 0;
      var ambiguousSeen = 0;
      for (var t = 0; t < 120; t++) {
        const size = 5;
        final grid = [
          for (var i = 0; i < size * size; i++) rng.nextInt(2) == 0,
        ];
        final clues = Clues.fromSolution(grid, size, size);
        final solved = solveGrid(clues.rows, clues.cols).solved;
        final count = _countSolutions(clues, size);
        if (solved) {
          solvedSeen++;
          expect(count, 1);
        }
        if (count > 1) {
          ambiguousSeen++;
          expect(solved, isFalse);
        }
      }
      expect(solvedSeen, greaterThan(0));
      expect(ambiguousSeen, greaterThan(0));
    });
  });

  group('generator', () {
    test('levels 1..40 are line-solvable, in density range, and fast', () {
      final sw = Stopwatch()..start();
      for (var level = 1; level <= 40; level++) {
        final stats = GeneratorStats();
        final p = puzzleForLevel(level, stats: stats);
        expect(p.size, sizeForLevel(level));
        expect(
          isLineSolvable(p.solution, p.size),
          isTrue,
          reason: 'level $level',
        );
        expect(stats.usedFallback, isFalse, reason: 'level $level');
        if (p.name == null) {
          expect(p.density, inInclusiveRange(kMinDensity, kMaxDensity));
        }
      }
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('15x15 levels generate quickly', () {
      final sw = Stopwatch()..start();
      for (var level = 46; level <= 60; level++) {
        final p = puzzleForLevel(level);
        expect(p.size, 15);
        expect(isLineSolvable(p.solution, p.size), isTrue);
      }
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('same level gives the same puzzle', () {
      for (final level in [4, 13, 27, 40, 50]) {
        expect(puzzleForLevel(level).solution, puzzleForLevel(level).solution);
      }
      expect(
        puzzleForLevel(21).solution,
        isNot(equals(puzzleForLevel(22).solution)),
      );
    });

    test('golden: PRNG and generated levels never change silently', () {
      // Changing these values changes shipped levels; see the generator ADR.
      final r = SeededRng(1);
      expect(
        [for (var i = 0; i < 5; i++) r.nextUint32()],
        [3677456184, 2433263795, 131063100, 1902920200, 3700092254],
      );
      String enc(int level) =>
          puzzleForLevel(level).solution.map((b) => b ? '#' : '.').join();
      expect(enc(4), '#..#.##...#..#..#.###.##.');
      expect(
        enc(21),
        '.#.....##.####..##....#...#.#.##...#...#...#...#.###...######.'
        '####..#.###.#.###.##..#####...#######.',
      );
      expect(
        enc(50),
        '.#..#####.####.########.#####.#.######.#.#..#..#...#.#...#.#..#.'
        '.#.###.#####.####.#.#.....#.##.####.#...####.#.##.###...######.'
        '####.#.##.##.#.###.##.##.#...#....#.#.#.#..#....###.#..#.####.##'
        '#..###.##..###.#.#####..##..#..##.',
      );
    });

    test('rng sequence is fixed for a seed', () {
      final a = SeededRng(1);
      final values = [for (var i = 0; i < 5; i++) a.nextUint32()];
      final b = SeededRng(1);
      expect([for (var i = 0; i < 5; i++) b.nextUint32()], values);
      expect(values.every((v) => v >= 0 && v <= 0xFFFFFFFF), isTrue);
    });

    test('sizes ramp from 5 to 15', () {
      expect(sizeForLevel(1), 5);
      expect(sizeForLevel(10), 7);
      expect(sizeForLevel(25), 10);
      expect(sizeForLevel(40), 12);
      expect(sizeForLevel(80), 15);
    });

    test('hand-made pictures are line-solvable', () {
      for (final level in kPictures.keys) {
        final p = puzzleForLevel(level);
        expect(p.name, isNotNull);
        expect(isLineSolvable(p.solution, p.size), isTrue, reason: p.name);
      }
    });
  });
}
