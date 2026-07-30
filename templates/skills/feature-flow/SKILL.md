---
name: feature-flow
description: Cybernet team workflow for a YouTrack feature/bugfix task — from task intake to PR. Use when starting work on a WEB-* ticket, or when the user says "possible new task", "новая таска", "сделай WEB-1234".
---

# Feature flow (Cybernet)

The team's standard path from a YouTrack ticket to a merged PR. Business
writes tickets loosely (sometimes one line, sometimes LLM-drafted with
contract/logic mistakes) — so step 1 exists to catch that BEFORE any code.

## 1. Task intake — interrogate the ticket first

- Read the ticket (youtrack MCP: `get_issue WEB-XXXX` + comments).
- Planned tasks arrive through the RAISE intake process (ADR-0009) and should
  carry the request form: current problem, expected outcome, alternatives
  considered, RICE score. Pull those fields into the change's why-section —
  the requester already wrote that context.
- Form missing or incomplete: list the missing fields, post questions for the
  ticket author WITH your recommended answers, and continue working on the
  recommended answers in parallel. Stop and wait ONLY on serious business
  forks (pricing, client commitments, data deletion). Validating requests is
  the RAISE process owner's job, not yours.
- Cross-check every claim against reality:
  - the code (does this already exist? does it conflict with current logic?),
  - repo specs (`openspec view`, `openspec/specs/`),
  - cross-service contracts (`openspec show <spec> --type spec --store cybernet-specs`).
- Output: a list of contradictions, gaps, and questions for the analyst
  (Dina/Olga) or business owner. Post as a ticket comment (ask the user first).
- Do NOT start coding while blocking questions are open. Non-blocking
  assumptions: write them down explicitly and proceed.

## 1b. Pick the tier (ADR-0010)

Tiers scale preparation depth only. Gates never change: spec, tests,
sdd-check, review, CI apply on every tier; no spec-guard bypass.

| Tier | What it means |
|---|---|
| light | minimal change (why + what + regression test); skip the plan grill and the test-cases doc |
| standard | this skill as written |
| deep | + architecture research before planning (compare options, write an ADR) + the grill is mandatory |

- Tier set in the ticket → use it as the default.
- The developer may ALWAYS override the tier.
- Nothing set → decide yourself from the signals: RAISE category, number of
  services touched, migrations, new/changed contracts.
- Write the tier AND its justification into the change (proposal.md) so the
  reviewer can challenge it.

## 2. Plan as an OpenSpec change

- Deep tier first: research architecture options (context7 for library/API
  docs), compare them, record the decision as an ADR. Use a strong model
  (opus/fable) for research, planning, and grilling; the implementation runs
  on the session model; bulk mechanical steps can drop to haiku.
- `/opsx:propose "WEB-XXXX: <what changes>"` — proposal + spec deltas + tasks.
- Reference the ticket id in the change. Spec-guard requires this active
  change before code edits in guarded paths.
- Size the change for a 2-day branch (ADR-0006). Bigger than that: several
  small PRs under ONE change, dark behind a feature flag (see 4b). The change
  stays active across all the epic's PRs and is archived when the flag is
  enabled in prod by default (ADR-0011).
- Standard/deep: interrogate the plan before implementing (grill it): edge
  cases, rollback, migrations, cross-service impact. Fix the plan, not the
  code later. Record the grill as a `## Grill` section in proposal.md — the
  sharp questions and the accepted answers, one line per decision. It
  archives with the change, so the "why option B" history survives.

## 3. Tests first (RED before implementation)

- This is a skill requirement, not a CI gate: write the tests from the plan
  BEFORE implementing, run them, and show the RED run in your report.
- Standard/deep: write the test-cases doc first — "what to check and how"
  for the tester/reviewer (see `postman-collections/*/docs/WEB-*-Test-Cases.md`
  for the shape): happy paths, error paths, permissions, data states,
  curl/newman snippets. Then pytest for unit/integration per plan; newman
  (Postman collection) for e2e API flows where the repo uses them.
- Light tier: one regression test that reproduces the bug/gap and fails on
  the current code — that IS the RED.
- Tests assert real behavior, not mock-echo. Paste failures honestly.

## 4. Implement

- Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
- Branches live ≤2 days; CI warns at 2 and fails at 5 (label `long-lived-ok`
  + a `Why long-lived:` line in the PR body for a deliberate exception).
- Code and spec deltas move together — the spec is part of the change.
- Commit normally: the pre-commit hook runs ruff, hygiene checks, `make sdd-check`.
- Run the tests; fix the implementation (not the tests) until green.

## 4b. Feature flags and contract migrations (ADR-0007, ADR-0011)

- Work that spans branches or repos ships dark behind a flag: register it in
  `feature_flags.py` (owner, ticket, `expires`), access only via
  `is_enabled("name")`. `make sdd-flags` fails CI once a flag outlives
  `expires` + 7 days. "Delete the flag" is a task in the same change's tasks.md;
  the removal itself is a small separate PR with no new change.
- Environment convention: a new flag is ON in dev and stage, OFF in prod.
  QA always sees the new behavior on stage; enabling in prod is a separate,
  deliberate step after QA verification.
- Touching a FIXED contract (frontend api/v1, external WebAPI, redis
  streams)? The change MUST carry an expand/contract plan:
  new fields optional → both sides read → flag flips the producer → old
  fields removed before `expires`. For cross-repo flags the `expires` date
  lives in the contract spec in the central store; use `spec=` in the
  registry instead of a local date.
- Large replacement (HubTalk, Asterisk removal): branch by abstraction — an
  interface over the current supplier, a config flag picks the
  implementation, the abstraction is deleted after cutover.

## 5. Manual testing

- Run the test-cases doc yourself against a local/stage environment before review.

## 6. Review

- `make sdd-check` green, then run the reviewer agents
  (`.claude/agents/{python,fastapi,database,code}-reviewer.md`) on the diff —
  or open the PR and let autoreview do it.
- Fix CRITICAL/HIGH that are in scope of the ticket. Out-of-scope findings:
  add `TODO`/`NOTE` with the ticket id, do not silently expand scope.
- Re-run the tests after applying review fixes.

## 7. Pull request

- Open PR to dev with ticket id in the title: `[feature/WEB-XXXX] <summary>`.
- Body: what changed, why, test plan (link the test-cases doc).
- Blocking gates: sdd-gate + tests + the TBD gates (branch age, PR size).
  Autoreview AI comments are advisory — address them like review findings,
  they do not block the merge by themselves.

## 8. Handoff (ADR-0011)

- After the PR is merged to dev, move the ticket to `status: ready_to_test`
  (youtrack MCP).
- Leave a comment for the tester: what to check and how — crystal clear,
  ONE paragraph max. Include the feature-flag name if there is one and a
  link to the test-cases doc (standard/deep).
- QA verifies on stage (the flag is already ON there). Enabling the flag in
  prod happens after QA — then archive the change and schedule the
  flag-removal PR by its `expires`.
