# sdd-kit

Bootstrap for spec-driven development (SDD) in a repository — new or
existing. One script, idempotent: never overwrites existing files, only adds
what is missing.

## Usage

```bash
sdd-kit/bootstrap.sh /path/to/repo
```

Re-running is safe. Without a TTY, questions are skipped with instructions;
`SDD_KIT_ASSUME_YES=1` auto-confirms installs (never the YouTrack token).

## What it installs

| Artifact | Purpose |
|---|---|
| `AGENTS.md` (+ `CLAUDE.md` symlink) | canonical agent context, ≤500 lines; existing `CLAUDE.md` is renamed, not lost |
| `openspec/` | OpenSpec init (`--tools claude`); specs + delta-changes live here |
| `Makefile.sdd` (+ `-include` in Makefile) | `make sdd-check`: AGENTS.md exists/≤500 lines + `openspec validate --all --strict` |
| `.github/workflows/sdd-ci.yml` | required SDD gate on every pull request |
| `.github/workflows/autoreview.yml` | PR auto-review: ruff → reviewdog inline comments + AI review via headless `claude -p` |
| `.claude/agents/*-reviewer.md` | python/fastapi/database/code reviewers used by the AI review step |
| `.claude/hooks/` + `.claude/settings.json` | spec-guard (blocks code edits without an active `openspec/changes/<id>/`) and a `git commit --no-verify` blocker |
| `.claude/scripts/spec-lint.py` | spec freshness (`Last verified` vs `git diff` over `enforced:` anchors) + spec-miner metadata validation; runs inside `sdd-check`, warn-only until `SPEC_LINT_STRICT=1` |
| `.git/hooks/pre-commit` | protected-branch guard (main/master/prod/stage block, dev warns; `SDD_ALLOW_PROTECTED=1` overrides), ruff autofix+format on staged Python, hygiene checks (merge markers, >5 MB files, `breakpoint()`, secrets/token patterns, new submodules, invalid JSON/TOML/YAML) + `make sdd-check` (merged by hand if a hook already exists) |
| `.claude/scripts/repo-audit.sh` | advisory clutter audit: extra MCP servers, foreign agent-tool configs (.cursor/.serena/…), stray skills/agents; runs at the end of bootstrap and via `make sdd-audit` |
| `.mcp.json` | project MCP servers: context7 + youtrack (paths resolved for this machine) |
| `ruff.toml` | explicit-select Ruff config (classic E/F + curated additions) — installed ONLY when the repo has no Ruff config of its own; explicit select because ruff ≥0.15 default rules ballooned to 400+ |

## Dependencies

Checked on start: git, node/npx, uv. Missing openspec CLI or youtrack-mcp are
offered for install (with permission). No YouTrack token → the script shows
https://cybernet.youtrack.cloud/users/me?tab=account-security, reads the token
hidden, and stores it only in youtrack-mcp's `.env` (chmod 600) — never in the
repo.

## After bootstrap (manual)

1. Fill the TODOs in `AGENTS.md`.
2. Create `.spec-guard-paths` (code path prefixes, one per line) to enable spec-guard.
3. Seed specs with the spec-miner agent, one capability at a time.
4. GitHub: make `sdd-gate` a required check, enable branch protection on dev.
5. AI review auth (subscription, no API key): run `claude setup-token` on a
   logged-in machine, save it as the `CLAUDE_CODE_OAUTH_TOKEN` repo/org secret.

## Deliberately NOT installed

sdd-kit installs repo-level assets only. Per-user tooling belongs on each
developer's machine (see the team onboarding guide), because baking it into
every repo bloats context and duplicates state:

- **ponytail / caveman skills** — personal working style; install as a user-level plugin/skill.
- **RTK** (rtk-ai/rtk) — shell-output compressor; global per-user integration
  (`rtk init -g`), never a repo asset. Only enable its hook after the binary is installed.
- **Graphify** — per-machine CLI + skill; navigation aid, never a CI gate.
- **Chrome DevTools MCP / Playwright** — frontend debug loops; add to `.mcp.json` only in frontend repos that need them.
- **Headroom MCP** — user-level context compression. Note: with Anthropic prompt
  caching active, cached input re-reads already cost ~10% — Headroom's savings
  estimates assume full-price tokens, so its real win is context-window space,
  not cost. It appends (never rewrites history), so it does not invalidate the cache prefix.
- **grill-with-docs** — a thin wrapper over the `/grilling` + `/domain-modeling`
  skill set; useful as a team practice (interrogate the plan before implementing)
  but not self-contained enough to vendor here.

What the kit DOES cover from that list: Claude Code hooks (PreToolUse:
spec-guard + no-verify blocker; PostToolUse: ruff auto-format on edited .py),
the review toolchain (ruff/radon/complexipy/vulture), and the MCP baseline
(context7 + youtrack).

## Configuration

- `YOUTRACK_URL` — YouTrack instance for youtrack-mcp (default: cybernet.youtrack.cloud).
- `YOUTRACK_MCP_DIR` — where youtrack-mcp lives (default search: ~/dev, ~/cybernet).
- `SDD_KIT_ASSUME_YES=1` — auto-confirm installs in non-TTY runs (never the token).
- `SPEC_LINT_STRICT=1` — make spec freshness/metadata violations blocking.
- `SDD_AUDIT_STRICT=1` — make repo-audit warnings blocking.
- `SDD_ALLOW_PROTECTED=1` — one-off bypass of the protected-branch commit guard.

## Design notes

Gate output follows [axi](https://github.com/kunchenguid/axi) agent-ergonomics
principles: summary line first, explicit "0 issues" instead of silence, and a
concrete `next:` command suggestion on every failure path.

## Attribution

Reviewer agents and spec-miner are adapted from
[everything-claude-code](https://github.com/affaan-m/ECC) (MIT).

## Layout

```
bootstrap.sh          the installer
templates/            everything installed into repos (English-only)
  agents/             reviewer agents for autoreview
```
