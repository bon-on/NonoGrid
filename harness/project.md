# Project instructions

Project-owned. Add instructions specific to this repository here, such as operational cautions, domain rules or verification notes that do not fit a spec, ADR or rule file. harness-lab creates this file once and never replaces your edits; keep `AGENTS.md`, `CLAUDE.md` and `harness/workflow.md` identical to the template so `harness-lab update` can refresh them.

- Active specs: `harness/specs/feature-short-viewport-layout.md`, `harness/specs/feature-portal-quality-pass.md`, `harness/specs/feature-daily-puzzle.md` and `harness/specs/feature-collection-sets.md` and `harness/specs/feature-size-ramp-6x6.md`
  (retention baseline: `harness/specs/feature-retention-polish.md`, MVP baseline: `harness/specs/feature-nono-grid-mvp.md`).
- Daily puzzles derive from the local calendar date (`adr-daily-puzzle`); changing `dailySeed`/`dailySize`
  changes every past and future daily.
- Level content is defined by code (`lib/src/logic/puzzle.dart`); changing the
  generator changes every generated level. Update the ADR and note it.
- Headless Chrome enforces a minimum window width, so for 390x844 screenshots
  load the app inside a 390x844 iframe.
- Portal builds are dart2wasm with a dart2js fallback (`adr-web-wasm-portal-build`).
  Keep `test/web/generator_parity_test.dart` and `tool/check_runtime_parity.sh` green
  whenever puzzle or RNG code changes.
- Fonts are subset (`tool/subset_fonts.sh`, needs fonttools); lib/ strings must stay ASCII.
