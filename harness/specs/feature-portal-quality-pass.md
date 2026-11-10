---
id: feature-portal-quality-pass
title: Portal quality pass - faster load, first-minute coaching, board polish
status: active
owner: games
related_adrs:
  - adr-web-wasm-portal-build
  - adr-nono-grid-crazygames-web
  - adr-nono-grid-gamepix-web
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-crazygames
  - contract-nono-grid-gamepix
required_evidence:
  - flutter-tests
  - flutter-analyze
  - chrome-tests
  - portal-builds
  - web-build
  - harness-audit
---

# Feature: Portal quality pass

## Problem
CrazyGames rejected the game with only "The overall quality of the game does
not yet meet the expectations of our platform". Their QA preview measured a
16.1 s load (limit 20 s) and a 43-file / 30.1 MB bundle. A first-time player
also met a blocking three-step "How to play" card before touching the board,
and got a random level 1 that might not offer an obvious first move. The next
submission (not before 2026-11-24, out of scope here) must feel faster and
friendlier from the first second.

## Scope
Load time and size
- Portal builds (`tool/build_crazygames.sh`, `tool/build_gamepix.sh`) compile
  with `--wasm`: Chromium browsers load `main.dart.wasm` + skwasm; Firefox,
  Safari and older browsers use `main.dart.js` + CanvasKit (Flutter's default
  wasm allow list) (`adr-web-wasm-portal-build`). Unused
  `wimp.*` renderer files and `*.symbols` are removed.
- `web/flutter_bootstrap.js` retries once with the JavaScript build
  (`renderer: 'canvaskit'`) when the first start rejects before an engine
  initializer exists; later failures are logged, never double-started.
- The bundled Roboto weights are subset to Basic Latin, Latin-1 and common
  punctuation (`tool/subset_fonts.sh`); lib/ stays ASCII-only.
- `web/index.html` shows a lightweight HTML splash in the desk colours (mini
  heart grid filled once, title, slim progress bar) that fades out on the
  first Flutter frame.
- The GitHub Pages build stays a JavaScript build (`--base-href /NonoGrid/`).

First minute
- First launch (tutorial flag unset) no longer opens the blocking card. A tip
  strip (`CoachStrip`, `FirstRunCoach`) sits above the board and never
  blocks input or the clock; gameplay starts immediately.
- Tips: 1 how clues work (names the full line when there is one), 2 marking
  empty cells (right-click wording on wide layouts, Mark X wording on
  narrow), 3 finished lines light up and Logic hint helps. Tip 1 advances on
  the first fill, tip 2 on the first X or completed line, tip 3 when Logic
  hint opens. Solving, the close button or reading the "?" card end it; the
  `tutorial_seen_v1` flag is stored then.
- The "?" button still opens the full How to play card with its existing
  keyboard, clock and gameplay-event behaviour.
- A new player's level 1 assignment uses `friendlyFirstSeed`: the drawn seed
  or one of the next 23 seeds derived from it whose puzzle has a fully filled
  line and at least three lines settled by their clue alone. The generator,
  other levels, dailies and legacy content do not change.
- Daily and Album stay on the first screen at every supported size.

Polish
- Board cells may grow to 84 px (was 64) and clue text to 20 px, so small
  boards fill desktop windows.
- Overlays ease in (180 ms fade/scale, opacity never below 0.25 so
  semantics stay). No new endless animation: effects tick only while active.
- Existing cell pop, line flash, mistake shake, confetti, picture reveal and
  sounds stay.

Out of scope: portal submission or portal websites, new store art, new
dependencies, gameplay rule changes.

## Acceptance Criteria
- Load: on the same machine and throttled network (10 Mbps, 40 ms RTT,
  uncompressed local server), the GamePix build reaches `flutter-first-frame`
  faster and with fewer bytes than the pre-change build; numbers are recorded
  in `reports/portal-quality-verification.md`.
- Removing `main.dart.mjs` from a built bundle still renders the game through
  the JavaScript retry (manual check, recorded in the report).
- Both portal scripts pass their self-checks, which now also require the wasm
  and JavaScript builds, the retry, subset fonts under 60 kB each, and (for
  GamePix) no `crazygames` or `bon-on.github.io` string in `main.dart.js`,
  `main.dart.wasm` or `main.dart.mjs`; CrazyGames forbids `bon-on.github.io`
  in the same files.
- Identical puzzles on every runtime: `test/web/generator_parity_test.dart`
  passes on the VM and on Chrome (dart2js), and `tool/check_runtime_parity.sh`
  prints the same fingerprints for VM, dart2js and dart2wasm (Node).
  (`flutter test --platform chrome --wasm` hung at loading on the dev machine,
  so the Node check is the required wasm evidence.)
- Unit tests cover `lineFixedByClue`, `isFriendlyFirstPuzzle`,
  `friendlyFirstSeed` (deterministic, 200/200 sampled seeds friendly and
  line-solvable), storage saving the friendly seed for level 1 only, and the
  `FirstRunCoach` transitions and tip text.
- Widget tests: first launch shows the strip and no card, a tap on the board
  fills a cell, the close button hides the strip and stores the flag; the
  flag set shows neither; a broken store still shows the strip; "?" card
  tests (steps, Skip/Escape, keys, clock, browser shortcuts, key repeat) keep
  passing; strip, card and board fit 390x844, 844x390, 1280x720 and 320x640.
- Platform flow: first launch sends `gameplayStart` at once; hiding tips is
  not a transition.
- Screenshots at 1280x720, 1366x768, 390x844 and 844x390 show no overflow,
  with Daily and Album visible (manual check, not committed).
- `flutter analyze`, `flutter test`, `flutter test --platform chrome
  test/web`, the Pages build and the harness audit (Critical 0) pass.

## Constraints
- No new pub dependency. fonttools is only a developer tool for
  `tool/subset_fonts.sh`; its output is committed.
- Gameplay, levels, dailies and saves must not change for existing players.
- Clue font never below 11 px; layouts must not overflow at the supported
  sizes.

## Evidence
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/check_runtime_parity.sh
- flutter build web --release --base-href /NonoGrid/
- tool/build_crazygames.sh and tool/build_gamepix.sh
- node <harness-lab>/dist/index.js audit . --format md
- reports/portal-quality-verification.md
