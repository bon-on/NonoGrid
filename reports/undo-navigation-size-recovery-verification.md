# Undo, level navigation and assignment recovery

The active specs are `feature-line-assist`, `feature-random-practice` and
`feature-size-ramp-6x6`. The generator ADR records the compatibility boundary
for cached CrazyGames clients. The manifest lists no approved or suggested
profile packs.

## Regression cases

- `test/game_test.dart` erases ink that an automatic cross replaces and
  checks that Undo restores the original board.
- `test/random_resume_screen_test.dart` advances a running stopwatch without
  a board move, navigates away with the level arrow and checks restored marks
  and elapsed time on return.
- `test/random_assignment_test.dart` covers restoring a 6x6 board from its
  marks, restoring backed-up assignments after an old-client rewrite and
  rejecting backup metadata for a different seed.

## Commands

| Command | Result |
| --- | --- |
| `git diff --check` | Exit 0 |
| `flutter analyze` | Exit 1, Flutter executable unavailable |
| `flutter test --reporter expanded` | Exit 1, Flutter executable unavailable |
| `flutter build web --release --base-href /NonoGrid/` | Exit 1, Flutter executable unavailable |

Flutter-dependent checks and live portal verification remain pending.
