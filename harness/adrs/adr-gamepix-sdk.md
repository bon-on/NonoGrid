---
id: adr-gamepix-sdk
title: Integrate the GamePix SDK v3 in the GamePix build
status: accepted
related_specs:
  - feature-gamepix-sdk
  - feature-nono-grid-gamepix
---

# ADR: Integrate the GamePix SDK v3 in the GamePix build

## Context
The GamePix build was SDK-free by design (adr-nono-grid-gamepix-web). GamePix publishes such games but withholds "SDK integration approval", which limits exposure on the portal.

## Decision
- `GAMEPIX=true` web builds select `GamePixPlatform` (SDK v3, manual lifecycle). The SDK script is injected by `tool/build_gamepix.sh` before the Flutter bootstrap; it is the only external script allowed.
- Pause/resume mute audio and stop the puzzle timer; interstitials only when leaving a solved puzzle for the next one, with a 2 minute cooldown; preferences in one named localStorage item via `CloudPrefsStore`.
- The factory keeps compile-time constant selection in `createGamePlatform`, so each bundle drops the other portal adapter.
- This supersedes the "no SDK, no ads" part of adr-nono-grid-gamepix-web; its other rules (no outbound links, bundled fonts, relative paths) stay.

## Alternatives
- Stay SDK-free: no work, but no SDK approval or extra exposure.
- Legacy automatic lifecycle: less code, but GamePix analytics (load time, time to play) are less accurate, which the guide says affects ranking.
- Keep shared_preferences_web as is: GamePix sync would not restore progress, because the plugin enumerates keys.

## Consequences
- The GamePix bundle makes requests to integration.gamepix.com and shows GamePix ads.
- The puzzle timer and audio follow GamePix pause events as well as tab visibility.
- Existing players keep their progress: the first SDK session copies the enumerated local keys into the named item.
