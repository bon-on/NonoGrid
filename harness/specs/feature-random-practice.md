---
id: feature-random-practice
title: Persist randomized level assignments and resume unfinished play
status: active
owner: games
related_adrs:
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-tests
  - flutter-analyze
  - web-build
  - portal-builds
  - harness-audit
---

## Problem
Fresh installs always start with the same curated level 1 puzzle. The user explicitly wants random puzzles as the default, matched to level difficulty, with existing sessions continuing unchanged. There is no separate practice mode.

## Scope
- Assign and persist a random nonzero 32-bit seed on first opening a new level. Generate at sizeForLevel(level) using the existing line-solvable generator with that independent seed; bypass curated pictures for newly assigned levels.
- Reopening/restarting/replaying an assigned level regenerates the same puzzle from its saved seed. Switching levels never replaces an existing assignment.
- Persist assignments in the same nonogrid_progress_v2 JSON envelope as current level, marks, time, mistakes, stars and records. New installations get randomized level 1; old saves preserve the original puzzles for previously exposed levels so saved boards/best times/album remain valid.
- Startup resumes a valid unfinished saved board first. Without unfinished progress on the selected level, an already cleared selection advances to maxCleared + 1. Explicit in-session replay remains available.
- Board, result, album and level-map thumbnails use the actual assigned puzzle. No random/practice mode UI or separate reward system; stars/XP/unlocks work normally.

## Acceptance Criteria
- Two fresh sessions with injected different seed sources get different level 1 solutions; fixed seed source is reproducible on VM/web.
- Randomized puzzles at all existing sizes are line-solvable. Default puzzleForLevel/generatePuzzle calls keep historical deterministic solutions for migration.
- Save marks/time/mistakes, reopen storage and app: identical puzzle and board resume. Restart and replay preserve seed; next new level gets a new assignment.
- Clear a level, close before Next, reopen: next unfinished level starts. An unfinished replay of a cleared level resumes rather than skips.
- Legacy v1 and v2 saves retain exposed levels, solved records, saved boards and album pictures; invalid optional seed data does not crash or silently attach marks to a different puzzle.
- Thumbnail caching distinguishes assigned solutions and does not allocate assignments for unopened locked levels.
- Existing keyboard, overlays, portal storage and layouts continue working. Analyze, VM/muted Chrome tests, Pages/both portal builds and audit pass. Independent review has no open Critical/High findings.

## Plan / check mapping
| Requirement | Owner / files | Check |
|---|---|---|
| Seeded generation, assignment persistence, legacy migration, startup continuation | storage worker: storage.dart, puzzle.dart, dedicated tests | storage/generator regression tests |
| UI uses assigned puzzles; thumbnails match actual puzzle | coordinator: game_screen.dart, overlays.dart, picture_thumb.dart, integration tests | widget resume/album tests |
| Spec/ADR/docs and verification | coordinator | all checks + independent harness-review |

## Constraints
No new dependencies, no external runtime calls, English ASCII lib strings. Puzzle randomness uses SeededRng. Existing generator density/tweaks and legacy numbered puzzle content stay unchanged; only new assignments use independent seeds. Portal uploads are outside this implementation task.

## Evidence
- flutter analyze --no-pub
- flutter test --no-pub
- flutter test --no-pub --platform chrome test/web (muted Chrome)
- flutter build web --release --base-href /NonoGrid/
- tool/build_crazygames.sh and tool/build_gamepix.sh
- node <harness-lab>/dist/index.js audit . --format md

## Update 2026-11-11 (feature-portal-quality-pass)

A new level 1 assignment saves `friendlyFirstSeed(drawn seed)`: the drawn
seed or a seed derived from it whose puzzle has a fully filled line and at
least three lines settled by their clue alone. Other levels keep the drawn
seed; the generator is unchanged.
