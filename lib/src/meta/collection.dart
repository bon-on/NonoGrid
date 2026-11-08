// Album picture sets (feature-collection-sets). Widget-free.

/// Levels per album set.
const int kSetSize = 10;

/// XP for completing a set, granted once per set.
const int kSetBonusXp = 50;

const List<String> _setNames = [
  'Sketchbook',
  'Garden',
  'Seaside',
  'Orchard',
  'Workshop',
  'Night Sky',
  'Harbor',
  'Meadow',
  'Old Town',
  'Festival',
];

/// 0-based set index of [level].
int setOfLevel(int level) => (level < 1 ? 0 : level - 1) ~/ kSetSize;

/// First level of set [index].
int firstLevelOfSet(int index) => index * kSetSize + 1;

/// Display name of set [index]: names cycle, later rounds get a roman suffix.
String setName(int index) {
  final i = index < 0 ? 0 : index;
  final base = _setNames[i % _setNames.length];
  final round = i ~/ _setNames.length;
  if (round == 0) return base;
  const romans = ['II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  return '$base ${round <= romans.length ? romans[round - 1] : round + 1}';
}

/// Progress of one set.
class SetProgress {
  const SetProgress(this.index, this.solved);

  final int index;

  /// Number of solved levels in the set (0..kSetSize).
  final int solved;

  int get total => kSetSize;
  bool get complete => solved >= kSetSize;
  String get name => setName(index);
  int get firstLevel => firstLevelOfSet(index);
  int get lastLevel => firstLevel + kSetSize - 1;
  double get fraction => solved / kSetSize;
}

SetProgress setProgress(int index, bool Function(int level) isSolved) {
  var solved = 0;
  final first = firstLevelOfSet(index);
  for (var l = first; l < first + kSetSize; l++) {
    if (isSolved(l)) solved++;
  }
  return SetProgress(index, solved);
}

/// Sets from the first one through the set holding [unlocked]. Bounded by
/// the open level so a damaged record key can never make this huge.
List<SetProgress> visibleSets(int unlocked, bool Function(int level) isSolved) {
  final last = setOfLevel(unlocked);
  return [for (var i = 0; i <= last; i++) setProgress(i, isSolved)];
}

/// The next picture that moves a set toward completion.
class SetGoal {
  const SetGoal({required this.set, required this.level});

  final SetProgress set;

  /// Lowest unsolved, openable level of [set].
  final int level;

  int get missing => set.total - set.solved;
}

/// Picks the incomplete set with the fewest missing pictures among sets
/// that have an unsolved level at or below [unlocked] (ties: earlier set),
/// and its lowest such level. Null when nothing is openable.
SetGoal? nextSetGoal(int unlocked, bool Function(int level) isSolved) {
  SetGoal? best;
  final lastSet = setOfLevel(unlocked);
  for (var i = 0; i <= lastSet; i++) {
    final progress = setProgress(i, isSolved);
    if (progress.complete) continue;
    int? open;
    for (var l = progress.firstLevel; l <= progress.lastLevel; l++) {
      if (l > unlocked) break;
      if (!isSolved(l)) {
        open = l;
        break;
      }
    }
    if (open == null) continue;
    final goal = SetGoal(set: progress, level: open);
    if (best == null || goal.missing < best.missing) best = goal;
  }
  return best;
}

/// Completed sets not yet in [awarded], ascending.
List<int> newlyCompleteSets(
  Iterable<int> solvedLevels,
  bool Function(int level) isSolved,
  Set<int> awarded,
) {
  final candidates = <int>{for (final l in solvedLevels) setOfLevel(l)};
  final out = <int>[
    for (final i in candidates)
      if (!awarded.contains(i) && setProgress(i, isSolved).complete) i,
  ]..sort();
  return out;
}
