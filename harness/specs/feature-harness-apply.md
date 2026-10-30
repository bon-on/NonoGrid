---
id: feature-harness-apply
title: Add repo-native harness apply workflow
status: active
owner: platform-ai
related_adrs:
  - adr-spec-driven-delivery
related_contracts:
  - contract-harness-apply-foundation
required_evidence:
  - unit-tests
  - audit-report
  - skill-doc
---

# Feature Spec: Add repo-native harness apply workflow

## Problem
AI-assisted development is inconsistent because repo rules, ADRs, and task expectations are not encoded in one place.

## Scope
- Add a repo harness manifest, rules, spec template, and ADR template.
- Add a skill that forces agents to read spec and ADR context first.
- Add audit tooling that reports missing critical harness artifacts.

## Acceptance Criteria
- The repo contains a manifest that defines source priority and policy mode.
- A feature spec and linked ADR exist for harness-aware delivery.
- The skill states which spec, ADR, and rule files it used.
- Audit blocks when critical harness files or acceptance criteria are missing.

## Constraints
- Preserve existing legacy harness evaluation commands.
- Prefer Markdown for human-maintained docs and JSON for machine-readable manifest data.
- Use warn-plus-block-critical enforcement by default.

## Evidence
- `npm run build`
- `harness-lab audit . --format md`
- `harness-lab plan harness/specs/feature-harness-apply.md --format text`
