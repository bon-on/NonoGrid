import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/game.dart';
import 'package:nono_grid/src/logic/puzzle.dart';

NonoGame _game() => NonoGame(Puzzle.fromPicture(1, 'Heart', kPictures[1]!.$2));

String _row(NonoGame g, int r) =>
    g.encode().substring(r * g.size, (r + 1) * g.size);

void main() {
  test('tap toggles fill and cross', () {
    final g = _game();
    g.tap(0, 0, Tool.fill);
    expect(g.at(0, 0), Mark.filled);
    g.tap(0, 0, Tool.fill);
    expect(g.at(0, 0), Mark.empty);
    g.tap(0, 0, Tool.cross);
    expect(g.at(0, 0), Mark.crossed);
    // A fill tap on a cross replaces it (start cell decides the action).
    g.tap(0, 0, Tool.fill);
    expect(g.at(0, 0), Mark.filled);
  });

  test('drag paints a straight segment and locks to the first axis', () {
    final g = _game();
    g.beginStroke(1, 0, Tool.fill);
    g.updateStroke(1, 1); // locks to row 1
    g.updateStroke(3, 4); // diagonal move: projected onto row 1
    g.endStroke();
    expect(_row(g, 1), '#####');
    expect(_row(g, 3), '.....');
  });

  test(
    'drag fills gaps when the pointer jumps and shrinks when going back',
    () {
      final g = _game();
      g.beginStroke(0, 2, Tool.fill);
      g.updateStroke(4, 2); // jump to bottom: column locked
      expect([
        for (var r = 0; r < 5; r++) g.at(r, 2),
      ], everyElement(Mark.filled));
      g.updateStroke(1, 2); // back up
      g.endStroke();
      expect(
        [for (var r = 0; r < 5; r++) g.at(r, 2)],
        [Mark.filled, Mark.filled, Mark.empty, Mark.empty, Mark.empty],
      );
    },
  );

  test('stroke only changes cells matching the start state', () {
    final g = _game();
    g.tap(2, 2, Tool.cross);
    g.tap(2, 4, Tool.fill);
    g.beginStroke(2, 0, Tool.fill);
    g.updateStroke(2, 4);
    g.endStroke();
    expect(_row(g, 2), '##x##');
    // Starting on a filled cell with the fill tool erases fills only.
    g.beginStroke(2, 0, Tool.fill);
    g.updateStroke(2, 4);
    g.endStroke();
    expect(_row(g, 2), '..x..');
  });

  test('undo reverts a whole stroke, restart clears everything', () {
    final g = _game();
    g.tap(0, 0, Tool.cross);
    g.beginStroke(1, 0, Tool.fill);
    g.updateStroke(1, 4);
    g.endStroke();
    expect(g.undo(), isTrue);
    expect(_row(g, 1), '.....');
    expect(g.at(0, 0), Mark.crossed);
    expect(g.undo(), isTrue);
    expect(g.undo(), isFalse);
    g.tap(3, 3, Tool.fill);
    g.restart();
    expect(g.encode(), '.' * 25);
    expect(g.canUndo, isFalse);
  });

  test('clue satisfaction and win detection', () {
    final g = _game();
    expect(g.rowSatisfied(1), isFalse);
    g.beginStroke(1, 0, Tool.fill);
    g.updateStroke(1, 4);
    g.endStroke();
    expect(g.rowSatisfied(1), isTrue);
    expect(g.isWon, isFalse);
    final p = g.puzzle;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (p.filledAt(r, c) && g.at(r, c) != Mark.filled) {
          g.tap(r, c, Tool.fill);
        } else if (!p.filledAt(r, c) && r == 4) {
          g.tap(r, c, Tool.cross); // crosses do not block the win
        }
      }
    }
    expect(g.isWon, isTrue);
    // Input is ignored after the win.
    final after = g.encode();
    g.tap(0, 0, Tool.fill);
    expect(g.encode(), after);
    expect(g.undo(), isFalse);
  });

  test('mistakes lists filled cells outside the solution', () {
    final g = _game();
    g.tap(0, 0, Tool.fill); // empty in heart
    g.tap(0, 1, Tool.fill); // filled in heart
    expect(g.mistakes(), [0]);
  });

  test('encode/restore round-trip', () {
    final g = _game();
    g.tap(0, 0, Tool.fill);
    g.tap(4, 4, Tool.cross);
    final data = g.encode();
    final h = _game();
    expect(h.restore(data), isTrue);
    expect(h.encode(), data);
    expect(h.restore('bad'), isFalse);
  });

  test('undo during a winning stroke keeps the win', () {
    final g = _game();
    final p = g.puzzle;
    // Fill everything except row 2 (a full row of 5).
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (r != 2 && p.filledAt(r, c)) g.tap(r, c, Tool.fill);
      }
    }
    g.beginStroke(2, 0, Tool.fill);
    g.updateStroke(2, 4);
    expect(g.undo(), isFalse); // stroke ends, puzzle won, undo refused
    expect(g.isWon, isTrue);
    expect(g.matchesClues, isTrue);
  });

  group('auto-cross finished lines', () {
    // Heart: row 1 '#####' (clue [5]), column 0 '.##..' (clue [2]).
    test('crosses the empty cells of a line that newly matches its clue', () {
      final g = _game();
      g.tap(1, 0, Tool.fill);
      g.tap(2, 0, Tool.fill); // column 0 now matches [2]
      expect(g.at(0, 0), Mark.crossed);
      expect(g.at(3, 0), Mark.crossed);
      expect(g.at(4, 0), Mark.crossed);
      // Row 1 has other empty cells and is not finished.
      expect(g.at(1, 1), Mark.empty);
    });

    test('finishing a line and its crosses undo as one step', () {
      final g = _game();
      g.tap(0, 1, Tool.fill);
      g.tap(0, 3, Tool.fill);
      g.tap(1, 3, Tool.fill);
      final before = g.encode();
      g.beginStroke(1, 0, Tool.fill);
      g.updateStroke(1, 4);
      g.endStroke(); // row 1 done
      expect(g.rowSatisfied(1), isTrue);
      expect(g.undo(), isTrue);
      expect(g.encode(), before);
    });

    test('keeps fills and existing crosses', () {
      final g = _game();
      g.tap(3, 0, Tool.cross);
      g.tap(1, 0, Tool.fill);
      g.tap(2, 0, Tool.fill);
      expect(g.at(3, 0), Mark.crossed);
      expect(g.at(1, 0), Mark.filled);
      expect(g.at(2, 0), Mark.filled);
    });

    test('a line that already matched is not crossed again', () {
      final g = _game();
      g.tap(1, 0, Tool.fill);
      g.tap(2, 0, Tool.fill); // column 0 finished, (0,0) crossed
      g.tap(0, 0, Tool.cross); // player clears the auto cross
      expect(g.at(0, 0), Mark.empty);
      g.tap(4, 4, Tool.fill); // unrelated action
      expect(g.at(0, 0), Mark.empty);
      expect(g.colSatisfied(0), isTrue);
    });

    test('a line with an empty clue is never crossed', () {
      final g = NonoGame(
        Puzzle.fromPicture(9, 'Gap', [
          '#....',
          '.....',
          '.....',
          '.....',
          '.....',
        ]),
      );
      g.tap(2, 2, Tool.fill);
      g.tap(2, 2, Tool.fill); // fill then erase inside empty-clue lines
      expect(g.cells.where((m) => m == Mark.crossed), isEmpty);
    });

    test('nothing is crossed once the puzzle is won', () {
      final g = _game();
      final p = g.puzzle;
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (p.filledAt(r, c)) g.tap(r, c, Tool.fill);
        }
      }
      expect(g.isWon, isTrue);
      // Row 0 finished earlier and was crossed; the winning tap adds none.
      final crossed = g.cells.where((m) => m == Mark.crossed).length;
      g.tap(0, 0, Tool.cross);
      expect(g.cells.where((m) => m == Mark.crossed).length, crossed);
    });

    test('misplaced ink that matches the clue is crossed; Undo restores', () {
      final g = _game();
      g.tap(3, 0, Tool.fill);
      final before = g.encode();
      g.tap(4, 0, Tool.fill); // column 0 [2] matches with rows 3 and 4
      expect(g.colSatisfied(0), isTrue);
      expect(g.at(0, 0), Mark.crossed);
      expect(g.at(1, 0), Mark.crossed);
      expect(g.undo(), isTrue);
      expect(g.encode(), before);
    });

    test('crosses are saved and restored like any cross', () {
      final g = _game();
      g.tap(1, 0, Tool.fill);
      g.tap(2, 0, Tool.fill);
      final copy = _game()..restore(g.encode());
      expect(copy.encode(), g.encode());
    });
  });
}
