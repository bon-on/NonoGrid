# Next-session hooks: per-level boards, daily hook, one-tap Next

Spec: `feature-next-session-hooks`. ADRs: `adr-level-boards` (new storage
format), `adr-daily-puzzle`, `adr-line-solvable-generator`,
`adr-nono-grid-crazygames-web`. The manifest lists no approved or suggested
profile packs.

## Tests written (not executed)

`flutter test` cannot run on this PC: Windows Smart App Control blocks
`flutter_tester.exe`. The tests below were written and pass `flutter analyze`
(they compile), but none of them has been executed.

- `test/level_boards_test.dart`
  - two levels' boards survive a reopen from the stored JSON string only;
  - an old single `progress` slot migrates into its level and both boards
    round-trip;
  - the `progress` mirror keeps the old 4-key shape and holds the most recent
    board; an old-client write (drops `boards`) keeps that board;
  - cap: five most recent boards, re-saving moves a board to newest;
  - seed mismatch and missing assignment reject the board, metadata kept;
    a legacy-level board stamped with a seed is rejected;
  - clearing a level drops only its own board;
  - startup opens the frontier and keeps lower boards;
  - daily board independent of level boards;
  - `untilNextDaily` / `formatCountdown` and all `DailyInfo.summaryHook`
    branches with a fixed clock;
  - widget: level 2 -> level 1 -> level 2 keeps both boards;
  - widget, at 1280x720, 390x844, 640x480, 620x349, 560x315: the level
    summary shows the daily hook, set goal and Next inside the viewport; after
    the summary animation level 2 is already assigned and Enter opens it.
- `test/random_assignment_test.dart`: the "unfinished replay wins" case now
  expects the frontier at startup and the replay board still saved.

## Commands

| Command | Result |
| --- | --- |
| `flutter analyze` | Exit 1, only pre-existing `deprecated_member_use` infos (21) |
| `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run -o <scratchpad>/ng_web` | Exit 0 |
| `dart run` throwaway script for `untilNextDaily`/`formatCountdown` | Output matched the test expectations |
| `dart run` throwaway generator benchmark (VM, 60 seeds per size) | median 44-289us, p95 0.2-1.1ms, max 5.1ms |
| `flutter test` | Not run (Smart App Control) |

Running flutter rewrote `pubspec.lock` and `analysis_options.yaml`; left as is.

## Independent review

A read-only `code-reviewer` agent found no Critical or High issues. One Low
issue was fixed: a level listed in `boards` but rejected for a seed mismatch
could come back through the unstamped `progress` mirror. The parser now skips
any level listed in `boards`. The seed-mismatch test keeps the mirror, and
the ADR wording was narrowed. After the fix, `flutter analyze` (only the 21
infos) and the web build (exit 0) were run again. The reviewer could not run
git or the tests either.

## Not verified

- Every test above, including the existing suite, after the startup-level
  change.
- Generator cost under dart2js/wasm in a real browser (only VM numbers).
- Live CrazyGames cloud save with a cached old client.
