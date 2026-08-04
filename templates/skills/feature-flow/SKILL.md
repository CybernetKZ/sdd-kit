---
name: feature-flow
description: Cybernet team workflow for a YouTrack feature/bugfix task - from task intake to PR. Use when starting work on a WEB-* ticket, or when the user says "possible new task", "новая таска", "сделай WEB-1234".
---

# Feature flow (Cybernet)

The team's standard path from a YouTrack ticket to a merged PR. Business
writes tickets loosely (sometimes one line, sometimes LLM-drafted with
contract/logic mistakes) - so step 1 exists to catch that BEFORE any code.

**Language rule.** Everything you write for a human reader goes out **in
Russian**: questions to the developer, ticket comments (intake questions to the
ticket author), the QA handoff comment, stop/done reports. Machine-readable
parts stay English: ids, branch names, tier names, flag names, tracer comments,
spec/Scenario text, commit and PR titles.

## 1. Task intake - interrogate the ticket first

1. Read the ticket (youtrack MCP: `get_issue WEB-XXXX` + comments).
2. Planned tasks arrive through the RAISE intake process and should carry the
   request form: current problem, expected outcome, alternatives considered,
   RICE score. Pull those into the change's why-section - the requester already
   wrote that context.
3. Form missing or incomplete: list the missing fields and keep working on your
   recommended answers. Stop and wait ONLY on serious business forks (pricing,
   client commitments, data deletion) - validating requests is the RAISE process
   owner's job, not yours.
4. Cross-check every claim against reality. Start from the repo knowledge graph
   for orientation only - it never decides anything, and `[INFERRED]` edges are
   guesses to confirm in code. Probe by SYMBOL, never by prose: a free-form
   question makes BFS start from its capitalized words and returns noise. The
   exact command sequence (`graphify explain` -> `query` -> `path`, plus
   `make sdd-index`) is in AGENTS.md, "Codebase search"; no
   `graphify-out/graph.json` in a large repo means build the index first (on a
   Claude subscription the first build runs through the interactive `/graphify`
   command, no API key - later updates need none). Then check:
   - the code (does this already exist? does it conflict with current logic?),
   - repo specs in `openspec/specs/` - empty for the touched capability in a
     brownfield repo: lean on the store + the code, and consider running the
     `spec-miner` agent for that capability first,
   - cross-service contracts in the store: `openspec store list` ->
     `openspec list --specs --store cybernet-specs` -> `openspec show <spec>
     --type spec --store cybernet-specs` (details and flag placement in
     AGENTS.md, "Specs and contracts"; `openspec view` only prints the local
     dashboard and never reads the store),
   - store freshness: it is a local clone - `git -C <store path> log -1`, pull if
     stale; each store spec ends with `Last verified: <date> @ <sha>`, and if the
     service repo has moved far past that sha, treat the contract as a lead, not
     gospel.
5. Output the contradictions, gaps, and questions **in Russian**, each with your
   recommended answer, addressed to the ticket author, else the RAISE process
   owner; if neither is set, say so explicitly in the change and proceed on the
   recommended answers. Post as a ticket comment (ask the user first).
6. Write the intake output down as soon as it exists - it must not evaporate
   before step 2. Before the change exists, `mkdir -p
   openspec/changes/<change-id>` and write `openspec/changes/<change-id>/intake.md`;
   once the change exists it belongs in the change itself - the planner folds
   intake.md into proposal.md (findings into the why-section, unanswered questions
   into `## Open questions`) and deletes it.
7. Blocking questions stop the DECISION, not the hands: while the author answers,
   prototype on the recommended answer - explicitly marked as a prototype, under
   the same OpenSpec change, gates unchanged; nothing merges while a blocking
   question is open. Non-blocking assumptions: write them down and proceed.

## 1b. Pick the tier

Tiers scale preparation depth only. Gates never change: spec, tests before
code, sdd-check, review, CI apply on every tier; no spec-guard bypass. Tasks
genuinely differ - a small clear edit ships via light right away; a risky or
cross-service one earns the full grill.

| Tier | What it means |
|---|---|
| light | minimal change (why + what + a Scenario for the regression test); skip the plan grill. The test is still written before the fix, by `test-author` |
| standard | this skill as written |
| deep | + architecture research before planning (compare options, record the comparison in the change's `design.md` — ADRs are kit-level and live in sdd-kit; target repos have no `docs/ADR/`) + the grill is mandatory |

The tier fixes the pipeline and the models. Models are static in each agent's
frontmatter - never pick a model at runtime:

| Tier | Pipeline | Models |
|---|---|---|
| light | intake -> change (no planner/griller) -> test-author -> executor | test-author/executor sonnet |
| standard | + planner, grill (agent or inline WITH provenance header) | planner/plan-griller opus, executor sonnet |
| deep | + design research; grill by the `plan-griller` AGENT only | same |

Picking it:

1. Tier set in the ticket -> use it as the default.
2. The developer may ALWAYS override the tier.
3. Nothing set -> decide yourself from the signals: RAISE category, number of
   services touched, migrations, new/changed contracts. Rough defaults: typo /
   config value / isolated bug with no cross-service impact -> light; a regular
   feature inside one service -> standard; cross-service change, data migration,
   new architecture, unknown territory -> deep.
4. Tier and size are independent: a deep tier that cannot fit a 2-day branch is
   planned as an epic from the start (one change, several ticket-sized PRs) -
   decided here, not discovered in step 2.
5. Write the tier AND its justification into the change (proposal.md) so the
   reviewer can challenge it.

## 2. Plan as an OpenSpec change

1. Deep tier first: research architecture options (context7 for library/API
   docs), compare them, record the comparison and the decision in the change's
   `design.md` (`openspec instructions design --change <id> --json` lists its
   sections); ADRs stay in sdd-kit for cross-cutting/process decisions. Model
   binding is automatic: plan and grill run as the `planner` / `plan-griller`
   subagents (`model: opus` in their frontmatter); the implementation runs on
   the session model; bulk mechanical steps can drop to haiku.
2. Run the `planner` agent: propose the change (a subagent cannot invoke skills
   - it follows `.claude/skills/openspec-propose/SKILL.md` through the openspec
   CLI; see `planner.md`) - proposal + spec deltas + tasks. It starts from step
   1's `openspec/changes/<change-id>/intake.md`.
3. Reference the ticket id in the change. Spec-guard requires this active
   change before code edits in guarded paths.
4. Size the change for a 2-day branch (a CI warning, not a block). Bigger is an
   epic: the unit of work is fixed at 1 YouTrack task = 1 PR, so split the epic
   into YouTrack tasks (declared in the tracker at intake, not invented in
   tasks.md) under ONE change; each task's PR moves its slice of code and runs
   the tests that already exist. A flag only if the half-built epic must stay
   invisible in prod (see 4b). Archive the change when the flag is on in prod by
   default, or - flagless - when the last task is merged and verified.
5. Epic tests are written ONCE for the whole change (all Scenarios, before the
   first PR); Scenarios not yet implemented stay as explicit skips (or, with a
   flag, run behind it while OFF). Intermediate merges do NOT ping QA - the
   single `ready_to_test` handoff happens when the whole change is done on stage.
6. Touching a cross-repo contract? The spec edit itself is a separate change + PR in
   `cybernet-specs` (its README, "How to add or change a contract"); this change keeps
   the reasoning and a `tasks.md` task naming that store change id, and is not archived
   while the store PR is open.
7. Standard/deep: interrogate the plan before implementing - the `plan-griller`
   agent asks (edge cases, rollback, migrations, cross-service impact), the
   developer answers **in Russian**; anything he cannot answer becomes a question
   to the ticket author. Fix the plan, not the code later. Record it as a
   `## Grill` section in proposal.md, one line per decision, so the "why option
   B" history survives. The section MUST open with a provenance header: who
   grilled (`plan-griller agent` / `session inline` - be honest), how many
   questions, what changed in the plan. Inline is legal on standard; deep
   requires the agent, and the header is what shows it actually ran.

## 3. Tests from the spec delta - before implementation

The implementer does NOT write the tests. The change (its spec delta) goes
through the test step before any implementation code:

1. Validate the spec delta first: every Requirement has at least one measurable
   Scenario (WHEN/THEN), edge cases covered (invalid input, permissions, empty
   values, repeated calls), no conflict with existing contracts. A delta that
   fails validation comes BACK to you - fix the Scenarios, not the tests.
2. Run the `test-author` agent: one test (or an explicit skip with a reason) per
   Scenario, each carrying a tracer comment `# spec: <requirement-id> /
   <scenario>`. An independent agent then adversarially checks every test for
   green stubs - a separate run, never `test-author` on itself.
3. Tests must be RED before implementation - the agent shows the RED run.
   A test that unexpectedly passes is a finding (the behavior may already
   exist), not something to force red.
4. Human QA ownership of this step is the TARGET state: today the agent writes,
   a human validates before prod (flagless: before the release, `ready_to_test`
   holds it - the release checklist verifies in YouTrack that no shipped ticket
   is still in `ready_to_test` without a human QA verdict). Say in the PR that
   the tests were agent-generated without human QA validation.
5. Light tier: the spec delta's single Scenario yields one regression test that
   reproduces the bug/gap and fails on the current code - that IS the RED.

## 4. Implement

1. Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
2. Branches live ≤2 days; CI warns at 2 and fails at 5 (label `long-lived-ok`
   + a `Why long-lived:` line in the PR body for a deliberate exception).
3. Code and spec deltas move together - the spec is part of the change.
4. The implementation runs as the `executor` subagent on sonnet: hand it the
   change id once the plan is grilled and the tests are RED. It walks tasks.md
   strictly, never edits tests, never commits, and STOPS with a report (in
   Russian) on any deviation - disputes with `test-author` and "change the plan?"
   calls stay with you, on the session model. Sections of tasks.md run
   sequentially today; parallel executors are a later step, after the
   sequential one survives a real ticket.
5. Commit normally after review: the pre-commit hook runs ruff, hygiene
   checks, `make sdd-check`. Committing is the developer's call, not the
   executor's.
6. The tests already exist - the executor runs them while implementing and
   fixes the implementation until green. A red test means one of three things,
   each with its own exit: the implementation is wrong -> fix the
   implementation; the test contradicts its Scenario -> dispute it, back to the
   test step with the Scenario it traces to, and never edit the test yourself
   (they are not yours; the arbiter is the Scenario text); the Scenario itself
   is ambiguous -> the spec delta goes back to its author.

## 4b. Feature flags and contract migrations

1. Flags are **on demand, not a process step**. Reach for one only when
   the work must ship dark - a contract migration, a branch-by-abstraction
   replacement, or an epic whose half-built state must not be reachable in prod.
2. Open question, still unsettled: who sets `FLAG_<NAME>=1` on stage/prod and
   where (helm values? service `.env`? CI/CD vars?) - settle it before your
   first flag.
3. When you take one: `feature_flags.py` maps flag name -> `expires` date, access
   only via `is_enabled("name")`, enable with `FLAG_<NAME>=1`, OFF everywhere by
   default; flag name + `FLAG_<NAME>=1` go in the QA handoff comment (step 8).
   Full lifecycle: the module docstring.
4. `make sdd-flags` fails CI 7 days past `expires`; "delete the flag" is a task
   in the same change's tasks.md, owned by the change's author.
5. Touching a FIXED contract (frontend api/v1, external WebAPI, redis streams)?
   The change MUST carry an expand/contract plan (new fields optional -> both
   sides read -> flag flips the producer -> old fields removed before `expires`);
   cross-repo flags share one `expires` date, written in the contract spec (§3).
6. Large replacement (HubTalk, Asterisk removal): branch by abstraction, deleted
   after cutover.

## 5. Manual testing

- Walk the QA Scenarios yourself against a local/stage environment before review.

## 6. Review

1. `make sdd-check` green, then run the reviewer agents on the diff
   (`backend-reviewer`, plus `database-reviewer` when the diff touches SQL, the
   ORM or migrations) - or open the PR and let autoreview do it.
2. Fix CRITICAL/HIGH that are in scope of the ticket. Out-of-scope findings:
   add `TODO`/`NOTE` with the ticket id, do not silently expand scope.
3. Re-run the tests after applying review fixes.

## 7. Pull request

1. Open PR to dev with ticket id in the title: `[feature/WEB-XXXX] <summary>`.
2. Body: what changed, why, test plan (link the tests/Scenarios). Say if the
   tests were agent-generated without human QA validation.
3. CI checks on the PR: sdd-gate, the tests, the TBD gates (branch age, PR size),
   autoreview. **All advisory today** - no branch protection, nothing
   required; a red gate does not stop the merge, it tells you something is wrong.
   Treat red as red anyway. What actually blocks you is local: spec-guard and the
   pre-commit hook. The traceability gate (each Scenario ⇄ one test) and the QA
   quality gate are review discipline until CI has them.

## 8. Handoff

1. After the PR is merged to dev, move the ticket to `status: ready_to_test`
   (youtrack MCP).
2. Leave a comment for the tester **in Russian**: what to check and how -
   crystal clear, ONE paragraph max. Include the feature-flag name and how to
   enable it (`FLAG_<NAME>=1`) if there is one, and a link to the QA
   Scenarios/tests (standard/deep).
3. QA enables the flag on stage per that comment (`FLAG_<NAME>=1`). Enabling
   the flag in prod happens after QA - then archive the change and schedule the
   flag-removal PR by its `expires`.
