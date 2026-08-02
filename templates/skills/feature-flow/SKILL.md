---
name: feature-flow
description: Cybernet team workflow for a YouTrack feature/bugfix task - from task intake to PR. Use when starting work on a WEB-* ticket, or when the user says "possible new task", "новая таска", "сделай WEB-1234".
---

# Feature flow (Cybernet)

The team's standard path from a YouTrack ticket to a merged PR. Business
writes tickets loosely (sometimes one line, sometimes LLM-drafted with
contract/logic mistakes) - so step 1 exists to catch that BEFORE any code.

## 1. Task intake - interrogate the ticket first

- Read the ticket (youtrack MCP: `get_issue WEB-XXXX` + comments).
- Planned tasks arrive through the RAISE intake process (ADR-0009) and should
  carry the request form: current problem, expected outcome, alternatives
  considered, RICE score. Pull those fields into the change's why-section -
  the requester already wrote that context.
- Form missing or incomplete: list the missing fields, post questions for the
  ticket author WITH your recommended answers, and continue working on the
  recommended answers in parallel. Stop and wait ONLY on serious business
  forks (pricing, client commitments, data deletion). Validating requests is
  the RAISE process owner's job, not yours.
- Cross-check every claim against reality: if a fresh graphify index exists
  (`graphify-out/graph.json`), start with a graph query for orientation
  (`graphify query "<ticket claim>"`, navigation only — ADR-0004, always
  verify in code), then grep/read the code and specs.
  - the code (does this already exist? does it conflict with current logic?),
  - repo specs (`openspec view`, `openspec/specs/`),
  - cross-service contracts (`openspec show <spec> --type spec --store cybernet-specs`).
- Output: a list of contradictions, gaps, and questions for the analyst
  (Dina/Olga) or business owner. Post as a ticket comment (ask the user first).
- Blocking questions stop the DECISION, not the hands: while the author
  answers, build a prototype on the recommended answer - explicitly marked
  as a prototype, with a request to verify it. The answer either confirms
  the direction or the prototype is cheaply discarded. The prototype lives
  behind the same OpenSpec change and never bypasses gates; nothing merges
  while a blocking question is open. Non-blocking assumptions: write them
  down explicitly and proceed.

## 1b. Pick the tier (ADR-0010)

Tiers scale preparation depth only. Gates never change: spec, tests before
code, sdd-check, review, CI apply on every tier; no spec-guard bypass. Tasks
genuinely differ - a small clear edit ships via light right away; a risky or
cross-service one earns the full grill.

| Tier | What it means |
|---|---|
| light | minimal change (why + what + a Scenario for the regression test); skip the plan grill. The test is still written before the fix, by `test-author` |
| standard | this skill as written |
| deep | + architecture research before planning (compare options, write an ADR) + the grill is mandatory |

- Tier set in the ticket -> use it as the default.
- The developer may ALWAYS override the tier.
- Nothing set -> decide yourself from the signals: RAISE category, number of
  services touched, migrations, new/changed contracts.
- Write the tier AND its justification into the change (proposal.md) so the
  reviewer can challenge it.

## 2. Plan as an OpenSpec change

- Deep tier first: research architecture options (context7 for library/API
  docs), compare them, record the decision as an ADR. Model binding is
  automatic: plan and grill run as the `planner` / `plan-griller` subagents
  (`model: opus` in their frontmatter, ADR-0013); the implementation runs
  on the session model; bulk mechanical steps can drop to haiku.
- Run the `planner` agent: `/opsx:propose "WEB-XXXX: <what changes>"` -
  proposal + spec deltas + tasks.
- Reference the ticket id in the change. Spec-guard requires this active
  change before code edits in guarded paths.
- Size the change for a 2-day branch (ADR-0006 - a warning in CI, not a
  block: ADR-0015). Bigger than that is an epic: split into YouTrack tasks
  (1 task = 1 PR, ADR-0013) under ONE change. A feature flag is optional here
  (ADR-0015): take one only if the half-built epic must stay invisible in
  prod (see 4b). With a flag, the change is archived when the flag is enabled
  in prod by default (ADR-0011); without one, when the last task is merged
  and verified.
- Standard/deep: interrogate the plan before implementing: the
  `plan-griller` agent asks the questions - edge cases, rollback,
  migrations, cross-service impact - and the developer answers; anything
  the developer cannot answer becomes a question to the ticket author.
  Fix the plan, not the code later. Record the grill as a `## Grill` section in proposal.md - the
  sharp questions and the accepted answers, one line per decision. It
  archives with the change, so the "why option B" history survives.

## 3. Tests from the spec delta - before implementation

The implementer does NOT write the tests. The change (its spec delta) goes
through the test step before any implementation code:

- Validate the spec delta first: every Requirement has at least one measurable
  Scenario (WHEN/THEN), edge cases are covered (invalid input, permissions,
  empty values, repeated calls), no conflict with existing contracts.
  A spec delta that fails validation comes BACK to you - fix the Scenarios,
  not the tests. Your job in step 2 is to write Scenarios that are testable.
- Run the `test-author` agent (ADR-0016): one test (or an explicit skip with a
  reason) per Scenario, each carrying a tracer comment
  `# spec: <requirement-id> / <scenario>`. An independent agent then
  adversarially checks every test for green stubs - a separate run, never
  `test-author` on itself.
- Tests must be RED before implementation - the agent shows the RED run.
  A test that unexpectedly passes is a finding (the behavior may already
  exist), not something to force red.
- Human QA ownership of this step is the TARGET state (ADR-0016): today the
  agent writes, a human validates before the flag goes to prod (flagless
  changes: before the release, `ready_to_test` holds it - ADR-0013). Note in
  the PR that the tests were agent-generated without human QA validation.
- Light tier: the spec delta's single Scenario yields one regression test that
  reproduces the bug/gap and fails on the current code - that IS the RED.

## 4. Implement

- Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
- Branches live ≤2 days; CI warns at 2 and fails at 5 (label `long-lived-ok`
  + a `Why long-lived:` line in the PR body for a deliberate exception).
- Code and spec deltas move together - the spec is part of the change.
- Commit normally: the pre-commit hook runs ruff, hygiene checks, `make sdd-check`.
- The tests already exist - run them locally while implementing; fix the
  implementation until green. Never edit the tests: they are not yours. A test
  that looks wrong goes back to the test step with the Scenario it traces to
  (dispute it, ADR-0012).

## 4b. Feature flags and contract migrations (ADR-0007, ADR-0011, ADR-0015)

- Flags are **on demand, not a process step** (ADR-0015): no step here requires
  creating one. Reach for a flag when the work genuinely must ship dark -
  a contract migration, a branch-by-abstraction replacement, or an epic whose
  half-built state must not be reachable in prod.
- Open question until answered (ADR-0015): who sets `FLAG_<NAME>=1` on stage
  and prod, and where (helm values? service `.env`? CI/CD vars?). Settle that
  with the owner before declaring your first real flag.
- When you do take one, it ships dark behind it: `feature_flags.py`
  maps flag name -> `expires` date, access only via `is_enabled("name")`, enable
  with `FLAG_<NAME>=1`. Full lifecycle: the module docstring + ADR-0007.
- OFF everywhere by default - the flag name and `FLAG_<NAME>=1` go in the QA
  handoff comment (ADR-0011 §2, step 8).
- `make sdd-flags` fails CI 7 days past `expires`; "delete the flag" is a task
  in the same change's tasks.md.
- Touching a FIXED contract (frontend api/v1, external WebAPI, redis streams)?
  The change MUST carry an expand/contract plan (new fields optional -> both
  sides read -> flag flips the producer -> old fields removed before `expires`);
  cross-repo flags use the same `expires` date in both repos, written in the
  contract spec (ADR-0007 §3).
- Large replacement (HubTalk, Asterisk removal): branch by abstraction, deleted
  after cutover (ADR-0007 §5).

## 5. Manual testing

- Walk the QA Scenarios yourself against a local/stage environment before review.

## 6. Review

- `make sdd-check` green, then run the reviewer agents
  (`.claude/agents/backend-reviewer.md` and, when the diff touches SQL, the
  ORM or migrations, `.claude/agents/database-reviewer.md`) on the diff -
  or open the PR and let autoreview do it.
- Fix CRITICAL/HIGH that are in scope of the ticket. Out-of-scope findings:
  add `TODO`/`NOTE` with the ticket id, do not silently expand scope.
- Re-run the tests after applying review fixes.

## 7. Pull request

- Open PR to dev with ticket id in the title: `[feature/WEB-XXXX] <summary>`.
- Body: what changed, why, test plan (link the tests/Scenarios). Say if the
  tests were agent-generated without human QA validation (ADR-0016).
- CI checks on the PR: sdd-gate, the tests, the TBD gates (branch age, PR
  size), autoreview. **All of them are advisory today** (ADR-0015): no branch
  protection, no required check - a red gate does not stop the merge, it tells
  you something is wrong. Treat red as red anyway; that is the whole deal.
  What actually blocks you is local: spec-guard and the pre-commit hook.
- Planned, not implemented yet (ADR-0012 p.8): the traceability gate (each
  Scenario ⇄ one test) and the QA quality gate — treat them as review
  discipline until they exist as CI checks.

## 8. Handoff (ADR-0011)

- After the PR is merged to dev, move the ticket to `status: ready_to_test`
  (youtrack MCP).
- Leave a comment for the tester: what to check and how - crystal clear,
  ONE paragraph max. Include the feature-flag name and how to enable it
  (`FLAG_<NAME>=1`) if there is one, and a link to the QA Scenarios/tests
  (standard/deep).
- QA enables the flag on stage per that comment (`FLAG_<NAME>=1`). Enabling
  the flag in prod happens after QA - then archive the change and schedule the
  flag-removal PR by its `expires`.
