# Verification: NonoGrid CrazyGames web build

- Spec: `harness/specs/feature-nono-grid-crazygames.md`
- ADR: `harness/adrs/adr-nono-grid-crazygames-web.md`
- Contract: `harness/contracts/contract-nono-grid-crazygames.md`
- Environment: Flutter 3.41.7 / Dart 3.11.5, macOS, headless Chrome (tests)

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 50 passed (was 47; 3 new platform flow tests) |
| `flutter test --platform chrome test/web` | 5 passed (missing SDK, disabled, rejected init, hung init, events) |
| `tool/build_crazygames.sh` | passed, 30 files, about 28MB, zip about 11MB |
| bundle `index.html` | `<base href="./">`, SDK script before `flutter_bootstrap.js`, `user-select: none` |
| `flutter build web --release --base-href /NonoGrid/` | passed, no SDK script in output |

Not verified: a live run against the real CrazyGames SDK or QA tool.
