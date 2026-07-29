#!/usr/bin/env bash
# sdd-doctor: checks that the machine + repo have everything SDD work needs.
# Advisory: exits 1 only when a REQUIRED tool is missing. Installed by sdd-kit.
set -u

PASS=0; WARN=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok:   $*"; }
warn() { WARN=$((WARN+1)); echo "  WARN: $*"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $*"; }

echo "[sdd-doctor] machine tools"

command -v git >/dev/null 2>&1 && ok "git ($(git --version | cut -d' ' -f3))" \
  || bad "git missing — install git"

if command -v node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
  ok "node ($(node --version)) + npx"
else
  bad "node/npx missing — install Node.js 20+ (https://nodejs.org or nvm)"
fi

if command -v python3 >/dev/null 2>&1; then
  PYV="$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
  case "$PYV" in
    3.1[0-9]|3.[2-9][0-9]) ok "python3 ($PYV)" ;;
    *) warn "python3 $PYV < 3.10 — spec-lint and services need 3.10+" ;;
  esac
else
  bad "python3 missing"
fi

if command -v uv >/dev/null 2>&1; then
  ok "uv ($(uv --version 2>/dev/null | cut -d' ' -f2)) — runs ruff/radon/complexipy/vulture via uvx"
else
  bad "uv missing — review tools and youtrack-mcp need it: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

if command -v ruff >/dev/null 2>&1; then
  ok "ruff ($(ruff --version | cut -d' ' -f2), native binary)"
elif command -v uvx >/dev/null 2>&1; then
  ok "ruff via uvx fallback (native install is faster: uv tool install ruff)"
else
  bad "ruff unavailable — pre-commit hook and autoreview depend on it"
fi

if command -v openspec >/dev/null 2>&1; then
  ok "openspec CLI ($(openspec --version 2>/dev/null || echo '?'))"
elif command -v npx >/dev/null 2>&1; then
  warn "openspec CLI not global — npx fallback works but is slow (npm install -g @fission-ai/openspec@latest)"
else
  bad "openspec unavailable"
fi

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI ($(claude --version 2>/dev/null | head -1))"
else
  warn "claude CLI missing — install Claude Code and log in (subscription, no API key)"
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok "gh CLI (authenticated)"; else warn "gh CLI present but not authenticated — run: gh auth login"; fi
else
  warn "gh CLI missing — needed for PRs and secrets (CLAUDE_CODE_OAUTH_TOKEN)"
fi

# ----------------------------------------------------------------- repo checks
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$ROOT" ]; then
  echo "[sdd-doctor] repo: $ROOT"
  cd "$ROOT" || exit 1

  [ -f AGENTS.md ] && ok "AGENTS.md present" || warn "AGENTS.md missing — run sdd-kit/bootstrap.sh"
  [ -f .claude/settings.json ] && ok "Claude hooks configured (.claude/settings.json)" \
    || warn "no .claude/settings.json — hooks (spec-guard, no-verify, format) inactive"
  [ -f .spec-guard-paths ] && ok "spec-guard enabled ($(wc -l < .spec-guard-paths | tr -d ' ') guarded path(s))" \
    || warn "no .spec-guard-paths — spec-guard hook is a no-op"

  if [ -f .git/hooks/pre-commit ] && grep -q sdd-check .git/hooks/pre-commit 2>/dev/null; then
    ok "pre-commit hook runs sdd-check"
  else
    warn "pre-commit hook missing or lacks sdd-check — run sdd-kit/bootstrap.sh"
  fi

  if [ -f openspec/config.yaml ] && grep -q '^references:' openspec/config.yaml; then
    STORE_ID="$(sed -n 's/^[[:space:]]*-[[:space:]]*//p' openspec/config.yaml | head -1)"
    OPENSPEC="openspec"; command -v openspec >/dev/null 2>&1 || OPENSPEC="npx -y @fission-ai/openspec@1.6.0"
    if $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
      ok "store '$STORE_ID' registered"
    else
      warn "store '$STORE_ID' referenced but not registered — clone it and run: openspec store register <path> --id $STORE_ID"
    fi
  fi

  if [ -f .mcp.json ] && grep -q '"youtrack"' .mcp.json; then
    YT_DIR="$(sed -n 's/.*"--directory",[[:space:]]*"\([^"]*\)".*/\1/p' .mcp.json | head -1)"
    if [ -n "$YT_DIR" ] && [ -f "$YT_DIR/.env" ] && grep -Eq '^[[:space:]]*YOUTRACK_API_TOKEN[[:space:]]*=[[:space:]]*[^[:space:]]' "$YT_DIR/.env"; then
      ok "youtrack-mcp token configured ($YT_DIR/.env)"
    else
      warn "youtrack MCP declared but no token in ${YT_DIR:-<dir>}/.env"
    fi
  fi

  # Per-service .env files a fresh clone needs to run the stack (paths only,
  # never secrets). List is seeded by the profile into .claude/expected-env.
  if [ -f .claude/expected-env ]; then
    ENV_MISSING=0
    while IFS= read -r ef; do
      [ -n "$ef" ] || continue
      [ -f "$ef" ] || { warn "missing env file: $ef (copy from a working clone; docker compose won't start without it)"; ENV_MISSING=1; }
    done < .claude/expected-env
    [ "$ENV_MISSING" = 0 ] && ok "all expected per-service .env present"
  fi
fi

# --------------------------------------- core personal tools (default stack)
# Installed by default via sdd-kit/setup-dev.sh: quality up, token spend down.
for t in rtk graphify headroom; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t installed (core personal tool)"
  else warn "$t missing — run sdd-kit/setup-dev.sh (installs the default tool stack)"; fi
done
if claude mcp list 2>/dev/null | grep -q '^serena:'; then
  ok "serena MCP registered (core personal tool)"
else
  warn "serena MCP not registered — run sdd-kit/setup-dev.sh"
fi
if grep -qs '"ponytail@ponytail"' "$HOME/.claude/settings.json" 2>/dev/null; then
  ok "ponytail plugin enabled (core personal tool)"
else
  warn "ponytail plugin not enabled — run sdd-kit/setup-dev.sh"
fi

echo "[sdd-doctor] summary: $PASS ok, $WARN warning(s), $FAIL failure(s)"
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo "[sdd-doctor] 0 issues found"
elif [ "$FAIL" -gt 0 ]; then
  echo "next: install the FAIL items above, then re-run make sdd-doctor"
  exit 1
else
  echo "next: review the WARN items above (advisory — nothing blocks)"
fi
exit 0
