---
id: adr-nono-grid-gamepix-web
title: Select the GamePix build with a GAMEPIX flag and the no-op platform
status: accepted
related_specs:
  - feature-daily-puzzle
  - feature-nono-grid-gamepix
  - feature-retention-polish
  - feature-portal-quality-pass
---

# ADR: Select the GamePix build with a GAMEPIX flag and the no-op platform

## Context
GamePix forbids third-party SDKs and external requests. The CrazyGames build
already exists and uses `CRAZYGAMES=true`. Flutter web also downloads Roboto
from fonts.gstatic.com unless a Roboto family is bundled.

## Decision
- `bool.fromEnvironment('GAMEPIX')` selects `NoopGamePlatform`; it takes
  precedence over `CRAZYGAMES`. Both are compile-time constants, so the
  CrazyGames adapter is tree-shaken out of the GamePix bundle.
- `GamePlatform` exposes `allowsAds` and `allowsResultRegistration`, both false.
- Roboto is bundled in every build instead of only the portal build, so all
  builds behave the same.
- `tool/build_gamepix.sh` adds no SDK script and verifies the result.

## Alternatives
- Reuse the CrazyGames build: ships the CrazyGames SDK, rejected by GamePix.
- Bundle Roboto only for GamePix: two font behaviors to maintain.

## Consequences
- Pages, CrazyGames and GamePix builds share one codebase.
- The app grows by about 0.7MB (also in mobile builds, which supersedes the "mobile unchanged" wording of the CrazyGames contract) for the Roboto files.
