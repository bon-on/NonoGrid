---
id: feature-nono-grid-mvp
title: NonoGrid MVP - generated line-solvable nonogram levels
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - screenshots
  - harness-audit
---

# Feature: NonoGrid MVP - generated line-solvable nonogram levels

## Problem
We want a small nonogram (paint-by-numbers logic puzzle) that runs in the
browser and on phones, never runs out of levels, and never forces the player
to guess. Hand-authoring enough puzzles is slow, and random grids are often
ambiguous (more than one picture fits the clues).

## Scope
- In scope:
  - Square grid with row/column run clues; a clue line dims once the player's
    filled runs in that line match it.
  - Tap or click to fill; a Fill / Mark X mode toggle; right-click marks X on
    desktop. Drag paints a straight stroke locked to the row or column of the
    first cell it moves into. A stroke only changes cells that share the start
    cell's original state, so fills never overwrite X marks and vice versa.
  - Undo (one stroke per step), Restart, and an optional Check button that
    briefly highlights wrong fills and reports how many there are.
  - Mistake policy: free mode (no hearts). Every puzzle is uniquely solvable
    by line logic, so mistakes are always recoverable by reasoning; a heart
    limit would punish exploration and push players to guess, and the timer
    already rewards clean play. Check is opt-in and has no penalty.
  - Levels: level N uses seed N. Levels 1-3 are hand-made pictures (Heart,
    Arrow, House); later levels are generated. Sizes ramp 5x5 (1-6), 7x7
    (7-12), 8x8 (13-20), 10x10 (21-30), 12x12 (31-45), 15x15 (46+).
    Fill density target 50-60%, accepted range 45-68% after tweaks.
  - Every puzzle must be fully solvable by the line solver (see
    `adr-line-solvable-generator`), which implies a unique solution.
  - Local progress via shared_preferences: current level, highest cleared
    level, best time per level, and the in-progress board plus elapsed time
    for one level (the last one played; browsing other levels keeps it).
    The clock pauses while the app or tab is hidden.
  - Timer per puzzle (starts on first move), best times, win reveal animation
    that recolors the picture cell by cell and hides grid lines and X marks.
  - Layout fits phone portrait (390x844) and desktop landscape (1280x720):
    board centered, scaled to fit, clue font at least 11 px, thicker lines
    every 5 cells.
  - Keyboard: arrows move a cursor, Space fills, X marks, U undoes, R
    restarts, Enter goes to the next level after a win.
- Out of scope (v1): ads, network, leaderboards, accounts, hint system,
  rectangular grids, colored nonograms, games hub navigation.

## Acceptance Criteria
- `runsOf` / `Clues.fromSolution` produce correct run clues (empty line = 0).
- `solveLine` matches brute-force enumeration on random lines, returns `null`
  on contradictions, and fixes exactly the cells common to all placements.
- `solveGrid` leaves ambiguous puzzles unsolved; every grid it fully solves
  has exactly one solution (checked by backtracking on random 5x5 grids).
- Levels 1..40 (and 46..60 at 15x15) are line-solvable, within the density
  range, never use the fallback pattern, and generate in under 5 s total.
- The same level always yields the same puzzle; neighbouring levels differ;
  golden values pin the PRNG output and levels 4, 21 and 50.
- Drag painting: axis lock, gap filling on pointer jumps, segment shrink on
  drag-back, start-state-only changes; one undo step per stroke.
- Win is detected when all row and column clues match; input and undo are
  ignored after the win; crosses do not block a win.
- Widget tests: app renders at 390x844 and 1280x720 without overflow, a tap
  saves progress, saved progress restores, a 15x15 level with two-digit
  clues fits both sizes, solving level 1 by keyboard shows
  the win bar and unlocks level 2.
- `flutter analyze` reports no issues, `flutter test` passes,
  `flutter build web --release --base-href /NonoGrid/` succeeds.
- No third-party trademarked genre name appears in the repository (the game
  says "nonogram").

## Constraints
- Game logic lives in widget-free files under `lib/src/logic/`.
- Dependencies: Flutter SDK and shared_preferences only.
- Puzzle generation must be deterministic across the Dart VM and the web, so
  it uses its own 32-bit xorshift PRNG instead of `dart:math` `Random`.
- No network access, no secrets, no personal paths in the repository.

## Stack Notes
- Flutter 3.41 stable, Dart 3.11. Targets: web, iOS, Android.
- GitHub Pages deploy via `.github/workflows/deploy-pages.yml`
  (`--base-href /NonoGrid/`).

## Evidence
- reports/nono-grid-mvp-verification.md

## Amendment: key auto-repeat
Key auto-repeat only moves the cursor with the arrow keys; Space, X, U, R and Enter act once per key press.
