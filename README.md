# NonoGrid

A small nonogram (paint-by-numbers) logic puzzle built with Flutter. Every
level is generated from its level number and is guaranteed to be uniquely
solvable by line logic alone, so you never have to guess.

Runs in the browser (GitHub Pages) and on iOS/Android. No ads, no network,
no accounts; progress is stored locally on the device.

## How to play

- The numbers next to each row and above each column list the lengths of the
  runs of filled cells in that line, in order. `0` means the line is empty.
- Fill cells so every row and column matches its clue. Mark cells you know are
  empty with an X to help yourself; X marks do not count against you.
- A clue turns grey once the filled runs in its line match it.
- Solving the puzzle reveals the picture and unlocks the next level.

### Controls

| Action | Touch / mouse | Keyboard |
| --- | --- | --- |
| Fill a cell | Tap/click in **Fill** mode | Space |
| Mark X | Tap in **Mark X** mode, or right-click | X |
| Paint a line | Drag (locks to the row or column you start moving in) | - |
| Move cursor | - | Arrow keys |
| Undo last stroke | Undo button | U |
| Restart puzzle | Restart button | R |
| Next level (after a win) | Next button | Enter |

Starting a stroke on a cell that already has the current mark erases that
mark along the stroke instead. **Check** briefly highlights wrong fills; there
is no penalty (free mode). The timer starts on your first move and best times
are kept per level.

The first launch shows a skippable "How to play" card (Enter/Space next, Esc
skip, arrows move between steps); the `?` button in the top bar reopens it and
the timer is paused while it is open.

### Levels

- Levels 1-3 are small hand-made pictures.
- Later levels are generated from seed = level number, growing from 5x5 to
  7x7, 8x8, 10x10, 12x12 and 15x15 (level 46+).
- See `harness/adrs/adr-line-solvable-generator.md` for how the generator
  and line solver guarantee a unique, guess-free solution.

## Run, test, build

Requires Flutter 3.41 (stable) or newer.

```sh
flutter pub get
flutter run -d chrome          # or an iOS/Android device
flutter analyze
flutter test
flutter build web --release --base-href /NonoGrid/
```

Pushing to `main` builds and deploys the web app to GitHub Pages via
`.github/workflows/deploy-pages.yml` (enable Pages with "GitHub Actions" as
the source in the repository settings).

## CrazyGames build

`tool/build_crazygames.sh` builds `build/nono-grid-crazygames.zip` for the CrazyGames portal (SDK gameplay events, no ads). See `docs/crazygames.md`.

## GamePix build

`tool/build_gamepix.sh` builds `build/nono-grid-gamepix.zip` for GamePix (no portal SDK, no ads, relative resources). See `docs/gamepix.md`.

## Fonts

Roboto (Regular, Medium, Bold, Black) is bundled in `assets/fonts/` so web builds never fetch it from fonts.gstatic.com. Roboto is licensed under Apache 2.0, see `assets/fonts/Roboto_LICENSE.txt`.

## Project layout

- `lib/src/logic/` - widget-free rules: clues, line/grid solver, seeded PRNG,
  puzzle generator, game state (strokes, undo, win).
- `lib/src/ui/` - board painter and game screen.
- `lib/src/storage.dart` - local persistence (shared_preferences).
- `harness/` - spec, ADRs, rules and contracts used for spec-driven work.

## License

MIT - see [LICENSE](LICENSE).
