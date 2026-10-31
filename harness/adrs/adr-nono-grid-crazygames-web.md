---
id: adr-nono-grid-crazygames-web
title: Use a build flag and a platform adapter for the CrazyGames build
status: accepted
related_specs:
  - feature-nono-grid-crazygames
  - feature-sound-effects
---

# ADR: Use a build flag and a platform adapter for the CrazyGames build

## Context
CrazyGames serves the bundle from an unknown sub path inside an iframe and
needs SDK gameplay events, while GitHub Pages and mobile builds must stay
unchanged.

## Decision
- The compile-time constant `bool.fromEnvironment('CRAZYGAMES')` selects the
  CrazyGames build. Without it every build uses `NoopGamePlatform`.
- The game screen depends only on the `GamePlatform` interface. A conditional
  import (`dart.library.js_interop`) provides the `dart:js_interop` adapter
  on web; other targets get the no-op.
- The screen derives one "is playing" boolean from its state and calls the
  platform only when that boolean changes, so events never duplicate.
- The SDK script and relative base href are injected by
  `tool/build_crazygames.sh` into the build output, not into `web/index.html`.

## Alternatives
- Always load the SDK: breaks offline play and GitHub Pages behavior.
- Inject the script in `web/index.html`: would ship the SDK in every build.

## Consequences
- One codebase serves Pages, mobile and CrazyGames.
- The script relies on string replacement in `index.html` and therefore
  verifies its result and fails loudly.
