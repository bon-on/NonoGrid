---
id: feature-web-audio-playback
title: Web Audio playback for sound effects on mobile browsers
status: active
owner: games
related_adrs:
  - adr-spec-driven-delivery
  - adr-nono-grid-crazygames-web
related_contracts:
  - contract-nono-grid-mvp
  - contract-nono-grid-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - independent-review
---

# Feature: Web Audio playback for sound effects on mobile browsers

## Problem
On 2026-11-27 the player reported that the GamePix build stutters on mobile every time an action plays a sound
(PulseDrift gate pass, PourSort pour, and similar actions in every game). The web build played each effect by rewinding
and replaying one HTML `Audio` element per asset (`lib/src/audio/web_sound_web.dart`). Mobile browsers restart a media pipeline for each play.
In headless Chrome at 390x844 with 6x CPU throttling, 8 PourSort pour/undo rounds with HTML `Audio` showed frame gaps
up to 117-333 ms and fewer frames. With playback stubbed out, or replaced by a Web Audio shim, the maximum was 50-67 ms.

## Scope
- Replace the inside of `WebSound` with the Web Audio API: one `AudioContext`, assets fetched once and decoded into
  buffers, each effect a short-lived `AudioBufferSourceNode` with its own gain.
- Keep the public `WebSound` API and its behavior, including the web/stub conditional import. `loop` starts the track from the beginning, `stopLoop` rewinds, `pauseLoop`/`resumeLoop` keep the position.
- Browsers start audio only after a user gesture. Capture-phase `pointerdown`, `pointerup`, `touchend` and `keydown`
  listeners on `document` resume the context, also after interruptions. Effects requested while audio is locked and no
  gesture happened in the last second are dropped instead of bursting out later. A loop requested while locked is
  scheduled and starts with the first gesture.
- A first play waits for fetch and decode; if that takes longer than 400 ms the effect is skipped rather than played late.
- Safari before 14.1 (only `webkitAudioContext`) gets no web sound; accepted.
- Failures (no `AudioContext`, fetch or decode errors) are silent and never break input. A failed asset can be retried.

## Constraints
- No new packages: `dart:js_interop` only. Native playback, mute logic and assets do not change.
- Portal builds stay self-contained: assets are fetched from the bundle, no external requests.
- iOS Safari routes Web Audio through the ringer switch, which matches the native `.ambient` session.

## Acceptance Criteria
- W1: no `HTMLMediaElement.play` calls during play; effects start Web Audio buffer sources (headless Chrome probe).
- W2: the PourSort probe with Web Audio shows no frame gap above the no-sound baseline.
- W3: `flutter analyze` and `flutter test` pass; the web/portal build scripts pass.

## Evidence
- `flutter analyze`, `flutter test`, `tool/build_gamepix.sh`
- PourSort probe numbers in the commit message and the GamePix notes.
