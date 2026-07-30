---
name: incident-flow
description: Cybernet team workflow for a production incident reported in Telegram — from raw report to verified fix. Use when the user pastes an incident report, mentions "инцидент", "сломалось", "разбор бага с прода", or gives a call/campaign uuid to investigate.
---

# Incident flow (Cybernet)

Incidents arrive as loose Telegram messages ("странно, не было end_call со
стороны агента, посмотри почему"), often without an owner. The cause may be
a real code bug, client misuse (9000 campaigns of 1 call each), or devops —
do not assume which until the data says so.

Incidents default to the **light tier** (ADR-0010): minimal change, no plan
grill, no test-cases doc — but every gate still applies (spec, regression
test, sdd-check, review, CI; no spec-guard bypass). The developer may raise
the tier if the fix turns out to be architectural — write the tier and why
into the change.

## 1. Collect the evidence first

- Bugs filed through the RAISE intake process (ADR-0009) carry a structured
  ticket: environment, Dialogue ID, steps, actual vs expected result,
  priority (low…critical). Read those fields from the ticket first instead of
  re-interrogating the reporter; ask only for what the template left empty.
- Get the call/campaign uuid from the report (ask if missing — one precise
  question, not a thread).
- Run the incident collector (WBN):
  `extra_scripts/incident_collect/collect_incident.py <uuid>` — pulls logs,
  Redis state, and DB rows for the call/campaign.
- Read what came back BEFORE forming a theory.

## 2. Root-cause document

- Write a short incident doc from the collected data: timeline, what happened
  vs what should have happened (cite the relevant spec — repo `openspec/specs/`
  or the store: `openspec show <spec> --type spec --store cybernet-specs`),
  root cause with file:line, blast radius (one call? all campaigns of a firm?).
- Classify honestly: code bug / client misuse / infra. Client misuse or infra →
  the doc IS the deliverable; hand it to the owner, stop here.

## 3. Fix plan

- For a code bug: plan as an OpenSpec change (`/opsx:propose "WEB-XXXX: <fix>"`)
  once a ticket exists. If the observed behavior contradicts a spec, say which
  requirement; if the spec itself was wrong, the change must update the spec too.
- Urgent status speeds up PRIORITIZATION, not development (ADR-0009): the
  spec is still mandatory, just minimal — why + what + the regression test.
  There is no spec-guard bypass for urgent work.
- Keep the fix minimal and in scope of the incident; adjacent findings go to
  TODO/NOTE with the ticket id.

## 4. Regression test first, then the fix (ADR-0010)

- Branch `bugfix/WEB-XXXX` off dev.
- Write the regression test BEFORE the fix: it reproduces the incident and
  fails on the current code. Run it and show the RED in your report — that is
  the light tier's tests-first requirement (skill rule, not a CI gate).
  Name the test after the ticket.
- Then implement the fix and run the test until green. Fix the
  implementation, not the test.
- Commit normally — hooks run ruff, hygiene checks, `make sdd-check`.

## 5. Verify against the incident

- Re-run the scenario from the incident doc (or the collector on a staging
  reproduction) and record the before/after in the ticket/PR body.
- Open the PR with the incident doc linked. Blocking gates: sdd-gate + tests
  (+ TBD gates); autoreview AI comments are advisory.

## 6. Handoff (ADR-0011)

- After the PR is merged to dev, move the ticket to `status: ready_to_test`
  (youtrack MCP) and archive the change.
- Leave a comment for the tester: what to check and how — crystal clear, ONE
  paragraph max. For incidents the reproduction steps are already in the
  RAISE bug report — point at them plus the before/after evidence.
