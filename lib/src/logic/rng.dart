/// Small deterministic PRNG (xorshift32).
///
/// `dart:math` `Random(seed)` is not guaranteed to produce the same sequence
/// on the Dart VM and on the web, so puzzles use this generator instead. It
/// only uses 32-bit shifts and xors, which behave identically on both.
class SeededRng {
  SeededRng(int seed) : _state = _mix(seed);

  static const int _mask = 0xFFFFFFFF;

  int _state;

  static int _mix(int seed) {
    var x = (seed ^ 0x5BD1E995) & _mask;
    if (x == 0) x = 0x9E3779B9;
    for (var i = 0; i < 8; i++) {
      x = _step(x);
    }
    return x;
  }

  static int _step(int x) {
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    return x & _mask;
  }

  /// Next unsigned 32-bit value.
  int nextUint32() {
    _state = _step(_state);
    return _state;
  }

  /// Uniform-ish integer in `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max');
    return nextUint32() % max;
  }

  /// Double in `[0, 1)`.
  double nextDouble() => nextUint32() / 4294967296.0;
}
