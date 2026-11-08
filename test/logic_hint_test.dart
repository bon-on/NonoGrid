import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/clues.dart';
import 'package:nono_grid/src/logic/line_solver.dart';
import 'package:nono_grid/src/logic/logic_hint.dart';

void main() {
  test('overlap forces a fill without a solution grid', () {
    final hint = findLogicHint(
      const Clues(
        [
          [3],
        ],
        [
          [1],
          [1],
          [1],
          [],
          [],
        ],
      ),
      List.filled(5, kUnknown),
    );
    expect((hint.row, hint.col, hint.value), (0, 2, kFilled));
    expect(hint.explanation, contains('Row 1 (clue: 3)'));
    expect(hint.explanation, contains('every placement'));
  });
  test('a completed run forces an unknown cell empty', () {
    final hint = findLogicHint(
      const Clues(
        [
          [1],
        ],
        [
          [1],
          [],
        ],
      ),
      [kFilled, kUnknown],
    );
    expect((hint.row, hint.col, hint.value), (0, 1, kEmpty));
    expect(hint.explanation, contains('mark X'));
  });
  test('column deduction is used when rows are ambiguous', () {
    final hint = findLogicHint(
      const Clues(
        [
          [1],
          [1],
        ],
        [
          [2],
          [],
        ],
      ),
      List.filled(4, kUnknown),
    );
    expect((hint.row, hint.col, hint.value), (0, 0, kFilled));
    expect(hint.explanation, contains('Column 1'));
  });
  test('ambiguous grid offers no invented deduction', () {
    final hint = findLogicHint(
      const Clues(
        [
          [1],
          [1],
        ],
        [
          [1],
          [1],
        ],
      ),
      List.filled(4, kUnknown),
    );
    expect(hint.hasStep, isFalse);
    expect(hint.explanation, contains('No immediate forced cell'));
  });
  test('a later contradiction takes priority over an earlier forced cell', () {
    final hint = findLogicHint(
      const Clues(
        [
          [2],
          [],
        ],
        [
          [1],
          [1],
        ],
      ),
      [kUnknown, kUnknown, kFilled, kUnknown],
    );
    expect(hint.hasStep, isFalse);
    expect(hint.explanation, contains('Row 2'));
    expect(hint.explanation, contains('no placement'));
  });
  test('crosses constrain reasoning and are never silently replaced', () {
    final cells = [kEmpty, kUnknown];
    final hint = findLogicHint(
      const Clues(
        [
          [1],
        ],
        [
          [],
          [1],
        ],
      ),
      cells,
    );
    expect((hint.row, hint.col, hint.value), (0, 1, kFilled));
    expect(cells, [kEmpty, kUnknown]);
    expect(
      findLogicHint(
        const Clues(
          [
            [2],
          ],
          [
            [1],
            [1],
          ],
        ),
        cells,
      ).hasStep,
      isFalse,
    );
  });
}
