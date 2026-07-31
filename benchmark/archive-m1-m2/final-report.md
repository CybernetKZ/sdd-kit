# Final report — sdd-kit pilot benchmark on web-backend-new (WEB-2314)

Date: 2026-07-29. Status: **stopped after pilot (1 run per arm) by user decision.**
This is a qualitative pilot, NOT a statistically valid comparison (n=1).

## Results

| Metric | A-1 (nude) | B-1 (sdd-kit) |
|---|---|---|
| Cost (sonnet, from OTEL) | $4.71 | $9.49 ($1.41 move1 + $8.08 move2) |
| Wall clock | 737 s | 1350 s (268 + 1082) |
| Interventions | 0 | 1 (asked 3 clarification questions) |
| Code diff | +138/−7, 6 files | +281/−13, 5 files (+~350 lines process artifacts) |
| Gates | 3/3 PASS | diff ✓ tests ✓ ruff FAIL (+1 CPY001, +7 SLF001, new test file; CPY001 is repo-wide baseline noise) |
| Scope creep vs frozen radius | 0 | 1 file (test-cases doc — mandated by feature-flow) |
| **Judge: task_success** | **1** | **1** |
| Judge rubric (corr/read/conv/tests/merge) | 5/5/4/4/**5** | 5/3/2/5/**3** |
| Judge verdict | **merge as-is** | send back: delete 6 non-code files first |

Both arms produced essentially the SAME core change (widen target_service
stash, generalize URL resolution, external YAML block mirroring
call-campaign). They differ in test breadth and non-code payload.

Judge highlights:
- B's test suite is objectively stronger (14 tests incl. regression guards
  for the widened branch — the exact tests A is missing; A's untested
  fallback branch is a real gap). Judge would cherry-pick B's 4 regression
  asserts and its SERVICE_MAPPINGS-based fallback onto A's diff.
- B's process artifacts (openspec change, tasks.md with unchecked boxes,
  test-cases doc) read as clutter to a reviewer of THIS repo's dev branch.
- **Shared miss, found by neither arm but by the judge:** both route
  internet-facing API-key traffic to VAC's `/internal` sub-app
  (previously network-trust-only, `PUBLIC`) with `check_firm_access:
  false` → real cross-tenant-read question; the JWT-scoped
  `VOICE_AGENT_URL` route already existed as the firm-scoped alternative.
  B at least documented the choice in design.md; A didn't mention it.

Primary metric ($/accepted task): A $4.71, B $9.49 — but see critique §2:
the arms answered different specs, so this number should not be quoted.

## Fact-check of raised concerns (Daniil)

1. **youtrack-mcp asymmetry** — real in config (bootstrap installs
   `.mcp.json` in arm B only), but null in effect: B's agent searched for
   youtrack tools and got 0 matches (project MCP servers not approved in
   the fresh config). Neither arm had ticket access beyond prompt.md.
2. **openspec incompleteness** — confirmed. Arm B had ONE seeded capability
   (`api-gateway-authorization`) + a store reference; not full spec
   coverage. The pilot measured sdd-kit at minimal seeding.
3. **cost mixing** — not found. Attribution verified per session.id and
   timestamps: A-1 = d1cf0d8b 16:37–16:49 $4.713; B-1 = d01d7ab8
   16:50–17:24 $9.487. Sequential, no overlap. Identical haiku rows
   ($0.001, 579 input in both) are the same background call on the
   identical prompt, not double counting. Only contamination: conductor's
   gate calibration (pytest) ran on the same machine during B-1 move 2 —
   wall-clock noise for B, not token/cost noise.

## Self-critique — why these numbers must not be trusted

Fatal for validity:
1. **The arms solved different specs.** A worked from the 1-line ticket;
   B additionally received clarify.md ≈ the conductor's acceptance criteria
   (written after a repo-scoping investigation). Conductor knowledge leaked
   into B only.
2. **Two-move rule invented post-hoc** after B-1 stalled; the frozen
   protocol was amended three times during the experiment day.
3. **Seeding contamination**: the one seeded spec covers exactly the
   task's subsystem, and was seeded after task selection.
4. **n=1 task × n=1 run** — against our own methodology doc (3–5 tasks ×
   3 runs); within-arm variance alone is 2–3× on tokens.

Systematic bias:
5. Author = experimenter = infra judge: same person (conductor) wrote ACs,
   clarify.md, gates, rubric. Zero independence.
6. Gates were calibrated AFTER the runs (venv pollution, line-shift
   compare, empty-baseline bug — three rewrites post-hoc).
7. Ruff gate is structurally biased against new files (CPY001 that the
   whole repo violates) — and creating new test files is the kit's style.
8. Frozen blast radius excluded the test-cases doc that feature-flow
   REQUIRES → B's "scope creep" was guaranteed by gate construction.
9. **Judge context asymmetry (setup error):** the judge evaluated both
   diffs against the NUDE baseline, so B's openspec artifacts were judged
   as "directories that don't exist in this repo" — but they DO exist in
   arm B's bootstrapped repo (and `make sdd-check` exists there). Judge's
   would-merge 3 for B partially reflects my setup, not only B's output.
   (Counterpoint: the real merge target `dev` has no kit, so the judge's
   reading matches "would this land in dev today".)
10. Blindness abandoned: openspec artifacts identify the arm; user opted
    for full-diff review knowingly.

Technical noise:
11. OTEL move1/move2 share tag run=1 (separable only via session.id).
12. Resume-based move 2 structurally inflates cacheRead (19.5M vs 8.2M).
13. `--allowedTools "Bash(*)"` without container/network isolation.
14. Actual order was A,B (not interleaved); different time-of-day API load.
15. Judge (opus subagent) cost not captured by OTEL (conductor-side session).

## What a valid version needs (if rerun)

- Freeze ONE identical prompt package (ticket + ACs) for both arms before
  any run; no mid-flight clarifications, or a pre-declared two-move rule.
- Seed specs for the whole repo capability list BEFORE task selection;
   3–5 tasks × 3 runs, interleaved, headless, containerized.
- Gates calibrated on baseline before run 1; ruff gate = new violations
  in added lines only; blast radius written per-arm-methodology.
- Independent judge with per-arm-correct baseline context (or two judges);
  MCP parity between arms; per-move OTEL tags.

## Money spent

Kit prep $3.60 + A-1 $4.71 + B-1 $9.49 = **$17.80** (+ judge/conductor
sessions outside OTEL). Break-even statement: not meaningful at n=1.

## Honest bottom line

On this one thin ticket both arms produced correct, mergeable core changes
of the same shape. sdd-kit cost 2× and one intervention, and bought:
stronger regression tests (judge-confirmed), an explicit design rationale
for the risky security decision (which the judge flagged and A ignored),
and process artifacts that a kit-less reviewer treats as clutter. Nothing
here generalizes beyond n=1 and the leaks documented above.
