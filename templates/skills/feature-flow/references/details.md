# Feature flow - details

Read this when you hit one of these: epic mechanics, a disputed test, the QA
fallback, contract migrations, intake/store command
sequences, PR body and handoff wording, or the light-tier specifics.

## 1. Task intake - the long version

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
   `scripts/sdd/index.sh`) is in AGENTS.md, "Codebase search"; no
   `graphify-out/graph.json` in a large repo means build the index first (on a
   Claude subscription the first build runs through the interactive `/graphify`
   command, no API key - later updates need none). Then check:
   - the code (does this already exist? does it conflict with current logic?),
   - repo specs in `openspec/specs/` - empty for the touched capability in a
     brownfield repo: lean on the store + the code, and consider running the
     `spec-miner` agent for that capability first,
   - cross-service contracts in the store: `openspec store list` ->
     `openspec list --specs --store cybernet-specs` -> `openspec show <spec>
     --type spec --store cybernet-specs` (details in
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

## 1b. Tier notes

Tiers exist because tasks genuinely differ - a small clear edit ships via light
right away; a risky or cross-service one earns the full grill. Tier and size are
independent: a deep tier that cannot fit a 2-day branch is planned as an epic
from the start (one change, several ticket-sized PRs) - decided while picking the
tier, not discovered in step 2.

## 2. Planning as an OpenSpec change - the long version

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
4. Size the change for a 2-day branch (a process rule you watch yourself, no
   automated check). Bigger is an epic: the unit of work is fixed at 1 YouTrack
   task = 1 PR, so split the epic into YouTrack tasks (declared in the tracker at
   intake, not invented in tasks.md) under ONE change; each task's PR moves its
   slice of code and runs the tests that already exist. Half-built state that
   must stay unreachable in prod: keep the wiring-in (route/handler/caller)
   for the LAST task instead of hiding merged code behind a flag (flags are
   cut, ADR-0026 §2). Archive the change
   when the last task is merged and verified.
5. Epic tests are written ONCE for the whole change (all Scenarios, before the
   first PR); Scenarios not yet implemented stay as explicit skips.
   Intermediate merges do NOT ping QA - the
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

## 3. Tests - validation, QA fallback, light tier

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
   a human validates before prod (before the release, `ready_to_test`
   holds it - the release checklist verifies in YouTrack that no shipped ticket
   is still in `ready_to_test` without a human QA verdict). Say in the PR that
   the tests were agent-generated without human QA validation.
5. Light tier: the spec delta's single Scenario yields one regression test that
   reproduces the bug/gap and fails on the current code - that IS the RED.

## 4. Implementation - branch rules and the disputed test

1. Branch: `feature/WEB-XXXX` (or `bugfix/WEB-XXXX`) off dev.
2. Branches live ≤2 days - a process rule, not an automated check (no server
   CI): if a branch runs long on purpose, say why in a `Why long-lived:` line
   in the PR body.
3. Code and spec deltas move together - the spec is part of the change.
4. The implementation runs as the `executor` subagent on sonnet: hand it the
   change id once the plan is grilled and the tests are RED. It walks tasks.md
   strictly, never edits tests, never commits, and STOPS with a report (in
   Russian) on any deviation - disputes with `test-author` and "change the plan?"
   calls stay with you, on the session model. Sections of tasks.md run
   sequentially today; parallel executors are a later step, after the
   sequential one survives a real ticket.
5. Commit normally after review: the pre-commit hook runs ruff, hygiene
   checks, `scripts/sdd/check.sh`. Committing is the developer's call, not the
   executor's.
6. The tests already exist - the executor runs them while implementing and
   fixes the implementation until green. A red test means one of three things,
   each with its own exit: the implementation is wrong -> fix the
   implementation; the test contradicts its Scenario -> dispute it, back to the
   test step with the Scenario it traces to, and never edit the test yourself
   (they are not yours; the arbiter is the Scenario text); the Scenario itself
   is ambiguous -> the spec delta goes back to its author.

## 4b. Contract migrations

There is no flag registry or lifecycle anymore (cut entirely, ADR-0026 §2);
a switch, when a migration truly needs one, is a plain config value with no
process around it.

1. Touching a FIXED contract (frontend api/v1, external WebAPI, redis streams)?
   The change MUST carry an expand/contract plan (new fields optional -> both
   sides read -> producer switches -> old fields removed); the removal step is
   a task in the same change's tasks.md, owned by the change's author.
2. Large replacement (HubTalk, Asterisk removal): branch by abstraction, deleted
   after cutover.

## 6. Review - scope discipline

1. `scripts/sdd/check.sh` green, then run the reviewer agents on the diff
   (`backend-reviewer`, plus `database-reviewer` when the diff touches SQL, the
   ORM or migrations) with `scripts/sdd/review.sh` - locally, before opening the
   PR; there is no server-side review step.
2. Fix CRITICAL/HIGH that are in scope of the ticket. Out-of-scope findings:
   add `TODO`/`NOTE` with the ticket id, do not silently expand scope.
3. Re-run the tests after applying review fixes.

## 7. Pull request conventions

1. Open PR to dev with ticket id in the title: `[feature/WEB-XXXX] <summary>`.
   Opening the PR is the developer's action by default; ONLY on their explicit
   command the agent runs `gh pr create` itself (ADR-0026 §1) - never
   unprompted.
2. Body: what changed, why, test plan (link the tests/Scenarios). Say if the
   tests were agent-generated without human QA validation.
3. There is no server CI - what actually blocks you is local: spec-guard, the
   pre-commit hook (runs `scripts/sdd/check.sh`), and `scripts/sdd/test.sh` /
   `scripts/sdd/review.sh`
   run before opening the PR, not after. Branch age (≤2 days) and PR size
   (≤1500 lines) are process rules the developer watches themselves - no
   automated check enforces them, and there are no escape labels for them
   anymore. The traceability gate (each Scenario ⇄ one test) and the QA
   quality gate are review discipline, same as before.

## 8. Handoff wording

1. After the PR is merged to dev, move the ticket to `status: ready_to_test`
   (youtrack MCP). Same rule as the PR: the developer's action by default,
   the agent does it only on their explicit command (ADR-0026 §1).
2. Leave a comment for the tester **in Russian**: what to check and how -
   crystal clear, ONE paragraph max, with a link to the QA
   Scenarios/tests (standard/deep).
