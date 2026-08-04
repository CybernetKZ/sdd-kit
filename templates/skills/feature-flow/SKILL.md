---
name: feature-flow
description: Cybernet team workflow for a YouTrack feature/bugfix task - from task intake to PR. Use when starting work on a WEB-* ticket, or when the user says "possible new task", "новая таска", "сделай WEB-1234".
---

# Feature flow (Cybernet)

YouTrack ticket -> merged PR. Business writes tickets loosely (one line, or LLM-drafted with contract/logic mistakes), so step 1 interrogates the ticket BEFORE any code.

**Language rule.** Everything you write for a human reader goes out **in Russian**: questions to the developer, ticket comments (intake questions to the ticket author), the QA handoff comment, stop/done reports. Machine-readable parts stay English: ids, branch names, tier names, flag names, tracer comments, spec/Scenario text, commit and PR titles.

## Phases

| # | Phase | Executed by |
|---|---|---|
| 1 | Intake: interrogate the ticket, cross-check every claim against code, repo specs and the contract store, findings to `openspec/changes/<id>/intake.md` | you |
| 1b | Pick the tier (section below) | you |
| 2 | Plan as an OpenSpec change: proposal + spec deltas + tasks, ticket id referenced, sized for a 2-day branch (bigger = epic) | `planner` agent |
| 2g | Grill the plan (standard/deep): edge cases, rollback, migrations, cross-service impact; `## Grill` in proposal.md, opening with a provenance header | `plan-griller` agent (deep: agent only) |
| 3 | Validate the spec delta, then one test (or an explicit skip) per Scenario with a `# spec: <req-id> / <scenario>` tracer; green-stub check by a separate agent | `test-author` agent, never the implementer |
| 4 | Implement on `feature/WEB-XXXX` (or `bugfix/`) off dev, walking tasks.md; code and spec deltas move together | `executor` agent |
| 5 | Manual testing: walk the QA Scenarios yourself on local/stage | you |
| 6 | Review the diff via `make sdd-review`; fix in-scope CRITICAL/HIGH, re-run tests | `backend-reviewer` + `database-reviewer` on SQL/ORM/migrations |
| 7+8 | PR to dev titled `[feature/WEB-XXXX] <summary>`; after merge, ticket to `status: ready_to_test` + a Russian tester comment | you |

## Gates and stops

- A spec (OpenSpec change) on every tier; no spec-guard bypass, urgent included.
- Tests before code, RED before implementation; the implementer never writes or edits tests.
- Fixed order: grill the plan (2g) before implementing, reviewer agents (6) after - never swapped.
- `make sdd-check` green before review, and again at commit via the pre-commit hook (ruff, hygiene, sdd-check); `make sdd-flags` for flag expiry.
- No automated check, so you watch them: branch ≤2 days, PR ≤1500 lines, each Scenario ⇄ exactly one test.
- STOP on a serious business fork (pricing, client commitments, data deletion) and ask.
- Blocking question open -> nothing merges; prototyping on the recommended answer, marked as a prototype, is fine.
- Executor deviation -> it STOPS with a Russian report; disputed tests and "change the plan?" calls are yours. Committing is the developer's call.
- Test unexpectedly green -> a finding, not something to force red.

## 1b. Pick the tier

Tiers scale preparation depth only; gates never change. The tier fixes the pipeline and the models, and models are static in each agent's frontmatter - never pick one at runtime.

| Tier | What it means |
|---|---|
| light | minimal change (why + what + a Scenario for the regression test); skip the plan grill. The test is still written before the fix, by `test-author` |
| standard | this skill as written |
| deep | + architecture research before planning (options compared in the change's `design.md`; ADRs are kit-level and live in sdd-kit, target repos have no `docs/ADR/`) + the grill is mandatory |

| Tier | Pipeline | Models |
|---|---|---|
| light | intake -> change (no planner/griller) -> test-author -> executor | test-author/executor sonnet |
| standard | + planner, grill (agent or inline WITH provenance header) | planner/plan-griller opus, executor sonnet |
| deep | + design research; grill by the `plan-griller` AGENT only | same |

Tier in the ticket -> the default; the developer may ALWAYS override it; nothing set -> decide from the signals (RAISE category, services touched, migrations, new/changed contracts): typo / config value / isolated bug -> light, a regular feature inside one service -> standard, cross-service change, data migration, new architecture or unknown territory -> deep. Size is independent of the tier: an epic is decided here, not discovered in step 2. Write the tier AND its justification into proposal.md so the reviewer can challenge it.

Epic mechanics, disputed test, QA fallback, flag lifecycle and contract migrations, intake and store command sequences, PR body and handoff wording: read `references/details.md`.
