# Portal quality pass - verification (2026-11-11)

Spec: `harness/specs/feature-portal-quality-pass.md`. ADR: `harness/adrs/adr-web-wasm-portal-build.md`.
Base commit for "before": `e8f9ed4`.

## Load metrics

Method: GamePix bundle (no external SDK script) served by `python3 -m http.server` (no
compression), fresh headless Chrome 157 per run with cache disabled, CDP network throttling,
1280x720. Time = `performance.now()` at the `flutter-first-frame` event; bytes = encoded bytes
received until then. Median of 3 runs.

| Network | Before (e8f9ed4) | After |
|---|---|---|
| 10 Mbps / 40 ms | 7.22 s, 8.26 MB, 14 requests | 4.78 s, 5.28 MB, 15 requests |
| 5 Mbps / 80 ms | 14.23 s, 8.26 MB, 14 requests | 9.40 s, 5.28 MB, 15 requests |

Bundle (CrazyGames script output): before 43 files / 30,104 KB (zip 12 MB); after 43 files /
27,864 KB (zip 11 MB). Both builds now ship (wasm first, JavaScript fallback), so the folder
shrinks less than the download.

What dominated before: `canvaskit/chromium/canvaskit.wasm` 5.5 MB + `main.dart.js` 2.1 MB + four
Roboto files 0.67 MB (downloaded before the first frame). After: `skwasm.wasm` 3.4 MB +
`main.dart.wasm` 1.7 MB + subset fonts 4 x 19 KB. Material icons were already tree-shaken
(11 KB); audio loads lazily on first play.

JavaScript retry: with `main.dart.mjs` deleted from a built bundle the page logged the retry and
rendered the game through `main.dart.js` + CanvasKit.

## Checks

| Command | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 202 passed |
| `flutter test --platform chrome test/web` | 23 passed (incl. generator parity on dart2js) |
| `tool/check_runtime_parity.sh` | VM, dart2js, dart2wasm: `276229561 939007943` on all three |
| `flutter test --platform chrome --wasm test/web/generator_parity_test.dart` | hung at "loading" on this machine (twice); replaced by the Node check above |
| `tool/build_gamepix.sh` | pass, 0 `crazygames` matches in main.dart.js/.wasm/.mjs |
| `tool/build_crazygames.sh` | pass |
| `flutter build web --release --base-href /NonoGrid/` | pass, no CrazyGames SDK script |
| harness audit | Critical 0 (2 older warnings: maintenance review, logic-hints Constraints) |

## Manual screenshots (not committed)

Local GamePix build in headless Chrome at 1280x720, 1366x768, 390x844 and 844x390, first launch:
tip strip above the board, no blocking card, Daily and Album visible, no overflow. A scripted
play of the heart level at 1280x720 showed tip 1 -> tip 2 after filling a full row, the row
flash, then reveal colours, confetti and the summary card; the strip disappears on solve. The
splash (390x844, 2 s into a 5 Mbps load) shows the heart grid, title and bar in desk colours.

## Not verified

Real phones and tablets, Safari/iOS (skwasm_heavy or JavaScript path), Firefox, the CrazyGames
and GamePix iframes and their CDN MIME types / compression, real audio output.

## Review

Independent code-reviewer: first pass approve with comments (no Critical/High; Medium: tip
truncation at 320 px, font check passing with no files, wasm claimed for Firefox/Safari, retry
could double-start after engine init). All fixed; second pass approve. Firefox and Safari keep the
JavaScript path (Flutter's default wasm allow list) and gain only the font subset.
