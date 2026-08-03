---
name: incident-flow
description: Cybernet team workflow for a production incident reported in Telegram - from raw report to verified fix. Use when the user pastes an incident report, mentions "инцидент", "сломалось", "разбор бага с прода", or gives a call/campaign uuid to investigate.
---

# Incident flow (Cybernet)

Incidents arrive as loose Telegram messages ("не было end_call со стороны
агента, посмотри почему"), often without an owner. Follow **feature-flow**
(`.claude/skills/feature-flow/SKILL.md`) with the differences below - everything
else is identical: tier rules, the gates (spec, tests before code, sdd-check,
review, CI), its step-3 test rules, no spec-guard bypass for urgent work.
`ADR-XXXX` references point at the sdd-kit repo's `docs/ADR/`; the essentials are
inlined in the two skills, so neither needs them present in this repo.

## Step 1 becomes: collect the evidence

- A bug filed through RAISE (ADR-0009) already carries environment, Dialogue ID,
  steps, actual vs expected, priority - read those fields instead of
  re-interrogating the reporter; ask only what the template left empty.
- Get the call/campaign uuid (ask if missing - one precise question) and run the
  collector (https://github.com/CybernetKZ/incident_collect):
  `collect_incident.py <uuid>` pulls logs, Redis state and DB rows (first run:
  clone it and fill its `.env` per its README). Read it BEFORE forming a theory.
- Searching by symptom: grep the logs for the failing symbol/handler name, then
  probe the graph by that SYMBOL, never by prose (`graphify explain "<sym>"`,
  then `query "<sym>"` for a fan-out ≈ blast radius; precise reverse deps -
  grep/ast-grep) - navigation only, ADR-0004, and
  `[INFERRED]` edges are guesses: verify in code either way.

## New step: root-cause document, before any plan

Write it to `openspec/changes/<change-id>/intake.md` (create the dir early) so it
survives into the plan - feature-flow step 1's convention; the planner folds it
into proposal.md. Timeline, what happened vs what the spec says should happen
(`openspec/specs/`, or the store: `openspec store list` -> `openspec list --specs
--store cybernet-specs` -> `openspec show <spec> --type spec --store
cybernet-specs`; `openspec view` never reads the store), root cause with
file:line, blast radius (one call? all campaigns of a firm?). Then classify
honestly - **code bug / client misuse / infra**. Misuse or infra: the doc IS the
deliverable; hand it to the owner and **STOP** - no change, no code.

## The rest, in feature-flow's numbering

- **1b (tier)**: light by default - minimal change, skip planner/plan-griller -
  unless the fix turns out architectural. Branch `bugfix/WEB-XXXX`. Urgent speeds
  up PRIORITIZATION, not development (ADR-0009): the spec stays mandatory, just
  minimal (why + what + one Scenario reproducing the incident).
- **3 (tests)**: the regression test is written by the `test-author` agent from
  the Scenario, before the fix (ADR-0016) - never by whoever writes the fix. It
  must fail on current code *for the incident's reason*: a RED run that merely
  errors out is not a reproduction. So write a precise Scenario: WHEN the
  incident's conditions, THEN the expected behavior. If the test passes on
  current code, the incident is not reproduced - report that instead of forcing
  a failure, and go back to the evidence.
- **5 + 8 (verify, handoff)**: re-run the incident scenario (or the collector on
  a staging reproduction), record before/after in the ticket/PR body, link the
  root-cause doc from the PR. The handoff comment points at the RAISE
  reproduction steps + that before/after evidence.

- Fix touches a cross-repo contract? The spec edit is a separate change + PR in
  `cybernet-specs`; this change carries a `tasks.md` task naming it and is not archived
  while that PR is open (ADR-0018).
