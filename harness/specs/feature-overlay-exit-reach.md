---
id: feature-overlay-exit-reach
title: Card buttons stay reachable on short and landscape phones
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-nono-grid-crazygames-web
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-analyze
  - flutter-tests
  - independent-review
---

# Feature Spec: Card buttons stay reachable on short and landscape phones

## Problem
On 2026-11-28 a player on GamePix mobile opened a Tiny Mines card that filled the screen and could not find a way back to the game.
The cause is shared by several games: a modal card scrolls as a whole, and its only exits (close, Skip, Next, result buttons) sit at the end of the scrolling content.
NonoGrid's How to play card had the same layout (Skip and Next below a whole-card scroll).
When the visible height is short (browser bars, a portal header, or landscape), the buttons are scrolled out of view and nothing tells the player to scroll.

## Scope
Each card below keeps its exits pinned outside the scrolling content (a `Column` with a `Flexible` `SingleChildScrollView` and a fixed header or footer):
- How to play: Skip and Next (every step)
- Paper themes: the header with its close button

The level summary, daily card, album and level map already pinned their exits; the logic hint is an AlertDialog with pinned actions.
Out of scope: card contents, keyboard shortcuts and gameplay.

## Acceptance Criteria
- X1: At 360x560, 320x480 and 640x300, every exit listed in Scope is fully on screen when the card opens, without scrolling, and tapping it calls its callback.
- X2: No layout exception at those sizes.
- X3: `flutter analyze` and `flutter test` pass.

## Constraints
- No new dependencies or assets. No gameplay, save or SDK changes.

## Requirement-to-check map
- X1, X2: `test/overlay_exit_reach_test.dart` (fails on the previous layout).
- X3: CI test command.

## Evidence
- Test run output in the commit's verification notes.
