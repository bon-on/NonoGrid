import 'clues.dart';
import 'puzzle.dart';

/// What the player has put in a cell.
enum Mark { empty, filled, crossed }

/// Which mark a tap or stroke applies.
enum Tool { fill, cross }

extension on Tool {
  Mark get mark => this == Tool.fill ? Mark.filled : Mark.crossed;
}

/// Axis a stroke is locked to after the pointer leaves the start cell.
enum StrokeAxis { none, row, col }

class _Change {
  const _Change(this.index, this.before, this.after);
  final int index;
  final Mark before;
  final Mark after;
}

/// An in-progress drag stroke.
///
/// The start cell decides the action: if it already holds the tool's mark the
/// stroke clears that mark, otherwise it applies the mark. Only cells whose
/// original state equals the start cell's original state are changed, so a
/// fill stroke never overwrites crosses and vice versa. The stroke is locked
/// to the row or column of the first cell it moves into, and covers the
/// straight segment from the start to the pointer (gaps are filled when the
/// pointer jumps). Dragging back shrinks the segment and restores cells.
class _Stroke {
  _Stroke(this.row, this.col, this.from, this.to);
  final int row;
  final int col;
  final Mark from;
  final Mark to;
  StrokeAxis axis = StrokeAxis.none;

  /// Original state of every cell touched so far, by index.
  final Map<int, Mark> original = {};
}

/// Widget-free game state: board marks, strokes, undo and win detection.
class NonoGame {
  NonoGame(this.puzzle)
    : cells = List<Mark>.filled(puzzle.size * puzzle.size, Mark.empty);

  final Puzzle puzzle;
  final List<Mark> cells;
  final List<List<_Change>> _undo = [];
  _Stroke? _stroke;
  bool _won = false;

  int get size => puzzle.size;
  bool get isWon => _won;
  bool get canUndo => _undo.isNotEmpty && !_won;
  bool get isStroking => _stroke != null;

  Mark at(int row, int col) => cells[row * size + col];

  bool inBounds(int row, int col) =>
      row >= 0 && col >= 0 && row < size && col < size;

  // ---- Strokes ----------------------------------------------------------

  /// Starts a stroke at ([row], [col]) and applies it to that cell.
  void beginStroke(int row, int col, Tool tool) {
    if (_won || !inBounds(row, col)) return;
    if (_stroke != null) endStroke();
    final from = at(row, col);
    final to = from == tool.mark ? Mark.empty : tool.mark;
    _stroke = _Stroke(row, col, from, to);
    _applySegment(row, col);
  }

  /// Extends the current stroke toward ([row], [col]).
  void updateStroke(int row, int col) {
    final s = _stroke;
    if (s == null) return;
    row = row.clamp(0, size - 1);
    col = col.clamp(0, size - 1);
    if (s.axis == StrokeAxis.none) {
      if (row == s.row && col == s.col) return;
      final dr = (row - s.row).abs();
      final dc = (col - s.col).abs();
      s.axis = dc >= dr ? StrokeAxis.row : StrokeAxis.col;
    }
    _applySegment(row, col);
  }

  void _applySegment(int row, int col) {
    final s = _stroke!;
    final segment = <int>{};
    if (s.axis == StrokeAxis.row) {
      final lo = col < s.col ? col : s.col;
      final hi = col < s.col ? s.col : col;
      for (var c = lo; c <= hi; c++) {
        segment.add(s.row * size + c);
      }
    } else if (s.axis == StrokeAxis.col) {
      final lo = row < s.row ? row : s.row;
      final hi = row < s.row ? s.row : row;
      for (var r = lo; r <= hi; r++) {
        segment.add(r * size + s.col);
      }
    } else {
      segment.add(s.row * size + s.col);
    }
    // Restore cells that left the segment.
    for (final entry in s.original.entries) {
      if (!segment.contains(entry.key)) cells[entry.key] = entry.value;
    }
    for (final i in segment) {
      final orig = s.original.putIfAbsent(i, () => cells[i]);
      cells[i] = orig == s.from ? s.to : orig;
    }
  }

  /// Finishes the stroke, records one undo step and checks for a win.
  void endStroke() {
    final s = _stroke;
    if (s == null) return;
    _stroke = null;
    final changes = [
      for (final e in s.original.entries)
        if (cells[e.key] != e.value) _Change(e.key, e.value, cells[e.key]),
    ];
    _checkWin();
    if (changes.isNotEmpty) {
      if (!_won) _autoCross(changes, s.original);
      _undo.add(changes);
    }
  }

  /// Crosses the empty cells of every row and column that this action made
  /// newly match its clue, adding the crosses to [changes] (one undo step).
  /// Uses clues only; [original] holds the pre-action state of touched cells.
  void _autoCross(List<_Change> changes, Map<int, Mark> original) {
    bool wasFilled(int r, int c) {
      final i = r * size + c;
      return (original[i] ?? cells[i]) == Mark.filled;
    }

    final lines = <List<int>>[];
    for (var i = 0; i < size; i++) {
      final rowClue = puzzle.clues.rows[i];
      if (rowClue.isNotEmpty &&
          rowSatisfied(i) &&
          !sameRuns(
            runsOf([for (var c = 0; c < size; c++) wasFilled(i, c)]),
            rowClue,
          )) {
        lines.add([for (var c = 0; c < size; c++) i * size + c]);
      }
      final colClue = puzzle.clues.cols[i];
      if (colClue.isNotEmpty &&
          colSatisfied(i) &&
          !sameRuns(
            runsOf([for (var r = 0; r < size; r++) wasFilled(r, i)]),
            colClue,
          )) {
        lines.add([for (var r = 0; r < size; r++) r * size + i]);
      }
    }
    for (final line in lines) {
      for (final i in line) {
        if (cells[i] != Mark.empty) continue;
        cells[i] = Mark.crossed;
        changes.add(_Change(i, Mark.empty, Mark.crossed));
      }
    }
  }

  /// A single tap: a one-cell stroke.
  void tap(int row, int col, Tool tool) {
    beginStroke(row, col, tool);
    endStroke();
  }

  // ---- Undo / restart ---------------------------------------------------

  /// Reverts the last stroke. Returns false when there is nothing to undo.
  bool undo() {
    // Finish a stroke in progress first: it may complete the puzzle.
    if (_stroke != null) endStroke();
    if (_won || _undo.isEmpty) return false;
    final changes = _undo.removeLast();
    for (final ch in changes) {
      cells[ch.index] = ch.before;
    }
    return true;
  }

  /// Clears the board and history.
  void restart() {
    _stroke = null;
    _undo.clear();
    _won = false;
    cells.fillRange(0, cells.length, Mark.empty);
  }

  // ---- Clues / win ------------------------------------------------------

  List<int> rowRuns(int row) =>
      runsOf([for (var c = 0; c < size; c++) at(row, c) == Mark.filled]);

  List<int> colRuns(int col) =>
      runsOf([for (var r = 0; r < size; r++) at(r, col) == Mark.filled]);

  /// True when the row's filled runs match its clue.
  bool rowSatisfied(int row) => sameRuns(rowRuns(row), puzzle.clues.rows[row]);

  bool colSatisfied(int col) => sameRuns(colRuns(col), puzzle.clues.cols[col]);

  /// Win when every row and column matches its clue. Generated puzzles are
  /// uniquely solvable, so this equals matching the stored solution.
  bool get matchesClues {
    for (var i = 0; i < size; i++) {
      if (!rowSatisfied(i) || !colSatisfied(i)) return false;
    }
    return true;
  }

  void _checkWin() {
    if (!_won && matchesClues) _won = true;
  }

  /// Indexes of filled cells that are empty in the solution.
  List<int> mistakes() => [
    for (var i = 0; i < cells.length; i++)
      if (cells[i] == Mark.filled && !puzzle.solution[i]) i,
  ];

  // ---- Persistence ------------------------------------------------------

  /// Encodes marks as `.`, `#` and `x`.
  String encode() => cells
      .map(
        (m) => switch (m) {
          Mark.empty => '.',
          Mark.filled => '#',
          Mark.crossed => 'x',
        },
      )
      .join();

  /// Restores marks from [encode] output. Ignores malformed data.
  bool restore(String data) {
    if (data.length != cells.length) return false;
    final parsed = <Mark>[];
    for (final ch in data.split('')) {
      switch (ch) {
        case '.':
          parsed.add(Mark.empty);
        case '#':
          parsed.add(Mark.filled);
        case 'x':
          parsed.add(Mark.crossed);
        default:
          return false;
      }
    }
    restart();
    cells.setAll(0, parsed);
    _checkWin();
    return true;
  }
}
