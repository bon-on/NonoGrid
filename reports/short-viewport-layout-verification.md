# Short viewport layout - verification (2026-11-11)

Spec: `harness/specs/feature-short-viewport-layout.md`. Base commit: `89d6249`.

## Cause

`build` chose the side-panel layout only for width >= 700 and width > 1.3 x
height. Every narrower landscape window (GamePix "Small" 620x349, 640x480,
667x375 ...) fell back to the stacked phone layout, whose header, Level/XP
card, Levels/Album/Themes row, Daily card, hint line and wrapped tool rows
need about 300 px before the board. At 349 px height the board box was about
50 px; `BoardMetrics.fit` keeps an 11 px clue font and 8 px cells, so the
painted board was larger than its box and its clues painted over the hint
text. Widget tests did not catch it because painting past a box is not a
Flutter overflow error.

## Board canvas size (widget tests, 5x5 level, px)

| Window | Layout | Board | Board with first-run strip |
|---|---|---|---|
| 620x349 | compact | 285x264 | ~267x246 |
| 600x338 | compact | 274x253 | ~254x234 |
| 560x315 | compact | 242x222 | ~228x209 |
| 640x480 | compact | 295x274 | 295x274 |
| 667x375 | compact | 310x289 | ~292x271 |
| 844x390 | wide | 355x334 | 289x268 |
| 932x430 | wide | 395x374 | 329x308 |
| 870x480 | wide | 410x389 | 379x358 |
| 360x640 | stacked (folded) | 324x303 | ~263x242 |
| 390x844 | stacked | 354x333 | 354x333 |
| 320x568 | stacked (folded) | 253x232 | ~180x162 |
| 1280x720, 1366x768 | wide | 469x448 | 469x448 |

Before the change the 620x349 board box was about 50 px high. 15x15 (level
60) with the strip: 620x349 231x249, 600x338 220x238, 560x315 197x215,
640x480 295x314, 667x375 257x275, 844x390 250x268, 320x568 155x170 (scaled).

## Manual screenshots (not committed)

GamePix build (`tool/build_gamepix.sh`) served by `python3 -m http.server`,
fresh headless Chrome per shot with `--mute-audio`, CDP device metrics at
620x349, 640x480, 600x338, 560x315, 844x390, 932x430, 667x375, 360x640,
390x844, 1280x720, 1366x768, 320x568 and 870x480 (first launch, tip strip
shown), plus level 60 (15x15) at 620x349, 600x338, 560x315, 640x480, 667x375,
844x390 and 320x568. All show the board first with readable clues, no overlap
or overflow, Daily and Levels/Album/Themes visible, all six tools visible and
the strip above the board (the card tape tucks under it). 15x15 at 560x315
and 320x568 is dense (about 8-9 px cells) but nothing overlaps.

## Checks

| Command | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 251 passed (49 in `short_viewport_layout_test.dart`) |
| `flutter test --platform chrome test/web` | 23 passed |
| `tool/check_runtime_parity.sh` | VM, dart2js, dart2wasm: `276229561 939007943` |
| `tool/build_crazygames.sh` | pass |
| `tool/build_gamepix.sh` | pass; no `crazygames` / `bon-on.github.io` in the bundle |
| harness audit | Critical 0 |

## Not verified

Real phones and tablets, Safari/iOS, Firefox, the real GamePix and CrazyGames
iframes (their preview chrome, safe areas, CDN), touch input on a real
device, real audio output.
