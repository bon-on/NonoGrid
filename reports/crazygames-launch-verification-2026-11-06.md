# CrazyGames launch verification — 2026-11-06 task

Final verification recorded at 2026-11-06T15:20:47.535754+00:00.

Base: `b13fc5f0a402663460efe2529a5f119a30d42c56`. HEAD: `b13fc5f0a402663460efe2529a5f119a30d42c56`. Working tree dirty: `True`. Existing gameplay changes were preserved; no commit or push performed.

Build inputs SHA-256 at report time: `5eb7aa0439f6c4cd49f22ad5f4f4ac3760d43fa1eee0073f8ffc54d163708919`. This fingerprint covers lib/assets/web/tool/pubspec; it is not a claim of a clean commit build.

## Final checks

| Check | Result |
|---|---|
| Flutter analyze | exit 0 |
| Full VM tests | exit 0; 145 passed |
| Chrome SDK/cloud tests | exit 0; 17 passed |
| Normal Pages release build | exit 0; no CrazyGames SDK in index.html |
| CrazyGames release build/self-checks | exit 0 |
| Harness audit | exit 0; Critical 0; warnings 2 |
| Independent review | approve; no findings |

Exact commands, sanitized logs and structural ZIP checks are in `crazygames-launch-2026-11-06/verification.json` and its sibling `.log` files. The five existing games' final Chrome rerun used a muted/headless wrapper with background timer throttling disabled and explicit timeouts after the earlier abandoned runner stalled; the successful complete rerun is the accepted evidence.

## Upload bundle

- Path: `build/nono-grid-crazygames.zip`
- ZIP SHA-256: `1134c96b1b891027a81b4d25e101b8228fedacf18cf26efc3f0ec7caa43eee73`
- ZIP bytes: 12524796; files: 43; unpacked bytes: 30691581
- Root index, relative base, SDK v3, no hub navigation, no debug symbols and ZIP CRC checked.

## Review and limits

Independent harness-review of the entire release working tree approved with no findings. Required Claude cross-review also completed with no Critical/High findings; remaining nonblocking comments are recorded in `crazygames-cross-review/review.md`. 

Local SDK tests use a fake SDK and do not establish real account syncing or platform-hosted QA. Authenticated draft upload, portal settings, actual QA and publication are coordinator-owned and recorded separately in the launch packet. Native device testing was not part of this web release verification. Existing maintenance/workflow warnings remain in the audit.

References used: repository AGENTS/workflow/project instructions where present, CrazyGames and cloud-save specs, linked ADR/contracts, constraints and golden rules. Applied packs: none. Constraints: preserve ordinary distributions, preexisting edits and source freeze; no production edits during final verification. Conflicts or gaps: external QA and existing audit maintenance warnings. Escalation: none for local verification.
