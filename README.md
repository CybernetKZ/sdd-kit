# sdd-kit

Bootstrap for spec-driven development (SDD) in a CybernetAI repository — new or
existing. One script, idempotent: never overwrites existing files, only adds
what is missing. Decisions behind it: ADR-0001…0003 in `refactor_v4/ADR/`.

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

## Layout

```
bootstrap.sh          the installer
templates/            everything installed into repos (English-only)
  agents/             reviewer agents for autoreview
```
