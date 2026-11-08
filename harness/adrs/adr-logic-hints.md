---
id: adr-logic-hints
title: Derive explainable hints from current marks and line constraints
status: accepted
related_specs:
  - feature-logic-hints
---

## Context
Players need reasoning help without a hidden-solution reveal disguised as logic.

## Decision
Reuse solveLine on all current rows and columns. Filled and crossed marks are
assumptions; untouched cells are unknown. Reject any direct line contradiction
before proposing a forced cell. Return one immediate line deduction, with its
source clue and coordinates, without modifying the board. A separate Apply
step uses ordinary game input and persistence. Explain that current marks are
assumed correct and Logic hint does not change stars; Check retains its rule.

## Alternatives
Revealing a solution cell does not explain reasoning. Full search could resolve
more states but adds complexity and cannot explain a single line deduction.

## Consequences
This detects direct line contradictions, not all globally inconsistent partial
boards. It can legitimately find no immediate step; players can undo marks or
use Check. Generation, seed assignments, stars and XP remain unchanged.
