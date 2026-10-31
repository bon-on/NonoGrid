# Verification: NonoGrid GamePix web build

- Spec: `harness/specs/feature-nono-grid-gamepix.md`
- ADR: `harness/adrs/adr-nono-grid-gamepix-web.md`
- Contract: `harness/contracts/contract-nono-grid-gamepix.md`
- Environment: Flutter 3.41.7 / Dart 3.11.5, macOS, headless Chrome

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 52 passed |
| `flutter test --platform chrome test/web` | 7 passed (5 CrazyGames adapter, 2 platform selection) |
| same with `--dart-define=GAMEPIX=true --dart-define=CRAZYGAMES=true` | 7 passed (no-op platform selected) |
| `tool/build_gamepix.sh` | passed, 34 files, about 28MB, zip about 11MB, index.html at zip root |
| `crazygames` matches in GamePix `main.dart.js` | 0 |
| `FontManifest.json` | lists family Roboto |
| `tool/build_crazygames.sh` | passed, Roboto bundled |
| `flutter build web --release --base-href /NonoGrid/` | passed, no CrazyGames SDK script |
| Headless Chrome 640x480 and 360x640 (iframe) | no overflow or clipping |
| Runtime network (headless Chrome net log) | no request for Roboto or fonts.gstatic.com |

Not verified: upload to GamePix; icon and cover images are not created.
