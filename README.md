# sdd-kit

Bootstrap for spec-driven development (SDD) in a repository — new or
existing. One script, idempotent: never overwrites existing files, only adds
what is missing.

## Usage

```bash
sdd-kit/bootstrap.sh /path/to/repo   # per repository: SDD assets, gates, hooks
sdd-kit/setup-dev.sh                 # per developer machine: recommended personal tools (opt-in)
```

Re-running is safe. Without a TTY, questions are skipped with instructions;
`SDD_KIT_ASSUME_YES=1` auto-confirms installs (never the YouTrack token).

## What it installs

| Artifact | Purpose |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | canonical agent context, ≤500 lines; existing `CLAUDE.md` is renamed, not lost |
| `openspec/` | OpenSpec init (`--tools claude`); specs + delta-changes live here |
| `Makefile.sdd` (+ `-include` in Makefile) | `make sdd-check`: AGENTS.md exists/≤500 lines + `openspec validate --all --strict` + spec-lint; every failure prints a concrete `next:` step |
| `.github/workflows/sdd-ci.yml` | required SDD gate on every pull request |
| `.github/workflows/autoreview.yml` | PR auto-review: ruff → reviewdog inline comments + AI review via headless `claude -p`, fed a static-tool report (radon, complexipy, vulture, semgrep security patterns) it must verify before reporting |
| `.claude/agents/*-reviewer.md` | python/fastapi/database/code reviewers used by the AI review step |
| `.claude/hooks/` + `.claude/settings.json` | spec-guard (blocks code edits without an active `openspec/changes/<id>/`) and a `git commit --no-verify` blocker |
| `.claude/scripts/spec-lint.py` | spec freshness (`Last verified` vs `git diff` over `enforced:` anchors) + spec-miner metadata validation; runs inside `sdd-check`, warn-only until `SPEC_LINT_STRICT=1` |
| `.git/hooks/pre-commit` | protected-branch guard (main/master/prod/stage block, dev warns; `SDD_ALLOW_PROTECTED=1` overrides), ruff autofix+format on staged Python, hygiene checks (merge markers, >5 MB files, `breakpoint()`, secrets/token patterns, new submodules, invalid JSON/TOML/YAML) + `make sdd-check` (merged by hand if a hook already exists) |
| `.claude/scripts/repo-audit.sh` | advisory clutter audit: extra MCP servers, foreign agent-tool configs (.cursor/.serena/…), stray skills/agents; runs at the end of bootstrap and via `make sdd-audit` |
| `.claude/scripts/sdd-doctor.sh` | environment doctor (`make sdd-doctor`): required tools (git, node, python3 ≥3.10, uv, ruff, openspec), claude/gh CLI + auth, store registration, youtrack token, hooks/pre-commit presence, and (profile) presence of per-service `.env` files a fresh clone needs — paths only, never secret values; runs at the end of bootstrap |
| `.mcp.json` | project MCP servers: context7 + youtrack (paths resolved for this machine); + chrome-devtools for frontend profiles |
| `.claude/skills/feature-flow/` | the team's ticket-to-PR workflow as a skill: interrogate the YouTrack ticket → OpenSpec change → implement → test-cases doc → tests → manual check → review → PR |
| `.claude/skills/incident-flow/` | the team's incident workflow: collect evidence (collect_incident.py) → root-cause doc (bug/misuse/infra) → OpenSpec change → fix + regression test → verify against the incident |
| `ruff.toml` | explicit-select Ruff config (classic E/F + curated additions) — installed ONLY when the repo has no Ruff config of its own; explicit select because ruff ≥0.15 default rules ballooned to 400+ |
| `.spec-guard-paths` + store wiring | for known repos (see Profiles below): seeded automatically |

## Profiles

`profiles/<repo-basename>.env` tailors the bootstrap for known repos. When the
target directory name matches a profile, bootstrap additionally:

- seeds `.spec-guard-paths` with the repo's real production-code prefixes
  (tests/docs/migrations/helm values stay unguarded);
- wires the central spec store: clones it if missing (with permission),
  registers it (`openspec store register`), and appends `references:` to
  `openspec/config.yaml` — `openspec validate` stays green on machines/CI
  without the store; `openspec doctor` tells you how to register it;
- skips Python tooling for non-Python repos (`PROFILE_SKIP_PY=1`);
- seeds `.claude/expected-env` from `PROFILE_ENV_FILES` so `sdd-doctor` warns when
  a per-service `.env` a fresh clone needs is missing (WBN lists all 8 services);
- for the store repo itself (`PROFILE_IS_STORE=1`): minimal install — local
  registration + a strict-validate CI gate, nothing else.

Shipped profiles: web-backend-new, voice-agent-constructor-backend,
voice-agent-postcall-analitics-backend, cybernet3.0, web-frontend-new,
conversation_flow, cybernet-specs (the store). Unknown repos fall back to the
generic flow with a `.spec-guard-paths` TODO.

## Dependencies

Checked on start: git, node/npx, uv. Missing openspec CLI or youtrack-mcp are
offered for install (with permission). No YouTrack token → the script shows
https://cybernet.youtrack.cloud/users/me?tab=account-security, reads the token
hidden, and stores it only in youtrack-mcp's `.env` (chmod 600) — never in the
repo.

## After bootstrap (manual)

1. Fill the TODOs in `AGENTS.md`.
2. Create `.spec-guard-paths` (code path prefixes, one per line) to enable
   spec-guard — automatic for known repos (see Profiles).
3. Seed specs with the spec-miner agent, one capability at a time.
4. GitHub: make `sdd-gate` a required check, enable branch protection on dev.
5. AI review auth (subscription, no API key): tokens are PER-DEVELOPER,
   machine-level — no shared GitHub secret. Run reviews locally with
   `make sdd-review`; the CI AI-step skips gracefully when no secret exists
   (reviewdog/ruff always runs).

## Per-developer tools: setup-dev.sh

Repo assets are bootstrap.sh's job; personal tooling lives on each developer's
machine (baking it into every repo bloats context and duplicates state). Run
once per machine:

```bash
sdd-kit/setup-dev.sh             # core stack installs by default [Y/n]
sdd-kit/setup-dev.sh --minimal   # old behavior: everything opt-in [y/N]
```

**Core stack (default install — quality up, token spend down):**
**ponytail** (plugin: minimal working solutions, saves tokens),
**rtk** (shell-output compressor + global hook),
**Graphify** (repo knowledge graph — faster/cheaper code analysis; PyPI name
`graphify`), **Headroom** (context compression MCP — real win is
context-window space, not cost: cached input re-reads already cost ~10%; it
appends, so the cache prefix survives), **ast-grep** (AST codemods for bulk
mechanical refactors).
`make sdd-doctor` warns when a core tool is missing.

**Optional (opt-in y/N):** **gh-axi** and **chrome-devtools-axi**
(agent-ergonomic CLI wrappers, ~/.claude/skills), **serena** (semantic
code-navigation MCP via uvx — an earlier trial left `.serena/` litter that
repo-audit flags, so it stays opt-in).

Not offered: **caveman** (only a benchmark arm inside the ponytail repo, not a
standalone tool — ponytail covers it), **grill-with-docs** (team practice, not
a self-contained install), **Playwright** (chrome-devtools-axi covers the
browser loop).

## Configuration

- `YOUTRACK_URL` — YouTrack instance for youtrack-mcp (default: cybernet.youtrack.cloud).
- `YOUTRACK_MCP_DIR` — where youtrack-mcp lives (default search: ~/dev, ~/cybernet).
- `SDD_KIT_ASSUME_YES=1` — auto-confirm installs in non-TTY runs (never the token).
- `SPEC_LINT_STRICT=1` — make spec freshness/metadata violations blocking.
- `SDD_AUDIT_STRICT=1` — make repo-audit warnings blocking.
- `SDD_ALLOW_PROTECTED=1` — one-off bypass of the protected-branch commit guard.
- `SDD_STORE_ID` / `SDD_STORE_DIR` / `SDD_STORE_GIT` — central spec store id,
  local checkout path, and clone URL (defaults: cybernet-specs,
  ~/cybernet/cybernet-specs, github.com/octrow/cybernet-specs).

## Design notes

Gate output follows [axi](https://github.com/kunchenguid/axi) agent-ergonomics
principles: summary line first, explicit "0 issues" instead of silence, and a
concrete `next:` command suggestion on every failure path.

## Attribution

Reviewer agents and spec-miner are adapted from
[everything-claude-code](https://github.com/affaan-m/ECC) (MIT).

## Layout

```
bootstrap.sh          per-repo installer
setup-dev.sh          per-developer machine setup (personal tools, opt-in)
profiles/             per-repo overrides: spec-guard paths, store wiring, py/no-py
templates/            everything installed into repos (English-only)
  agents/             reviewer agents for autoreview
  skills/             team skills (feature-flow: ticket-to-PR workflow)
```
