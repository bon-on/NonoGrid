---
id: feature-size-ramp-6x6
title: Add a 6x6 step between 5x5 and 7x7 without changing puzzles players already hold
status: active
owner: games
related_adrs:
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - runtime-parity
  - web-build
---

## Problem
The ramp jumps from 5x5 (levels 1-6) straight to 7x7 (levels 7-12). 7x7 doubles the clue density
and is where new players stall.

## Scope
New ramp: levels 1-4 are 5x5, 5-8 are 6x6, 9-12 are 7x7. Level 13 and up are unchanged (8x8 to
20, 10x10 to 30, 12x12 to 45, 15x15 beyond). Generator, PRNG, density and tweak rule are unchanged.

Puzzles a player already holds must not change (`adr-line-solvable-generator` calls ramp changes
breaking): `NonoProgressData.puzzleSizes` records the size when a level is assigned. A level with a
seed, a legacy level or a solved level that has no recorded size keeps the old size
(`legacySizeForLevel`). Only levels assigned after this change use `sizeForLevel`. The Daily puzzle
and random practice sizes are unchanged.

## Acceptance Criteria
- `sizeForLevel` returns 5,5,5,5,6,6,6,6,7 for levels 1-9 and the old sizes from level 13.
- A saved game with seeds for levels 5-7 and no `puzzleSizes` loads the same 5x5/5x5/7x7 puzzles,
  stars, XP and clear size as before.
- New assignments store their size; reopening gives the same puzzle. A damaged size entry is
  ignored (old size).
- Levels 1-60 are line-solvable at their size; VM, dart2js and dart2wasm produce identical puzzles
  (`tool/check_runtime_parity.sh`), and the pinned parity hash is updated.
- Layouts at 390x844, 1280x720 and short viewports are unchanged (6x6 is smaller than 7x7).

## Plan / check mapping
| Requirement | Owner / files | Verification |
| --- | --- | --- |
| Ramp and legacy ramp | `lib/src/logic/puzzle.dart` | `test/random_assignment_test.dart` |
| Size per assignment | `lib/src/storage.dart` | `test/random_assignment_test.dart` |
| Cross-runtime identity | parity tool and test | `tool/check_runtime_parity.sh` |
