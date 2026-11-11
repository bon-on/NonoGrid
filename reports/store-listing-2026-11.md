# Store listing - 2026-11

Final store texts for CrazyGames and GamePix (ASCII English). They replace the
2026-11-06 launch description, which promised "handcrafted-style" puzzles that
"reveal a hidden picture" in a "pixel-art" world. Since `feature-random-practice`,
new players get randomly generated puzzles (mostly abstract patterns, not
pictures), and that text left out the Daily puzzle, streak, album sets,
3-star goals, themes and Logic hint.

## Description (85 words)

```text
NonoGrid is a calm nonogram logic puzzle. Fill cells so every row and column matches its number clues. Puzzles are freshly generated for each level, grow from 5x5 to 15x15 and always have one solution you can reach by logic alone, with no guessing. Play the Daily puzzle to build a streak, earn up to 3 stars per level, collect your solved grids in color in album sets and unlock paper themes as you level up. Stuck? A Logic hint explains the next forced step.
```

## Controls

```text
Mouse or touch: tap or drag to fill cells; switch to Mark X, or right-click, to mark empty cells. Keyboard: arrow keys move the cursor, Space fills, X marks, U undoes, R restarts, Enter opens the next puzzle after a win and D opens the Daily puzzle. Check shows wrong fills; Logic hint explains the next step.
```

## Fact check

| Claim | Source |
|---|---|
| Freshly generated puzzle per level | `harness/specs/feature-random-practice.md` (random persisted seed per new level; level 1 uses `friendlyFirstSeed`, `feature-portal-quality-pass.md`) |
| 5x5 to 15x15 | README "Levels" (5, 7, 8, 10, 12, 15; 15x15 from level 46) |
| One solution, logic alone, no guessing | `harness/adrs/adr-line-solvable-generator.md` |
| Daily puzzle and streak | `harness/specs/feature-daily-puzzle.md`, `lib/src/meta/daily.dart` |
| Up to 3 stars | `lib/src/meta/progress_rules.dart` (solve, no Check mistakes, under par) |
| Album sets, solved grids in color | `harness/specs/feature-collection-sets.md`, `lib/src/meta/collection.dart` |
| Paper themes unlocked by painter level | `NonoTheme` unlocks in `progress_rules.dart` (Notebook, Kraft, Washi, Midnight) |
| Logic hint explains the next forced step | `harness/specs/feature-logic-hints.md` (`Logic hint` button, no key binding) |
| Keys Space, X, U, R, Enter, D, arrows | `lib/src/ui/game_screen.dart` key handler |

Not claimed: hand-made pictures, pixel art, ads, online play or leaderboards.
The tag suggestion "Pixel" from the launch packet no longer fits; "Logic",
"Brain", "1 Player" and "2D" still do.

## Covers

New CrazyGames covers (landscape 1920x1080, portrait 800x1200, square 800x800)
live in the workspace marketing folder `../_marketing/NonoGrid/covers_v3/`,
with a reproducible source (`source/cover.html`, `source/render.sh`) and
`source/verify.py`, which checks every drawn clue against the drawn cells.
They replace the launch covers, whose landscape heart had clues that did not
match its cells. The only text on the covers is the title "NonoGrid".

Nothing was uploaded to any portal.
