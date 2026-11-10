---
id: feature-nono-grid-gamepix
title: NonoGrid GamePix web distribution
status: active
owner: games
related_adrs:
  - adr-nono-grid-gamepix-web
related_contracts:
  - contract-nono-grid-gamepix
required_evidence:
  - flutter-tests
  - flutter-analyze
  - gamepix-web-build
  - harness-audit
---

# Feature: NonoGrid GamePix web distribution

## Problem
GamePix accepts HTML5 games that load only their own relative resources and
use no third-party SDK. The CrazyGames bundle ships the CrazyGames SDK script
and Flutter web fetches Roboto from fonts.gstatic.com at runtime, so neither
can be uploaded to GamePix as is.

## Scope
- `--dart-define=GAMEPIX=true` selects the no-op `GamePlatform`. It wins over
  `CRAZYGAMES`; the CrazyGames adapter is selected only when `CRAZYGAMES=true`
  and `GAMEPIX` is not set.
- `GamePlatform.allowsAds` and `allowsResultRegistration` are `false` (this
  game has no ads, leaderboard or result upload, and no hub navigation bar).
- Roboto (400/500/700/900) is bundled in `assets/fonts/` for every build, so
  no build requests fonts.gstatic.com for Roboto. The license file sits next to it.
- `web/index.html`: viewport meta with `user-scalable=no`, `touch-action: none`,
  and a CSS loader (spinner and title) removed on the first Flutter frame.
- `tool/build_gamepix.sh` builds `build/gamepix/` and
  `build/nono-grid-gamepix.zip` (index.html at the zip root) with relative
  `<base href="./">`, no CrazyGames SDK script, no outbound URLs, Roboto in
  `FontManifest.json`.
- Progress is stored in localStorage through shared_preferences, which GamePix
  syncs automatically. No code is needed (see `docs/gamepix.md`).
- UI strings use only characters Roboto covers (ASCII). `tool/build_gamepix.sh`
  fails on non-ASCII characters in `lib/**/*.dart`, because a missing glyph makes
  Flutter fetch a fallback font from fonts.gstatic.com.
  NonoGrid: the U+00B7 separators in the hint line were replaced by `-`.

Out of scope: GamePix SDK integration, ads, gameplay changes, portal submission.

## Acceptance Criteria
- `flutter analyze` and `flutter test` pass.
- `flutter test --platform chrome test/web` passes with and without
  `--dart-define=GAMEPIX=true --dart-define=CRAZYGAMES=true`; with GAMEPIX the
  platform is the no-op one, never the CrazyGames adapter.
- `tool/build_gamepix.sh` passes its self-checks and `main.dart.js` has no
  `crazygames` string.
- `tool/build_crazygames.sh` and the Pages build still work.
- Headless Chrome at 640x480 and 360x640 shows no overflow or clipping.

## Constraints
- Gameplay, levels and persistence do not change.
- No new pub dependency.
- Portal builds are English only; no CJK fonts are bundled.

## Evidence
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/build_gamepix.sh
- tool/build_crazygames.sh
- node <harness-lab>/dist/index.js audit . --format md
- reports/nono-grid-gamepix-verification.md

## Update 2026-11-11 (feature-portal-quality-pass)

The GamePix bundle is built with `--wasm` (JavaScript fallback kept). The
`crazygames` / `bon-on.github.io` string checks cover `main.dart.js`,
`main.dart.wasm` and `main.dart.mjs`.
