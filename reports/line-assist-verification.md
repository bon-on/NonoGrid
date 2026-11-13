# Line assist verification (2026-11-14)

Spec: `harness/specs/feature-line-assist.md`. Base commit 5149c1b.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 271 tests passed (new: auto-cross group in `test/game_test.dart`,
  `test/line_assist_screen_test.dart`; the win test now compares the saved board after the win).
- `flutter build web --release --base-href /NonoGrid/`: built.

## Review follow-up
Independent review (code-reviewer): request changes. Fixed:
- High: auto-cross made `how_to_play_test` "? reopens at step 1" and `widget_test` "tapping a cell starts
  the game" fail on about 8.5% of random level-1 seeds (row or column 4 with clue [1], so the single
  bottom-right fill finishes the line and the save is `....................xxxx#`). My earlier "cold-start
  flake" guess was wrong. Both tests now assert only that the one fill is saved.
- Medium: weak game tests replaced (already-finished line, empty-clue line, win, misplaced ink + Undo);
  haptic screen tests now use a fixed seed (Heart) and cover win (heavy), Check (medium) and mute.
- Low: `HapticKind` moved off `_LineState`'s doc comment; haptics also honour the platform mute.

## Known gaps
- Haptics were exercised only through the injected hook, not on a physical device.
- A line that matches its clue with misplaced ink is auto-crossed too (clues only, by design); Logic
  hint then reads those crosses as known-empty cells, so later hints can come from a contradictory board.
  Undo removes them. Not changed.
