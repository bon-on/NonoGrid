---
id: feature-gamepix-sdk
title: NonoGrid GamePix SDK v3 integration
status: active
owner: games
related_adrs:
  - adr-gamepix-sdk
related_contracts:
  - contract-nono-grid-gamepix
required_evidence:
  - flutter-tests
  - flutter-web-tests
  - flutter-analyze
  - gamepix-web-build
---

# Feature Spec: NonoGrid GamePix SDK v3 integration

## Problem
The SDK-free GamePix package (feature-nono-grid-gamepix) gets no "SDK integration approval" from GamePix, so it misses the extra exposure SDK games get. The SDK v3 guide asks for pause/resume handlers that mute audio, manual lifecycle signals, ads only at natural breaks and localStorage read by known key names.

## Scope
- GamePix web build (`--dart-define=GAMEPIX=true`) only: `GamePixPlatform` adapter, the break-ad wiring in the game screen and `tool/build_gamepix.sh`.
- Out of scope: puzzles and balance, CrazyGames/Pages/mobile behaviour, rewarded ads, login, `happyMoment`/`sadMoment`, loading percentages.

## Acceptance Criteria
- S1: The GamePix `index.html` sets `window.GamePixConfig = { lifecycle: 'manual' }` and loads `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js` exactly once, both before the Flutter bootstrap. No other external script, link or URL is added; the build script fails otherwise.
- S2: The adapter registers `pause` and `resume`. Pause mutes all game audio (`isAudioMuted`), resume restores it; the Player's `soundOff`/`soundOn` do the same for its mute control; repeated events change nothing. Pause also stops the puzzle timer and input like a hidden tab (`setPauseListener`); resume restarts the timer only when play is possible.
- S3: `lifecycle.loaded()` is sent once after the first Flutter frame; `lifecycle.gameStart()` is sent when gameplay starts, after `loaded()`. A Player that never answers does not block the game (10 s timeout).
- S4: Interstitials (`ads.interstitial()`) play only at one break point: the player leaves a finished (solved) puzzle for the next one through `Next` on the win bar or the summary card (also Enter/Space on them). For a solved daily puzzle the same button reads `Levels` and goes back to the levels, so it is the same break point. Never mid-puzzle: starting, restarting, the previous/next level arrows, the album, the level list, Replay and opening the daily puzzle show no ad. At least 2 minutes pass between ads (the first break may show one; the Player itself caps ads at one every 3 minutes) and never two run at once. While an ad runs, input, buttons and keys are blocked, so a double tap cannot skip or repeat it; afterwards the game continues only if the same board is still solved. A failed, unfilled or hung ad (120 s) still opens the next puzzle.
- S5: Preferences are kept in one localStorage item read with `getItem` by name (`nonogrid.prefs_v1`, named per game because GamePix may serve several games from one origin), so GamePix storage sync restores progress. Progress saved before the SDK (enumerated `flutter.` keys) is kept on the first SDK session, and those keys are never cleared.
- S6: Without the SDK (blocked script, direct page) the adapter behaves like the old no-op platform: no ads, no share link.
- S7: The CrazyGames and Pages bundles contain no GamePix adapter code, and the GamePix bundle no CrazyGames code or `crazygames` string.

## Constraints
- GamePix rules: no other third-party SDK, no external links, no timer-triggered ads, the game pauses and mutes during ads.
- A broken SDK must never keep the game from starting or continuing.
- The factory chooses the adapter with compile-time constants (`createGamePlatform`) so bundles tree-shake the other adapters.

## Stack Notes
- `lib/src/platform/gamepix_platform.dart` reuses `CloudPrefsStore` (`crazygames_prefs_store.dart`) with the prefixed localStorage item as the "cloud", an in-memory mirror seeded from the old keys and no local stamp, so the named item is always the source.
- shared_preferences_web lists keys with `localStorage.key(i)`, which GamePix sync does not see; that is why the named item is needed.
- `GameScreen._advance` is the break point: on platforms without break ads (`showsRunBreakAds` false) it advances at once.

## Evidence
- `flutter analyze`, `flutter test` (break-ad widget test in `test/game_platform_flow_test.dart`), `flutter test --platform chrome test/web` (`gamepix_sdk_test.dart`, `gamepix_platform_test.dart`).
- `tool/build_gamepix.sh` and `tool/build_crazygames.sh` succeed; `grep -c GamePix build/crazygames/main.dart.js` is 0.
