# NonoGrid MVP verification

Spec: `harness/specs/feature-nono-grid-mvp.md`
Contract: `harness/contracts/contract-nono-grid-mvp.md`
ADR: `harness/adrs/adr-line-solvable-generator.md`
Date: 2026-10-31. Toolchain: Flutter 3.41.7 stable, Dart 3.11.5.

| Command | Exit | Result |
| --- | --- | --- |
| `flutter analyze` | 0 | No issues found |
| `flutter test` | 0 | 33 tests passed (logic, game, widget) |
| `flutter test --platform chrome test/logic_test.dart` | 0 | 17 tests passed; PRNG and level golden values match on the web compiler |
| `flutter build web --release --base-href /NonoGrid/` | 0 | Built build/web |
| `node <harness-lab>/dist/index.js audit . --format md` | 0 | Critical findings: 0 |

## Acceptance criteria to evidence

- Clues: `test/logic_test.dart` group `clues`.
- Line solver vs brute-force enumeration (400 random lines incl.
  contradictions), grid solver ambiguity and uniqueness by backtracking on 120
  random 5x5 grids: group `line solver`.
- Generator levels 1..40 and 46..60 line-solvable, density range, no
  fallback, under 5 s; determinism and golden values: group `generator`.
- Drag painting, undo (incl. undo during a winning stroke), win, mistakes,
  encode/restore: `test/game_test.dart`.
- Widget: 390x844 and 1280x720 render without overflow for level 1 and a
  15x15 level with two-digit clues; tap saves progress; progress restores;
  keyboard solve of level 1 shows the win bar and unlocks level 2:
  `test/widget_test.dart`.

## Screenshots

Headless Chrome against the release build served under `/NonoGrid/`
(390x844 rendered inside a 390x844 iframe because headless Chrome enforces a
minimum window width). Reviewed: level 1 at both sizes, level 1 in progress
(satisfied clues dimmed, X marks), level 31 (12x12) on phone, level 50 (15x15)
at both sizes. Board centered, no overflow, clue font >= 11 px, thick lines
every 5 cells. Screenshots are not committed.

## Review

Independent `code-reviewer` pass: approve with comments, no Critical/High.
Fixed: undo during a winning stroke could leave `won` with an incomplete
board (Medium); added PRNG/level golden tests (Medium); clock pauses while the
app/tab is hidden and saves elapsed time (Low); browsing levels no longer
discards saved progress (Low); added 15x15 layout widget test (Low).

## Known gaps

- Generated levels are abstract patterns, not drawings (only levels 1-3 are
  pictures).
- Only one in-progress board is saved (the last level played).
- Win reveal animation is not covered by screenshots (it needs input).
