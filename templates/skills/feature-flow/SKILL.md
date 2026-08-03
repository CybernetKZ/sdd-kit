---
name: feature-flow
description: Cybernet team workflow for a YouTrack feature/bugfix task - from task intake to PR. Use when starting work on a WEB-* ticket, or when the user says "possible new task", "новая таска", "сделай WEB-1234".
---

# Feature flow (Cybernet)

The team's standard path from a YouTrack ticket to a merged PR. Business
writes tickets loosely (sometimes one line, sometimes LLM-drafted with
contract/logic mistakes) - so step 1 exists to catch that BEFORE any code.

`ADR-XXXX` references point at the sdd-kit repo's `docs/ADR/`; the essentials are
inlined here, so this skill stands alone without them (never copy ADRs in).

## 1. Task intake - interrogate the ticket first

- Read the ticket (youtrack MCP: `get_issue WEB-XXXX` + comments).
- Planned tasks arrive through the RAISE intake process (ADR-0009) and should
  carry the request form: current problem, expected outcome, alternatives
  considered, RICE score. Pull those into the change's why-section - the
  requester already wrote that context.
- Form missing or incomplete: list the missing fields and keep working on your
  recommended answers. Stop and wait ONLY on serious business forks (pricing,
  client commitments, data deletion) - validating requests is the RAISE process
  owner's job, not yours.
- Cross-check every claim against reality: start from the graph for orientation
  (navigation only - ADR-0004). Probe by SYMBOL, never by prose - a free-form
  question makes BFS start from its capitalized words and returns noise:
  `graphify explain "<sym>"` (file:line + typed edges) first, then
  `query "<sym>"` (BFS fan-out ≈ blast radius; for precise reverse deps use
  grep/ast-grep - the graph keeps one node per file), `path "A" "B"`,
  `query "<sym1> <sym2>"`. `[EXTRACTED]` edges come from the AST, `[INFERRED]`
  ones are guesses - verify both in code. No `graphify-out/graph.json` and the
  repo is large? Build one first: `make sdd-index` (on a Claude subscription the
  first build runs via the interactive `/graphify` command, no API key; later
  updates need none). Then check:
  - the code (does this already exist? does it conflict with current logic?),
  - repo specs in `openspec/specs/` - empty for the touched capability in a
    brownfield repo: lean on the store + the code, and consider running the
    `spec-miner` agent for that capability first,
  - cross-service contracts, in this order: `openspec store list` (is the store
    reachable at all) -> `openspec list --specs --store cybernet-specs` ->
    `openspec show <spec> --type spec --store cybernet-specs`. `openspec view`
    only prints the local dashboard and never reads the store.
  - store freshness: it is a local clone - `git -C <store path> log -1`, pull if
    stale; each store spec ends with `Last verified: <date> @ <sha>`, and if the
    service repo has moved far past that sha, treat the contract as a lead, not
    gospel.
- Output: contradictions, gaps, and questions with your recommended answers,
  addressed to the ticket author, else the RAISE process owner; if neither is
  set, say so explicitly in the change and proceed on the recommended answers.
  Post as a ticket comment (ask the user first).
- Where the intake output lives (it must not evaporate before step 2): write it
  down as soon as it exists. Before the change exists, `mkdir -p
  openspec/changes/<change-id>` and write `openspec/changes/<change-id>/intake.md`;
  once the change exists it belongs in the change itself - the planner folds
  intake.md into proposal.md (findings into the why-section, unanswered questions
  into `## Open questions`) and deletes it.
- Blocking questions stop the DECISION, not the hands: while the author answers,
  prototype on the recommended answer - explicitly marked as a prototype, under
  the same OpenSpec change, gates unchanged; nothing merges while a blocking
  question is open. Non-blocking assumptions: write them down and proceed.

## 1b. Pick the tier (ADR-0010)

Tiers scale preparation depth only. Gates never change: spec, tests before
code, sdd-check, review, CI apply on every tier; no spec-guard bypass. Tasks
genuinely differ - a small clear edit ships via light right away; a risky or
cross-service one earns the full grill.

| Tier | What it means |
|---|---|
| light | minimal change (why + what + a Scenario for the regression test); skip the plan grill. The test is still written before the fix, by `test-author` |
| standard | this skill as written |
| deep | + architecture research before planning (compare options, record the comparison in the change's `design.md` — ADRs are kit-level and live in sdd-kit; target repos have no `docs/ADR/`) + the grill is mandatory |

The tier fixes the pipeline and the models (ADR-0021; models are static in
each agent's frontmatter - no runtime model picking):

| Tier | Pipeline | Models |
|---|---|---|
| light | intake -> change (no planner/griller) -> test-author -> executor | test-author/executor sonnet |
| standard | + planner, grill (agent or inline WITH provenance header) | planner/plan-griller opus, executor sonnet |
| deep | + design research; grill by the `plan-griller` AGENT only | same |

- Tier set in the ticket -> use it as the default.
- The developer may ALWAYS override the tier.
- Nothing set -> decide yourself from the signals: RAISE category, number of
  services touched, migrations, new/changed contracts.
- Tier and size are independent: a deep tier that cannot fit a 2-day branch is
  planned as an epic from the start (one change, several ticket-sized PRs) -
  decided here, not discovered in step 2.
- Write the tier AND its justification into the change (proposal.md) so the
  reviewer can challenge it.

## 2. Plan as an OpenSpec change

- Deep tier first: research architecture options (context7 for library/API
  docs), compare them, record the comparison and the decision in the change's `design.md` (`openspec instructions design --change <id> --json` lists its sections); ADRs stay in sdd-kit for cross-cutting/process decisions. Model binding is
  automatic: plan and grill run as the `planner` / `plan-griller` subagents
  (`model: opus` in their frontmatter, ADR-0013); the implementation runs
  on the session model; bulk mechanical steps can drop to haiku.
- Run the `planner` agent: propose the change (a subagent
  cannot invoke skills - it follows `.claude/skills/openspec-propose/SKILL.md`
  through the openspec CLI; see `planner.md`) -
  proposal + spec deltas + tasks. It starts from step 1's
  `openspec/changes/<change-id>/intake.md`.
- Reference the ticket id in the change. Spec-guard requires this active
  change before code edits in guarded paths.
- Size the change for a 2-day branch (ADR-0006 - a CI warning, not a block).
  Bigger is an epic: split into YouTrack tasks (1 task = 1 PR, ADR-0013) under
  ONE change; a flag only if the half-built epic must stay invisible in prod
  (see 4b, ADR-0015). Archive the change when the flag is on in prod by default
  (ADR-0011), or - flagless - when the last task is merged and verified.
- Touching a cross-repo contract? The spec edit itself is a separate change + PR in
  `cybernet-specs` (its README, "How to add or change a contract"); this change keeps
  the reasoning and a `tasks.md` task naming that store change id, and is not archived
  while the store PR is open (ADR-0018).
- Standard/deep: interrogate the plan before implementing - the `plan-griller`
  agent asks (edge cases, rollback, migrations, cross-service impact), the
  developer answers; anything he cannot answer becomes a question to the ticket
  author. Fix the plan, not the code later. Record it as a `## Grill` section in
  proposal.md, one line per decision, so the "why option B" history survives.
  The section MUST open with a provenance header (ADR-0021): who grilled
  (`plan-griller agent` / `session inline` - be honest), how many questions,
  what changed in the plan. Inline is legal on standard; deep requires the
  agent, and the header is what shows it actually ran.

## 3. Tests from the spec delta - before implementation

The implementer does NOT write the tests. The change (its spec delta) goes
through the test step before any implementation code:

- Validate the spec delta first: every Requirement has at least one measurable
  Scenario (WHEN/THEN), edge cases covered (invalid input, permissions, empty
  values, repeated calls), no conflict with existing contracts. A delta that
  fails validation comes BACK to you - fix the Scenarios, not the tests.
- Run the `test-author` agent (ADR-0016): one test (or an explicit skip with a
  reason) per Scenario, each carrying a tracer comment
  `# spec: <requirement-id> / <scenario>`. An independent agent then
  adversarially checks every test for green stubs - a separate run, never
  `test-author` on itself.
- Tests must be RED before implementation - the agent shows the RED run.
  A test that unexpectedly passes is a finding (the behavior may already
  exist), not something to force red.
- Human QA ownership of this step is the TARGET state (ADR-0016): today the
  agent writes, a human validates before prod (flagless: before the release,
  `ready_to_test` holds it - ADR-0013). Say in the PR that the tests were
  agent-generated without human QA validation.
- Light tier: the spec delta's single Scenario yields one regression test that
  reproduces the bug/gap and fails on the current code - that IS the RED.

## 4. Implement

- Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
- Branches live ≤2 days; CI warns at 2 and fails at 5 (label `long-lived-ok`
  + a `Why long-lived:` line in the PR body for a deliberate exception).
- Code and spec deltas move together - the spec is part of the change.
- The implementation runs as the `executor` subagent on sonnet (ADR-0021):
  hand it the change id once the plan is grilled and the tests are RED. It
  walks tasks.md strictly, never edits tests, never commits, and STOPS with a
  report on any deviation - disputes with `test-author` and "change the plan?"
  calls stay with you, on the session model. Sections of tasks.md run
  sequentially today; parallel executors are a later step, after the
  sequential one survives a real ticket.
- Commit normally after review: the pre-commit hook runs ruff, hygiene
  checks, `make sdd-check`. Committing is the developer's call, not the
  executor's.
- The tests already exist - the executor runs them while implementing and
  fixes the implementation until green. Never edit the tests: they are not
  yours. A test that looks wrong goes back to the test step with the Scenario
  it traces to (dispute it, ADR-0012).

## 4b. Feature flags and contract migrations (ADR-0007, ADR-0011, ADR-0015)

- Flags are **on demand, not a process step** (ADR-0015). Reach for one only when
  the work must ship dark - a contract migration, a branch-by-abstraction
  replacement, or an epic whose half-built state must not be reachable in prod.
- Open question (ADR-0015): who sets `FLAG_<NAME>=1` on stage/prod and where
  (helm values? service `.env`? CI/CD vars?) - settle it before your first flag.
- When you take one: `feature_flags.py` maps flag name -> `expires` date, access
  only via `is_enabled("name")`, enable with `FLAG_<NAME>=1`, OFF everywhere by
  default; flag name + `FLAG_<NAME>=1` go in the QA handoff comment (ADR-0011 §2,
  step 8). Full lifecycle: the module docstring + ADR-0007.
- `make sdd-flags` fails CI 7 days past `expires`; "delete the flag" is a task
  in the same change's tasks.md.
- Touching a FIXED contract (frontend api/v1, external WebAPI, redis streams)?
  The change MUST carry an expand/contract plan (new fields optional -> both
  sides read -> flag flips the producer -> old fields removed before `expires`);
  cross-repo flags share one `expires` date, written in the contract spec (§3).
- Large replacement (HubTalk, Asterisk removal): branch by abstraction, deleted
  after cutover (ADR-0007 §5).

## 5. Manual testing

- Walk the QA Scenarios yourself against a local/stage environment before review.

## 6. Review

- `make sdd-check` green, then run the reviewer agents on the diff
  (`backend-reviewer`, plus `database-reviewer` when the diff touches SQL, the
  ORM or migrations) - or open the PR and let autoreview do it.
- Fix CRITICAL/HIGH that are in scope of the ticket. Out-of-scope findings:
  add `TODO`/`NOTE` with the ticket id, do not silently expand scope.
- Re-run the tests after applying review fixes.

## 7. Pull request

- Open PR to dev with ticket id in the title: `[feature/WEB-XXXX] <summary>`.
- Body: what changed, why, test plan (link the tests/Scenarios). Say if the
  tests were agent-generated without human QA validation (ADR-0016).
- CI checks on the PR: sdd-gate, the tests, the TBD gates (branch age, PR size),
  autoreview. **All advisory today** (ADR-0015) - no branch protection, nothing
  required; a red gate does not stop the merge, it tells you something is wrong.
  Treat red as red anyway. What actually blocks you is local: spec-guard and the
  pre-commit hook. The traceability gate (each Scenario ⇄ one test) and the QA
  quality gate are review discipline until CI has them (ADR-0012 p.8).

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
