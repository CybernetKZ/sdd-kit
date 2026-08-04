# sdd-kit

Installer for spec-driven development (SDD) in a repository - new or existing.
One script (`install.sh`), idempotent: never overwrites existing files, only
adds what is missing.

**Where to start:**

- New to the team or to SDD -> `WORKFLOW.md`, then `docs/GLOSSARY.md`.
- How the process works (signal -> merged PR) -> `WORKFLOW.md`.
- Installing the kit into a repo -> keep reading this file.
- Installed already, "what do I actually use, and how do I start a task?" ->
  [After install: what to use](#after-install-what-to-use) and
  [Working a new task](#working-a-new-task).

## Usage

One command, from inside the repo you want to set up:

```bash
sdd-kit/install.sh                   # repo assets + developer machine tools
sdd-kit/install.sh --repo-only       # repo assets only (path arg optional: defaults to cwd)
sdd-kit/install.sh --machine-only    # only the personal tools on this machine
sdd-kit/install.sh --refresh         # update the kit-owned files to the current kit
sdd-kit/uninstall.sh /path/to/repo   # reverse the repo half: put the repo back the way it was
sdd-kit/uninstall.sh --force /path/to/repo  # also delete kit files that were modified since install
```

Re-running is safe. Every question has a default and plain Enter accepts it
(`[Y/n]` = yes, `[y/N]` = no). `SDD_KIT_ASSUME_YES=1` or no TTY takes all the
defaults without asking; in that mode nothing that downloads and runs remote
code is executed - the command to run yourself is printed instead. The YouTrack
token is only ever read from an interactive prompt.

## Updating the kit in a repo: `install.sh --refresh`

The plain install never overwrites, so a repo installed months ago keeps the
old templates. To pull the current versions in:

```bash
cd /path/to/sdd-kit && git pull
cd /path/to/repo && /path/to/sdd-kit/install.sh --refresh
```

`--refresh` re-copies only the **kit-owned manifest** (the list lives in
`install.sh`, function `kit_manifest`): `.claude/hooks/*.cjs`,
`.claude/agents/*.md`, `.claude/skills/*/` (feature-flow, incident-flow, grilling, grill-me, grill-with-docs, domain-modeling),
`.claude/scripts/{spec-lint.py,sdd-doctor.sh,review-prompt.md}`, `scripts/sdd/*.sh`
and `.git/hooks/pre-commit`.
Each changed file is reported as `refreshed: <path> (+X/-Y lines)`; a second run
reports zero. Repo-owned files are never touched: `AGENTS.md`, `CLAUDE.md`,
`.spec-guard-paths`, `.claude/expected-env`, `ruff.toml`,
`openspec/**`, `.mcp.json`. `.claude/settings.json` is compared, never written:
if its `hooks` block drifted from the template you get a WARN and merge by hand
(the repo may have added its own hooks). Review the result with `git diff`
before committing. `--refresh` is the repo section only - machine tools have no
refresh semantics, re-run `--machine-only` for those.

## Uninstall

`uninstall.sh` reverses the repo install with one safety rule: a file is deleted
only when it is byte-identical to the kit template (or profile payload) that
installed it - anything the team modified is kept, with a WARN and the exact
manual command. `--force` deletes the kit-installed files even when modified
(useful when the repo carries an older kit version); AGENTS.md and openspec/
are team content and are never force-deleted. The `CLAUDE.md -> AGENTS.md`
rename is offered back;
`openspec/` (specs + changes) is deleted only after an explicit yes. The
central store registration is machine-wide state shared by every repo: it is
unregistered only on an interactive yes or with `--force` - an unattended run
(no TTY / `SDD_KIT_ASSUME_YES=1`) keeps it and prints the manual command. On an untouched install the round trip is
clean: `git status` shows the repo exactly as before install.

## What it installs

| Artifact | Purpose |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | canonical agent context, ≤500 lines; existing `CLAUDE.md` is renamed, not lost |
| `openspec/` | `openspec init --tools claude` on the pinned CLI **`@fission-ai/openspec@1.7.0`** (same pin in `install.sh`, `scripts/sdd/check.sh` and `sdd-doctor.sh`, each marked `# openspec-pin` - bump all of them together). Creates `openspec/specs/` (capability specs), `openspec/changes/` (+ `archive/`), `openspec/config.yaml`, and the six `.claude/skills/openspec-*` skills. A profile may instead restore a prepared `openspec/` tree from `PROFILE_OPENSPEC_SEED_REF` |
| `scripts/sdd/*.sh` | 5 scripts (the Makefile is gone, ADR-0026 §3): `check.sh` (the gate: AGENTS.md exists/≤500 lines + `openspec validate --all --strict`, blocking; spec-lint advisory until `SPEC_LINT_STRICT=1`), `doctor.sh`, `test.sh` (advisory ruff+pytest, override with `SDD_TEST_CMD`), `review.sh` (local AI review of the diff, seeded with static leads in `/tmp/tools.txt` when radon/complexipy/vulture/semgrep are installed), `index.sh` (graphify graph, built/updated by install too, never a gate - ADR-0004). Every failure prints a concrete `next:` step |
| `.claude/agents/` | 7 agents: `planner` + `plan-griller` (phase-2 plan/grill on opus via `model` frontmatter, ADR-0013), `test-author` (phase-3 failing tests from the spec delta, sonnet, ADR-0016), `executor` (phase-4 implementation on sonnet, strictly `tasks.md`-bound, ADR-0021), `backend-reviewer` (Python/FastAPI) and `database-reviewer` (PostgreSQL/SQLAlchemy) for the AI review step, `repo-auditor` (read-only agent-readiness audit of the repo). Full table with the OpenSpec wiring: [After install](#after-install-what-to-use) |
| `.claude/hooks/` + `.claude/settings.json` | spec-guard (blocks code edits without an active `openspec/changes/<id>/` - **silent until `.spec-guard-paths` lists at least one path prefix**), a `git commit --no-verify` blocker, and a PreCompact survival packet (`.claude/last-session-state.md` - active change + uncommitted work, so agents resume after compaction; idea from ProjectStore, ADR-0008) |
| `.claude/scripts/spec-lint.py` | spec freshness (`Last verified` vs `git diff` over `enforced:` anchors) + spec metadata validation; runs inside `sdd-check`, warn-only until `SPEC_LINT_STRICT=1`. Anchor format: `<!-- enforced: path/to/file.py:ClassName.method -->` - repo-relative path first, symbol (or line/range) after the colon. **Both halves are checked**: a missing file or a symbol that does not appear in it makes the spec MISSING (bare `ClassName.method()` anchors are not resolved - see Design notes) |
| `.git/hooks/pre-commit` | protected-branch guard (main/master/prod/stage block, dev warns; `SDD_ALLOW_PROTECTED=1` overrides), ruff autofix+format on staged Python, hygiene checks (merge markers, >5 MB files, `breakpoint()`, secrets/token patterns, new submodules, invalid JSON/TOML/YAML) + `scripts/sdd/check.sh` (merged by hand if a hook already exists) |
| `.claude/scripts/review-prompt.md` | the one canonical AI-review prompt, used by `scripts/sdd/review.sh` |
| `.claude/scripts/sdd-doctor.sh` | environment doctor (`scripts/sdd/doctor.sh`): required tools (git, node, python3 ≥3.10, uv, ruff, openspec), claude/gh CLI + auth, store registration, youtrack token, hooks/pre-commit presence, (profile) presence of per-service `.env` files a fresh clone needs - paths only, never secret values - and an `audit` section (advisory clutter: extra MCP servers, foreign agent-tool configs like .cursor/.serena, stray skills/agents); runs at the end of the install; findings as `{level, group, code, message, next}` with the exact fix command, `--json` for machines (ADR-0008) |
| `.mcp.json` | project MCP servers: context7 + youtrack (paths resolved for this machine) |
| `.claude/skills/feature-flow/` | the team's ticket-to-PR workflow as a skill: interrogate the YouTrack ticket -> pick tier (light/standard/deep, ADR-0010) -> OpenSpec change + grill -> validate the spec delta, then the `test-author` agent writes the tests BEFORE code (QA-SDD-PROCESS.md, ADR-0016; the implementer never writes them, human QA ownership is the target) -> implement -> manual check -> review -> PR -> ready_to_test handoff |
| `.claude/skills/incident-flow/` | the team's incident workflow: collect evidence (CybernetKZ/incident_collect) -> root-cause doc (bug/misuse/infra - misuse/infra: the doc is the deliverable) -> OpenSpec change -> regression test first (written by the `test-author` agent from the incident scenario), then fix -> verify against the incident -> ready_to_test handoff |
| `.claude/skills/{grilling,grill-me,grill-with-docs,domain-modeling}/` | the grill practice, vendored from [mattpocock/skills](https://github.com/mattpocock/skills): a relentless one-question-at-a-time interview to stress-test a plan, with grill-with-docs recording decisions into the project's ADR registry and glossary as they crystallise (this is how the kit's own ADR-0019...0023 sessions ran) |
| `ruff.toml` | explicit-select Ruff config (classic E/F + curated additions) - installed ONLY when the repo has no Ruff config of its own; explicit select because ruff ≥0.15 default rules ballooned to 400+ |
| `.spec-guard-paths` + store wiring | for known repos (see Profiles below): seeded automatically |

## Profiles

`profiles/<repo-basename>.env` tailors the install for known repos. When the
target directory name matches a profile, install.sh additionally:

- seeds `.spec-guard-paths` with the repo's real production-code prefixes
  (tests/docs/migrations/helm values stay unguarded);
- copies a payload directory `profiles/<repo-basename>/` if one exists -
  pre-configured files for that repo (a filled-in `AGENTS.md`, openspec
  config, ...), never overwriting existing files;
- wires the central spec store: clones it if missing (with permission),
  registers it (`openspec store register`), and appends `references:` to
  `openspec/config.yaml` - `openspec validate` stays green on machines/CI
  without the store; `openspec doctor` tells you how to register it;
- skips Python tooling for non-Python repos (`PROFILE_SKIP_PY=1`);
- seeds `.claude/expected-env` from `PROFILE_ENV_FILES` so `sdd-doctor` warns when
  a per-service `.env` a fresh clone needs is missing (WBN lists all 8 services);
- for the store repo itself (`PROFILE_IS_STORE=1`): minimal install - local
  registration + a strict-validate CI gate, nothing else.

The store is read-only for a service repo. A repo change that needs a
cross-repo contract edited keeps the reasoning in its own `proposal.md`, but
the spec edit itself is a separate change + PR in `cybernet-specs`; the repo
change's `tasks.md` carries an explicit task linking to it and cannot be
archived while that PR is open (ADR-0018). Spec metadata differs by location:
local `openspec/specs/**` requirements carry `<!-- id: -->` / `<!-- enforced: -->`
(read by `spec-lint.py`), store contracts stay prose with `file.py:line`
anchors (ADR-0017).

Shipped profiles: web-backend-new, voice-agent-constructor-backend,
voice-agent-postcall-analitics-backend, cybernet3.0, web-frontend-new,
conversation_flow, cybernet-specs (the store). Unknown repos fall back to the
generic flow with a `.spec-guard-paths` TODO.

## Dependencies

Checked on start: git, node/npx, uv. Missing openspec CLI or youtrack-mcp are
offered for install (with permission). No YouTrack token -> the script shows
https://cybernet.youtrack.cloud/users/me?tab=account-security, reads the token
hidden, and stores it only in youtrack-mcp's `.env` (chmod 600) - never in the
repo.

## After install (manual)

1. Fill the TODOs in `AGENTS.md`.
2. Create `.spec-guard-paths` (code path prefixes, one per line) to enable
   spec-guard - automatic for known repos (see Profiles). Until this file has a
   non-comment line, spec-guard and the LIVING SPEC pre-commit fragment are
   deliberate no-ops.
3. Seed `openspec/specs/` one capability at a time. The kit does **not** ship a
   spec-miner agent - use the `openspec-explore` / `openspec-sync-specs` skills,
   or a machine-level miner agent of your own; the conversation_flow run that
   produced the current convention is written up in `docs/archive/SPEC_MINER_PILOT.md`
   and `docs/archive/STORE_VERIFICATION.md`. Anchor format is
   `<!-- enforced: path/to/file.py:ClassName.method -->` and `spec-lint.py`
   validates **both** halves - a fabricated symbol makes the spec MISSING.
4. Run `scripts/sdd/doctor.sh` and clear the FAILs. WARNs are advisory clutter
   reports, not blockers.
5. AI review auth (subscription, no API key): tokens are PER-DEVELOPER,
   machine-level - no shared GitHub secret. Run reviews locally with
   `scripts/sdd/review.sh`; there is no CI AI-step (ADR-0023/0026).

GitHub branch protection and required checks are intentionally **not** part of
setup: enforcement stays local and advisory today (ADR-0015). Turning the
server gates on is one deliberate, separate decision.

## After install: what to use

Three kinds of thing land in the repo. Only the middle column blocks anything.

**Skills** - prompt-level workflows you invoke. Two ship with the kit and are
model-invocable (an agent may pick them up on its own); the six `openspec-*`
skills come from `openspec init` and carry `disable-model-invocation: true`,
meaning they run only when you name them.

| Skill | Use it for | OpenSpec wiring |
|---|---|---|
| `/feature-flow` | a YouTrack feature/bugfix ticket, end to end (8 steps, tier table) | reads `openspec/specs/` + the store, writes `openspec/changes/<id>/intake.md`, then drives the change through to archive |
| `/incident-flow` | a prod incident reported in chat | same change machinery, but the root-cause doc is the first deliverable |
| `/openspec-propose` | create a change (proposal + spec deltas + tasks) | writes `openspec/changes/<id>/` |
| `/openspec-update-change` | amend a change already in flight | rewrites the same dir |
| `/openspec-apply-change` | implement against a change | reads `tasks.md` |
| `/openspec-archive-change` | close a shipped change | moves it to `openspec/changes/archive/` and folds deltas into `openspec/specs/` |
| `/openspec-sync-specs` | reconcile specs with reality | rewrites `openspec/specs/` |
| `/openspec-explore` | find out what is already specified before writing anything | read-only over `openspec/` |

**Agents** - subagents you delegate a phase to. They cannot invoke skills, so
each carries the relevant protocol inline.

| Agent | Phase | Model | OpenSpec wiring |
|---|---|---|---|
| `planner` | 2 - plan | opus | **writes** `openspec/changes/<id>/` (proposal + spec deltas + tasks) |
| `plan-griller` | 2 - interrogate the plan | opus | **reads** the change, returns a paste-ready `## Grill` block for `proposal.md`; the dialogue itself belongs to the main session (ADR-0012) |
| `test-author` | 3 - RED tests | sonnet | **reads** the spec delta, one test per `#### Scenario:`, tracer comment `# spec: <requirement-id> / <scenario>` |
| `executor` | 4 - implement | sonnet | **reads** `tasks.md`, drives RED to green; never commits, never edits tests, stops and reports on deviation (ADR-0021) |
| `backend-reviewer` | 5 - review | sonnet | reads the diff + specs |
| `database-reviewer` | 5 - review | sonnet | reads migrations/queries |
| `repo-auditor` | any time | inherits | read-only agent-readiness scorecard for the repo |

**Utils** - the deterministic half. These are the only things that can stop you.

| Util | Blocks? | What it does |
|---|---|---|
| `scripts/sdd/check.sh` | yes (pre-commit) | AGENTS.md present/≤500 lines, `openspec validate --all --strict`; spec-lint advisory |
| `.claude/scripts/spec-lint.py` | only with `SPEC_LINT_STRICT=1` | spec freshness (`> Last verified: <date> (commit <hash>)` vs `git diff` over `enforced:` anchors) + metadata (`id`+`enforced` on every Requirement, ids unique, whitelisted keys only, no `#### Scenario:` under `## Invariants`) |
| `.git/hooks/pre-commit` | yes | protected branches, hygiene, secrets, ruff autofix, then `sdd-check` when spec-related files are staged |
| `.claude/hooks/spec-guard.cjs` | yes, once `.spec-guard-paths` is filled | no code edits without an active change |
| `.claude/hooks/block-no-verify.cjs` | yes | no `--no-verify` / `commit -n` |
| `scripts/sdd/doctor.sh` | no | environment + repo + clutter audit, `--json` for machines |
| `scripts/sdd/test.sh` | no | ruff + pytest, advisory (ADR-0015); `SDD_TEST_CMD` overrides for monorepos |
| `scripts/sdd/review.sh` | no | local AI review of `git diff $SDD_REVIEW_BASE...HEAD` |
| `scripts/sdd/index.sh` | no | graphify graph for navigation only (ADR-0004) |

Are they wired to OpenSpec correctly? Yes, with two things to know. The CLI is
pinned to `1.7.0` in four places (`# openspec-pin`) - bump them together or
`sdd-check` and `sdd-doctor` will disagree. And `openspec validate --all
--strict` checks *structure* (a Requirement needs at least one Scenario, a
change needs its deltas), while `spec-lint.py` checks *truthfulness* (do the
`enforced:` anchors point at symbols that exist, is the spec still fresh). Both
run inside `scripts/sdd/check.sh`; neither replaces the other.

## Working a new task

The pipeline is one shape with three depths. Pick the depth from the tier table
in `.claude/skills/feature-flow/SKILL.md` §1b (ADR-0010/ADR-0021) - preparation
depth varies, **the gates never do**.

```
ticket -> intake -> change -> [grill] -> RED tests -> implement -> review -> PR -> archive
```

| Tier | When | Pipeline |
|---|---|---|
| light | one obvious change, no design questions | intake -> change -> `test-author` -> `executor` |
| standard | the default | + `planner` writes the change, + `plan-griller` interrogates it |
| deep | architecture, cross-repo contract, risky data path | + `openspec instructions design` research pass, grill by agent |

Concretely, for "we have a new task":

1. **Invoke `/feature-flow` with the ticket id.** It does the intake
   interrogation and picks the tier; everything below happens inside it. Doing
   the steps by hand is fine too - the skill is the checklist, not a wrapper.
2. **Read before writing.** `/openspec-explore` (or the store:
   `openspec list --specs --store cybernet-specs`) tells you what is already
   specified. Changing documented behaviour is a different task than adding to
   it.
3. **Create the change**, not the code: `openspec/changes/<id>/` with
   `proposal.md`, the spec deltas, and `tasks.md`. `planner` for standard/deep.
   This is what unblocks spec-guard.
4. **Grill it, then review it - in that order.** `plan-griller` hardens the
   plan; `tz-review`-style mechanical review verifies claims against the code.
   These are not duplicates (ADR-0020): review first for facts, grill after for
   design.
5. **`test-author` writes failing tests from the spec deltas** - one per
   `#### Scenario:`. RED before any production code (ADR-0016). The implementer
   never writes its own tests.
6. **`executor` implements** against `tasks.md` until the tests go green. It
   stops and reports rather than improvising past the plan.
7. **`scripts/sdd/test.sh`, `scripts/sdd/check.sh`, `scripts/sdd/review.sh`**, then the reviewer
   agents on the diff.
8. **PR -> merge -> archive the change** (`/openspec-archive-change`), which
   folds the deltas into `openspec/specs/`. If the task touched a cross-repo
   contract, the store edit is its own change + PR in `cybernet-specs`, and this
   change cannot be archived while that PR is open (ADR-0018).

**A repo may override this.** `conversation_flow` is the live example: it runs a
project-local `/tz -> /tz-review -> plan-griller -> test-author -> /tz-implement`
trilogy instead of `feature-flow`, keeps `docs/DOCUMENTATION.md` as a LIVING
SPEC in parallel with `openspec/specs/` forever, and keeps `.spec-guard-paths`
empty on purpose while the conversion runs (ADR-0019,
`docs/archive/PLAN_CF_MIGRATION.md`). There, `feature-flow` is installed but used only
as the source of the tier table. Always read the target repo's `AGENTS.md`
before assuming the kit's default flow applies - the repo's own lints and guards
outrank the kit's.

## Per-developer tools: install.sh --machine-only

The repo half installs repo assets; personal tooling lives on each developer's
machine (baking it into every repo bloats context and duplicates state). It runs
as part of a plain `install.sh`, or on its own:

```bash
sdd-kit/install.sh --machine-only   # core stack installs by default [Y/n]
```

**Core stack (default install - quality up, token spend down):**
**ponytail** (plugin: minimal working solutions, saves tokens),
**rtk** (shell-output compressor + global hook),
**Graphify** (repo knowledge graph - faster/cheaper code analysis; PyPI name
`graphifyy`, installed as `graphifyy[postgres,sql]`), **ast-grep** (AST codemods
for bulk mechanical refactors), **ruff** (linter/formatter behind the pre-commit
hook and `scripts/sdd/test.sh`), and the **static review tools** radon / complexipy /
vulture / semgrep (leads for `scripts/sdd/review.sh` via `/tmp/tools.txt`; each is
optional - a missing one just means fewer leads).
`scripts/sdd/doctor.sh` warns when a core tool is missing.

**Optional (opt-in y/N):** **gh-axi** and **chrome-devtools-axi**
(agent-ergonomic CLI wrappers, ~/.claude/skills), **serena** (semantic
code-navigation MCP via uvx - an earlier trial left `.serena/` litter that
the sdd-doctor audit section flags, so it stays opt-in).

Not offered here: **caveman** (only a benchmark arm inside the ponytail repo, not a
standalone tool - ponytail covers it; the grill practice itself is installed
per-repo: `grilling`/`grill-me`/`grill-with-docs`/`domain-modeling` are in the
repo manifest), **Playwright** (chrome-devtools-axi covers the
browser loop), **Headroom** (dropped 2026-07-31: compresses ~0-2%, breaks the
prompt-cache prefix, measured +45..62% cost - see
[ADR-0014](docs/ADR/ADR-0014-drop-headroom.md)).

## Configuration

- `YOUTRACK_URL` - YouTrack instance for youtrack-mcp (default: cybernet.youtrack.cloud).
- `YOUTRACK_MCP_DIR` - where youtrack-mcp lives (default search: ~/dev, ~/cybernet).
- `SDD_KIT_ASSUME_YES=1` - auto-confirm installs in non-TTY runs (never the token).
- `SPEC_LINT_STRICT=1` - make spec freshness/metadata violations blocking.
- `SDD_TEST_CMD` - replace the `scripts/sdd/test.sh` command (monorepos, non-pytest stacks).
- `SDD_REVIEW_BASE` - diff base for `scripts/sdd/review.sh` (default `origin/HEAD`, fallback `dev`).
- `SDD_ALLOW_PROTECTED=1` - one-off bypass of the protected-branch commit guard.
- `SDD_STORE_ID` / `SDD_STORE_DIR` / `SDD_STORE_GIT` - central spec store id,
  local checkout path, and clone URL (defaults: cybernet-specs,
  ~/cybernet/cybernet-specs, github.com/octrow/cybernet-specs).

## Process docs

- `WORKFLOW.md` - the end-to-end team flow (signal -> merged PR) with every
  tool's plug-in point.
- `QA-SDD-PROCESS.md` - the separate QA workflow: tests are written BEFORE
  implementation, from the OpenSpec spec delta, with a traceability gate
  (each Scenario ⇄ one test) and adversarial verification of generated tests.
  Whoever writes the implementation never writes its tests: today that is the
  `test-author` agent, with human QA ownership as the target (ADR-0016).

## Design notes

Gate output follows [axi](https://github.com/kunchenguid/axi) agent-ergonomics
principles: summary line first, explicit "0 issues" instead of silence, and a
concrete `next:` command suggestion on every failure path.

No magic: "skills"/"rules"/"plugins" are prompts injected into the model's
context - advisory by nature, the model can ignore them. Hooks
(pre-commit, PreToolUse/PreCompact) are deterministic code and cannot be
ignored. Enforcement therefore lives only in hooks + CI gates, and every
installed piece must be verifiable (a gate, a log line, a measured
artifact) - the `sdd-doctor` audit section names what never runs.

Spec anchors are paths, not symbols. `spec-lint` used to resolve a bare
`ClassName.method()` by building a CamelCase->file index and falling back to
`git grep`; in a monorepo that over-matched same-named classes across services
and made `enforced_files` counts fiction. The resolver was dropped: write the
path in the spec (`path/to/file.py:ClassName.method`), and the symbol after the
colon stays there for humans and code-explorer. Older specs mined with bare
symbols report MISSING until rewritten. The symbol half is validated too: a
miner that invented `agent.py:build_agent_session` used to pass every gate
(conversation_flow defect M1), so `spec-lint` now requires the symbol to appear
in the named file.

Decision trail for the workflow shape: **ADR-0021** (executor subagent + the
tier->pipeline->models table), **ADR-0020** (`tz-review` and `plan-griller` are
not duplicates - review first, grill after), **ADR-0019** (conversation_flow
onboarding: convert and verify all specs first, only then run a task on the new
process), **ADR-0010** (three tiers vary preparation, never gates). Index with
one-line summaries: `docs/ADR/README.md`.

And today even the CI half is advisory on purpose (ADR-0015): branch
protection is off and no check is required, so the only pieces that actually
block are local (spec-guard, the `--no-verify` blocker, pre-commit). Server
gates are honest signals in a log; switching them on is one deliberate
decision, deferred rather than cancelled.

## Attribution

The reviewer agents are adapted from
[everything-claude-code](https://github.com/affaan-m/ECC) (MIT).

## Layout

```
install.sh            installer: --repo-only (repo assets) / --machine-only (dev tools)
uninstall.sh          per-repo uninstaller (reverses install.sh, keeps team edits)
WORKFLOW.md           end-to-end team flow + a live "what runs today vs planned" table
QA-SDD-PROCESS.md     the QA half: tests before code, from the spec delta
profiles/             per-repo overrides: spec-guard paths, store wiring, py/no-py
                      (+ optional payload dirs copied into the repo)
templates/            everything installed into repos (English-only)
  agents/             the 7 subagents (planner, plan-griller, test-author,
                      executor, backend-reviewer, database-reviewer, repo-auditor)
  skills/             team skills (feature-flow, incident-flow, grill set)
tools/cf/             conversation_flow migration instructions - run by hand,
                      NOT installed (mine-section, verify-section, patch2change, ...)
docs/                 ADR/ (the decision registry), GLOSSARY.md, DEFECTS_CF.md,
                      archive/ (finished plans, dry-runs, handoffs), ...
```

## Benchmarks

The [cc-bench](https://github.com/octrow/cc-bench) repo (local:
`/home/octrow/cybernet/cc-bench`) is the benchmark harness for this stack;
design docs live in its `docs/`.
Historical m1/m2 benchmark runs: `docs/archive/benchmark-m1-m2/` (in Russian).
