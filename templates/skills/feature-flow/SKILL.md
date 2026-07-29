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
- Interrogate the plan before implementing (grill it): edge cases, rollback,
  migrations, cross-service impact. Fix the plan, not the code later.

## 3. Implement

- Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
- Code and spec deltas move together — the spec is part of the change.
- Commit normally: the pre-commit hook runs ruff, hygiene checks, `make sdd-check`.

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
