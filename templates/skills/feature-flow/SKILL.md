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

## 2. Plan as an OpenSpec change

- `/opsx:propose "WEB-XXXX: <what changes>"` — proposal + spec deltas + tasks.
- Reference the ticket id in the change. Spec-guard requires this active
  change before code edits in guarded paths.
- Size the change for a 2-day branch (ADR-0006). Bigger than that: split it
  into several changes with independent value; a feature flag hides the
  unfinished whole (see 3b).
- Interrogate the plan before implementing (grill it): edge cases, rollback,
  migrations, cross-service impact. Fix the plan, not the code later.

## 3. Implement

- Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
- Branches live ≤2 days; CI warns at 2 and fails at 5 (label `long-lived-ok`
  + a `Why long-lived:` line in the PR body for a deliberate exception).
- Code and spec deltas move together — the spec is part of the change.
- Commit normally: the pre-commit hook runs ruff, hygiene checks, `make sdd-check`.

## 3b. Feature flags and contract migrations (ADR-0007)

- Work that spans branches or repos ships dark behind a flag: register it in
  `feature_flags.py` (owner, ticket, `expires`), access only via
  `is_enabled("name")`. `make sdd-flags` fails CI once a flag outlives
  `expires` + 7 days. "Delete the flag" is a task in the same change's tasks.md.
- Touching a FIXED contract (frontend api/v1, external WebAPI, redis
  streams)? The change MUST carry an expand/contract plan:
  new fields optional → both sides read → flag flips the producer → old
  fields removed before `expires`. For cross-repo flags the `expires` date
  lives in the contract spec in the central store; use `spec=` in the
  registry instead of a local date.
- Large replacement (HubTalk, Asterisk removal): branch by abstraction — an
  interface over the current supplier, a config flag picks the
  implementation, the abstraction is deleted after cutover.

## 4. Test-cases doc

- Write "what to check and how" for the tester/reviewer (see
  `postman-collections/*/docs/WEB-*-Test-Cases.md` for the shape):
  happy paths, error paths, permissions, data states, curl/newman snippets.

## 5. Automated tests

- pytest for unit/integration per plan; newman (Postman collection) for e2e
  API flows where the repo uses them.
- Tests assert real behavior, not mock-echo. Run them; paste failures honestly.

## 6. Manual testing

- Run the test-cases doc yourself against a local/stage environment before review.

## 7. Review

- `make sdd-check` green, then run the reviewer agents
  (`.claude/agents/{python,fastapi,database,code}-reviewer.md`) on the diff —
  or open the PR and let autoreview do it.
- Fix CRITICAL/HIGH that are in scope of the ticket. Out-of-scope findings:
  add `TODO`/`NOTE` with the ticket id, do not silently expand scope.

## 8. Pull request

- Open PR to dev with ticket id in the title: `[feature/WEB-XXXX] <summary>`.
- Body: what changed, why, test plan (link the test-cases doc).
- Merge only green: sdd-gate + autoreview + tests.
