---
id: adr-nono-grid-gamepix-web
title: Select the GamePix build with a GAMEPIX flag
status: accepted
related_specs:
  - feature-daily-puzzle
  - feature-nono-grid-gamepix
  - feature-retention-polish
  - feature-portal-quality-pass
  - feature-short-viewport-layout
  - feature-large-screen-scale
---

# ADR: Select the GamePix build with a GAMEPIX flag

## Context
GamePix first accepted only SDK-free games with no external requests
(superseded by adr-gamepix-sdk, which adds the GamePix SDK v3). The CrazyGames build
already exists and uses `CRAZYGAMES=true`. Flutter web also downloads Roboto
from fonts.gstatic.com unless a Roboto family is bundled.

## Decision
- `bool.fromEnvironment('GAMEPIX')` selects the GamePix platform (first the
  no-op `NoopGamePlatform`, now `GamePixPlatform` per adr-gamepix-sdk); it takes
  precedence over `CRAZYGAMES`. Both are compile-time constants, so the
  CrazyGames adapter is tree-shaken out of the GamePix bundle.
- `GamePlatform` exposes `allowsAds` and `allowsResultRegistration`, both false.
- Roboto is bundled in every build instead of only the portal build, so all
  builds behave the same.
- `tool/build_gamepix.sh` adds no CrazyGames SDK script and verifies the
  result (it now also injects the GamePix SDK, see adr-gamepix-sdk).

## Alternatives
- Reuse the CrazyGames build: ships the CrazyGames SDK, rejected by GamePix.
- Bundle Roboto only for GamePix: two font behaviors to maintain.

## Consequences
- Pages, CrazyGames and GamePix builds share one codebase.
- The app grows by about 0.7MB (also in mobile builds, which supersedes the "mobile unchanged" wording of the CrazyGames contract) for the Roboto files.
