// Prints generator fingerprints; tool/check_runtime_parity.sh runs it on the
// VM, as dart2js and as dart2wasm and compares the output. Same values as
// test/web/generator_parity_test.dart (feature-portal-quality-pass).
import 'package:nono_grid/src/logic/puzzle.dart';
import 'package:nono_grid/src/logic/rng.dart';
import 'package:nono_grid/src/meta/daily.dart';

int _hash(Iterable<int> values) {
  var h = 17;
  for (final v in values) {
    h = (h * 31 + v) % 1000000007;
  }
  return h;
}

int _ph(Puzzle p) => _hash(p.solution.map((c) => c ? 1 : 0));

// ignore_for_file: avoid_print

void main() {
  final rng = SeededRng(0xDEADBEEF);
  print(_hash([for (var i = 0; i < 1000; i++) rng.nextUint32() % 65521]));
  final values = <int>[
    for (var level = 1; level <= 60; level += 3) _ph(puzzleForLevel(level)),
    for (final seed in [1, 12345, 0x7FFFFFFF, 0xFFFFFFFF])
      for (final level in [1, 7, 13, 21, 31, 46])
        _ph(generatePuzzle(level, seed: seed)),
    for (var day = 20400; day < 20414; day++) _ph(dailyPuzzle(day)),
    for (final seed in [1, 777, 12345, 0xFFFFFFFF])
      friendlyFirstSeed(seed) % 1000003,
  ];
  print(_hash(values));
}
