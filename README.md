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
`.claude/scripts/{spec-lint.py,sdd-doctor.sh,review-prompt.md}`, `scripts/sdd/*.sh`
and `.git/hooks/pre-commit`. Agents and the shared skills are **not** in the
manifest anymore - they come from the `code-conventions` plugin (ADR-0027).
Each changed file is reported as `refreshed: <path> (+X/-Y lines)`; a second run
reports zero. Repo-owned files are never touched: `AGENTS.md`, `CLAUDE.md`,
`.spec-guard-paths`, `.claude/expected-env`, `ruff.toml`,
`openspec/**`, `.mcp.json`. `.claude/settings.json` is never rewritten wholesale:
its `hooks`, `extraKnownMarketplaces` and `enabledPlugins` blocks are additively
merged instead (`merge_settings()`, run on both install and `--refresh`) -
missing kit hooks are added in, the `code-conventions@cybernet` plugin is
enabled, and anything the repo added on its own is left untouched. Review the
result with `git diff` before committing. `--refresh` is the repo section only -
machine tools have no refresh semantics, re-run `--machine-only` for those.

`--refresh` also runs the **ADR-0027 migration cleanup**: the agents and shared
skills that moved into the plugin are deleted from the repo, but only when both
halves hold - the file is still byte-identical to the kit's old template (kept
verbatim in `templates/_migrated/`, or any version of it ever committed to the
kit) **and** the plugin is confirmed available (enabled in
`.claude/settings.json` *and* installed on this machine). Otherwise the files
stay and the run says why: refresh must never leave a repo with neither the file
nor the plugin. Team-modified copies are always kept, with the exact `diff`
command.

## Uninstall

`uninstall.sh` reverses the repo install with one safety rule: a file is deleted
only when it is byte-identical to the kit template (or profile payload) that
installed it - anything the team modified is kept, with a WARN and the exact
manual command. `--force` deletes the kit-installed files even when modified
(useful when the repo carries an older kit version); AGENTS.md and openspec/
are team content and are never force-deleted. The `CLAUDE.md -> AGENTS.md`
rename is offered back;
`openspec/` (specs + changes) is deleted only after an explicit yes. The
A `.claude/settings.json` the install merged into (the repo had its own hooks, or
another marketplace) is team content and is kept - drop the two kit-added keys
(`extraKnownMarketplaces.cybernet`, `enabledPlugins["code-conventions@cybernet"]`)
by hand. Copies of the migrated agents/skills left over from an older kit are
still removed under the same byte-identical rule (the old templates stay in
`templates/_migrated/` for exactly this comparison). The
central store registration is machine-wide state shared by every repo: it is
unregistered only on an interactive yes or with `--force` - an unattended run
(no TTY / `SDD_KIT_ASSUME_YES=1`) keeps it and prints the manual command. On an untouched install the round trip is
clean: `git status` shows the repo exactly as before install.

## What it installs

| Artifact | Purpose |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | canonical agent context, ≤500 lines; existing `CLAUDE.md` is renamed, not lost |
| `openspec/` | `openspec init --tools claude` on the pinned CLI **`@fission-ai/openspec@1.7.0`** (the same pin is marked `openspec-pin` at every site - installers, scripts, agent prompts; `grep -rn openspec-pin` finds them all; `grep '# openspec-pin'` finds them all - bump all of them together). Creates `openspec/specs/` (capability specs), `openspec/changes/` (+ `archive/`), `openspec/config.yaml`, and the six `.claude/skills/openspec-*` skills. A profile may instead restore a prepared `openspec/` tree from `PROFILE_OPENSPEC_SEED_REF` |
| `scripts/sdd/*.sh` | 5 scripts (the Makefile is gone, ADR-0026 §3): `check.sh` (the gate: AGENTS.md exists/≤500 lines + `openspec validate --all --strict`, blocking; spec-lint advisory until `SPEC_LINT_STRICT=1`), `doctor.sh`, `test.sh` (advisory ruff+pytest, override with `SDD_TEST_CMD`), `review.sh` (local AI review of the diff, seeded with static leads in `/tmp/tools.txt` when radon/complexipy/vulture/semgrep are installed), `index.sh` (graphify graph, built/updated by install too, never a gate - ADR-0004). Every failure prints a concrete `next:` step |
| the 7 agents | **via the `code-conventions` plugin, not copied into the repo** (ADR-0027): `planner` + `plan-griller` (phase-2 plan/grill on opus via `model` frontmatter, ADR-0013), `test-author` (phase-3 failing tests from the spec delta, sonnet, ADR-0016), `executor` (phase-4 implementation on sonnet, strictly `tasks.md`-bound, ADR-0021), `backend-reviewer` (Python/FastAPI) and `database-reviewer` (PostgreSQL/SQLAlchemy) for the AI review step, `repo-auditor` (read-only agent-readiness audit). What the kit installs is the *enablement*: the marketplace + `enabledPlugins` entry below. Full table with the OpenSpec wiring: [After install](#after-install-what-to-use) |
| `.claude/settings.json` plugin entries | `extraKnownMarketplaces.cybernet` (`CybernetKZ/code-conventions`) + `enabledPlugins["code-conventions@cybernet"]`, merged additively on install and `--refresh` - the "zero-click for a whole project" shape from the plugin's README. Anyone opening the project accepts one trust prompt and has the agents and shared skills. `superpowers` and `ponytail` come along as plugin dependencies |
| `.claude/hooks/` + `.claude/settings.json` | spec-guard (blocks code edits without an active `openspec/changes/<id>/` - **silent until `.spec-guard-paths` lists at least one path prefix**), a `git commit --no-verify` blocker, and a PreCompact survival packet (`.claude/last-session-state.md` - active change + uncommitted work, so agents resume after compaction; idea from ProjectStore, ADR-0008) |
| `.claude/scripts/spec-lint.py` | spec freshness (`Last verified` vs `git diff` over `enforced:` anchors) + spec metadata validation; runs inside `sdd-check`, warn-only until `SPEC_LINT_STRICT=1`. Anchor format: `<!-- enforced: path/to/file.py:ClassName.method -->` - repo-relative path first, symbol (or line/range) after the colon. **Both halves are checked**: a missing file or a symbol that does not appear in it makes the spec MISSING (bare `ClassName.method()` anchors are not resolved - see Design notes) |
| `.git/hooks/pre-commit` | protected-branch guard (main/master/prod/stage block, dev warns; `SDD_ALLOW_PROTECTED=1` overrides), ruff autofix+format on staged Python, hygiene checks (merge markers, >5 MB files, `breakpoint()`, secrets/token patterns, new submodules, invalid JSON/TOML/YAML) + `scripts/sdd/check.sh` (merged by hand if a hook already exists) |
| `.claude/scripts/review-prompt.md` | the one canonical AI-review prompt, used by `scripts/sdd/review.sh` |
| `.claude/scripts/sdd-doctor.sh` | environment doctor (`scripts/sdd/doctor.sh`): required tools (git, node, python3 ≥3.10, uv, ruff, openspec), claude/gh CLI + auth, store registration, youtrack token, hooks/pre-commit presence, (profile) presence of per-service `.env` files a fresh clone needs - paths only, never secret values - and an `audit` section (advisory clutter: extra MCP servers, foreign agent-tool configs like .cursor/.serena, stray skills/agents); runs at the end of the install; findings as `{level, group, code, message, next}` with the exact fix command, `--json` for machines (ADR-0008) |
| `.mcp.json` | project MCP servers: context7 + youtrack (paths resolved for this machine) |
| `feature-flow` skill (**via the plugin**, ADR-0027) | the team's ticket-to-PR workflow as a skill: interrogate the YouTrack ticket -> pick tier (light/standard/deep, ADR-0010) -> OpenSpec change + grill -> validate the spec delta, then the `test-author` agent writes the tests BEFORE code (QA-SDD-PROCESS.md, ADR-0016; the implementer never writes them, human QA ownership is the target) -> implement -> manual check -> review -> PR -> ready_to_test handoff |
| `incident-flow` skill (**via the plugin**) | the team's incident workflow: collect evidence (CybernetKZ/incident_collect) -> root-cause doc (bug/misuse/infra - misuse/infra: the doc is the deliverable) -> OpenSpec change -> regression test first (written by the `test-author` agent from the incident scenario), then fix -> verify against the incident -> ready_to_test handoff |
| `{grilling,grill-me,grill-with-docs,domain-modeling}` skills (**via the plugin**) | the grill practice, vendored from [mattpocock/skills](https://github.com/mattpocock/skills): a relentless one-question-at-a-time interview to stress-test a plan, with grill-with-docs recording decisions into the project's ADR registry and glossary as they crystallise (this is how the kit's own ADR-0019...0023 sessions ran) |
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
  registration + a pre-commit hook in the store's own clone that runs
  `openspec validate --all --strict` at commit time (ADR-0026 §5), nothing else.

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
offered for install (with permission). The `code-conventions@cybernet` plugin is
a real dependency of the *prompt* half (agents + shared skills, ADR-0027): the
install wires it into `.claude/settings.json`, Claude Code resolves it on the
next open (trust prompt), and `scripts/sdd/doctor.sh` reports `repo.plugin` when
it is missing. Enforcement never depends on it - hooks, pre-commit, `openspec/`
and `scripts/sdd/*` are physically in the repo (ADR-0027 §2). No YouTrack token -> the script shows
https://cybernet.youtrack.cloud/users/me?tab=account-security, reads the token
hidden, and stores it only in youtrack-mcp's `.env` (chmod 600) - never in the
repo.

## After install (manual)

1. Fill the TODOs in `AGENTS.md`.
1b. Reopen the project in Claude Code and accept the trust prompt for the
   `cybernet` marketplace - that is what actually pulls in
   `code-conventions@cybernet` with the 7 agents and the shared skills
   (ADR-0027). Or do it by hand:
   `claude plugin marketplace add CybernetKZ/code-conventions && claude plugin install code-conventions@cybernet`.
2. Create `.spec-guard-paths` (code path prefixes, one per line) to enable
   spec-guard - automatic for known repos (see Profiles). Until this file has a
   non-comment line, spec-guard is a deliberate no-op. (LIVING SPEC docs drift
   for conversation_flow has no pre-commit check either - ADR-0026 §4 removed
   it in favor of on-demand `tools/cf/main-drift.sh`.)
3. Seed `openspec/specs/` one capability at a time with the `spec-miner` agent,
   which comes from the `code-conventions` plugin like every other kit agent
   (ADR-0027) - it needs plugin **1.2.0 or newer**, and `doctor.sh` reports an
   older cached build as `repo.plugin` `partial`. It is a subagent, not a skill:
   there is no `/spec-miner`, you delegate to it. One capability per run - it
   writes only `openspec/specs/<capability>/spec.md` and its Bash is read-only.
   Its metadata keys and the anchor format `<!-- enforced: path/to/file.py:ClassName.method -->`
   are a contract with `spec-lint.py` (`ALLOWED_KEYS` + anchor resolution):
   `spec-lint` validates **both** halves, so a fabricated symbol makes the spec
   MISSING, and changing either side alone fails every mined spec at the
   pre-commit gate. The conversation_flow run that produced this convention is
   written up in `docs/archive/SPEC_MINER_PILOT.md` and
   `docs/archive/STORE_VERIFICATION.md`. For a spec that already has a change
   with deltas, archive the change instead - mining is only for behaviour that
   never went through the pipeline.
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

**Skills** - prompt-level workflows you invoke. `feature-flow` and
`incident-flow` come from the `code-conventions` plugin (ADR-0027 - the kit
enables the plugin, it no longer copies the files); the six `openspec-*` skills
come from `openspec init` into the repo and carry
`disable-model-invocation: true`, meaning they run only when you name them.
Without the plugin enabled and installed, everything in the first two rows and
the whole Agents table below simply does not exist - `scripts/sdd/doctor.sh`
reports that as `repo.plugin`.

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

**Agents** - subagents you delegate a phase to. All eight come from the
`code-conventions` plugin (ADR-0027), not from `.claude/agents/`. They cannot
invoke skills, so each carries the relevant protocol inline.

| Agent | Phase | Model | OpenSpec wiring |
|---|---|---|---|
| `planner` | 2 - plan | opus | **writes** `openspec/changes/<id>/` (proposal + spec deltas + tasks) |
| `plan-griller` | 2 - interrogate the plan | opus | **reads** the change, returns a paste-ready `## Grill` block for `proposal.md`; the dialogue itself belongs to the main session (ADR-0012) |
| `test-author` | 3 - RED tests | sonnet | **reads** the spec delta, one test per `#### Scenario:`, tracer comment `# spec: <requirement-id> / <scenario>` |
| `executor` | 4 - implement | sonnet | **reads** `tasks.md`, drives RED to green; never commits, never edits tests, stops and reports on deviation (ADR-0021) |
| `backend-reviewer` | 5 - review | sonnet | reads the diff + specs |
| `database-reviewer` | 5 - review | sonnet | reads migrations/queries |
| `repo-auditor` | any time | inherits | read-only agent-readiness scorecard for the repo |
| `spec-miner` | 0 - onboarding | opus | **writes** `openspec/specs/<capability>/spec.md` from existing code, one capability per run; flat Requirement/Invariant blocks with `id`/`enforced`/`entities` metadata that `spec-lint.py` validates |

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
pinned to `1.7.0` at every marked site (`grep -rn openspec-pin` finds them all) - bump
them together or `sdd-check` and `sdd-doctor` will disagree. And `openspec validate --all
--strict` checks *structure* (a Requirement needs at least one Scenario, a
change needs its deltas), while `spec-lint.py` checks *truthfulness* (do the
`enforced:` anchors point at symbols that exist, is the spec still fresh). Both
run inside `scripts/sdd/check.sh`; neither replaces the other.

## Working a new task

The pipeline is one shape with three depths. Pick the depth from the tier table
in the `feature-flow` skill (plugin) §1b (ADR-0010/ADR-0021) - preparation
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

### Worked example: WEB-2316 in `conversation_flow`

The override above, spelled out end to end. Ticket `WEB-2316`, target repo
`/home/octrow/cybernet/conversation_flow`, kit freshly installed.

**0. Verify the install, then restart Claude Code.**

```bash
cd /home/octrow/cybernet/conversation_flow
bash scripts/sdd/doctor.sh          # must end in 0 failure(s)
git status --short                  # must NOT show staged D for .claude/hooks/*, scripts/sdd/*
```

Two things bite here. `install.sh` after an `uninstall.sh` leaves the kit files
staged as **deleted** (uninstall removes them via git, install only re-tracks the
`CLAUDE.md` symlink) - `git add .claude/hooks .claude/scripts scripts/sdd .mcp.json
.spec-guard-paths` before you commit anything, or the commit takes the kit out
with it. And the plugin, hooks and skills only take effect after a restart, so
`/tz` does not exist in the session that ran the installer.

`doctor.sh` will report `WARN [repo.spec-guard]` here. That is correct for this
repo, not a defect: `.spec-guard-paths` is comments-only on purpose until phase 5
of the CF migration.

**1. Read `AGENTS.md` first.** It is the reason this example does not start with
`/feature-flow`.

**2. Find out what is already specified** - changing documented behaviour is a
different task than adding to it.

```bash
openspec list --specs                                  # this repo
openspec list --specs --store cybernet-specs           # cross-repo contracts
grep -rn "<the behaviour you are about to touch>" docs/DOCUMENTATION.md
```

`/openspec-explore` does the same read-only sweep conversationally.

**3. Pick the ТЗ number - count it, never guess.** CF numbers changes
`tz-NNN-<slug>`; the YouTrack id lives inside `proposal.md`, not in the directory
name. The next free number is the **maximum of four sources** (`/tz` §1 lists
them; `origin/main` still creates `docs/patches/` in parallel, so the remote
lookup is not redundant). Say the max comes back `100` - you are `tz-101`.

**4. `/tz WEB-2316`** writes `openspec/changes/tz-101-<slug>/` - `proposal.md`
(with `> Тикет: WEB-2316`), the spec deltas, `tasks.md`. Branch:
`feature/web-2316-<slug>`.

**5. `/tz-review`, then `plan-griller`. In that order** (ADR-0020): review checks
the change's claims against the actual code and returns
`готово к реализации` / `требует правок`; the grill then attacks the design and
its answers land in the `## Grill` section of `proposal.md`. Do not implement
while either is open.

**6. `test-author`** turns each `#### Scenario:` in the spec delta into one
failing test with a `# spec: <requirement-id> / <scenario>` tracer. RED before
production code (ADR-0016) - the implementer never writes its own tests.

**7. `/tz-implement`** walks the phases with their STOP gates: logical commits
tagged `ТЗ №101`, `make test` plus the frontend build after each, and the spec
delta, `docs/DOCUMENTATION.md`, §17 changelog and version bump in those same
commits.

**8. Gates, then PR.** `scripts/sdd/test.sh`, `scripts/sdd/check.sh`,
`scripts/sdd/review.sh`, then `backend-reviewer` on the diff and
`database-reviewer` too if it touched migrations or queries. Merge, then archive
the change - which folds the deltas into `openspec/specs/`. If WEB-2316 had
touched a cross-repo contract, the `cybernet-specs` edit would be its own change
and PR, and this change could not be archived while that PR was open (ADR-0018).

## Where a rule lives: judgment channels and precedence

Two channels, on purpose, and one precedence order (ADR-0027 §6 - the same text
lives in the `code-conventions` repo, so it is readable from either side):

| Channel | What goes there | How it changes |
|---|---|---|
| **YouTrack KB** (Web-A-8) | live calls about code style - the things that get revisited often | edited in place, no PR |
| **sdd-kit `docs/ADR/` + `docs/GLOSSARY.md`** | process decisions that must outlive a session and deserve review | PR |

**Precedence when they disagree:** the target repo's `AGENTS.md` > YouTrack KB >
skills (plugin or otherwise). A repo's own rule always wins - the kit's default
flow is a default, not a mandate. A style call in the KB outranks a skill's
prose, because the KB is where the team keeps changing its mind on purpose. If a
decision keeps being re-litigated in the KB, that is the signal to promote it to
an ADR.

## Per-developer tools: install.sh --machine-only

The repo half installs repo assets; personal tooling lives on each developer's
machine (baking it into every repo bloats context and duplicates state). It runs
as part of a plain `install.sh`, or on its own:

```bash
sdd-kit/install.sh --machine-only   # core stack installs by default [Y/n]
```

**CLI binaries only** (ADR-0027 §7). Claude Code *plugins* are not installed
here: `ponytail` (and optionally `rtk-plugin`) arrive as dependencies of
`code-conventions` through the `cybernet` marketplace, which the repo half
enables in `.claude/settings.json`. Installing ponytail from here as well would
enable the same plugin from two marketplaces and load its skills twice.

**Core stack (default install - quality up, token spend down):**
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
standalone tool - ponytail covers it; the grill practice
`grilling`/`grill-me`/`grill-with-docs`/`domain-modeling` comes from the
`code-conventions` plugin, ADR-0027), **Playwright** (chrome-devtools-axi covers the
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
ignored. There is no server CI for target repos (ADR-0023/0026): enforcement
therefore lives only in local hooks, and every installed piece must be
verifiable (a gate, a log line, a measured artifact) - the `sdd-doctor` audit
section names what never runs.

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

And gates are local-only by design (ADR-0015/0023/0026): there is no server
CI for target repos, no branch protection, no required check - the only
pieces that actually block are local (spec-guard, the `--no-verify` blocker,
pre-commit's `scripts/sdd/check.sh`). The store repo adds its own local
pre-commit `openspec validate --all --strict` on its clone (ADR-0026 §5).
Turning server gates on for target repos is one deliberate decision,
deferred rather than cancelled.

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
.github/workflows/ci.yml   self-test of the kit itself (shellcheck, syntax,
                      smoke install) - never installed into target repos, so
                      it does not contradict the "no server CI" doctrine above
                      (that doctrine is about target repos, not the kit repo)
```

## Benchmarks

The [cc-bench](https://github.com/octrow/cc-bench) repo (local:
`/home/octrow/cybernet/cc-bench`) is the benchmark harness for this stack;
design docs live in its `docs/`.
Historical m1/m2 benchmark runs: `docs/archive/benchmark-m1-m2/` (in Russian).
