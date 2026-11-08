---
id: feature-logic-hints
title: Explain a forced nonogram step before applying it
status: active
owner: games
related_adrs:
  - adr-logic-hints
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
---

## Problem
Check identifies wrong fills but does not teach how to find the next move.

## Scope
Add a separate Logic hint with a clue-based explanation and explicit Apply step.
Keep generation, assignments, scoring and storage formats unchanged.

## Acceptance Criteria
- Widget-free deduction consumes only clues and current marks, never the solution.
- Scan all lines for contradictions before offering the first forced unknown cell. Explain row/column, clue, cell and whether every legal placement fills or excludes it. Existing marks are assumptions, clearly stated to the player.
- No compatible placement produces a contradiction explanation and no Apply button; ambiguous lines with no forced cells produce a no-step explanation.
- Preview changes no marks or mistake flag. Apply marks exactly one unknown cell, supports Undo, persists through normal save, and can complete a puzzle.
- Hint overlay pauses gameplay/time and blocks board input. Closing cancels. Recompute before applying to avoid stale proposals.
- Logic hints do not cost stars or XP; existing Check-found-mistake and elapsed-play-time rules remain. Explain this in the overlay. No separate mode or new dependencies.
- Phone and desktop layouts fit; unit tests cover fill/empty, ambiguity and inconsistency; widget tests cover preview, cancel, apply, undo, persistence and unchanged mistake flags.

## Plan / check mapping
| Requirement | Owner / files | Verification |
| --- | --- | --- |
| Forced-step reasoning | NonoGrid worker: logic_hint.dart | Pure solver cases |
| Preview and explicit apply | Same worker: game_screen.dart | Widget interactions and saved state |
| Compatibility | Same worker: docs and reports | Analyze, VM/web tests, Pages/portal builds, audit |
| Independent review | Root coordinator | harness-review against recorded base |

## Evidence
reports/logic-hints-verification.md records commands and limits.
