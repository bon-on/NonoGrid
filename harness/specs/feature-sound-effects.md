---
id: feature-sound-effects
title: Sound effects with a mute toggle
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-nono-grid-crazygames-web
related_contracts:
  - contract-nono-grid-mvp
  - contract-nono-grid-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - web-build
  - portal-builds
  - harness-audit
---

# Feature: Sound effects with a mute toggle

## Problem
NonoGrid is silent. Players expect short feedback sounds on web (GitHub Pages,
CrazyGames, GamePix) and on iOS/Android, and a way to turn them off.

## Scope
- Four bundled sounds in `assets/audio/`, synthesized by the dependency-free
  `tool/generate_sounds.py` (deterministic): `fill`, `mark`, `undo`,
  `level_clear`. No third-party audio.
- `lib/src/audio/sound_fx.dart` (`SoundFx`, `Sfx`): `play` is a no-op while muted,
  never throws and never awaits. Web uses HTML `Audio` elements
  (`lib/src/audio/web_sound_web.dart`, conditional import with `web_sound_stub.dart`);
  mobile uses the `nono_grid/audio` MethodChannel (`play {asset, volume}`,
  `disposeAudio`): iOS AVAudioPlayer with the `.ambient` session category,
  Android MediaPlayer with USAGE_GAME. Missing plugins are swallowed.
- Hook points are in `GameScreen`, once per finished user action (a stroke
  plays one sound at its end, not per cell): a stroke or key press that
  changes the board plays `fill` (fill tool) or `mark` (X tool); the one that
  solves the puzzle plays `level_clear` instead; a successful undo plays
  `undo`. Restart, Check, level navigation and the tutorial are silent, and
  there is no sound per timer tick.
- Mute: user toggle persisted in `shared_preferences` key `sound_muted_v1`
  (default on). Effective mute = user mute OR `GamePlatform.isAudioMuted`
  (CrazyGames SDK `game.settings.muteAudio`, updated through
  `addSettingsChangeListener`; the game has no ads; no-op platform: false).
- A sound button (`Icons.volume_up_rounded` / `Icons.volume_off_rounded`,
  tooltip "Sound on"/"Sound off") sits next to the "?" button in the top bar,
  with the same style. Like "?" it is covered by the tutorial scrim while the
  card is open, the whole screen is already focus-excluded, and a press
  refocuses the board so keys keep working. No new keyboard shortcut.

## Acceptance Criteria
- Each `Sfx` asset exists on disk and under the pubspec `assets/audio/` entry.
- No sound plays while muted by the user or by the platform; the toggle flips
  the icon and persists the choice; storage failure keeps sound on.
- Fill, mark, undo and level_clear fire at the hook points above, once per
  action.
- Existing tests, `flutter analyze`, web release build, portal build scripts
  and harness audit pass; lib/ stays ASCII.
- The generator produces identical files on two runs.

## Constraints
- No new dependency; audio is bundled (no external requests).
- English UI strings only.

## Evidence
- flutter test, flutter test --platform chrome test/web, flutter analyze
- python3 tool/generate_sounds.py twice with identical shasum
- flutter build web --release --base-href /NonoGrid/, tool/build_crazygames.sh,
  tool/build_gamepix.sh
- harness-lab audit
