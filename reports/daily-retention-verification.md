# Daily puzzle and album sets verification

Specs: `feature-daily-puzzle`, `feature-collection-sets`; ADR: `adr-daily-puzzle`. Base commit f0f8765.

## Commands (2026-11-08, exit 0 unless noted)
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 190 tests passed (new: `daily_test`, `collection_test`, `daily_screen_test`,
  `collection_screen_test`, cloud-sync case in `crazygames_prefs_store_test`).
- `flutter test --no-pub --platform chrome test/web`: 21 passed (share link validation, flavor links,
  copy fallback). Also `game_platform_factory_test` with `GAMEPIX=true CRAZYGAMES=true` and with
  `CRAZYGAMES=true`: passed.
- `tool/build_gamepix.sh`: passed; `main.dart.js` has 0 `crazygames` and 0 `bon-on.github.io` (now enforced).
- `tool/build_crazygames.sh`: passed; no `bon-on.github.io` in `main.dart.js` (now enforced).
- `flutter build web --release --base-href /NonoGrid/`: passed; Pages link present once.
- `node ~/sources/harness-lab/dist/index.js audit . --format md`: Critical 0, 2 pre-existing warnings
  (maintenance review, `feature-logic-hints` missing Constraints).
- Temporary golden screenshots (not committed) at 390x844, 1280x720, 1366x768, 844x390 for the main
  screen, daily overlay, daily board, daily summary and album were reviewed.

## Independent review
code-reviewer: approve with comments, no Critical/High. Fixed: album set count bounded by the open level
and record keys capped (Medium), a reward-free earlier-date solve no longer hides a later day's Done state
(Medium), after-midnight summary goal text (Low), card "playing" state only for today's board (Low);
regression tests added.

## Not verified
- Real CrazyGames iframe: whether `SDK.game.link` exists and whether clipboard/`execCommand` are allowed by
  the portal's permissions policy (blocked copy shows "Could not copy").
- Real devices (iOS/Android) and real clock/time-zone changes beyond unit tests.
- Cross-device cloud sync on the live Data module (only a fake Data module is tested).
