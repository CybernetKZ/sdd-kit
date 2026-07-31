# Pilot report (run 1 of 3 per arm) - 2026-07-29

Task WEB-2314, sonnet pinned, headless, two-move rule (see deviations.md).

## Headline numbers

| Metric | A-1 (nude) | B-1 (sdd-kit) |
|---|---|---|
| Cost (sonnet) | **$4.71** | **$9.49** (move1 $1.41 + move2 $8.08) |
| Cost (haiku, background) | $0.001 | $0.001 |
| Wall clock | 737 s | 1350 s (268 + 1082) |
| Interventions | 0 | **1** (asked 3 clarification questions; fixed answer given) |
| Code diff | +138/−7, 6 files | +281/−13, 5 files |
| Non-code artifacts | - | openspec change (proposal/design/spec/tasks), test-cases doc |
| Scope creep | 0 files | 1 file (`postman-collections/.../WEB-2314-Test-Cases.md` - outside frozen blast radius; mandated by feature-flow skill) |
| Gate: diff applies | PASS | PASS |
| Gate: ruff (no new) | PASS | **FAIL** (+1 CPY001, +7 SLF001 - both in the NEW test file) |
| Gate: tests (no new failures) | PASS | PASS |
| New tests added | extended 2 existing test files | 14 tests in a new file + conftest fake |

Ruff-gate caveat: CPY001 (copyright header) is violated by every existing
file in the repo - flagging only B's new file is baseline-policy noise.
SLF001 (private-member access in tests, ×7) is a real but minor nit; the
repo's own baseline tests violate comparable test rules (S101). Recorded
as-is; blind review will weigh actual quality.

## What happened

- **A-1** went straight to implementation: modified gateway rules, middleware,
  route handler; extended existing tests. Clean, minimal, in-radius.
- **B-1 move 1** followed feature-flow intake: investigated the repo,
  correctly identified `vac-knowledge-base` as the only internal RAG
  candidate, found the ticket ambiguous (scope? auth role? read-only?),
  and stopped to ask - empty diff, $1.41. Move 2 (fixed clarification =
  frozen ACs) implemented: same 3 core gateway files as A, a new dedicated
  test file (14 tests incl. full ASGI e2e), openspec change artifacts,
  test-cases doc, and ran a python-reviewer self-review pass (Approve).

## Early read (n=1 - NOT a conclusion)

- sdd-kit doubled cost and wall-clock on this run; the extra spend bought
  process artifacts (spec/design/tasks/test-doc), a larger dedicated test
  suite, and a self-review - plus one human intervention by design.
- The methodology's intake step is fundamentally at odds with thin tickets
  in headless mode; in real interactive work the same questions would go to
  the ticket owner (arguably correct behavior).
- Task success (0/0.5/1) is assigned at blind review after all runs.

## Costs so far

Kit prep (one-off): $3.60. Pilot: A $4.71 + B $9.49 = $14.20.
Remaining 4 runs (A-2, B-2, A-3, B-3) projected: ~$30 ± 10.
