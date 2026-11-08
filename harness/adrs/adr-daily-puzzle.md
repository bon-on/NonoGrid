---
id: adr-daily-puzzle
title: Key the daily puzzle to the local calendar date and keep streak, set and share state in the v2 envelope
status: accepted
related_specs:
  - feature-daily-puzzle
  - feature-collection-sets
---

# ADR: Daily puzzle date source, streak rule and storage

## Context
The daily puzzle must be the same for every player on a given day, be fair
(line-solvable), survive offline play and tolerate clock changes. The game has
no server, so the device clock is the only date source. Streaks, set rewards
and daily boards must sync through the CrazyGames cloud save like the rest of
the progress.

## Decision
- Date source: the device's local calendar date. `day` = days from
  1970-01-01 to `DateTime.utc(local.year, local.month, local.day)`. Every
  player on the same calendar date gets the same puzzle; the share text
  carries the `YYYY-MM-DD` label so results compare by date.
- Puzzle: `generatePuzzle(0, sizeOverride: dailySize(day), seed: dailySeed(day))`.
  The seed uses only small integer arithmetic (no products above 2^31) so
  VM and dart2js agree; size follows the weekday (8, 8, 10, 10, 10, 12, 12
  from Monday). The generator, PRNG and level content are unchanged.
- Streak: consecutive solved days; one missed day is covered once by a
  grace that refills after 7 more daily solves. Solving a day earlier than
  the last solved day (clock moved back) gives no reward and changes nothing.
  The board's day is fixed when it opens, so a solve after midnight counts
  for the day it started.
- Rewards: first solve of a day gets normal stars/first-clear XP plus a daily
  bonus of 10 + 5 x min(streak - 1, 4) XP. Completing a 10-level album set
  gives 50 XP once, tracked by set index.
- Storage: optional keys `daily` and `setsAwarded` inside the existing
  `nonogrid_progress_v2` JSON (version stays 2). Each is parsed in isolation
  with per-field defaults so a damaged value never invalidates level
  progress. The CrazyGames `CloudPrefsStore` mirrors every preference key, so
  no portal-specific code is needed.
- Share link: `GamePlatform.shareLink`. Pages/mobile use the GitHub Pages URL
  supplied only by the non-GamePix factory branches; CrazyGames reads
  `SDK.game.link` and accepts only an https CrazyGames URL; GamePix returns
  null. The game never opens the link.

## Alternatives
- UTC date: one puzzle per instant worldwide, but the day rolls over at odd
  local hours (09:00 in Korea), which breaks the intuitive "one a day" streak.
- Server date: tamper-proof but needs a backend and network, forbidden here.
- Hard-coded CrazyGames slug: the public game page does not exist yet; a
  guessed URL could be wrong.
- Rejecting all clock changes: impossible offline; we only make backwards
  changes reward-free and keep values non-negative.

## Consequences
- Players in different time zones may play different dates at the same
  instant; results stay comparable through the date label.
- Moving the clock forward can extend a streak, but the real date then lags
  the last solved day and earns nothing until it catches up.
- Downgrading to an older build drops `daily`/`setsAwarded` on its next save
  (older builds ignore unknown keys); acceptable for a forward-only release.
