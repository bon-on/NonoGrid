# GamePix build

Building with `--dart-define=GAMEPIX=true` produces a GamePix SDK v3 bundle
(feature-gamepix-sdk): the GamePix SDK is the only external script, there is no
CrazyGames SDK, no leaderboard or result upload, no hub link, no share link, and
no other external requests (Roboto is bundled in `assets/fonts/`).

## Build

```sh
tool/build_gamepix.sh
```

Output:

- `build/gamepix/`: bundle folder
- `build/nono-grid-gamepix.zip`: zip to upload (files at the zip root, `index.html` first level)

The script runs `flutter build web --release --wasm --base-href / --no-web-resources-cdn
--dart-define=GAMEPIX=true` (WebAssembly on Chromium browsers, JavaScript elsewhere and as a fallback; see
`adr-web-wasm-portal-build`), switches `<base href>` to `./`, removes `*.symbols` and the
unused `wimp.*` renderer and checks: both builds and the JavaScript retry present, subset
fonts, relative base, the GamePix `GamePixConfig` (`lifecycle: 'manual'`) and SDK
script present exactly once and in that order before `flutter_bootstrap.js`, no
`crazygames`, no `bon-on.github.io`, no other script and no external
`src`/`href` in `index.html`, viewport `user-scalable=no`, Roboto in
`FontManifest.json`, no `crazygames` / `bon-on.github.io` in `main.dart.js`,
`main.dart.wasm` or `main.dart.mjs`, and `index.html` at the zip root. It prints file count and size.

## Upload notes

| Item | Value |
|---|---|
| Zip | `build/nono-grid-gamepix.zip` |
| Icon | 256x256 (not created yet) |
| Cover | 1360x850 (not created yet) |
| Orientation | portrait and landscape; the layout fits any iframe size |
| Desktop / Mobile friendly | both (mouse, touch and keyboard) |
| SDK integration | GamePix SDK v3 (manual lifecycle, pause/resume, interstitial between puzzles) |
| Language | English |
| Description / controls | see `reports/store-listing-2026-11.md` (same texts as CrazyGames) |

## GamePix SDK

- `tool/build_gamepix.sh` adds `window.GamePixConfig = { lifecycle: 'manual' }` and
  `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js` to `<head>`, before the Flutter bootstrap.
- `GamePixPlatform` (`lib/src/platform/gamepix_platform.dart`): `pause`/`resume` stop the
  puzzle timer and input and mute audio; `soundOff`/`soundOn` mute; `lifecycle.loaded()`
  after the first frame; `lifecycle.gameStart()` when play starts.
- Ads: one interstitial when the player leaves a solved puzzle through Next (or Levels after
  a daily puzzle), at most every 2 minutes, never mid-puzzle. A failed ad never blocks the game.
- Without the SDK (blocked script) the game runs without ads.

## Saved progress

Progress lives in one localStorage item, `nonogrid.prefs_v1`, read and written by name through
`CloudPrefsStore`, because GamePix syncs localStorage items it reads with `getItem` by key
(shared_preferences_web only lists keys). Progress saved before the SDK is copied into it on the
first session.

## Platform flags

`GAMEPIX=true` selects `GamePixPlatform` (`allowsAds` and `allowsResultRegistration` stay
false; no share link). It wins over `CRAZYGAMES=true`; the CrazyGames adapter is only used
when `CRAZYGAMES=true` and `GAMEPIX` is not set. Both flags are compile-time constants, so
each bundle drops the other adapter (`tool/build_crazygames.sh` fails if `GamePix` appears in
its `main.dart.js`).

## Tests

```sh
flutter test
flutter test --platform chrome test/web
flutter test --platform chrome test/web --dart-define=GAMEPIX=true --dart-define=CRAZYGAMES=true
```

## Verification notes

- `tool/build_gamepix.sh` fails when `main.dart.js` contains `crazygames` or
  `bon-on.github.io`. The daily Copy result text carries no link in this build.
- `main.dart.js` still contains the engine's default `https://fonts.gstatic.com/s/`
  constant. The app does not request Roboto from there because Roboto is bundled.
- Roboto comes from the Flutter SDK cache (`material_fonts/`); its license is
  `assets/fonts/Roboto_LICENSE.txt` (Apache 2.0).
- Glyphs missing from Roboto make the engine fetch a fallback font from
  fonts.gstatic.com. Keep UI text to characters Roboto covers and avoid U+00B7.
- Local check: `cd build && python3 -m http.server 8765`, then open
  `http://localhost:8765/gamepix/`. Test 640x480 and 360x640 iframes.
