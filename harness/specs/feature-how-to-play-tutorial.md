---
id: feature-how-to-play-tutorial
title: First-run how-to-play tutorial with skip
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-line-solvable-generator
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-tests
  - flutter-analyze
  - web-build
  - harness-audit
---

# Feature: First-run how-to-play tutorial with skip

## Problem
A new player gets no explanation of the goal, the controls or the key rules.
We want a short, skippable tutorial on the first launch only.

## Scope
- On the first launch (flag `tutorial_seen_v1` not set) a "How to play" overlay
  card appears over the dimmed game. It has 3 short steps shown one at a time,
  each with an icon, page dots, a "Skip" button and a "Next" button ("Play" on
  the last step).
- Skip or Play closes it and stores `tutorial_seen_v1` (bool,
  `shared_preferences`), so later launches go straight into the game.
- A "?" button (`Icons.help_outline`, tooltip "How to play") in the top bar reopens
  it at step 1 at any time without resetting the game.
- Keyboard while open: Enter/Space = Next/Play, Escape = Skip, Left/Right =
  previous/next step. No key reaches the game while it is open (arrows,
  Space, X, U, R, Enter), and taps, drags and right-clicks are blocked by the
  scrim.
- The puzzle clock does not count while it is open: opening it stops a running
  clock (and saves progress) and closing resumes it; on first launch the
  clock does not start until the player makes a move after closing it.
- Tab, F5 and Ctrl/Meta/Alt shortcuts are left unhandled while it is open so
  the browser keeps reload and focus behavior.
- Storage failures never break play: a read failure shows the tutorial, a write
  failure just closes it.
- Text is English.
- Implementation lives in `lib/src/ui/how_to_play.dart` (overlay + injectable
  `TutorialStore`).

## Acceptance Criteria
- With the flag unset the overlay shows on launch and taps and game keys do not
  change the game.
- Next walks the 3 steps, the last step shows Play, Play closes the overlay and
  stores the flag.
- Skip closes and stores the flag; Escape also skips.
- With the flag set the overlay does not appear on launch.
- "?" reopens at step 1 without resetting the board or progress.
- The elapsed time does not advance while the overlay is open and resumes after
  it closes.
- The card does not overflow at 390x844, 844x390 and 1280x720.
- Flutter analyze, flutter tests, web release build and harness audit pass.

## Constraints
- No new dependency (`shared_preferences` is already used).
- Layouts must not overflow at 390x844 and 1280x720.

## Evidence
- flutter test
- flutter analyze
- flutter build web --release --base-href /NonoGrid/
- harness-lab audit

## Update 2026-11-11 (feature-portal-quality-pass)

First launch no longer opens the card. A non-blocking tip strip coaches the
first puzzle instead and stores `tutorial_seen_v1` when it ends; the "?"
card keeps every behaviour above (steps, Skip/Escape, keys, clock pause,
browser shortcuts). Criteria about the card appearing on launch now apply
to the card opened with "?". See `feature-portal-quality-pass`.
