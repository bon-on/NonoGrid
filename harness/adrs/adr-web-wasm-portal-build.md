---
id: adr-web-wasm-portal-build
title: Ship portal builds as WebAssembly with a JavaScript fallback
status: accepted
related_specs:
  - feature-portal-quality-pass
  - feature-nono-grid-crazygames
  - feature-nono-grid-gamepix
---

# ADR: Ship portal builds as WebAssembly with a JavaScript fallback

## Context
CrazyGames QA measured a 16.1 s load. Before the first frame the JavaScript
build downloads `main.dart.js` (2.1 MB), CanvasKit (5.5 MB on Chromium) and
every bundled font (0.7 MB). Locally at 10 Mbps / 40 ms that is 8.26 MB and
7.2 s. The bundle also carried renderer variants the JavaScript build never
loads.

## Decision
- `tool/build_crazygames.sh` and `tool/build_gamepix.sh` build with
  `flutter build web --wasm`. With Flutter's default wasm allow list only
  Chromium (Blink) browsers load `main.dart.wasm` (1.7 MB) and `skwasm.wasm`
  (3.4 MB; `skwasm_heavy` where codecs or break iterators are missing).
  Firefox, Safari and older browsers use the dart2js + CanvasKit build in the
  same bundle (about 7.7 MB with subset fonts). Opting Gecko/WebKit in
  (`wasmAllowList`) was not done because it cannot be verified here.
- `web/flutter_bootstrap.js` catches a start that rejects before the engine
  initializer exists and retries once with `config.renderer = 'canvaskit'`,
  which selects the dart2js build. This guards hosts that break the wasm path
  (for example `.mjs` served with a non-JavaScript MIME type). Failures after
  the engine started are only logged, so two engines never share the host.
- `wimp.*` (only used with an explicit opt-in) and `*.symbols` are deleted
  from portal bundles.
- Roboto is subset to Latin ranges; lib/ is ASCII-only already.
- The GitHub Pages build stays dart2js only.

## Alternatives
- Keep dart2js and only trim files: shrinks the bundle but not what a player
  downloads (still about 7.7 MB with subset fonts).
- Precompressed files: depends on the portal CDN, not under our control.
- Deferred Dart libraries: most of `main.dart.js` is framework code; small
  gain for a riskier code split.

## Consequences
- Locally (Chrome) the first frame arrives in about 4.8 s instead of 7.2 s
  with 5.3 MB instead of 8.3 MB (`reports/portal-quality-verification.md`).
  Firefox/Safari only gain the font subset (about 0.6 MB less).
- dart2wasm uses 64-bit integers like the VM while dart2js uses doubles;
  `test/web/generator_parity_test.dart` (VM, Chrome) and
  `tool/check_runtime_parity.sh` (VM, dart2js, dart2wasm) must agree so every
  runtime generates the same puzzles and saves stay valid.
- The bundle stays about 28 MB because both builds ship; well inside portal
  limits.
- Real portal iframes, Safari and mobile devices are verified only when the
  next submission is previewed.
