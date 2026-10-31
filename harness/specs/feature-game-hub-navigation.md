---
id: feature-game-hub-navigation
title: Always-visible return link to the game hub
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-nono-grid-mvp
required_evidence:
  - flutter-tests
  - web-build
  - harness-audit
---

# Feature: Return to the game hub

## Problem
Players who launch NonoGrid from the Bon-on hub (https://bon-on.github.io/) have no way back to the game list other than the browser history.

## Scope
- Reserve a separate navigation bar above the web game with a "← 게임 목록" link on its left, matching the other Bon-on games.
- Navigate directly to https://bon-on.github.io/ without relying on browser history.
- Render Flutter into `#flutter-host` (via `web/flutter_bootstrap.js`), which starts below the bar, so Flutter sizes itself to the remaining area and the bar never covers the game.
- Keep native mobile behavior and game rules unchanged.

## Acceptance Criteria
- The GitHub Pages entry point contains an accessible link to the Bon-on hub.
- The bar stays visible above the Flutter surface, respects mobile safe areas and reserves its own layout space; the loading screen starts below it.
- The CrazyGames and GamePix bundles strip the bar and reset its height at build time (portals forbid outbound links); their build scripts fail if the bar remains.
- Flutter tests, the web builds and harness audit pass.

## Constraints
- Static web shell only; no runtime dependency, no gameplay change.

## Evidence
- flutter test
- flutter build web --release, tool/build_crazygames.sh, tool/build_gamepix.sh
- harness audit
