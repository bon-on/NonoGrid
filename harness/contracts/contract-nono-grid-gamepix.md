---
id: contract-nono-grid-gamepix
title: Deliver the NonoGrid GamePix web bundle
status: active
related_specs:
  - feature-daily-puzzle
  - feature-nono-grid-gamepix
  - feature-portal-quality-pass
evidence_files:
  - docs/gamepix.md
  - reports/nono-grid-gamepix-verification.md
---

# Contract: NonoGrid GamePix web bundle

## Goal
Produce an upload-ready GamePix bundle (SDK-free, relative resources) from the
same Flutter codebase without changing gameplay.

## Done Criteria
- `flutter analyze` and `flutter test` pass.
- `tool/build_gamepix.sh` succeeds and writes `build/nono-grid-gamepix.zip` with
  index.html at the zip root.
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
