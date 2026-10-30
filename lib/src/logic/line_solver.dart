/// Single-line and whole-grid nonogram solving by line logic only.
library;

/// Cell knowledge used by the solver.
const int kUnknown = -1;
const int kEmpty = 0;
const int kFilled = 1;

/// Deduces everything line logic can about one line.
///
/// [cells] holds [kUnknown], [kEmpty] or [kFilled]. Returns a new list where
/// every cell that is filled (or empty) in *all* placements of [clue]
/// consistent with [cells] is fixed, or `null` when no placement exists.
///
/// Uses dynamic programming over (position, clue index): `canFrom[i][j]` is
/// true when cells `i..` can be completed with clues `j..`. A forward pass
/// over reachable states then records which cells can be filled or empty.
/// This is equivalent to full enumeration, in O(n^2 * k) time.
List<int>? solveLine(List<int> clue, List<int> cells) {
  final n = cells.length;
  final k = clue.length;
  final w = k + 1;

  // emptyPrefix[i] = number of known-empty cells in [0, i).
  final emptyPrefix = List<int>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    emptyPrefix[i + 1] = emptyPrefix[i] + (cells[i] == kEmpty ? 1 : 0);
  }
  bool noEmptyIn(int from, int to) => emptyPrefix[to] - emptyPrefix[from] == 0;

  bool blockFits(int i, int j) {
    final len = clue[j];
    final end = i + len;
    if (end > n) return false;
    if (!noEmptyIn(i, end)) return false;
    if (end < n && cells[end] == kFilled) return false;
    return true;
  }

  final canFrom = List<bool>.filled((n + 1) * w, false);
  canFrom[n * w + k] = true;
  for (var i = n - 1; i >= 0; i--) {
    for (var j = k; j >= 0; j--) {
      var ok = false;
      if (cells[i] != kFilled && canFrom[(i + 1) * w + j]) ok = true;
      if (!ok && j < k && blockFits(i, j)) {
        final end = i + clue[j];
        final next = end < n ? end + 1 : n;
        if (canFrom[next * w + j + 1]) ok = true;
      }
      canFrom[i * w + j] = ok;
    }
  }
  if (!canFrom[0]) return null;

  final canFill = List<bool>.filled(n, false);
  final canEmpty = List<bool>.filled(n, false);
  final reach = List<bool>.filled((n + 1) * w, false);
  reach[0] = true;
  for (var i = 0; i < n; i++) {
    for (var j = 0; j <= k; j++) {
      if (!reach[i * w + j]) continue;
      if (cells[i] != kFilled && canFrom[(i + 1) * w + j]) {
        canEmpty[i] = true;
        reach[(i + 1) * w + j] = true;
      }
      if (j < k && blockFits(i, j)) {
        final end = i + clue[j];
        final next = end < n ? end + 1 : n;
        if (canFrom[next * w + j + 1]) {
          for (var p = i; p < end; p++) {
            canFill[p] = true;
          }
          if (end < n) canEmpty[end] = true;
          reach[next * w + j + 1] = true;
        }
      }
    }
  }

  return [
    for (var i = 0; i < n; i++)
      canFill[i] && !canEmpty[i]
          ? kFilled
          : (canEmpty[i] && !canFill[i] ? kEmpty : cells[i]),
  ];
}

/// Outcome of solving a whole grid with line logic.
class GridSolveResult {
  const GridSolveResult(this.cells, {required this.contradiction});

  /// Row-major knowledge grid ([kUnknown], [kEmpty], [kFilled]).
  final List<int> cells;
  final bool contradiction;

  bool get solved => !contradiction && !cells.contains(kUnknown);
}

/// Repeatedly applies [solveLine] to rows and columns until nothing changes.
///
/// A grid that ends with no unknown cells has exactly one solution, because
/// every step only fixes cells forced in all solutions.
GridSolveResult solveGrid(List<List<int>> rowClues, List<List<int>> colClues) {
  final height = rowClues.length;
  final width = colClues.length;
  final cells = List<int>.filled(width * height, kUnknown);
  final rowDirty = List<bool>.filled(height, true);
  final colDirty = List<bool>.filled(width, true);
  var anyDirty = true;

  while (anyDirty) {
    anyDirty = false;
    for (var r = 0; r < height; r++) {
      if (!rowDirty[r]) continue;
      rowDirty[r] = false;
      final line = [for (var c = 0; c < width; c++) cells[r * width + c]];
      final out = solveLine(rowClues[r], line);
      if (out == null) return GridSolveResult(cells, contradiction: true);
      for (var c = 0; c < width; c++) {
        if (out[c] != line[c]) {
          cells[r * width + c] = out[c];
          colDirty[c] = true;
          anyDirty = true;
        }
      }
    }
    for (var c = 0; c < width; c++) {
      if (!colDirty[c]) continue;
      colDirty[c] = false;
      final line = [for (var r = 0; r < height; r++) cells[r * width + c]];
      final out = solveLine(colClues[c], line);
      if (out == null) return GridSolveResult(cells, contradiction: true);
      for (var r = 0; r < height; r++) {
        if (out[r] != line[r]) {
          cells[r * width + c] = out[r];
          rowDirty[r] = true;
          anyDirty = true;
        }
      }
    }
  }
  return GridSolveResult(cells, contradiction: false);
}
