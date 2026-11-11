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

## Board canvas size (widget tests, px, clues + grid)

Level 1 is a 5x5, level 60 a 15x15 (random assignment, so sizes vary a few
px between puzzles).

| Window | Layout | 5x5 | 5x5 + strip | 15x15 | 15x15 + strip |
|---|---|---|---|---|---|
| 620x349 | compact | 278x258 | 264x243 | 278x297 | 225x243 |
| 600x338 | compact | 268x247 | 253x232 | 268x286 | 214x232 |
| 560x315 | compact, icon tools | 292x271 | 228x209 | 253x271 | 191x209 |
| 640x480 | compact | 289x268 | 289x268 | 289x307 | 289x307 |
| 667x375 | compact | 303x282 | 290x269 | 303x321 | 251x269 |
| 844x390 | wide | 355x334 | 289x268 | 316x334 | 250x268 |
| 932x430 | wide | 395x374 | 329x308 | 356x374 | 290x308 |
| 870x480 | wide | 410x389 | 379x358 | 405x424 | 340x358 |
| 360x640 | stacked, folded | 324x303 | 259x238 | 286x304 | 220x238 |
| 390x844 | stacked | 354x333 | 354x333 | 354x372 | 338x356 |
| 320x568 | stacked, folded | 253x232 | 182x166 | 214x232 | 151x166 (scaled) |
| 1280x720 | wide | 469x448 | 469x448 | 633x664 | 570x598 |
| 1366x768 | wide | 469x448 | 469x448 | 679x712 | 616x646 |

Before the change the 620x349 board box was about 50 px high. A scan of
levels 31-200 finds no scaled board at 560x315, 600x338, 620x349, 640x480,
667x375 or 844x390 (with the strip too from 600 px). Accepted exception:
with the first-run strip a 12x12/15x15 board may scale at 560x315 and
320x568 (clue font about 9-10 px).

## Manual screenshots (not committed)

GamePix build (`tool/build_gamepix.sh`) served by `python3 -m http.server`,
fresh headless Chrome per shot with `--mute-audio`, CDP device metrics at
620x349, 640x480, 600x338, 560x315, 844x390, 932x430, 667x375, 360x640,
390x844, 1280x720, 1366x768, 320x568 and 870x480 (first launch, tip strip
shown), plus level 60 (15x15) at 620x349, 600x338, 560x315, 640x480, 667x375,
844x390 and 320x568. All show the board first with readable clues, no overlap
or overflow, Daily and Levels/Album/Themes visible, all six tools visible and
the strip above the board (the card tape tucks under it). 15x15 at 560x315
and 320x568 is dense (8-9 px cells) but nothing overlaps.

## Checks

| Command | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 264 passed (incl. `short_viewport_layout_test.dart` and summary fit at 620x349, 560x315, 640x480, 320x568) |
| `flutter test --platform chrome test/web` | 23 passed |
| `tool/check_runtime_parity.sh` | VM, dart2js, dart2wasm: `276229561 939007943` |
| `tool/build_crazygames.sh` | pass |
| `tool/build_gamepix.sh` | pass; no `crazygames` / `bon-on.github.io` in the bundle |
| `flutter build web --release --base-href /NonoGrid/` | pass |
| harness audit | Critical 0 (2 older warnings) |

## Review

Independent code-reviewer on `fd196c7`: request changes. High: at 560x315
22 of levels 31-200 scaled down (clue font about 10 px). Fixed by an
icon-only tool column under 600 px width, with a level 31-200 scan test.
Medium: spec and report disagreed on scaling (spec now states the one
first-run strip exception); no test of taps on a scaled board (added).
Low: unused `maxLines` parameter (removed); level map height not monotonic
at 390-409 px (fixed). Hit testing under scale, overlays, semantics and
focus were confirmed correct by the reviewer's probes.

## Not verified

Real phones and tablets, Safari/iOS, Firefox, the real GamePix and CrazyGames
iframes (their preview chrome, safe areas, CDN), touch input on a real
device, real audio output.
