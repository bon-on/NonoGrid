---
id: adr-line-solvable-generator
title: Generate levels from seeded random grids accepted only when line logic solves them
status: accepted
related_specs:
  - feature-nono-grid-mvp
---

# ADR: Generate levels from seeded random grids accepted only when line logic solves them

## Context
NonoGrid needs an unbounded number of levels that are fair: one solution,
reachable without guessing. Random grids frequently have several solutions.
Checking uniqueness with a general backtracking solver is expensive for 15x15
and still allows puzzles that need deep trial and error.

## Decision
- Line solver: for one line, a dynamic program over (cell index, clue index)
  computes which suffixes can still be completed, then a forward pass over
  reachable states records whether each cell can be filled and/or empty in any
  valid placement. Cells that are only ever filled (or only empty) are fixed.
  This equals full enumeration of placements at O(n^2 * k) per line, so no
  cache is needed. The grid solver re-runs dirty rows and columns until a
  fixpoint.
- Acceptance: a candidate solution is accepted only if the grid solver fixes
  every cell. Each line step only fixes cells forced in all solutions, so a
  fully solved grid has exactly one solution.
- Generation for level N: seed a xorshift32 PRNG with N, pick a target
  density in [0.50, 0.60), draw a random grid. While the solver stalls, flip
  one still-unknown cell of the picture (preferring the side that moves density
  toward the target) and retry, up to 2 * size^2 tweaks. If the result leaves
  [0.45, 0.68] density or the tweak budget runs out, restart with a new random
  grid (up to 40 attempts). As a last resort return a fixed frame-and-diagonal
  pattern that is always line-solvable (tests assert it is never used for the
  shipped level range).
- Levels 1-3 use hand-made pictures, which tests also verify are
  line-solvable.

## Alternatives considered
- Hand-made puzzles only: best pictures, but limited content and slow to add.
- Backtracking uniqueness check: proves uniqueness but accepts puzzles that
  need guessing, and is slower on 15x15.
- Left-most/right-most overlap only: cheaper, but weaker than the full
  per-line deduction and would reject many fair puzzles.
- `dart:math` `Random(seed)`: not guaranteed identical on VM and web.

## Consequences
- Every level is unique and solvable by pure line reasoning; difficulty is
  bounded (no puzzles that need contradiction/look-ahead reasoning).
- Generated pictures are abstract noise rather than drawings.
- Level content depends on the generator code: changing the PRNG, size ramp,
  density or tweak rule changes existing levels (and makes stored best times
  refer to different puzzles). Treat such changes as breaking and note them.
- Generation takes about a millisecond per level, so it runs synchronously on
  level load.
