---
id: contract-nono-grid-crazygames
title: Deliver the NonoGrid CrazyGames web bundle
status: active
related_specs:
  - feature-daily-puzzle
  - feature-nono-grid-crazygames
  - feature-sound-effects
  - feature-retention-polish
  - feature-crazygames-cloud-save
  - feature-portal-quality-pass
evidence_files:
  - docs/crazygames.md
  - reports/nono-grid-crazygames-verification.md
---

# Contract: NonoGrid CrazyGames web bundle

## Goal
Produce an upload-ready CrazyGames bundle from the same Flutter codebase,
without changing the Pages or mobile builds.

## Done Criteria
- `flutter analyze` and `flutter test` pass.
- `tool/build_crazygames.sh` succeeds and writes `build/nono-grid-crazygames.zip`.
- The Pages build output contains no CrazyGames SDK script.
- Results are recorded in `reports/nono-grid-crazygames-verification.md`.

## Verification
- flutter analyze
- flutter test
- flutter test --platform chrome test/web
- tool/build_crazygames.sh
- flutter build web --release --base-href /NonoGrid/
- harness audit

## Evidence References
- docs/crazygames.md
- reports/nono-grid-crazygames-verification.md
