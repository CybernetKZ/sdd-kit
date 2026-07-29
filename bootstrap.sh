#!/usr/bin/env bash
# SDD bootstrap for a repository (new or existing).
# Usage: sdd-kit/bootstrap.sh /path/to/repo
# Idempotent: never overwrites existing files, only adds what is missing.
# Basis: openspec in every repo, AGENTS.md <= 500 lines,
# make test/sdd-check in CI + PreToolUse hooks.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
REPO="${1:?Usage: bootstrap.sh /path/to/repo}"
REPO="$(cd "$REPO" && pwd)"
cd "$REPO"

say()  { echo "[sdd-kit] $*"; }
warn() { echo "[sdd-kit] WARN: $*" >&2; }
fail() { echo "[sdd-kit] FAIL: $*" >&2; exit 1; }

SKIP_COUNT=0
SKIP_LIST=""   # one skipped step per line (bash 3.2-safe, no arrays)
skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); SKIP_LIST="$SKIP_LIST$1
"; say "skipped: $1"; }

# YouTrack instance for the youtrack-mcp server; override per company/machine.
YT_URL="${YOUTRACK_URL:-https://cybernet.youtrack.cloud}"

# ------------------------------------------------------------------ repo profile
# Known repos get tailored config (spec-guard paths, central-store wiring, py/no-py).
# A profile is a shell fragment in profiles/<repo-basename>.env setting PROFILE_* vars.
REPO_NAME="$(basename "$REPO")"
PROFILE_STORE=0            # 1 = wire this repo to the central spec store
PROFILE_IS_STORE=0         # 1 = this repo IS the store (minimal install)
PROFILE_SKIP_PY=0          # 1 = not a Python repo (no ruff.toml)
PROFILE_FRONTEND=0         # 1 = frontend repo: add chrome-devtools MCP to .mcp.json
PROFILE_LIVING_SPEC=0      # 1 = LIVING SPEC repo: pre-commit warns when code is staged without docs/DOCUMENTATION.md
PROFILE_SPEC_GUARD_PATHS=""
PROFILE_ENV_FILES=""       # newline-separated per-service .env paths sdd-doctor should check exist
if [ -f "$KIT/profiles/$REPO_NAME.env" ]; then
  # shellcheck disable=SC1090
  . "$KIT/profiles/$REPO_NAME.env"
  say "profile: $REPO_NAME"
fi

# Central spec store (ADR-0001). Override per machine/org.
STORE_ID="${SDD_STORE_ID:-cybernet-specs}"
STORE_DIR="${SDD_STORE_DIR:-$HOME/cybernet/cybernet-specs}"
STORE_GIT="${SDD_STORE_GIT:-https://github.com/octrow/cybernet-specs.git}"

INTERACTIVE=0; [ -t 0 ] && INTERACTIVE=1
ASSUME_YES=0; [ "${SDD_KIT_ASSUME_YES:-0}" = "1" ] && ASSUME_YES=1

# ask <question> -> 0 = yes, 1 = no.
# Non-interactive: yes only when SDD_KIT_ASSUME_YES=1, otherwise skipped.
ask() {
  local q="$1" answer=""
  if [ "$INTERACTIVE" = 1 ]; then
    printf '[sdd-kit] %s [y/N] ' "$q"
    read -r answer || answer=""
    case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
  fi
  if [ "$ASSUME_YES" = 1 ]; then say "auto-yes (SDD_KIT_ASSUME_YES=1): $q"; return 0; fi
  skip "question not asked (no TTY): $q"
  return 1
}

put() { # put <template> <destination> — copies only when the destination is missing
  if [ -e "$2" ]; then say "exists:  $2 (left alone)"; else
    mkdir -p "$(dirname "$2")"; cp "$KIT/templates/$1" "$2"; say "created: $2"; fi
}

# ---------------------------------------------------------------- 0. dependencies
[ -d .git ] || fail "$REPO is not a git repository"

# The store repo needs only itself: local registration + validate gate. Nothing else.
if [ "$PROFILE_IS_STORE" = 1 ]; then
  command -v git >/dev/null 2>&1 || fail "git not found. Install git and re-run."
  OPENSPEC="npx -y @fission-ai/openspec@1.6.0"
  command -v openspec >/dev/null 2>&1 && OPENSPEC="openspec"
  if ! $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
    $OPENSPEC store register "$REPO" --id "$STORE_ID"
    say "registered: this repo as store '$STORE_ID'"
  else
    say "ok:      store '$STORE_ID' already registered on this machine"
  fi
  put store-ci.yml .github/workflows/store-ci.yml
  say "done (store profile). Gate: openspec validate --all --strict runs on every PR."
  exit 0
fi

command -v git >/dev/null 2>&1 || fail "git not found. Install git and re-run."
if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
  fail "node/npx not found. Install Node.js 20+ from https://nodejs.org or via nvm:
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && nvm install 22"
fi

# openspec CLI: prefer a global install, fall back to pinned npx (slower, no install).
OPENSPEC="npx -y @fission-ai/openspec@1.6.0"
if command -v openspec >/dev/null 2>&1; then
  OPENSPEC="openspec"
  say "found:   openspec CLI ($(openspec --version 2>/dev/null || echo 'version unknown'))"
elif ask "Install the OpenSpec CLI globally? (npm install -g @fission-ai/openspec@latest)"; then
  npm install -g @fission-ai/openspec@latest
  OPENSPEC="openspec"
  say "installed: openspec CLI (global)"
else
  say "using npx fallback for openspec commands (no global install)"
fi

WANT_YOUTRACK=1
if ! command -v uv >/dev/null 2>&1; then
  warn "uv not found — it is required to run youtrack-mcp."
  say  "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
  if ask "Continue without the youtrack MCP server?"; then
    WANT_YOUTRACK=0
  else
    fail "aborted: install uv and re-run."
  fi
fi

# ------------------------------------------------------- 1. resolve youtrack-mcp
YT_DIR=""
if [ "$WANT_YOUTRACK" = 1 ]; then
  for candidate in "${YOUTRACK_MCP_DIR:-}" "$HOME/dev/youtrack-mcp" "$HOME/cybernet/youtrack-mcp"; do
    [ -n "$candidate" ] || continue
    if [ -f "$candidate/main.py" ]; then YT_DIR="$(cd "$candidate" && pwd)"; break; fi
  done

  if [ -z "$YT_DIR" ]; then
    say "youtrack-mcp not found (checked \$YOUTRACK_MCP_DIR, ~/dev/youtrack-mcp, ~/cybernet/youtrack-mcp)."
    if ask "Install youtrack-mcp to ~/dev/youtrack-mcp?"; then
      mkdir -p "$HOME/dev"
      git clone https://github.com/tonyzorin/youtrack-mcp.git "$HOME/dev/youtrack-mcp"
      YT_DIR="$HOME/dev/youtrack-mcp"
      say "cloned:  $YT_DIR"
    else
      WANT_YOUTRACK=0
      skip "youtrack-mcp install declined — .mcp.json will contain context7 only"
    fi
  else
    say "found:   youtrack-mcp at $YT_DIR"
  fi
fi

# --------------------------------------------------------------- 2. youtrack token
# The server reads <youtrack-mcp-dir>/.env (YOUTRACK_URL, YOUTRACK_API_TOKEN).
# The token never leaves that file — it is never echoed and never written into the repo.
if [ "$WANT_YOUTRACK" = 1 ]; then
  YT_ENV="$YT_DIR/.env"
  HAS_TOKEN=0
  [ -n "${YOUTRACK_API_TOKEN:-}" ] && HAS_TOKEN=1
  if [ "$HAS_TOKEN" = 0 ] && [ -f "$YT_ENV" ] \
     && grep -Eq '^[[:space:]]*YOUTRACK_API_TOKEN[[:space:]]*=[[:space:]]*[^[:space:]]' "$YT_ENV"; then
    HAS_TOKEN=1
  fi

  if [ "$HAS_TOKEN" = 1 ]; then
    say "ok:      YOUTRACK_API_TOKEN already configured"
  elif [ "$INTERACTIVE" = 1 ]; then
    say "Get a permanent token here: $YT_URL/users/me?tab=account-security (Account Security -> New token)"
    printf '[sdd-kit] Paste the YouTrack token (input hidden): '
    read -r -s YT_TOKEN_INPUT || YT_TOKEN_INPUT=""
    echo
    if [ -n "$YT_TOKEN_INPUT" ]; then
      touch "$YT_ENV"; chmod 600 "$YT_ENV"
      grep -Eq '^[[:space:]]*YOUTRACK_URL[[:space:]]*=' "$YT_ENV" \
        || printf 'YOUTRACK_URL=%s\n' "$YT_URL" >> "$YT_ENV"
      printf 'YOUTRACK_API_TOKEN=%s\n' "$YT_TOKEN_INPUT" >> "$YT_ENV"
      unset YT_TOKEN_INPUT
      say "wrote:   YOUTRACK_API_TOKEN into $YT_ENV (chmod 600)"
    else
      skip "empty token — add YOUTRACK_API_TOKEN to $YT_ENV manually"
    fi
  else
    skip "no YOUTRACK_API_TOKEN. Add YOUTRACK_URL and YOUTRACK_API_TOKEN to $YT_ENV manually (chmod 600). Token page: $YT_URL/users/me?tab=account-security"
  fi
fi

# --------------- 3. agent context: AGENTS.md is canonical, CLAUDE.md a symlink
if [ ! -e AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  if git ls-files --error-unmatch CLAUDE.md >/dev/null 2>&1; then
    git mv CLAUDE.md AGENTS.md
  else
    mv CLAUDE.md AGENTS.md  # file is not tracked by git (e.g. in .git/info/exclude)
  fi
  say "created: AGENTS.md (renamed from CLAUDE.md)"
fi
put AGENTS.md AGENTS.md
if [ ! -e CLAUDE.md ]; then ln -s AGENTS.md CLAUDE.md; say "created: CLAUDE.md -> AGENTS.md"; fi

# ------------------------------------------------------------------- 4. OpenSpec
if [ ! -d openspec ]; then
  say "initializing OpenSpec (--tools claude)..."
  $OPENSPEC init --tools claude
else
  say "exists:  openspec/ (left alone)"
fi

# ------------------------------------------- 4b. central spec store (profile repos)
if [ "$PROFILE_STORE" = 1 ]; then
  if ! $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
    if [ ! -d "$STORE_DIR" ] && ask "Clone the central spec store to $STORE_DIR? ($STORE_GIT)"; then
      git clone "$STORE_GIT" "$STORE_DIR"
      say "cloned:  $STORE_DIR"
    fi
    if [ -d "$STORE_DIR" ]; then
      $OPENSPEC store register "$STORE_DIR" --id "$STORE_ID"
      say "registered: store '$STORE_ID' from $STORE_DIR"
    else
      skip "store not cloned — register later: $OPENSPEC store register $STORE_DIR --id $STORE_ID"
    fi
  else
    say "ok:      store '$STORE_ID' already registered"
  fi
  CFG=openspec/config.yaml
  if [ -f "$CFG" ] && ! grep -q '^references:' "$CFG"; then
    printf '\n# Central contract store (ADR-0001), registered via `openspec store register`\nreferences:\n  - %s\n' "$STORE_ID" >> "$CFG"
    say "appended: references: $STORE_ID to $CFG"
  fi
fi

# --------------------------------------------------------- 5. Makefile: sdd-check
put Makefile.sdd Makefile.sdd
if [ -f Makefile ]; then
  grep -q "Makefile.sdd" Makefile || { printf '\n-include Makefile.sdd\n' >> Makefile; say "appended: -include Makefile.sdd to Makefile"; }
else
  printf -- "-include Makefile.sdd\n" > Makefile; say "created: Makefile (include only)"
fi

# ------------------------------------------------------- 6. CI gate on pull request
put sdd-ci.yml .github/workflows/sdd-ci.yml

# ----------------------------------------- 6b. ruff config (only when none exists)
if [ "$PROFILE_SKIP_PY" = 1 ]; then
  say "skipped: ruff.toml (profile: not a Python repo)"
elif [ -e ruff.toml ] || [ -e .ruff.toml ] \
   || grep -rls --include=pyproject.toml '^\[tool\.ruff' . >/dev/null 2>&1; then
  say "exists:  ruff config (repo's own — left alone)"
else
  put ruff.toml ruff.toml
fi

# ------------------------------------------------- 7. Claude Code hooks (repo-local)
put block-no-verify.js .claude/hooks/block-no-verify.js
put format-py.js .claude/hooks/format-py.js
if [ "$PROFILE_LIVING_SPEC" = 1 ]; then
  # LIVING SPEC repos: no spec-guard (internal work is not openspec-gated);
  # the pre-commit LIVING-SPEC check enforces the spec-doc discipline instead.
  put settings-living-spec.json .claude/settings.json
else
  put spec-guard.js .claude/hooks/spec-guard.js
  put settings.json .claude/settings.json  # if settings.json already exists, merge by hand
fi
put spec-lint.py .claude/scripts/spec-lint.py
put repo-audit.sh .claude/scripts/repo-audit.sh
put sdd-doctor.sh .claude/scripts/sdd-doctor.sh

# ---------------------------------------- 7b. auto-review: agents + PR workflow
for a in python-reviewer fastapi-reviewer database-reviewer code-reviewer; do
  put "agents/$a.md" ".claude/agents/$a.md"
done
put autoreview.yml .github/workflows/autoreview.yml
put skills/feature-flow/SKILL.md .claude/skills/feature-flow/SKILL.md
put skills/incident-flow/SKILL.md .claude/skills/incident-flow/SKILL.md

# 8. spec-guard is opt-in: create .spec-guard-paths with your code path prefixes
if [ ! -e .spec-guard-paths ] && [ -n "$PROFILE_SPEC_GUARD_PATHS" ]; then
  printf '%s\n' "$PROFILE_SPEC_GUARD_PATHS" > .spec-guard-paths
  say "created: .spec-guard-paths (from profile: $REPO_NAME)"
fi
[ -e .spec-guard-paths ] || say "TODO:    create .spec-guard-paths (code path prefixes) to enable spec-guard"

# Expected per-service .env files (from profile): sdd-doctor warns if any is missing.
# Only the list of PATHS is written — never any secret value.
if [ -n "$PROFILE_ENV_FILES" ] && [ ! -e .claude/expected-env ]; then
  printf '%s\n' "$PROFILE_ENV_FILES" > .claude/expected-env
  say "created: .claude/expected-env (sdd-doctor checks these .env exist)"
fi

# ------------------------------------------- 8b. git pre-commit hook: sdd-check
# Lives in .git/hooks (never committed), so it is safe to install even in test mode.
PRE_COMMIT=.git/hooks/pre-commit
if [ -e "$PRE_COMMIT" ]; then
  if grep -q "sdd-check" "$PRE_COMMIT" 2>/dev/null; then
    say "exists:  $PRE_COMMIT (already runs sdd-check)"
  else
    warn "$PRE_COMMIT exists without sdd-check — add 'make sdd-check' to it manually"
  fi
else
  cp "$KIT/templates/pre-commit-hook.sh" "$PRE_COMMIT"
  chmod +x "$PRE_COMMIT"
  say "created: $PRE_COMMIT (hygiene checks + make sdd-check before every commit)"
fi
# LIVING SPEC repos: warn when production code is staged without the spec doc.
if [ "$PROFILE_LIVING_SPEC" = 1 ] && [ -f "$PRE_COMMIT" ] \
   && ! grep -q "LIVING SPEC discipline" "$PRE_COMMIT"; then
  python3 - "$PRE_COMMIT" "$KIT/templates/living-spec-check.sh" <<'PYEOF'
import sys
hook, tpl = sys.argv[1], sys.argv[2]
s, block = open(hook).read(), open(tpl).read()
marker = "make sdd-check"
i = s.index(marker)
open(hook, "w").write(s[:i] + block + s[i:])
PYEOF
  say "added:   LIVING SPEC discipline check to $PRE_COMMIT"
fi

# --------------------------------------------- 9. project MCP servers (.mcp.json)
if [ -e .mcp.json ]; then
  say "exists:  .mcp.json (left alone)"
else
  MCP_LIST="context7"
  {
    printf '{\n  "mcpServers": {\n'
    printf '    "context7": {\n      "type": "http",\n      "url": "https://mcp.context7.com/mcp"\n    }'
    if [ "$WANT_YOUTRACK" = 1 ]; then
      MCP_LIST="$MCP_LIST + youtrack"
      # --with mcp<2: youtrack-mcp needs mcp.server.fastmcp, removed in mcp 2.x
      # (requirements.txt says mcp>=1.11.0, so a fresh uv env silently breaks).
      printf ',\n    "youtrack": {\n      "type": "stdio",\n      "command": "uv",\n      "args": [\n        "run",\n        "--directory", "%s",\n        "--no-project",\n        "--with", "mcp<2",\n        "--with-requirements", "%s/requirements.txt",\n        "main.py"\n      ],\n      "env": {}\n    }' "$YT_DIR" "$YT_DIR"
    fi
    if [ "$PROFILE_FRONTEND" = 1 ]; then
      MCP_LIST="$MCP_LIST + chrome-devtools"
      printf ',\n    "chrome-devtools": {\n      "type": "stdio",\n      "command": "npx",\n      "args": ["-y", "chrome-devtools-mcp@latest"]\n    }'
    fi
    printf '\n  }\n}\n'
  } > .mcp.json
  say "created: .mcp.json ($MCP_LIST)"
fi

# -------------------------------------------------------------- 10. repo audit
# Advisory report: extra MCP servers, foreign agent-tool configs, stray skills.
sh .claude/scripts/repo-audit.sh || true

# -------------------------------------------- 10b. environment doctor (advisory)
bash .claude/scripts/sdd-doctor.sh || true

# ------------------------------------------------------------------- 11. wrap up
say "done. Remaining manual steps:"
say "  1) fill in the TODOs in AGENTS.md (module map, rules)"
say "  2) make sdd-gate a required check in branch protection settings"
say "  3) enable branch protection on dev (no direct pushes)"
say "  4) seed the specs: run the spec-miner agent one capability at a time"
say "  5) AI review runs locally: 'make sdd-review' (your own subscription login;"
say "     tokens are per-developer — no shared GitHub secret; the CI AI-step"
say "     skips gracefully without one, reviewdog/ruff always runs)"

if [ "$SKIP_COUNT" -gt 0 ]; then
  say "skipped $SKIP_COUNT interactive step(s) — finish them later:"
  printf '%s' "$SKIP_LIST" | while IFS= read -r item; do say "  - $item"; done
  say "  re-run this script from a terminal, or set SDD_KIT_ASSUME_YES=1 to auto-confirm installs"
fi
