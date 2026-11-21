---
id: feature-large-screen-scale
title: Large screen scale - the wide layout grows with fullscreen and big windows
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
  - portal-builds
  - harness-audit
---

# Feature: Large screen scale

## Problem
The wide layout uses fixed logical sizes: the info panel is at most 270 px, the tool panel 236 px, and the board
card has its own cap. In fullscreen (1920x1080) the 5x5 board covers a small square in the middle, the panels'
text looks tiny and most of the desk is empty. CrazyGames reviewers and players use fullscreen.

## Scope
1. Wide windows larger than the 1280x720 design size lay the wide layout out at `size / scale` and scale it up
   uniformly, `scale = min(width / 1280, height / 720)` clamped to 1..1.6. Inside the scaled subtree `MediaQuery`
   reports the unscaled layout size, so every size rule keeps working as at 1280x720.
2. The same widget structure is used at scale 1, so entering or leaving fullscreen does not remount the layout.
3. Windows at or below 1280x720, the compact and the stacked layouts are unchanged. Overlays (summary, album, levels,
   themes, logic hint, daily, tutorial) and the desk scenery stay at their own size.
4. Input (tap, drag painting, right click, keys) works unchanged in the scaled layout.
5. The scale uses the SafeArea box. It overrides the "unscaled canvas" clause of `feature-short-viewport-layout` for
   these windows: that clause now means "never scaled down". A 1366x768 iframe gets about 1.07x and a 1366x1024 tablet
   (SafeArea 1366x980) about 1.07x as well.
6. Tooltips are drawn by the root overlay at their own (1x) size next to scaled buttons; accepted.

## Acceptance Criteria
- 1920x1080: the board is 1.5x its 1280x720 size, at the scaled position; no overflow.
- 1280x720 and 1100x620: identical board size.
- 2560x1440 capped at 1.6x; ultra-wide windows do not overflow.
- A tap and a drag in the scaled layout fill the cells under the pointer.

## Constraints
- No new package or asset.

## Plan and check mapping
| Requirement | Files | Verification |
|---|---|---|
| Scale rule and scaled wide layout | `lib/src/ui/game_screen.dart` | `test/large_screen_scale_test.dart` |
