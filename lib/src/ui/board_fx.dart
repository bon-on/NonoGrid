import 'package:flutter/foundation.dart';

import '../logic/game.dart';

/// A cell mark that just changed and is animating in (or out).
class CellPop {
  const CellPop(this.start, this.before, this.after);
  final Duration start;
  final Mark before;
  final Mark after;
}

/// A row or column effect: completion flash or overflow error.
class LineFx {
  const LineFx(this.isRow, this.index, this.start, {required this.error});
  final bool isRow;
  final int index;
  final Duration start;
  final bool error;
}

/// Timeline of board effects.
///
/// Effects only decorate: the game state is already updated when an effect
/// is queued, so nothing here blocks or delays input. The clock belongs to
/// this object (not to the board widget), so a board that is rebuilt after a
/// layout switch continues the same timeline.
class BoardFx extends ChangeNotifier {
  BoardFx({this.onNeedsTick});

  /// Called when an effect is queued, so the owner can start its ticker.
  VoidCallback? onNeedsTick;

  static const popLength = Duration(milliseconds: 220);
  static const lineLength = Duration(milliseconds: 750);
  static const shakeLength = Duration(milliseconds: 380);
  static const confettiLength = Duration(milliseconds: 2400);

  Duration _now = Duration.zero;
  Duration get now => _now;

  final Map<int, CellPop> pops = <int, CellPop>{};
  final List<LineFx> lines = <LineFx>[];
  Duration? shakeStart;
  Duration? confettiStart;
  int confettiSeed = 1;

  bool get isActive =>
      pops.isNotEmpty ||
      lines.isNotEmpty ||
      shakeStart != null ||
      confettiStart != null;

  /// Advances the clock to [t] and drops finished effects.
  void tick(Duration t) {
    _now = t;
    pops.removeWhere((_, p) => t - p.start > popLength);
    lines.removeWhere((l) => t - l.start > lineLength);
    if (shakeStart != null && t - shakeStart! > shakeLength) shakeStart = null;
    if (confettiStart != null && t - confettiStart! > confettiLength) {
      confettiStart = null;
    }
    notifyListeners();
  }

  void _queued() {
    onNeedsTick?.call();
    notifyListeners();
  }

  /// Cell [index] changed from [before] to [after]; [delay] staggers cells
  /// changed together.
  void cellChanged(
    int index,
    Mark before,
    Mark after, {
    Duration delay = Duration.zero,
  }) {
    pops[index] = CellPop(_now + delay, before, after);
    _queued();
  }

  void lineDone(bool isRow, int index) {
    lines.add(LineFx(isRow, index, _now, error: false));
    _queued();
  }

  void lineError(bool isRow, int index) {
    lines.add(LineFx(isRow, index, _now, error: true));
    _queued();
  }

  void shake() {
    shakeStart = _now;
    _queued();
  }

  void confetti() {
    confettiStart = _now;
    confettiSeed++;
    _queued();
  }

  /// Drops every effect (level change, restart).
  void clear() {
    pops.clear();
    lines.clear();
    shakeStart = null;
    confettiStart = null;
    notifyListeners();
  }

  /// 0..1 progress of an effect that started at [start] and lasts [length];
  /// negative while delayed.
  double progress(Duration start, Duration length) =>
      (_now - start).inMicroseconds / length.inMicroseconds;
}
