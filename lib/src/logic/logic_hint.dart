import 'clues.dart';
import 'line_solver.dart';

/// One deduction based only on clues and current marks (never a solution).
class LogicHint {
  const LogicHint(this.explanation, {this.row, this.col, this.value});

  final String explanation;
  final int? row;
  final int? col;
  final int? value;
  bool get hasStep => value != null;
}

/// Unknowns use kUnknown, crosses kEmpty and filled marks kFilled.
/// Existing marks are assumptions, not validated against a hidden solution.
LogicHint findLogicHint(Clues clues, List<int> cells) {
  final height = clues.rows.length;
  final width = clues.cols.length;
  if (cells.length != height * width ||
      cells.any((c) => c != kUnknown && c != kEmpty && c != kFilled)) {
    throw ArgumentError('Invalid knowledge grid');
  }
  LogicHint? first;
  for (final rows in [true, false]) {
    final lines = rows ? clues.rows : clues.cols;
    for (var line = 0; line < lines.length; line++) {
      final length = rows ? width : height;
      int index(int pos) => rows ? line * width + pos : pos * width + line;
      final current = [
        for (var pos = 0; pos < length; pos++) cells[index(pos)],
      ];
      final solved = solveLine(lines[line], current);
      final axis = rows ? 'Row' : 'Column';
      final clue = lines[line].isEmpty ? '0' : lines[line].join(', ');
      if (solved == null) {
        return LogicHint(
          '$axis ${line + 1} (clue: $clue) has no placement that fits your '
          'current marks. Undo or revise a fill or X in this line, then try again.',
        );
      }
      if (first != null) continue;
      for (var pos = 0; pos < length; pos++) {
        if (current[pos] != kUnknown || solved[pos] == kUnknown) continue;
        final row = rows ? line : pos;
        final col = rows ? pos : line;
        final action = solved[pos] == kFilled ? 'filled' : 'empty (mark X)';
        first = LogicHint(
          '$axis ${line + 1} (clue: $clue): every placement that fits these '
          'clues and your current marks makes row ${row + 1}, column '
          '${col + 1} $action.',
          row: row,
          col: col,
          value: solved[pos],
        );
        break;
      }
    }
  }
  return first ??
      const LogicHint(
        'No immediate forced cell follows from a single row or column. '
        'Review your marks or use Check to look for wrong fills.',
      );
}
