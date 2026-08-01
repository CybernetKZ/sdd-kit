# sdd-kit

Installer for spec-driven development (SDD) in a repository - new or existing.
One script (`install.sh`), idempotent: never overwrites existing files, only
adds what is missing.

**Where to start:**

- New to the team or to SDD -> `docs/ONBOARDING.md`.
- How the process works (signal -> merged PR) -> `WORKFLOW.md`.
- Installing the kit into a repo -> keep reading this file.

## Usage

One command, from inside the repo you want to set up:

```bash
sdd-kit/install.sh                   # repo assets + developer machine tools
sdd-kit/install.sh --repo-only       # repo assets only (path arg optional: defaults to cwd)
sdd-kit/install.sh --machine-only    # only the personal tools on this machine
sdd-kit/uninstall.sh /path/to/repo   # reverse the repo half: put the repo back the way it was
sdd-kit/uninstall.sh --force /path/to/repo  # also delete kit files that were modified since install
```

Re-running is safe. Every question has a default and plain Enter accepts it
(`[Y/n]` = yes, `[y/N]` = no). `SDD_KIT_ASSUME_YES=1` or no TTY takes all the
defaults without asking; in that mode nothing that downloads and runs remote
code is executed — the command to run yourself is printed instead. The YouTrack
token is only ever read from an interactive prompt.

`bootstrap.sh` and `setup-dev.sh` still work as deprecated shims for
`--repo-only` / `--machine-only` and will be removed after one release.

## Uninstall

`uninstall.sh` reverses the repo install with one safety rule: a file is deleted
only when it is byte-identical to the kit template (or profile payload) that
installed it - anything the team modified is kept, with a WARN and the exact
manual command. `--force` deletes the kit-installed files even when modified
(useful when the repo carries an older kit version); AGENTS.md and openspec/
are team content and are never force-deleted. The `CLAUDE.md -> AGENTS.md`
rename is offered back;
`openspec/` (specs + changes) and the central store registration are touched
only after an explicit yes. On an untouched install the round trip is
clean: `git status` shows the repo exactly as before install.

## What it installs

| Artifact | Purpose |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | canonical agent context, ≤500 lines; existing `CLAUDE.md` is renamed, not lost |
| `openspec/` | OpenSpec init (`--tools claude`); specs + delta-changes live here |
| `Makefile.sdd` (+ `-include` in Makefile) | `make sdd-check`: AGENTS.md exists/≤500 lines + `openspec validate --all --strict` + `sdd-flags` (blocking) + spec-lint (advisory until `SPEC_LINT_STRICT=1`); every failure prints a concrete `next:` step |
| `feature_flags.py` | minimal flag registry (ADR-0007), **on demand - no process step requires a flag** (ADR-0015): flag name -> `expires` date, `FLAG_<NAME>=1` to enable, `is_enabled()` to read; `make sdd-flags` warns 7 days past expiry, then fails CI. Lifecycle is documented in the module docstring; `git add` it so the gate sees it |
| `.github/workflows/sdd-ci.yml` | the SDD gate on every pull request - **advisory today**: no branch protection, no required check (ADR-0015); + `tbd-gates` job (ADR-0006): branch age (warn >2 days, red >5) and PR size (fail >1500 changed lines; edit `PR_XL_LINES` in the workflow if a repo needs another limit) - escape labels `long-lived-ok`/`xl-ok` require a `Why ...:` reason in the PR body |
| `.github/workflows/autoreview.yml` | PR auto-review: AI review via headless `claude -p` using the shared prompt `.claude/scripts/review-prompt.md`, fed a static-tool report (radon, complexipy, vulture, semgrep security patterns) it must verify before reporting; the whole job exits in seconds when `CLAUDE_CODE_OAUTH_TOKEN` is absent |
| `.claude/agents/` | `backend-reviewer` (Python/FastAPI) and `database-reviewer` (PostgreSQL/SQLAlchemy) for the AI review step + `planner` and `plan-griller` (phase-2 plan/grill on opus via `model` frontmatter, ADR-0013) + `test-author` (phase-3 failing tests from the spec delta, sonnet, ADR-0016) |
| `.claude/hooks/` + `.claude/settings.json` | spec-guard (blocks code edits without an active `openspec/changes/<id>/`), a `git commit --no-verify` blocker, and a PreCompact survival packet (`.claude/last-session-state.md` - active change + uncommitted work, so agents resume after compaction; idea from ProjectStore, ADR-0008) |
| `.claude/scripts/spec-lint.py` | spec freshness (`Last verified` vs `git diff` over `enforced:` anchors) + spec-miner metadata validation; runs inside `sdd-check`, warn-only until `SPEC_LINT_STRICT=1` |
| `.git/hooks/pre-commit` | protected-branch guard (main/master/prod/stage block, dev warns; `SDD_ALLOW_PROTECTED=1` overrides), ruff autofix+format on staged Python, hygiene checks (merge markers, >5 MB files, `breakpoint()`, secrets/token patterns, new submodules, invalid JSON/TOML/YAML) + `make sdd-check` (merged by hand if a hook already exists) |
| `.claude/scripts/review-prompt.md` | the one canonical AI-review prompt, used by both `make sdd-review` and `autoreview.yml` |
| `.claude/scripts/sdd-doctor.sh` | environment doctor (`make sdd-doctor`): required tools (git, node, python3 ≥3.10, uv, ruff, openspec), claude/gh CLI + auth, store registration, youtrack token, hooks/pre-commit presence, (profile) presence of per-service `.env` files a fresh clone needs - paths only, never secret values - and an `audit` section (advisory clutter: extra MCP servers, foreign agent-tool configs like .cursor/.serena, stray skills/agents); runs at the end of the install; findings as `{level, group, code, message, next}` with the exact fix command, `--json` for machines (ADR-0008) |
| `.mcp.json` | project MCP servers: context7 + youtrack (paths resolved for this machine) |
| `.claude/skills/feature-flow/` | the team's ticket-to-PR workflow as a skill: interrogate the YouTrack ticket -> pick tier (light/standard/deep, ADR-0010) -> OpenSpec change + grill -> validate the spec delta, then the `test-author` agent writes the tests BEFORE code (QA-SDD-PROCESS.md, ADR-0016; the implementer never writes them, human QA ownership is the target) -> implement -> manual check -> review -> PR -> ready_to_test handoff |
| `.claude/skills/incident-flow/` | the team's incident workflow: collect evidence (CybernetKZ/incident_collect) -> root-cause doc (bug/misuse/infra - misuse/infra: the doc is the deliverable) -> OpenSpec change -> regression test first (written by the `test-author` agent from the incident scenario), then fix -> verify against the incident -> ready_to_test handoff |
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
   spec-guard - automatic for known repos (see Profiles).
3. Seed specs with the spec-miner agent, one capability at a time.
4. GitHub: make `sdd-gate` a required check, enable branch protection on dev.
5. AI review auth (subscription, no API key): tokens are PER-DEVELOPER,
   machine-level - no shared GitHub secret. Run reviews locally with
   `make sdd-review`; the CI AI-step skips (in seconds) when no secret exists.

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
`graphify`), **ast-grep** (AST codemods for bulk mechanical refactors).
`make sdd-doctor` warns when a core tool is missing.

**Optional (opt-in y/N):** **gh-axi** and **chrome-devtools-axi**
(agent-ergonomic CLI wrappers, ~/.claude/skills), **serena** (semantic
code-navigation MCP via uvx - an earlier trial left `.serena/` litter that
the sdd-doctor audit section flags, so it stays opt-in).

Not offered: **caveman** (only a benchmark arm inside the ponytail repo, not a
standalone tool - ponytail covers it), **grill-with-docs** (team practice, not
a self-contained install), **Playwright** (chrome-devtools-axi covers the
browser loop), **Headroom** (dropped 2026-07-31: compresses ~0-2%, breaks the
prompt-cache prefix, measured +45..62% cost - see
[ADR-0014](docs/ADR/ADR-0014-drop-headroom.md)).

## Configuration

- `YOUTRACK_URL` - YouTrack instance for youtrack-mcp (default: cybernet.youtrack.cloud).
- `YOUTRACK_MCP_DIR` - where youtrack-mcp lives (default search: ~/dev, ~/cybernet).
- `SDD_KIT_ASSUME_YES=1` - auto-confirm installs in non-TTY runs (never the token).
- `SPEC_LINT_STRICT=1` - make spec freshness/metadata violations blocking.
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

And today even the CI half is advisory on purpose (ADR-0015): branch
protection is off and no check is required, so the only pieces that actually
block are local (spec-guard, the `--no-verify` blocker, pre-commit). Server
gates are honest signals in a log; switching them on is one deliberate
decision, deferred rather than cancelled.

## Attribution

Reviewer agents and spec-miner are adapted from
[everything-claude-code](https://github.com/affaan-m/ECC) (MIT).

## Layout

```
install.sh            installer: --repo-only (repo assets) / --machine-only (dev tools)
uninstall.sh          per-repo uninstaller (reverses install.sh, keeps team edits)
bootstrap.sh          deprecated shim -> install.sh --repo-only
setup-dev.sh          deprecated shim -> install.sh --machine-only
profiles/             per-repo overrides: spec-guard paths, store wiring, py/no-py
templates/            everything installed into repos (English-only)
  agents/             reviewer agents for autoreview
  skills/             team skills (feature-flow: ticket-to-PR workflow)
```

## Benchmarks

The [cc-bench](https://github.com/octrow/cc-bench) repo (local:
`/home/octrow/cybernet/cc-bench`) is the benchmark harness for this stack;
design docs live in its `docs/`.
Historical m1/m2 benchmark runs: `docs/archive/benchmark-m1-m2/` (in Russian).
