Review target: working tree against b13fc5f, including untracked files
References used: harness/specs/feature-nono-grid-crazygames.md, harness/specs/feature-logic-hints.md, the diff, `logic_hint.dart`, `game_screen.dart` (panel, lifecycle and tap paths), and the new tests. I did not read `harness/adrs/adr-logic-hints.md`, the manifest, the rules files or `reports/crazygames-launch-verification-2026-11-06.md`.
Checks run: none (read-only cross-review)

Findings

1. [Medium] harness/specs/feature-logic-hints.md:38 - The spec points to `reports/logic-hints-verification.md` as its evidence, but that file doesn't exist.
   Scenario: The evidence file is a Glob miss, and the changed-files list has no such report. The only new report is the CrazyGames launch one, which doesn't cover the hint feature.
   Evidence: The glob `reports/logic-hints*` returned nothing. The spec status is `active`, so the Evidence section is unmet.
   Suggested fix: Add the report with argv and exit status for analyze and test, and the layout checks, before accepting.

2. [Medium] test/game_platform_flow_test.dart / harness/specs/feature-logic-hints.md:27 - Required coverage is missing for the Apply button on the contradiction path.
   Scenario: The spec requires that a contradiction shows no Apply button, and that ambiguous no-step cases are covered. The unit tests cover contradiction and ambiguity. The widget test only exercises a forced-step hint on an essentially empty or `.`-only grid.
   Evidence: In `game_screen.dart`, `apply-logic-hint` is rendered only when `hasStep`, but no widget test checks that it is absent.
   Suggested fix: Add a widget case with an inconsistent mark that asserts `find.byKey('apply-logic-hint')` finds nothing.

3. [Medium] test/logic_hint_screen_test.dart:48 - The test doesn't prove that Apply can complete a puzzle or that the stale-recompute path works.
   Scenario: The spec says "can complete a puzzle" and "Recompute before applying to avoid stale proposals". `_applyLogicHint` has a branch that swaps in a changed hint without applying it, and no test reaches it. The win-by-apply path isn't tested either.
   Evidence: The test only taps Apply once on a freshly previewed hint.
   Suggested fix: Add a test where the board is one forced cell from solved, and apply completes it and triggers the win and summary. A second test could change the marks while the dialog is open and check that the hint is refreshed rather than applied.

4. [Low] lib/src/ui/game_screen.dart:~631 - `_applyLogicHint` calls `_tapAtCursor` after `_closePanel`, so it runs `_startClock()` and `_maybeOpenSummary` in an order that is untested for the win case.
   Scenario: If the applied cell completes the puzzle, `_closePanel` has already resumed the clock via `_resumeAfterClose`. `_tapAtCursor` then starts the clock again and `_afterChange` handles the win. This is likely fine, but finding 3 would exercise it.
   Suggested fix: Cover it with the win-by-apply test.

5. [Low] docs/crazygames.md:83 - The docs reference `../_marketing/...` paths outside the repository.
   Scenario: Readers of the public repo can't resolve these paths, and they reveal the local workspace layout. The paths contain no secrets.
   Suggested fix: Drop the relative paths, or describe the assets generically.

6. [Low] lib/src/ui/game_screen.dart:~163 - `_appActive` now counts `inactive` as not active, which blocks input and stops gameplay.
   Scenario: On desktop or web, the window losing focus (a click on browser chrome or a dialog) immediately blocks board input and stops SDK gameplay. That matches the new acceptance criterion in the CrazyGames spec, but it differs from the previous behavior where `inactive` still counted as visible. A stroke that is in progress when focus is lost isn't ended.
   Suggested fix: Consider calling `_onStrokeEnd()` on the transition away from resumed. Otherwise note this behavior in the spec.

Acceptance coverage
| Criterion | Implemented | Tested | Notes |
| --- | --- | --- | --- |
| Hint uses only clues and marks | Yes | Yes | `findLogicHint` takes no solution |
| Contradiction scan precedes forced cell | Yes | Yes | Unit test |
| Contradiction shows no Apply; ambiguity gives no step | Yes | Unit only | See finding 2 |
| Preview changes nothing; Apply marks one cell; Undo; persistence | Yes | Yes | Phone and desktop sizes, mistake flag on and off |
| Apply can complete a puzzle | Yes | No | See findings 3 and 4 |
| Overlay pauses play and blocks input; stale recompute | Yes | Partial | Pause only indirectly; stale path untested |
| No cost to stars or XP; explained in overlay | Yes | Yes | Text checked |
| Layouts fit | Yes (compact tool panel) | Partial | Relies on the existing 844x390 regression |
| Background pause, no duplicate events, overlay-aware resume | Yes | Yes | Platform flow test |
| Verification evidence | No | N/A | See finding 1 |

Questions: Is the `Colors.black54` overlay wrapping an `AlertDialog` meant to block taps on the board? That depends on `Positioned.fill` absorbing pointer events, which the preview test doesn't check directly.

Verdict: approve with comments
