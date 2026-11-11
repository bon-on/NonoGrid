# Constraints

- Default policy mode: warn on drift, block critical gaps.
- Every feature change needs a feature spec in `harness/specs/`.
- Architectural or cross-cutting decisions need an ADR in `harness/adrs/`.
- AI responses must cite the spec, ADRs, and rules they used.
- If the repo state contradicts the spec or ADR, escalate instead of guessing.

## Project Constraints (NonoGrid)

- Stack: Flutter (stable 3.41+), Dart 3.11; targets web, iOS, Android.
- Dependencies: Flutter SDK and `shared_preferences` only. No ads SDK, no
  network calls, no analytics, no leaderboard in v1.
- Game rules, solver and generator stay widget-free in `lib/src/logic/` and
  are covered by unit tests in `test/`.
- Every shipped puzzle must be fully solvable by the line solver
  (`adr-line-solvable-generator`). Changing the PRNG, size ramp, density or
  tweak rule changes existing levels and needs an ADR update.
- Puzzle randomness uses `SeededRng` (xorshift32), never `dart:math` `Random`.
- Layout must fit 390x844 portrait and 1280x720 landscape without overflow;
  clue font never below 11 logical px. Short portal iframes (620x349 GamePix
  "Small" preview, 640x480 minimum, down to 560x315) must keep the board
  first and playable (`feature-short-viewport-layout`).
- Do not use third-party trademarked names for the genre; call it nonogram.
- Never commit secrets, `.env` files, personal absolute paths or emails.
- Before claiming completion run `flutter analyze`, `flutter test` and
  `flutter build web --release --base-href /NonoGrid/`.

## Detected Stack Summary

- No known stack profile detected

## Suggested Profile Pack Constraints

These constraints are recommendations derived from the detected repository signals. Move relevant items into approved rules after review.

