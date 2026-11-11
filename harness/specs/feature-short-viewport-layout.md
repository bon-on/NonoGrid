---
id: feature-short-viewport-layout
title: Short viewport layout - board first in small portal iframes
status: active
owner: games
related_adrs:
  - adr-nono-grid-crazygames-web
  - adr-nono-grid-gamepix-web
related_contracts:
  - contract-nono-grid-crazygames
  - contract-nono-grid-gamepix
required_evidence:
  - flutter-tests
  - flutter-analyze
  - chrome-tests
  - portal-builds
  - harness-audit
---

# Feature: Short viewport layout

## Problem
The GamePix preview "Small" frame (620x349, landscape) used the stacked phone
layout because it is narrower than the 700 px side-panel layout. The header,
Level/XP card, Levels/Album/Themes row and Daily card took almost all of the
height, the board shrank to about 50 px and its clues painted over the hint
text: the game was unplayable. GamePix requires the game to work in at least
a 640x480 iframe and CrazyGames iframes vary in size. The portal quality pass
(`feature-portal-quality-pass`) only checked 1280x720, 1366x768, 390x844 and
844x390.

## Scope
Layout selection (`screenLayoutFor`)
- `wide` (unchanged): width >= 700 and width > 1.3 x height. Info panel,
  board, tool panel.
- `compact` (new): any other landscape window (width > height) shorter than
  560 px, e.g. 620x349, 600x338, 560x315, 640x480, 667x375. Board first: a
  slim info column (level nav, clock, compact Daily card, Levels/Album/Themes
  as one row of icon buttons with tooltips and semantics labels, XP, sound
  and "?"), the board in the middle with all remaining width and height, and
  a slim tool column (dense Fill, Mark X, Undo, Logic hint, Check, Restart;
  the win box when solved). Below 600 px width the tool column shows icons
  only (labels stay as tooltips and semantics labels) and the win box shows
  the time and an icon Next button, so 15x15 boards keep their clue font.
  Check and other short messages appear in the info column. No key hint
  text.
- `stacked` (unchanged arrangement) for portrait and square windows. Below
  700 px height it folds the Daily card and the Levels/Album/Themes icon
  buttons into one row and shows Undo, Check and Restart as icon buttons.
- In the `wide` layout an info panel shorter than 600 px shows the
  Levels/Album/Themes icon row under the Daily card instead of labelled
  buttons at the bottom, so every menu stays reachable without scrolling.

Board fit
- The board canvas is scaled down (FittedBox) only when its minimum size
  (8 px cells, 11 px clue font) does not fit its box, so it never paints over
  neighbouring controls; pointer input follows the scale. At the supported
  sizes it is not scaled, with one accepted exception: while the first-run
  tip strip is shown (first session only, before the tutorial flag is
  stored) a 12x12 or 15x15 board may scale down at 560x315 and 320x568.

First-run coach
- The tip strip stays above the board in every layout and never overlaps it.
  The strip is painted after the board so the card's tape tucks under it.

Overlays
- The level map shrinks its node area on windows under 410 px high so the
  header and page buttons stay on screen (560x315 overflowed by 26 px).

Out of scope: game rules, saves, generators, dailies, portal submission,
portal websites, new dependencies.

## Acceptance Criteria
- `screenLayoutFor` returns `compact` for 620x349, 640x480, 600x338,
  560x315, 667x375; `wide` for 844x390, 932x430, 870x480, 1280x720,
  1366x768; `stacked` for 800x700, 360x640, 390x844, 320x568.
- Widget tests (`test/short_viewport_layout_test.dart`) at 620x349, 600x338,
  560x315, 640x480, 667x375, 844x390, 932x430, 870x480, 360x640, 390x844,
  320x568, 1280x720 and 1366x768, with and without the first-run strip:
  no Flutter error or overflow; the board canvas lies inside the window and
  does not intersect Levels, Album, Themes, Daily, Fill, Mark X, Logic hint,
  "?" or the strip; those controls are hit-testable; the 5x5 canvas is
  unscaled and at least 240 px tall at 620x349 (230 at 600x338, 210 at
  560x315, 260 at 640x480/667x375, 300 at 844x390), and with the strip at
  least 75 % of that; a tap on the bottom-right cell fills it.
- 15x15 boards (level 60) with the strip at 620x349, 600x338, 560x315,
  640x480, 667x375, 844x390 and 320x568: no overlap, canvas inside its box,
  at least 150 px tall (scaled down if needed).
- Levels 31-200 at 560x315, 600x338, 620x349, 640x480, 667x375 and 844x390
  are never scaled and keep the clue font at 11 px or more (with the strip
  too from 600 px width).
- On a scaled-down board (320x568, level 60, strip shown) taps on cells
  (14,14), (3,7) and (0,0) fill exactly those cells.
- Icon-only buttons expose Levels, Album, Themes, Fill, Mark X, Undo,
  Logic hint, Check and Restart as semantics labels and tooltips at 560x315;
  a Check message appears on screen there.
- Levels, Album, Themes and Daily overlays open from the compact panel at
  620x349 and 560x315 without overflow.
- Existing tests keep passing (390x844, 844x390, 1280x720, 320x640 strip and
  card fit; text-label tool tests on 390x844 and 1280x720).
- Real screenshots of the GamePix build in headless Chrome (audio muted) at
  all sizes above show the board first, no overlap or overflow, Daily and
  Levels/Album/Themes visible (manual, not committed; recorded in
  `reports/short-viewport-layout-verification.md`).
- `flutter analyze`, `flutter test`, `flutter test --platform chrome
  test/web`, `tool/check_runtime_parity.sh`, both portal build scripts
  (self-checks pass; GamePix build has no `crazygames` or `bon-on.github.io`)
  and the harness audit (Critical 0) pass.

## Constraints
- No new dependency; no change to game rules, saves, generators or dailies.
- Clue font never below 11 px at the supported sizes (the FittedBox fallback
  only applies below them, apart from the first-run strip exception above).
- Icon-only buttons keep their label as tooltip and semantics label.

## Evidence
- flutter analyze
- flutter test (incl. test/short_viewport_layout_test.dart)
- flutter test --platform chrome test/web
- tool/check_runtime_parity.sh
- tool/build_gamepix.sh and tool/build_crazygames.sh
- node <harness-lab>/dist/index.js audit . --format md
- reports/short-viewport-layout-verification.md
