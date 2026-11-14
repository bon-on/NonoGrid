import 'clues.dart';
import 'line_solver.dart';
import 'rng.dart';

/// A square nonogram with a known, line-solvable solution.
class Puzzle {
  Puzzle({
    required this.level,
    required this.size,
    required List<bool> solution,
    this.name,
  }) : solution = List.unmodifiable(solution),
       clues = Clues.fromSolution(solution, size, size) {
    if (solution.length != size * size) {
      throw ArgumentError('solution must have size*size cells');
    }
  }

  /// Builds a puzzle from rows of `#` (filled) and `.` (empty).
  factory Puzzle.fromPicture(int level, String name, List<String> rows) {
    final size = rows.length;
    final cells = <bool>[];
    for (final row in rows) {
      if (row.length != size) throw ArgumentError('picture must be square');
      for (final ch in row.split('')) {
        cells.add(ch == '#');
      }
    }
    return Puzzle(level: level, size: size, solution: cells, name: name);
  }

  final int level;
  final int size;

  /// Row-major solution, `true` = filled.
  final List<bool> solution;
  final Clues clues;

  /// Picture name for hand-made puzzles, `null` for generated ones.
  final String? name;

  bool filledAt(int row, int col) => solution[row * size + col];

  double get density =>
      solution.where((c) => c).length / (size * size).toDouble();
}

/// Hand-made pictures used for the first levels.
const Map<int, (String, List<String>)> kPictures = {
  1: ('Heart', ['.#.#.', '#####', '#####', '.###.', '..#..']),
  2: ('Arrow', ['..#..', '.###.', '#####', '..#..', '..#..']),
  3: ('House', ['..#..', '.###.', '#####', '.#.##', '.#.##']),
};

/// Grid size for [level]: 5x5, a 6x6 step, then up to 15x15.
///
/// Players who already hold a puzzle for a level keep that puzzle's size
/// (`GameStorage.sizeOf`); only levels assigned from now on use this ramp.
int sizeForLevel(int level) {
  if (level <= 4) return 5;
  if (level <= 8) return 6;
  if (level <= 12) return 7;
  if (level <= 20) return 8;
  if (level <= 30) return 10;
  if (level <= 45) return 12;
  return 15;
}

/// The ramp before the 6x6 step. Boards and records created under it keep
/// these sizes, so saved puzzles, albums and stars do not change.
int legacySizeForLevel(int level) {
  if (level <= 6) return 5;
  if (level <= 12) return 7;
  return sizeForLevel(level);
}

/// True when [solution] can be fully solved by line logic alone.
bool isLineSolvable(List<bool> solution, int size) {
  final clues = Clues.fromSolution(solution, size, size);
  return solveGrid(clues.rows, clues.cols).solved;
}

/// Statistics about the last generation, useful for tests.
class GeneratorStats {
  int attempts = 0;
  int tweaks = 0;
  bool usedFallback = false;
}

/// Returns the puzzle for [level], deterministic for a given level.
///
/// Levels with a hand-made picture use it; others are generated from seed
/// `level`.
Puzzle puzzleForLevel(int level, {GeneratorStats? stats, int? sizeOverride}) {
  final picture = kPictures[level];
  if (picture != null) {
    return Puzzle.fromPicture(level, picture.$1, picture.$2);
  }
  return generatePuzzle(level, stats: stats, sizeOverride: sizeOverride);
}

/// True when [clue] alone settles every cell of a line of [size] cells:
/// an empty line, or runs that exactly fill it (`5`, `2 2`, `1 1 1`).
bool lineFixedByClue(List<int> clue, int size) {
  if (clue.isEmpty) return true;
  final sum = clue.fold(0, (a, b) => a + b);
  return sum + clue.length - 1 == size;
}

/// A welcoming first puzzle: at least one completely filled line (an obvious
/// first move) and at least [minFixed] lines whose clue alone settles them.
bool isFriendlyFirstPuzzle(Puzzle puzzle, {int minFixed = 3}) {
  final n = puzzle.size;
  final lines = [...puzzle.clues.rows, ...puzzle.clues.cols];
  final hasFullLine = lines.any((l) => l.length == 1 && l.first == n);
  final fixed = lines.where((l) => lineFixedByClue(l, n)).length;
  return hasFullLine && fixed >= minFixed;
}

/// How many candidates [friendlyFirstSeed] tries.
const int kFriendlySeedTries = 24;

/// Picks the seed of a new player's level 1 (feature-portal-quality-pass).
///
/// Tries [seed] first, then seeds derived from it with [SeededRng], and
/// returns the first whose puzzle [isFriendlyFirstPuzzle]; falls back to
/// [seed]. Deterministic, so the chosen seed is simply saved as the level's
/// assignment and the generator itself is unchanged.
int friendlyFirstSeed(int seed) {
  final rng = SeededRng(seed);
  var candidate = seed;
  for (var i = 0; i < kFriendlySeedTries; i++) {
    if (candidate != 0 &&
        isFriendlyFirstPuzzle(generatePuzzle(1, seed: candidate))) {
      return candidate;
    }
    candidate = rng.nextUint32();
  }
  return seed;
}

const double kMinDensity = 0.45;
const double kMaxDensity = 0.68;

/// Generates a uniquely line-solvable puzzle for [level] (seed = level).
///
/// Strategy (see the generator ADR): draw a random grid at 50-60% density
/// and line-solve it. While the solver stalls, flip one still-unknown cell of
/// the picture (toward the target density) and retry. Restart from a fresh
/// random grid after a bounded number of tweaks; after a bounded number of
/// restarts fall back to a trivially solvable pattern.
Puzzle generatePuzzle(
  int level, {
  GeneratorStats? stats,
  int? sizeOverride,
  int? seed,
}) {
  final size = sizeOverride ?? sizeForLevel(level);
  final rng = SeededRng(seed ?? level);
  final total = size * size;
  final target = 0.5 + rng.nextDouble() * 0.1;
  const maxAttempts = 40;
  final maxTweaks = total * 2;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    stats?.attempts = attempt + 1;
    final grid = [for (var i = 0; i < total; i++) rng.nextDouble() < target];
    for (var tweak = 0; tweak <= maxTweaks; tweak++) {
      final clues = Clues.fromSolution(grid, size, size);
      final result = solveGrid(clues.rows, clues.cols);
      final filled = grid.where((c) => c).length;
      final density = filled / total;
      if (result.solved) {
        if (density >= kMinDensity && density <= kMaxDensity) {
          return Puzzle(level: level, size: size, solution: grid);
        }
        break; // Drifted out of range: restart with a fresh grid.
      }
      // Flip an undetermined cell, preferring the side that keeps density
      // close to the target.
      final wantEmpty = density > target;
      final unknown = <int>[];
      final preferred = <int>[];
      for (var i = 0; i < total; i++) {
        if (result.cells[i] != kUnknown) continue;
        unknown.add(i);
        if (grid[i] == wantEmpty) preferred.add(i);
      }
      final pool = preferred.isNotEmpty ? preferred : unknown;
      final pick = pool[rng.nextInt(pool.length)];
      grid[pick] = !grid[pick];
      stats?.tweaks++;
    }
  }

  // Fallback: a frame with a filled diagonal band is always line-solvable.
  stats?.usedFallback = true;
  final grid = [
    for (var r = 0; r < size; r++)
      for (var c = 0; c < size; c++)
        r == 0 ||
            c == 0 ||
            r == size - 1 ||
            c == size - 1 ||
            (r - c).abs() <= 1,
  ];
  return Puzzle(level: level, size: size, solution: grid);
}
