---
id: feature-line-assist
title: Auto-cross finished lines and haptic feedback on phones
status: active
owner: games
related_adrs:
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
---

## Problem
After a row or column is finished the player still crosses its empty cells by hand, which is slow
on phones and is not where the puzzle is. Phone play also has no tactile feedback for a finished
line, a mistake or a win.

## Scope
1. Auto-cross: when a finished action (stroke, tap, logic hint) makes a row or column newly match
   its clue (and the clue is not empty), every empty cell of that line becomes crossed. The crosses
   belong to the same undo step as the action, so one Undo reverts both.
2. Haptics (not on web; skipped while sound is muted): light impact on a finished line, medium
   impact on an overfilled line or a Check that finds mistakes, heavy impact on a win.
Out of scope: generation, scoring, stars, XP, storage format, a settings toggle.

## Acceptance Criteria
- Auto-cross never changes filled cells or existing crosses, never runs once the puzzle is won,
  and never touches lines that were already matching before the action.
- Auto-cross uses the clues only, not the solution. A line that matches its clue with misplaced
  ink is crossed as well; the crossing columns/rows still flag it. Undo restores it.
- Win detection, mistake detection (Check), stars and the save format are unchanged. Crosses are
  saved like any other cross.
- Haptics are fire-and-forget, never throw, and are injectable for tests.
- 390x844 and 1280x720 layouts are unchanged.

## Plan / check mapping
| Requirement | Owner / files | Verification |
| --- | --- | --- |
| Auto-cross rule and undo grouping | `lib/src/logic/game.dart` | `test/game_test.dart` |
| Screen effects and haptics | `lib/src/ui/game_screen.dart` | `test/line_assist_screen_test.dart` |

## Evidence
`flutter analyze`, `flutter test`, `flutter build web --release --base-href /NonoGrid/`, review.
