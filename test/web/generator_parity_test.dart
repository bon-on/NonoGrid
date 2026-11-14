// Runs on the VM (`flutter test`) and in the browser
// (`flutter test --platform chrome test/web`; tool/check_runtime_parity.sh
// covers dart2wasm). The
// portal builds load dart2wasm where supported and dart2js elsewhere, so
// both must generate exactly the puzzles the VM generates
// (feature-portal-quality-pass, adr-line-solvable-generator).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/logic/rng.dart';
import 'package:nono_grid/src/meta/daily.dart';

/// Polynomial hash that stays exact with JavaScript doubles.
int _hash(Iterable<int> values) {
  var h = 17;
  for (final v in values) {
    h = (h * 31 + v) % 1000000007;
  }
  return h;
}

int _puzzleHash(Puzzle p) => _hash(p.solution.map((c) => c ? 1 : 0));

void main() {
  test('SeededRng sequence matches the VM', () {
    final rng = SeededRng(0xDEADBEEF);
    expect(
      _hash([for (var i = 0; i < 1000; i++) rng.nextUint32() % 65521]),
      _rngHash,
    );
  });

  test('numbered, seeded, daily and first puzzles match the VM', () {
    final values = <int>[
      for (var level = 1; level <= 60; level += 3)
        _puzzleHash(puzzleForLevel(level)),
      for (final seed in [1, 12345, 0x7FFFFFFF, 0xFFFFFFFF])
        for (final level in [1, 7, 13, 21, 31, 46])
          _puzzleHash(generatePuzzle(level, seed: seed)),
      for (var day = 20400; day < 20414; day++) _puzzleHash(dailyPuzzle(day)),
      for (final seed in [1, 777, 12345, 0xFFFFFFFF])
        friendlyFirstSeed(seed) % 1000003,
    ];
    expect(_hash(values), _puzzleHashAll);
  });
}

const int _rngHash = 276229561;
const int _puzzleHashAll = 270885681;
