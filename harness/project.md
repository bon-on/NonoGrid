# Project instructions

Project-owned. Add instructions specific to this repository here, such as operational cautions, domain rules or verification notes that do not fit a spec, ADR or rule file. harness-lab creates this file once and never replaces your edits; keep `AGENTS.md`, `CLAUDE.md` and `harness/workflow.md` identical to the template so `harness-lab update` can refresh them.

- Active spec: `harness/specs/feature-retention-polish.md` (MVP baseline: `harness/specs/feature-nono-grid-mvp.md`).
- Level content is defined by code (`lib/src/logic/puzzle.dart`); changing the
  generator changes every generated level. Update the ADR and note it.
- Headless Chrome enforces a minimum window width, so for 390x844 screenshots
  load the app inside a 390x844 iframe.
