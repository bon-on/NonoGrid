/// Run-length clues for nonogram lines.
library;

/// Returns the lengths of consecutive filled runs in [line].
///
/// An empty list means the line has no filled cells (displayed as `0`).
List<int> runsOf(Iterable<bool> line) {
  final runs = <int>[];
  var current = 0;
  for (final filled in line) {
    if (filled) {
      current++;
    } else if (current > 0) {
      runs.add(current);
      current = 0;
    }
  }
  if (current > 0) runs.add(current);
  return runs;
}

/// Row and column clues for a solution grid.
class Clues {
  const Clues(this.rows, this.cols);

  /// Computes clues for a row-major [solution] of [height] x [width].
  factory Clues.fromSolution(List<bool> solution, int width, int height) {
    final rows = [
      for (var r = 0; r < height; r++)
        runsOf([for (var c = 0; c < width; c++) solution[r * width + c]]),
    ];
    final cols = [
      for (var c = 0; c < width; c++)
        runsOf([for (var r = 0; r < height; r++) solution[r * width + c]]),
    ];
    return Clues(rows, cols);
  }

  final List<List<int>> rows;
  final List<List<int>> cols;

  /// Longest clue list among rows (at least 1, for the `0` clue).
  int get maxRowClueCount =>
      rows.fold(1, (m, r) => r.length > m ? r.length : m);

  /// Longest clue list among columns (at least 1).
  int get maxColClueCount =>
      cols.fold(1, (m, c) => c.length > m ? c.length : m);
}

/// True when two clue lists are equal.
bool sameRuns(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
