# 6x6 step verification (2026-11-14)

Spec: `harness/specs/feature-size-ramp-6x6.md`. ADR: `adr-line-solvable-generator` (addendum).
Base commit 5f36993.

## Commands (2026-11-14)
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 283 tests passed (new: 6x6 group in `test/random_assignment_test.dart`;
  the pinned parity hash in `test/web/generator_parity_test.dart` changed to 270885681 because level 7
  is now 6x6).
- `bash tool/check_runtime_parity.sh`: VM, dart2js and dart2wasm agree (`276229561 270885681`).
- `flutter build web --release --base-href /NonoGrid/`: built.
- 500 random seeds at 6x6: 0 fallbacks, all line-solvable, average 0.34 tweaks, max 4 attempts.

## Known gaps
- Not played by hand; the 6x6 board layout was not screenshotted (it is smaller than the 7x7 it
  replaces, and the existing layout tests cover the other sizes).
- An older client reading a newer save ignores `puzzleSizes` and would show levels 5-8 at the old size.
- Players who have not reached level 5-8 yet get 6x6; players past them are unchanged.

## Review follow-up
Independent review: approve with comments (no Critical/High). Applied: recorded sizes must equal the
current or legacy ramp size; a re-assigned level that was held keeps its old size (`sizeOf` at
assignment); v1 migration XP test; MVP spec, project.md and thumbnail comment updated; ADR notes that
an older client re-saving a newer save drops `puzzleSizes` (levels 5-8 assigned meanwhile return to
the old size) and that this is accepted. Fixes were not re-reviewed.
