---
id: contract-nono-grid-gamepix
title: Deliver the NonoGrid GamePix web bundle
status: active
related_specs:
  - feature-daily-puzzle
  - feature-nono-grid-gamepix
  - feature-gamepix-sdk
  - feature-portal-quality-pass
  - feature-short-viewport-layout
  - feature-large-screen-scale
evidence_files:
  - docs/gamepix.md
  - reports/nono-grid-gamepix-verification.md
---

# Contract: NonoGrid GamePix web bundle

## Goal
Produce an upload-ready GamePix bundle (GamePix SDK v3 as the only external
script, relative resources) from the same Flutter codebase without changing
gameplay (feature-gamepix-sdk).

## Done Criteria
- `flutter analyze` and `flutter test` pass.
- `tool/build_gamepix.sh` succeeds and writes `build/nono-grid-gamepix.zip` with
  index.html at the zip root.
- `index.html` loads the GamePix SDK exactly once, after `GamePixConfig`, before
  the Flutter bootstrap, and no other script or external URL.
- `grep -c GamePix build/crazygames/main.dart.js` is 0 (`tool/build_crazygames.sh`).
- The GamePix `main.dart.js` has no `crazygames` string and `FontManifest.json`
  lists Roboto.
- Results are recorded in `reports/nono-grid-gamepix-verification.md`.

## Verification
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/build_gamepix.sh
- tool/build_crazygames.sh
- harness audit

## Evidence References
- docs/gamepix.md
- reports/nono-grid-gamepix-verification.md
