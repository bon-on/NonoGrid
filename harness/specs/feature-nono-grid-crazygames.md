---
id: feature-nono-grid-crazygames
title: NonoGrid CrazyGames web distribution
status: active
owner: games
related_adrs:
  - adr-nono-grid-crazygames-web
related_contracts:
  - contract-nono-grid-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - crazygames-web-build
  - harness-audit
---

# Feature: NonoGrid CrazyGames web distribution

## Problem
The web build only runs on GitHub Pages. To upload it to CrazyGames the game
needs the HTML5 SDK v3 gameplay events, a relative-path bundle and no
outbound links or ads.

## Scope
- Only a web build made with `--dart-define=CRAZYGAMES=true` talks to the
  CrazyGames SDK. The GitHub Pages build (`--base-href /NonoGrid/`) and the mobile
  builds keep a no-op platform and behave exactly as before.
- `GamePlatform` interface (`initialize`, `gameplayStart`, `gameplayStop`), a
  no-op default and a `dart:js_interop` CrazyGames adapter.
- `SDK.init()` with a timeout; the SDK is used only when `environment` is
  `crazygames` or `local`. Missing SDK, rejected or hung init, or a throwing
  call downgrade to no-op.
- Gameplay events, sent on transitions only (never duplicated):
  - `gameplayStart` when the player is actually playing: the tutorial flag has
    been read, the how-to-play overlay is closed and the puzzle is not cleared.
  - `gameplayStop` when the how-to-play overlay opens (first launch or the
    "?" button) and when the puzzle is cleared.
  - `gameplayStart` again when the overlay closes, and when the next
    puzzle starts after a clear.
  - On first launch the start is sent only after the tutorial is closed.
  - The solve timer behaves as before: it already pauses while the overlay is open.
- No ads (Basic Launch forbids them; this game never had any) and no
  leaderboard or external result upload exist in this game, so nothing else is
  disabled in the CrazyGames build. There is no hub navigation bar to remove.
- `web/index.html` gets `user-select: none` and touch rules so text is not
  selected while playing (also applies to GitHub Pages).
- `tool/build_crazygames.sh` builds `build/crazygames/` and
  `build/nono-grid-crazygames.zip` with a relative `<base href="./">`, the SDK
  script before `flutter_bootstrap.js`, no `*.symbols`, at most 1500 files and
  50MB.

Out of scope: ads, gameplay changes, portal submission. (Data/User modules were introduced later only for progress saving, see
`feature-crazygames-cloud-save`.)

## Acceptance Criteria
- Losing app/tab focus stops SDK gameplay once and pauses active timers/simulation; resume starts only when no tutorial/menu/result is open. Lifecycle transitions never duplicate events.
- `flutter analyze` and `flutter test` pass.
- A widget test with a recording fake platform shows the call order: start
  after launch (when the tutorial is already seen), stop while the overlay is
  open, start after it closes, stop on clear, start on the next puzzle; first
  launch sends no start until the overlay closes; restart while playing sends
  no duplicate.
- Browser tests (`flutter test --platform chrome test/web`) cover: missing
  SDK, `disabled` environment, rejected and hung init, gameplay events.
- `tool/build_crazygames.sh` produces the zip and passes its self-checks.
- `flutter build web --release --base-href /NonoGrid/` output has no CrazyGames SDK
  script.

## Constraints
- Gameplay, levels and persistence do not change.
- Gameplay must work without the SDK or network.
- No new pub dependency (`dart:js_interop` only).

## Evidence
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/build_crazygames.sh
- node <harness-lab>/dist/index.js audit . --format md
- reports/nono-grid-crazygames-verification.md

## Launch hardening — 2026-11-06

The screen observes app lifecycle so hidden or inactive tabs pause play and sound, then resume only an active run. Widget regression checks cover background/resume and overlays.
Short landscape tool panels use compact controls and spacing so the Logic hint action does not push sound/help below the viewport. Existing 844x390 layout regression must pass.

## Update 2026-11-11 (feature-portal-quality-pass)

First launch shows a non-blocking tip strip instead of the card, so
`gameplayStart` is sent right after launch; the "?" card still stops and
restarts gameplay. Portal builds now use `--wasm` with a JavaScript fallback
(`adr-web-wasm-portal-build`).
