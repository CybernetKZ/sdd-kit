# Protocol v2 - FROZEN 2026-07-29, before any v2 run

Rerun of the pilot with every pilot flaw fixed or explicitly accepted.
Scale (user decision): **minimum - 1 run per arm**, task **Web-2314**
(user's explicit choice; contamination from the pilot is documented below).

## Fixes vs pilot (numbering = final-report.md critique)

1. **Identical frozen prompt package** for both arms (`~/bench/prompt-v2.md`):
   verbatim ticket + the user-approved acceptance criteria + "no one is
   available; make reasonable assumptions and implement". No clarifications,
   no resume. Empty diff = task_success 0. (Kills flaw #1/#2; the kit's
   intake step is intentionally neutralized - v2 measures implementation,
   not requirement-interrogation.)
2. Two-move rule: **removed** (declared before runs, not invented after).
3. Seeding: unchanged from pilot (1 capability + store reference) - user
   chose "start with minimum". v2 therefore measures sdd-kit at MINIMAL
   seeding; full-repo seeding remains untested. Seeding-after-task-selection
   contamination from the pilot still applies - accepted, documented.
4. n: 1 run/arm (user decision). No medians; qualitative only.
5. Conductor still writes/scores everything - unchanged, documented.
6. **Gates frozen NOW, before runs** (already baseline-calibrated in pilot):
   diff-applies, ruff-no-new-violations **excluding CPY001** (repo-wide
   noise), pytest-no-new-failures vs cached per-arm baseline.
7. CPY001 excluded (fixes new-file bias).
8. **Blast radius per arm**: common list as v1; for arm B additionally
   NON-creep: `openspec/changes/**`, `postman-collections/**/WEB-2314*`
   (feature-flow-mandated artifacts).
9. **Judge context fixed**: judge evaluates each diff against its OWN arm's
   bench-base worktree (kit artifacts present for B), then head-to-head.
10. Blindness: abandoned by design (n=1, arms self-identifying). Judge is a
    fresh opus subagent that hasn't seen this conversation.
11. OTEL tags: `run=v2` per arm; single move -> no move ambiguity.
12. No resume -> no structural cacheRead inflation.
13. Isolation: host, as pilot (user decision; push disabled, throwaway clones).
14. Order: **B first, then A** (reverse of pilot).
15. Judge cost: reported from subagent usage (outside OTEL), stated in report.

MCP: arm B keeps kit-installed `.mcp.json` (kit feature) - project MCP
servers do not connect in the isolated config (verified in pilot); both arms
effectively prompt-only. Dev stack: left RUNNING (user decision) - gateway
tests are in-process pytest; port/DB conflicts not applicable to this task.

## Run command (per arm)

Same as v1: `claude -p "$(cat ~/bench/prompt-v2.md)" --model sonnet
--permission-mode acceptEdits --allowedTools "Bash(*)"`, fresh branch from
bench-base, OTEL `arm={a|b},task=WEB-2314,run=v2`.

## Known contamination (accepted by user)

Web-2314 was used in the pilot: the ACs in the prompt package originate
from the conductor's scoping of this exact task, and arm B's seeded spec
covers the task's subsystem. Both arms now receive the same package, so the
asymmetry is gone, but absolute costs are not comparable to a "cold" task.
