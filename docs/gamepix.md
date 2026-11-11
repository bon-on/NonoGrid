# GamePix build

Building with `--dart-define=GAMEPIX=true` produces an SDK-free bundle for GamePix:
no portal SDK script, no ads, no leaderboard or result upload, no hub link, and
no external requests (Roboto is bundled in `assets/fonts/`).

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
fonts, relative base, no `crazygames-sdk`, no `bon-on.github.io`, no external
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
| SDK integration | none |
| Language | English |
| Description / controls | see `reports/store-listing-2026-11.md` (same texts as CrazyGames) |

## Saved progress

Progress is saved in the browser's localStorage through `shared_preferences`.
GamePix syncs localStorage automatically, so no SDK code is required.

## Platform flags

`GAMEPIX=true` selects the no-op `GamePlatform` (`allowsAds` and
`allowsResultRegistration` are false). It wins over `CRAZYGAMES=true`; the CrazyGames
adapter is only used when `CRAZYGAMES=true` and `GAMEPIX` is not set.

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
