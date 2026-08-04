---
name: incident-flow
description: Cybernet team workflow for a production incident reported in Telegram - from raw report to verified fix. Use when the user pastes an incident report, mentions "инцидент", "сломалось", "разбор бага с прода", or gives a call/campaign uuid to investigate.
---

# Incident flow (Cybernet)

Incidents arrive as loose Telegram messages ("не было end_call со стороны
агента, посмотри почему"), often without an owner. Follow **feature-flow**
(`.claude/skills/feature-flow/SKILL.md`) with the differences below - everything
else is identical: its language rule, tier rules, the gates (spec, tests before
code, sdd-check, review - all local, no server CI), its step-3 test rules, no
spec-guard bypass for urgent work.

## Step 1 becomes: collect the evidence

1. A bug filed through RAISE already carries environment, Dialogue ID, steps,
   actual vs expected, priority - read those fields instead of re-interrogating
   the reporter; ask only what the template left empty, and ask **in Russian**.
2. Get the call/campaign uuid (ask if missing - one precise question) and run the
   collector (https://github.com/CybernetKZ/incident_collect):
   `collect_incident.py <uuid>` pulls logs, Redis state and DB rows (first run:
   clone it and fill its `.env` per its README). Read it BEFORE forming a theory.
3. Searching by symptom: grep the logs for the failing symbol/handler name, then
   probe the graph by that SYMBOL, never by prose - the command sequence
   (`graphify explain` -> `query` for a fan-out ≈ blast radius; precise reverse
   deps via grep/ast-grep) is in AGENTS.md, "Codebase search". The graph is
   navigation only and `[INFERRED]` edges are guesses: verify in code either way.

## New step: root-cause document, before any plan

Write it to `openspec/changes/<change-id>/intake.md` (create the dir early) so it
survives into the plan - feature-flow step 1's convention; the planner folds it
into proposal.md. It holds: timeline, what happened vs what the spec says should
happen (repo `openspec/specs/`, or the store - the read sequence is in
feature-flow step 1), root cause with file:line, blast radius (one call? all
campaigns of a firm?). Then classify honestly - **code bug / client misuse /
infra**. Misuse or infra: the doc IS the deliverable; hand it to the owner
(ticket comment **in Russian** + status via youtrack MCP - the ticket author or
process owner closes it, not the dev) and **STOP** - no change, no code.

## The rest, in feature-flow's numbering

- **1b (tier)**: light by default - minimal change, skip planner/plan-griller -
  unless the fix turns out architectural. Branch `bugfix/WEB-XXXX`. Urgent speeds
  up PRIORITIZATION, not development: the spec stays mandatory, just minimal
  (why + what + one Scenario reproducing the incident).
- **3 (tests)**: the regression test is written by the `test-author` agent from
  the Scenario, before the fix - never by whoever writes the fix. It
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
  while that PR is open.
