---
id: adr-level-boards
title: Keep up to five unfinished level boards in the v2 JSON, mirrored into the old single slot
status: accepted
related_specs:
  - feature-next-session-hooks
  - feature-retention-polish
  - feature-crazygames-cloud-save
  - feature-size-ramp-6x6
---

# ADR: Per-level unfinished boards

## Context
`nonogrid_progress_v2` held one unfinished board (`progress`). A move on any
level replaced it, so moving between levels lost boards. Cached CrazyGames
clients from before this change keep running for a while and read and write
the same JSON (local storage and the `prefs_v1` cloud snapshot).

## Decision
- New optional key `boards` in the v2 JSON (version stays 2): a list, oldest
  first, of at most 5 entries `{level, cells, elapsed, mistakes, seed?}`.
  `seed` is the level's assigned seed when the board was written; legacy
  levels (`<= legacyThrough`) have no seed and must carry none.
- `progress` keeps its exact old shape and always mirrors the most recent
  board, so an old client resumes that board as before.
- Parse: entries whose stamp does not equal the current `puzzleSeeds` entry
  (or that lack an assignment) are dropped; damaged entries are skipped one
  by one. A `progress` board whose level is not in `boards` was written by an
  older client (it drops unknown keys) and is added as the most recent board,
  validated as before (an assignment must exist). Duplicates keep the last
  entry; more than 5 keep the newest 5. The 6x6 size recovery from marks runs
  for every kept board.
- Clearing a level or restarting it removes only that level's board. Startup
  opens the frontier level (`maxCleared + 1`); its board, if any, resumes.

## Alternatives
- A separate prefs key for boards: survives old-client rewrites, but can
  disagree with the v2 JSON (an old client clears a level or reassigns a
  seed without touching it) and the request asked to stay inside the v2 JSON.
- Unbounded boards: grows the cloud snapshot without a clear benefit.
- Bumping `version` to 3: old clients return null from `tryParse` and fall
  back to the v1 keys, losing XP, records and assignments. Rejected.

## Consequences
- Compatibility, old client reading new JSON: `tryParse` reads named keys only
  and ignores `boards` and the extra `seed`; `SavedProgress.fromJson` ignores
  unknown keys. It resumes the mirrored most-recent board. No crash.
- Old client writing back: its `toJson` is explicit, so `boards` is dropped.
  Only the most recent board (in `progress`) survives a downgrade write;
  other levels' boards are lost, which is the pre-change behavior.
- A board written by this client never lands on a reassigned seed: the stamp
  no longer matches, and a level listed (even rejected) in `boards` is not
  re-added from the unstamped `progress` mirror. A legacy-level board stamped
  with a seed is rejected. A `progress` written by an older client carries no
  stamp and is trusted when its level has an assignment, exactly as before
  this change (that residual risk is unchanged).
- The JSON grows by at most 5 x (cells + ~60 bytes), under 1.5 KB at 15x15,
  far below the 1 MB Data module limit. `CloudPrefsStore` stores the string
  unchanged, so no portal code changes.
- Startup no longer jumps back to a lower level with an unfinished replay;
  that board stays saved and resumes when its level is opened.
