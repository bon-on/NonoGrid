---
id: contract-nono-grid-mvp
title: Deliver the NonoGrid MVP with line-solvable generated levels
status: active
related_specs:
  - feature-logic-hints
  - feature-nono-grid-mvp
  - feature-how-to-play-tutorial
  - feature-game-hub-navigation
  - feature-sound-effects
  - feature-retention-polish
  - feature-random-practice
evidence_files:
  - reports/nono-grid-mvp-verification.md
---

# Contract: NonoGrid MVP

## Goal
Ship a playable web/mobile nonogram whose levels are generated
deterministically and are always uniquely solvable by line logic.

## Done Criteria
- Widget-free logic with unit tests for clues, line solver, grid solver,
  generator (levels 1..40, determinism), drag painting, undo and win.
- Widget smoke tests at phone and desktop sizes plus a full keyboard solve.
- Free mistake mode with an optional Check button, timer and best times,
  local progress, win reveal animation.
- `flutter analyze`, `flutter test`, release web build and harness audit pass;
  screenshots at 1280x720 and 390x844 reviewed.

## Verification
- flutter analyze
- flutter test
- flutter build web --release --base-href /NonoGrid/
- headless Chrome screenshots (1280x720, 390x844)
- harness audit

## Evidence References
- reports/nono-grid-mvp-verification.md
