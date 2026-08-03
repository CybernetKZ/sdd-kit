#!/usr/bin/env bash
# SDD installer — one entry point for both halves of the setup:
#
#   1. REPO section    SDD assets in a repository: openspec, AGENTS.md, gates,
#                      hooks, agents, skills, CI, pre-commit. Idempotent:
#                      never overwrites existing files, only adds what is missing.
#   2. MACHINE section per-developer tools (ponytail, rtk, graphify, ast-grep,
#                      and the opt-in ones). Touches no repository.
#
# Usage:
#   sdd-kit/install.sh [/path/to/repo]              both sections (repo first)
#   sdd-kit/install.sh --repo-only [/path/to/repo]  repo assets only
#   sdd-kit/install.sh --machine-only               developer tools only
#   sdd-kit/install.sh --refresh [/path/to/repo]    update the kit-owned files
#
# --refresh re-copies ONLY the kit-owned manifest (hooks, agents, skills,
# scripts, Makefile.sdd, CI workflows, pre-commit) when the target drifted from
# the template, and reports a per-file (+added/-removed) summary. Repo-owned
# files (AGENTS.md, .spec-guard-paths, feature_flags.py, .claude/expected-env,
# ruff.toml, openspec/**, .mcp.json, .claude/settings.json) are never touched.
# --refresh always implies the repo section only: the machine tools have no
# refresh semantics (re-run --machine-only for those), so --repo-only is
# redundant with it (accepted, ignored).
#
# The repo path defaults to the current directory.
# Every question takes a default: plain Enter accepts it ([Y/n] = yes,
# [y/N] = no). SDD_KIT_ASSUME_YES=1 or no TTY => all defaults, no prompts.
# Steps that fetch and run code from the network are NEVER run unattended:
# without a TTY (or with SDD_KIT_ASSUME_YES=1) they print the command instead.
#
# Basis: openspec in every repo, AGENTS.md <= 500 lines,
# make sdd-test/sdd-check in CI + PreToolUse hooks.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"

say()  { echo "[sdd-kit] $*"; }
warn() { echo "[sdd-kit] WARN: $*" >&2; }
fail() { echo "[sdd-kit] FAIL: $*" >&2; exit 1; }

SKIP_COUNT=0
SKIP_LIST=""   # one skipped step per line (bash 3.2-safe, no arrays)
skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); SKIP_LIST="$SKIP_LIST$1
"; say "skipped: $1"; }

# ------------------------------------------------------------------ arguments
DO_REPO=1
DO_MACHINE=1
DO_REFRESH=0
REPO_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-only)    DO_MACHINE=0 ;;
    --machine-only) DO_REPO=0 ;;
    --refresh)      DO_REFRESH=1; DO_MACHINE=0 ;;  # repo section only, by definition
    -h|--help)
      sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) fail "unknown option: $1 (try --help)" ;;
    *)  REPO_ARG="$1" ;;
  esac
  shift
done

# ------------------------------------------------------------------- prompting
INTERACTIVE=0; [ -t 0 ] && INTERACTIVE=1
ASSUME_YES=0; [ "${SDD_KIT_ASSUME_YES:-0}" = "1" ] && ASSUME_YES=1
UNATTENDED=0
if [ "$INTERACTIVE" = 0 ] || [ "$ASSUME_YES" = 1 ]; then UNATTENDED=1; fi

# ask <question> [default: y|n] -> 0 = yes, 1 = no.
# Enter accepts the default; unattended runs take the default without asking.
ask() {
  local q="$1" def="${2:-n}" answer="" hint="[y/N]"
  [ "$def" = y ] && hint="[Y/n]"
  if [ "$UNATTENDED" = 1 ]; then
    if [ "$def" = y ]; then say "default yes: $q"; return 0; fi
    skip "default no: $q"
    return 1
  fi
  printf '[sdd-kit] %s %s ' "$q" "$hint"
  read -r answer || answer=""
  case "$answer" in
    "")                 [ "$def" = y ] ;;
    [yY]|[yY][eE][sS])  return 0 ;;
    *)                  return 1 ;;
  esac
}

# ask_install <question> <default> <manual command> -> 0 = install, 1 = don't.
# For anything that downloads and executes remote code (curl|sh, npm -g, git
# clone, plugin installs): unattended runs print the command and skip it.
ask_install() {
  if [ "$UNATTENDED" = 1 ]; then
    skip "not installed unattended: $1 — run it yourself: $3"
    return 1
  fi
  ask "$1" "$2"
}

put() { # put <template> <destination> — copies only when the destination is missing
  if [ -e "$2" ]; then say "exists:  $2 (left alone)"; else
    mkdir -p "$(dirname "$2")"; cp "$KIT/templates/$1" "$2"; say "created: $2"; fi
}

# ------------------------------------------------------------- kit manifest --
# The kit-owned files: ONE source of truth, used by both the install pass
# (put(), never overwrites) and `--refresh` (overwrites what drifted).
# Format per line: "<path under templates/> <destination relative to the repo>".
#
# Deliberately NOT here — repo-owned, never overwritten by --refresh:
#   AGENTS.md, CLAUDE.md, .spec-guard-paths, feature_flags.py,
#   .claude/expected-env, ruff.toml, openspec/**, .mcp.json,
#   .claude/settings.json (its `hooks` block is compared and warned about only),
#   store-ci.yml (store profile: handled separately, see PROFILE_IS_STORE).
#
# .git/hooks/pre-commit is listed but never copied verbatim: it is assembled by
# assemble_pre_commit() (LIVING SPEC splice), so both loops special-case it.
KIT_PRE_COMMIT_DST=".git/hooks/pre-commit"
kit_manifest() {
  cat <<'EOF'
block-no-verify.cjs .claude/hooks/block-no-verify.cjs
pre-compact.cjs .claude/hooks/pre-compact.cjs
spec-guard.cjs .claude/hooks/spec-guard.cjs
agents/backend-reviewer.md .claude/agents/backend-reviewer.md
agents/database-reviewer.md .claude/agents/database-reviewer.md
agents/planner.md .claude/agents/planner.md
agents/plan-griller.md .claude/agents/plan-griller.md
agents/test-author.md .claude/agents/test-author.md
skills/feature-flow/SKILL.md .claude/skills/feature-flow/SKILL.md
skills/incident-flow/SKILL.md .claude/skills/incident-flow/SKILL.md
spec-lint.py .claude/scripts/spec-lint.py
sdd-doctor.sh .claude/scripts/sdd-doctor.sh
review-prompt.md .claude/scripts/review-prompt.md
Makefile.sdd Makefile.sdd
sdd-ci.yml .github/workflows/sdd-ci.yml
autoreview.yml .github/workflows/autoreview.yml
pre-commit-hook.sh .git/hooks/pre-commit
EOF
}

# assemble_pre_commit <destination> — writes the pre-commit hook, splicing in
# the LIVING SPEC fragment right before the '# SDD gate:' block when the
# profile asks for it. Used by both the install pass and --refresh.
assemble_pre_commit() {
  local dst="$1"
  if [ "${PROFILE_LIVING_SPEC:-0}" = 1 ]; then
    awk -v frag="$KIT/templates/living-spec-check.sh" '
      /^# SDD gate:/ && !ins { while ((getline line < frag) > 0) print line; ins = 1 }
      { print }
    ' "$KIT/templates/pre-commit-hook.sh" > "$dst"
    grep -q "LIVING SPEC discipline" "$dst" \
      || warn "LIVING SPEC fragment not inserted (no '# SDD gate:' anchor in the template?)"
  else
    cp "$KIT/templates/pre-commit-hook.sh" "$dst"
  fi
  chmod +x "$dst"
}

# load_profile <repo-basename> — resets the PROFILE_* globals to their defaults
# and then sources profiles/<repo-basename>.env if it exists. Shared by the
# install pass and --refresh (which needs PROFILE_LIVING_SPEC / PROFILE_IS_STORE).
load_profile() {
  PROFILE_STORE=1            # 1 = wire this repo to the central spec store (default)
  PROFILE_IS_STORE=0         # 1 = this repo IS the store (minimal install)
  PROFILE_SKIP_PY=0          # 1 = not a Python repo (no ruff.toml)
  PROFILE_LIVING_SPEC=0      # 1 = LIVING SPEC repo: pre-commit warns when code is staged without docs/DOCUMENTATION.md
  PROFILE_SPEC_GUARD_PATHS=""
  PROFILE_ENV_FILES=""       # newline-separated per-service .env paths sdd-doctor should check exist
  if [ -f "$KIT/profiles/$1.env" ]; then
    # shellcheck disable=SC1090
    . "$KIT/profiles/$1.env"
    say "profile: $1"
  fi
}

# ============================================================== REPO SECTION ==
repo_section() {
  local REPO REPO_NAME
  REPO="${REPO_ARG:-$PWD}"
  REPO="$(cd "$REPO" && pwd)"
  cd "$REPO"
  say "repo:    $REPO"

  # YouTrack instance for the youtrack-mcp server; override per company/machine.
  local YT_URL="${YOUTRACK_URL:-https://cybernet.youtrack.cloud}"

  # ---------------------------------------------------------------- profile
  # Known repos get tailored config (spec-guard paths, central-store wiring,
  # py/no-py). A profile is a shell fragment in profiles/<repo-basename>.env
  # setting PROFILE_* vars.
  REPO_NAME="$(basename "$REPO")"
  load_profile "$REPO_NAME"

  # Central spec store (ADR-0001). Override per machine/org.
  local STORE_ID="${SDD_STORE_ID:-cybernet-specs}"
  local STORE_DIR="${SDD_STORE_DIR:-$HOME/cybernet/cybernet-specs}"
  local STORE_GIT="${SDD_STORE_GIT:-https://github.com/octrow/cybernet-specs.git}"

  # ------------------------------------------------------------ 0. dependencies
  [ -d .git ] || fail "$REPO is not a git repository"
  command -v git >/dev/null 2>&1 || fail "git not found. Install git and re-run."
  if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
    fail "node/npx not found. Install Node.js 20+ from https://nodejs.org or via nvm:
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && nvm install 22"
  fi

  # openspec CLI, single source of the pin for this script: prefer a global
  # install, fall back to pinned npx (slower, no install). The other pin lives
  # in templates/Makefile.sdd, which runs standalone inside target repos.
  # openspec-pin
  OPENSPEC="npx -y @fission-ai/openspec@1.7.0"
  if command -v openspec >/dev/null 2>&1; then
    OPENSPEC="openspec"
    say "found:   openspec CLI ($(openspec --version 2>/dev/null || echo 'version unknown'))"
  elif ask_install "Install the OpenSpec CLI globally?" y \
       "npm install -g @fission-ai/openspec@latest"; then
    npm install -g @fission-ai/openspec@latest
    OPENSPEC="openspec"
    say "installed: openspec CLI (global)"
  else
    say "using npx fallback for openspec commands (no global install)"
  fi

  # The store repo needs only itself: local registration + validate gate.
  if [ "$PROFILE_IS_STORE" = 1 ]; then
    if ! $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
      $OPENSPEC store register "$REPO" --id "$STORE_ID"
      say "registered: this repo as store '$STORE_ID'"
    else
      say "ok:      store '$STORE_ID' already registered on this machine"
    fi
    put store-ci.yml .github/workflows/store-ci.yml
    say "done (store profile). Gate: openspec validate --all --strict runs on every PR."
    return 0
  fi

  local WANT_YOUTRACK=1
  if ! command -v uv >/dev/null 2>&1; then
    warn "uv not found — it is required to run youtrack-mcp."
    say  "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    if ask "Continue without the youtrack MCP server?" y; then
      WANT_YOUTRACK=0
    else
      fail "aborted: install uv and re-run."
    fi
  fi

  # --------------------------------------------------- 1. resolve youtrack-mcp
  local YT_DIR="" candidate
  if [ "$WANT_YOUTRACK" = 1 ]; then
    for candidate in "${YOUTRACK_MCP_DIR:-}" "$HOME/dev/youtrack-mcp" "$HOME/cybernet/youtrack-mcp"; do
      [ -n "$candidate" ] || continue
      if [ -f "$candidate/main.py" ]; then YT_DIR="$(cd "$candidate" && pwd)"; break; fi
    done

    if [ -z "$YT_DIR" ]; then
      say "youtrack-mcp not found (checked \$YOUTRACK_MCP_DIR, ~/dev/youtrack-mcp, ~/cybernet/youtrack-mcp)."
      if ask_install "Install youtrack-mcp to ~/dev/youtrack-mcp?" y \
         "git clone https://github.com/tonyzorin/youtrack-mcp.git ~/dev/youtrack-mcp"; then
        mkdir -p "$HOME/dev"
        git clone https://github.com/tonyzorin/youtrack-mcp.git "$HOME/dev/youtrack-mcp"
        YT_DIR="$HOME/dev/youtrack-mcp"
        say "cloned:  $YT_DIR"
      else
        WANT_YOUTRACK=0
        say "youtrack-mcp not installed — .mcp.json will contain context7 only"
      fi
    else
      say "found:   youtrack-mcp at $YT_DIR"
    fi
  fi

  # ----------------------------------------------------------- 2. youtrack token
  # The server reads <youtrack-mcp-dir>/.env (YOUTRACK_URL, YOUTRACK_API_TOKEN).
  # The token never leaves that file — it is never echoed and never written into the repo.
  local YT_ENV HAS_TOKEN YT_TOKEN_INPUT
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
      printf '[sdd-kit] Paste the YouTrack token (input hidden, Enter to skip): '
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

  # ------------------ 2b. profile payload: pre-configured files for known repos
  # profiles/<repo-basename>/ may carry ready files (AGENTS.md, openspec config,
  # ...). Copied with the same never-overwrite rule; the generic steps below
  # then skip whatever the payload already provided.
  local rel
  if [ -d "$KIT/profiles/$REPO_NAME" ]; then
    (cd "$KIT/profiles/$REPO_NAME" && find . -type f) | sed 's|^\./||' | while IFS= read -r rel; do
      if [ -e "$rel" ]; then say "exists:  $rel (left alone)"; else
        mkdir -p "$(dirname "$rel")"
        cp "$KIT/profiles/$REPO_NAME/$rel" "$rel"
        say "created: $rel (profile payload)"
      fi
    done
  fi

  # ------------- 3. agent context: AGENTS.md is canonical, CLAUDE.md a symlink
  if [ ! -e AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
    if git ls-files --error-unmatch CLAUDE.md >/dev/null 2>&1; then
      git mv CLAUDE.md AGENTS.md
    else
      mv CLAUDE.md AGENTS.md  # file is not tracked by git (e.g. in .git/info/exclude)
    fi
    say "created: AGENTS.md (renamed from CLAUDE.md)"
  fi
  if [ ! -e AGENTS.md ]; then put AGENTS.md AGENTS.md; fi  # profile payload may have provided it already — avoid a second "exists" line
  if [ ! -e CLAUDE.md ]; then ln -s AGENTS.md CLAUDE.md; say "created: CLAUDE.md -> AGENTS.md"; fi

  # ----------------------------------------------------------------- 4. OpenSpec
  if [ ! -d openspec ]; then
    say "initializing OpenSpec (--tools claude)..."
    $OPENSPEC init --tools claude
  else
    say "exists:  openspec/ (left alone)"
  fi

  # ----------------------------------------- 4b. central spec store (PROFILE_STORE)
  local CFG
  if [ "$PROFILE_STORE" = 1 ]; then
    if ! $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
      if [ ! -d "$STORE_DIR" ] && ask_install "Clone the central spec store to $STORE_DIR?" y \
           "git clone $STORE_GIT $STORE_DIR"; then
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

  # ---------------------------------- 5. kit-owned files (the manifest, once)
  # Hooks, agents, skills, scripts, Makefile.sdd, CI workflows. Same list that
  # `--refresh` re-copies later; .git/hooks/pre-commit is assembled in 8b.
  local m_src m_dst
  while read -r m_src m_dst; do
    [ -n "$m_src" ] || continue
    [ "$m_dst" = "$KIT_PRE_COMMIT_DST" ] && continue
    put "$m_src" "$m_dst"
  done <<EOF
$(kit_manifest)
EOF

  # ------------------------------------------------- 5a. Makefile: sdd-check
  if [ -f Makefile ]; then
    grep -q "Makefile.sdd" Makefile || { printf '\n-include Makefile.sdd\n' >> Makefile; say "appended: -include Makefile.sdd to Makefile"; }
  else
    printf -- "-include Makefile.sdd\n" > Makefile; say "created: Makefile (include only)"
  fi

  # --------------------------- 5b. flag registry (makes sdd-flags a real gate)
  put feature_flags.py feature_flags.py

  # --------------------------------- 6b. ruff config (only when none exists)
  if [ "$PROFILE_SKIP_PY" = 1 ]; then
    say "skipped: ruff.toml (profile: not a Python repo)"
  elif [ -e ruff.toml ] || [ -e .ruff.toml ] \
     || grep -rls --include=pyproject.toml '^\[tool\.ruff' . >/dev/null 2>&1; then
    say "exists:  ruff config (repo's own — left alone)"
  else
    put ruff.toml ruff.toml
  fi

  # ----- 7. Claude Code settings (NOT in the manifest: repos add own hooks;
  #          if settings.json already exists, merge the hooks block by hand —
  #          `--refresh` only warns when the two differ)
  put settings.json .claude/settings.json

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

  # ----------------------------------- 8b. git pre-commit hook: sdd-check
  # Lives in .git/hooks (never committed), so it is safe to install even in test mode.
  local PRE_COMMIT=.git/hooks/pre-commit
  if [ -e "$PRE_COMMIT" ]; then
    if grep -q "sdd-check" "$PRE_COMMIT" 2>/dev/null; then
      say "exists:  $PRE_COMMIT (already runs sdd-check)"
    else
      warn "$PRE_COMMIT exists without sdd-check — add 'make sdd-check' to it manually (template: $KIT/templates/pre-commit-hook.sh)"
    fi
    if [ "$PROFILE_LIVING_SPEC" = 1 ] && ! grep -q "LIVING SPEC discipline" "$PRE_COMMIT"; then
      warn "$PRE_COMMIT has no LIVING SPEC check — insert $KIT/templates/living-spec-check.sh above its '# SDD gate:' / 'make sdd-check' block"
    fi
  elif [ "$PROFILE_LIVING_SPEC" = 1 ]; then
    # LIVING SPEC repos: the fragment is concatenated in at install time,
    # right before the '# SDD gate:' block. No post-injection into a live hook.
    assemble_pre_commit "$PRE_COMMIT"
    say "created: $PRE_COMMIT (hygiene checks + LIVING SPEC discipline + make sdd-check)"
  else
    assemble_pre_commit "$PRE_COMMIT"
    say "created: $PRE_COMMIT (hygiene checks + make sdd-check before every commit)"
  fi

  # ------------------- 8c. local git exclude for machine-local artifacts
  # graphify-out/ (the code graph, ~30MB json) must never land in a commit;
  # .git/info/exclude keeps the tracked .gitignore untouched.
  if ! grep -qx "graphify-out/" .git/info/exclude 2>/dev/null; then
    echo "graphify-out/" >> .git/info/exclude
    say "created: .git/info/exclude entry graphify-out/ (machine-local, never committed)"
  fi

  # ------------------------------------- 9. project MCP servers (.mcp.json)
  local MCP_LIST
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
      printf '\n  }\n}\n'
    } > .mcp.json
    say "created: .mcp.json ($MCP_LIST)"
  fi

  # --------------------------- 10. environment doctor + repo audit (advisory)
  # Tools, repo wiring, and the clutter audit (extra MCP servers, foreign
  # agent-tool configs, stray skills/agents) in one report.
  bash .claude/scripts/sdd-doctor.sh || true

  # ------------------------------------------------------------- 11. wrap up
  say "repo done. Remaining manual steps:"
  say "  1) fill in the TODOs in AGENTS.md (module map, rules)"
  say "  2) enforcement stays advisory by default (ADR-0015): CI gates report but"
  say "     don't block. Turning them on later is one owner decision — sdd-gate"
  say "     as a required check + branch protection on dev. Not a setup step."
  say "  3) seed the specs: run the spec-miner agent one capability at a time"
  say "  3b) build the code graph for intake: 'make sdd-index' (needs an LLM API"
  say "      key for the first build; on a Claude subscription run the interactive"
  say "      '/graphify' command in Claude Code instead — later updates need no key)"
  say "  4) AI review runs locally: 'make sdd-review' (your own subscription login;"
  say "     tokens are per-developer — no shared GitHub secret; the CI AI-step"
  say "     (autoreview.yml) skips in seconds without one)"
}

# =========================================================== REFRESH SECTION ==
# `--refresh`: re-copy the kit-owned manifest into an already-installed repo.
# Repo-owned files are never touched (see the kit_manifest comment for the list).
# Idempotent: a second run reports zero refreshed files.
REFRESHED=0

# refresh_file <rendered source> <destination> — overwrite only on drift.
refresh_file() {
  local src="$1" dst="$2" added removed
  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"
    REFRESHED=$((REFRESHED + 1)); say "refreshed: $dst (was missing)"
    return 0
  fi
  cmp -s "$src" "$dst" && return 0
  added=$(diff "$dst" "$src" | grep -c '^>' || true)
  removed=$(diff "$dst" "$src" | grep -c '^<' || true)
  cp "$src" "$dst"
  REFRESHED=$((REFRESHED + 1))
  say "refreshed: $dst (+$added/-$removed lines)"
}

# .claude/settings.json is never rewritten: a repo may have added its own hooks
# (pretooluse_guard.py in conversation_flow). Compare the `hooks` object only.
refresh_settings_hooks() {
  [ -f .claude/settings.json ] || { say "missing:   .claude/settings.json (run install.sh --repo-only)"; return 0; }
  if python3 - "$KIT/templates/settings.json" .claude/settings.json <<'PY'
import json, sys

def hooks(path):
    try:
        with open(path) as fh:
            return json.load(fh).get("hooks")
    except Exception:
        return "<unreadable>"

sys.exit(0 if hooks(sys.argv[1]) == hooks(sys.argv[2]) else 1)
PY
  then
    say "ok:      .claude/settings.json hooks match the template"
  else
    warn ".claude/settings.json: hooks differ from template — merge manually (repo may have custom hooks)"
    echo "        next: diff <(python3 -m json.tool $KIT/templates/settings.json) <(python3 -m json.tool .claude/settings.json)" >&2
  fi
}

# .git/hooks/pre-commit is assembled, not copied (LIVING SPEC splice), and a
# hand-merged hook (repo's own checks) is never overwritten.
refresh_pre_commit() {
  local tmp
  if [ -e "$KIT_PRE_COMMIT_DST" ] && ! grep -q "sdd-kit git pre-commit hook" "$KIT_PRE_COMMIT_DST"; then
    warn "$KIT_PRE_COMMIT_DST is not the kit hook (hand-merged?) — left alone"
    return 0
  fi
  tmp="$(mktemp)"
  assemble_pre_commit "$tmp"
  refresh_file "$tmp" "$KIT_PRE_COMMIT_DST"
  rm -f "$tmp"
  chmod +x "$KIT_PRE_COMMIT_DST"
}

refresh_section() {
  local REPO REPO_NAME m_src m_dst
  REPO="${REPO_ARG:-$PWD}"
  REPO="$(cd "$REPO" && pwd)"
  cd "$REPO"
  say "refresh: $REPO (kit-owned files only)"
  [ -d .git ] || fail "$REPO is not a git repository"

  REPO_NAME="$(basename "$REPO")"
  load_profile "$REPO_NAME"

  if [ "$PROFILE_IS_STORE" = 1 ]; then
    refresh_file "$KIT/templates/store-ci.yml" .github/workflows/store-ci.yml
    say "refresh done (store profile): $REFRESHED file(s) updated"
    return 0
  fi

  while read -r m_src m_dst; do
    [ -n "$m_src" ] || continue
    [ "$m_dst" = "$KIT_PRE_COMMIT_DST" ] && continue
    refresh_file "$KIT/templates/$m_src" "$m_dst"
  done <<EOF
$(kit_manifest)
EOF

  refresh_pre_commit
  refresh_settings_hooks

  # same as install step 8c: keep machine-local graph out of commits
  if ! grep -qx "graphify-out/" .git/info/exclude 2>/dev/null; then
    echo "graphify-out/" >> .git/info/exclude
    say "added:   .git/info/exclude entry graphify-out/"
  fi

  if [ "$REFRESHED" = 0 ]; then
    say "refresh done: 0 files refreshed (everything already matches the kit)"
  else
    say "refresh done: $REFRESHED file(s) refreshed — review with git diff before committing"
  fi
}

# =========================================================== MACHINE SECTION ==
# Per-DEVELOPER tools (machine-level, run once). Nothing here touches a repo.
# CORE tools (quality up, token spend down) default to yes; the rest opt-in.
machine_section() {
  local DONE=0 SKIPPED=0

  if ! ask "Install the recommended developer tools on this machine?" y; then
    say "machine section skipped"
    return 0
  fi

  # -------------------------------------------------------------- 1. ponytail
  # Lazy-senior-developer skill: less code, fewer tokens (plugin by Dietrich Gebert).
  if grep -qs '"ponytail@ponytail"' "$HOME/.claude/settings.json" 2>/dev/null; then
    say "ok:      ponytail already enabled"
  elif ask_install "Install ponytail? (minimal working solutions, saves tokens)" y \
       "claude plugin marketplace add DietrichGebert/ponytail && claude plugin install ponytail@ponytail"; then
    if claude plugin marketplace add DietrichGebert/ponytail \
       && claude plugin install ponytail@ponytail; then
      DONE=$((DONE+1)); say "installed: ponytail (restart Claude Code to activate)"
    else
      say "manual:  run inside Claude Code: /plugin marketplace add DietrichGebert/ponytail then /plugin install ponytail"
    fi
  else SKIPPED=$((SKIPPED+1)); fi
  # Note: "caveman" is not a standalone tool — it exists only as a benchmark arm
  # inside the ponytail repo. Ponytail covers the same ground.

  # ------------------------------------------------------------------- 2. rtk
  # Compresses shell output before it hits the context (git log -> hash+subject).
  if command -v rtk >/dev/null 2>&1; then
    say "ok:      rtk already installed ($(rtk --version 2>/dev/null || echo '?'))"
  elif ask_install "Install rtk? (token-saving shell-output proxy, adds one Claude hook)" y \
       "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh && rtk init -g"; then
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
      && rtk init -g \
      && { DONE=$((DONE+1)); say "installed: rtk + global hook (restart Claude Code)"; } \
      || say "rtk install failed — see https://github.com/rtk-ai/rtk"
  else SKIPPED=$((SKIPPED+1)); fi

  # -------------------------------------------------------------- 3. Graphify
  # Repo-to-knowledge-graph: faster code analysis at lower token cost
  # (graph query instead of grep-and-read). Navigation/context aid, never a CI gate.
  # CLI alone is not enough: /graphify in Claude Code needs the skill under
  # ~/.claude/skills (graphify installs it into ~/.agents/skills)
  link_graphify_skill() {
    if [ ! -e "$HOME/.claude/skills/graphify" ] && [ -d "$HOME/.agents/skills/graphify" ]; then
      mkdir -p "$HOME/.claude/skills"
      ln -s "$HOME/.agents/skills/graphify" "$HOME/.claude/skills/graphify"
      say "linked:  ~/.claude/skills/graphify -> ~/.agents/skills/graphify (/graphify now visible)"
    fi
  }
  if command -v graphify >/dev/null 2>&1; then
    link_graphify_skill
    say "ok:      graphify already installed"
  elif ask_install "Install Graphify? (codebase knowledge graph; PyPI package is 'graphifyy')" y \
       "uv tool install 'graphifyy[postgres,sql]' && graphify install --platform claude"; then
    uv tool install "graphifyy[postgres,sql]" \
      && graphify install --platform claude \
      && { link_graphify_skill; DONE=$((DONE+1)); say "installed: graphify CLI + claude skill"; } \
      || say "graphify install failed — see https://github.com/safishamsi/graphify"
  else SKIPPED=$((SKIPPED+1)); fi

  # -------------------------------------------------------------- 4. ast-grep
  # AST-based structural search & rewrite (codemods) — the only code-rewriting
  # tool in the stack; language-agnostic (Python + the React frontend).
  if command -v ast-grep >/dev/null 2>&1 || command -v sg >/dev/null 2>&1; then
    say "ok:      ast-grep already installed"
  elif ask_install "Install ast-grep? (structural codemods for bulk mechanical refactors)" y \
       "uv tool install ast-grep-cli"; then
    uv tool install ast-grep-cli \
      && { DONE=$((DONE+1)); say "installed: ast-grep (binary: ast-grep / sg)"; } \
      || say "ast-grep install failed — see https://github.com/ast-grep/ast-grep"
  else SKIPPED=$((SKIPPED+1)); fi

  # ---------------------------------------------------------------- 5. gh-axi
  # Agent-ergonomic gh wrapper: compact TOON output, next-step hints.
  # Prereq: gh CLI authenticated.
  if [ -d "$HOME/.claude/skills/gh-axi" ]; then
    say "ok:      gh-axi skill already installed"
  elif ask_install "Install gh-axi? (compact GitHub CLI output for agents; needs gh auth)" n \
       "npx -y skills add kunchenguid/gh-axi --skill gh-axi -g"; then
    npx -y skills add kunchenguid/gh-axi --skill gh-axi -g \
      && { DONE=$((DONE+1)); say "installed: gh-axi skill (~/.claude/skills/gh-axi)"; } \
      || say "gh-axi install failed — see https://github.com/kunchenguid/gh-axi"
  else SKIPPED=$((SKIPPED+1)); fi

  # --------------------------------------------------- 6. chrome-devtools-axi
  # Browser-debugging wrapper over chrome-devtools-mcp (frontend work).
  if [ -d "$HOME/.claude/skills/chrome-devtools-axi" ]; then
    say "ok:      chrome-devtools-axi skill already installed"
  elif ask_install "Install chrome-devtools-axi? (browser debug loop for frontend work)" n \
       "npx -y skills add kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi -g"; then
    npx -y skills add kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi -g \
      && { DONE=$((DONE+1)); say "installed: chrome-devtools-axi skill"; } \
      || say "install failed — see https://github.com/kunchenguid/chrome-devtools-axi"
  else SKIPPED=$((SKIPPED+1)); fi

  # ---------------------------------------------------------------- 7. serena
  # Semantic code navigation/editing MCP (LSP-backed): find_symbol /
  # references instead of reading whole files — fewer tokens, better targeting.
  # Opt-in: an earlier team trial left .serena/ litter that the sdd-doctor audit flags.
  if claude mcp list 2>/dev/null | grep -q '^serena:'; then
    say "ok:      serena MCP already registered"
  elif ask_install "Install serena? (semantic code navigation MCP via uvx; leaves .serena/ dirs — sdd-doctor's audit flags them)" n \
       "claude mcp add --scope user serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant"; then
    claude mcp add --scope user serena -- \
        uvx --from "git+https://github.com/oraios/serena" \
        serena start-mcp-server --context ide-assistant \
      && { DONE=$((DONE+1)); say "installed: serena user-scope MCP entry (uvx, no local install needed)"; } \
      || say "serena registration failed — see https://github.com/oraios/serena"
  else SKIPPED=$((SKIPPED+1)); fi

  say "machine done: $DONE installed, $SKIPPED declined"
  say "restart Claude Code so new plugins/hooks/skills take effect"
}

# ======================================================================= main ==
if [ "$DO_REFRESH" = 1 ]; then
  refresh_section
else
  if [ "$DO_REPO" = 1 ]; then repo_section; fi
  if [ "$DO_MACHINE" = 1 ]; then machine_section; fi
fi

if [ "$SKIP_COUNT" -gt 0 ]; then
  say "skipped $SKIP_COUNT step(s) — finish them later:"
  printf '%s' "$SKIP_LIST" | while IFS= read -r item; do say "  - $item"; done
  say "  re-run this script from a terminal to answer the questions interactively"
fi
exit 0
