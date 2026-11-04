# Persistent randomized levels verification

Base: `242e216`. Implements `feature-random-practice` (historical filename; single default mode, no separate practice mode).

New level assignments store an independent seed alongside board marks. Reopening/restarting retains the puzzle; completed selections advance on next startup unless an unfinished board needs resuming. Existing exposed legacy puzzles and records remain compatible. Summary, album and solved map thumbnails use assigned puzzles; damaged completed assignments show an empty placeholder instead of an unrelated legacy picture.

Checks executed from this repository:

| Command | Exit / result |
|---|---|
| `flutter analyze --no-pub` | 0, no issues |
| `flutter test --no-pub --reporter expanded` | 0, 134 tests |
| `flutter test --no-pub --platform chrome test/web --reporter expanded` | 0, muted Chrome |
| `flutter build web --release --base-href /NonoGrid/` | 0 |
| `bash tool/build_crazygames.sh` | 0, bundle self-checks passed |
| `bash tool/build_gamepix.sh` | 0, bundle self-checks passed |
| `node <harness-lab>/dist/index.js audit . --format md` | 0, Critical 0, existing maintenance warning |
| `git diff --check` | 0 |

Independent harness-review: final approve, no Critical/High findings. Cross-model Claude review: approve with comments; damaged-assignment thumbnail concern and README drift fixed and independently re-reviewed. Existing deterministic fixture tests explicitly seed legacy preferences; new tests cover genuinely fresh randomized sessions, saved boards, startup advancement, legacy v1/v2 migration and actual result/album pictures.

References used: random-level assignment feature spec, generator ADR, MVP contract/spec, repository constraints and golden rules. Applied packs: none. No new dependencies or external game runtime requests. Native builds, physical-device play and audible music not exercised. No blocking conflicts or escalation.
