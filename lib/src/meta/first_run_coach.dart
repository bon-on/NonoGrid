/// First-run coaching: a few short tips shown in a strip next to the board
/// while a new player solves the first puzzle (feature-portal-quality-pass).
///
/// It never blocks input. Each tip advances on the action it teaches; the
/// player can also dismiss it. Widget-free so the rules are unit tested.
enum CoachStep {
  /// How clues work and where to start.
  clues,

  /// Marking cells that must stay empty.
  mark,

  /// Finished lines light up; Logic hint helps when stuck.
  hint,

  /// Finished or dismissed: nothing is shown.
  done,
}

class FirstRunCoach {
  FirstRunCoach({required bool active})
    : _step = active ? CoachStep.clues : CoachStep.done;

  CoachStep _step;
  CoachStep get step => _step;

  bool get visible => _step != CoachStep.done;

  /// Number of tips, for the "1/3" counter.
  static const int tipCount = 3;

  /// Called after a finished board action with what it changed. Returns
  /// true when the step changed.
  bool onBoardChange({
    required int filledAdded,
    required int crossedAdded,
    required int linesDone,
  }) {
    final before = _step;
    if (_step == CoachStep.clues && filledAdded > 0) {
      _step = CoachStep.mark;
    } else if (_step == CoachStep.mark && (crossedAdded > 0 || linesDone > 0)) {
      _step = CoachStep.hint;
    }
    return before != _step;
  }

  /// The player opened Logic hint: the last tip has done its job.
  bool onHintOpened() => _finish(onlyFrom: CoachStep.hint);

  /// The puzzle was solved: coaching ends.
  bool onSolved() => _finish();

  /// The player closed the strip or read the full How to play card.
  bool dismiss() => _finish();

  bool _finish({CoachStep? onlyFrom}) {
    if (_step == CoachStep.done) return false;
    if (onlyFrom != null && _step != onlyFrom) return false;
    _step = CoachStep.done;
    return true;
  }
}

/// Text of the tip for [step]. [fullLine] is the size of the board when the
/// puzzle has a completely filled line (the obvious first move), else null.
/// [pointer] selects mouse wording (right-click) over touch wording.
String coachText(CoachStep step, {int? fullLine, required bool pointer}) {
  switch (step) {
    case CoachStep.clues:
      return fullLine != null
          ? 'Clues count filled cells per line. '
                'A $fullLine fills the whole line - start there!'
          : 'Clues count filled cells per line, in order. '
                'Start with the biggest clue.';
    case CoachStep.mark:
      return pointer
          ? 'Right-click (or Mark X) to cross out cells that must stay empty.'
          : 'Use Mark X to cross out cells that must stay empty.';
    case CoachStep.hint:
      return 'Finished lines light up. Stuck? Logic hint shows a safe next '
          'step for free.';
    case CoachStep.done:
      return '';
  }
}
