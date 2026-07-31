#!/usr/bin/env bash
# sdd-doctor: checks that the machine + repo have everything SDD work needs.
# Advisory: exits 1 only when a REQUIRED tool is missing. Installed by sdd-kit.
#
# Finding format (ADR-0008, ported from ProjectStore's doctor): every check
# emits {level, group, code, message, next} where `next` is the exact fix
# command. Human output by default; `--json` prints the findings as JSON.
set -u

JSON=0; [ "${1:-}" = "--json" ] && JSON=1
FINDINGS="$(mktemp)"; trap 'rm -f "$FINDINGS"' EXIT
PASS=0; WARN=0; FAIL=0
GROUP="machine"

# emit <level> <code> <message> [next]
emit() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$GROUP" "$2" "$3" "${4:-}" >> "$FINDINGS"
  if [ "$JSON" = 0 ]; then
    case "$1" in
      ok)   echo "  ok:   [$2] $3" ;;
      warn) echo "  WARN: [$2] $3"; [ -n "${4:-}" ] && echo "        next: $4" ;;
      fail) echo "  FAIL: [$2] $3"; [ -n "${4:-}" ] && echo "        next: $4" ;;
    esac
  fi
}
ok()   { PASS=$((PASS+1)); emit ok   "$@"; }
warn() { WARN=$((WARN+1)); emit warn "$@"; }
bad()  { FAIL=$((FAIL+1)); emit fail "$@"; }

[ "$JSON" = 0 ] && echo "[sdd-doctor] machine tools"

command -v git >/dev/null 2>&1 && ok tool.git "git ($(git --version | cut -d' ' -f3))" \
  || bad tool.git "git missing" "install git"

if command -v node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
  ok tool.node "node ($(node --version)) + npx"
else
  bad tool.node "node/npx missing" "install Node.js 20+ (https://nodejs.org or nvm)"
fi

if command -v python3 >/dev/null 2>&1; then
  PYV="$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
  case "$PYV" in
    3.1[0-9]|3.[2-9][0-9]) ok tool.python "python3 ($PYV)" ;;
    *) warn tool.python "python3 $PYV < 3.10 — spec-lint and services need 3.10+" "install python 3.10+" ;;
  esac
else
  bad tool.python "python3 missing" "install python 3.10+"
fi

if command -v uv >/dev/null 2>&1; then
  ok tool.uv "uv ($(uv --version 2>/dev/null | cut -d' ' -f2)) — runs ruff/radon/complexipy/vulture via uvx"
else
  bad tool.uv "uv missing — review tools and youtrack-mcp need it" "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

if command -v ruff >/dev/null 2>&1; then
  ok tool.ruff "ruff ($(ruff --version | cut -d' ' -f2), native binary)"
elif command -v uvx >/dev/null 2>&1; then
  ok tool.ruff "ruff via uvx fallback (native install is faster)" "uv tool install ruff"
else
  bad tool.ruff "ruff unavailable — pre-commit hook and autoreview depend on it" "uv tool install ruff"
fi

if command -v openspec >/dev/null 2>&1; then
  ok tool.openspec "openspec CLI ($(openspec --version 2>/dev/null || echo '?'))"
elif command -v npx >/dev/null 2>&1; then
  warn tool.openspec "openspec CLI not global — npx fallback works but is slow" "npm install -g @fission-ai/openspec@latest"
else
  bad tool.openspec "openspec unavailable" "npm install -g @fission-ai/openspec@latest"
fi

if command -v claude >/dev/null 2>&1; then
  ok tool.claude "claude CLI ($(claude --version 2>/dev/null | head -1))"
else
  warn tool.claude "claude CLI missing" "install Claude Code and log in (subscription, no API key)"
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then ok tool.gh "gh CLI (authenticated)"
  else warn tool.gh "gh CLI present but not authenticated" "gh auth login"; fi
else
  warn tool.gh "gh CLI missing — needed for PRs and secrets" "install gh, then: gh auth login"
fi

# ----------------------------------------------------------------- repo checks
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$ROOT" ]; then
  GROUP="repo"
  [ "$JSON" = 0 ] && echo "[sdd-doctor] repo: $ROOT"
  cd "$ROOT" || exit 1

  [ -f AGENTS.md ] && ok repo.agents-md "AGENTS.md present" \
    || warn repo.agents-md "AGENTS.md missing" "run sdd-kit/bootstrap.sh $ROOT"
  [ -f .claude/settings.json ] && ok repo.hooks "Claude hooks configured (.claude/settings.json)" \
    || warn repo.hooks "no .claude/settings.json — hooks (spec-guard, no-verify, format) inactive" "run sdd-kit/bootstrap.sh $ROOT"
  [ -f .spec-guard-paths ] && ok repo.spec-guard "spec-guard enabled ($(wc -l < .spec-guard-paths | tr -d ' ') guarded path(s))" \
    || warn repo.spec-guard "no .spec-guard-paths — spec-guard hook is a no-op" "create .spec-guard-paths (code path prefixes, one per line)"

  if [ -f .git/hooks/pre-commit ] && grep -q sdd-check .git/hooks/pre-commit 2>/dev/null; then
    ok repo.pre-commit "pre-commit hook runs sdd-check"
  else
    warn repo.pre-commit "pre-commit hook missing or lacks sdd-check" "run sdd-kit/bootstrap.sh $ROOT"
  fi

  if [ -f openspec/config.yaml ] && grep -q '^references:' openspec/config.yaml; then
    STORE_ID="$(sed -n 's/^[[:space:]]*-[[:space:]]*//p' openspec/config.yaml | head -1)"
    OPENSPEC="openspec"; command -v openspec >/dev/null 2>&1 || OPENSPEC="npx -y @fission-ai/openspec@1.7.0" # openspec-pin
    if $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
      ok repo.store "store '$STORE_ID' registered"
    else
      warn repo.store "store '$STORE_ID' referenced but not registered" "clone it, then: openspec store register <path> --id $STORE_ID"
    fi
  fi

  if [ -f .mcp.json ] && grep -q '"youtrack"' .mcp.json; then
    YT_DIR="$(sed -n 's/.*"--directory",[[:space:]]*"\([^"]*\)".*/\1/p' .mcp.json | head -1)"
    if [ -n "$YT_DIR" ] && [ -f "$YT_DIR/.env" ] && grep -Eq '^[[:space:]]*YOUTRACK_API_TOKEN[[:space:]]*=[[:space:]]*[^[:space:]]' "$YT_DIR/.env"; then
      ok repo.youtrack "youtrack-mcp token configured ($YT_DIR/.env)"
    else
      warn repo.youtrack "youtrack MCP declared but no token in ${YT_DIR:-<dir>}/.env" "add YOUTRACK_API_TOKEN to ${YT_DIR:-<dir>}/.env (chmod 600)"
    fi
  fi

  # Per-service .env files a fresh clone needs to run the stack (paths only,
  # never secrets). List is seeded by the profile into .claude/expected-env.
  if [ -f .claude/expected-env ]; then
    ENV_MISSING=0
    while IFS= read -r ef; do
      [ -n "$ef" ] || continue
      [ -f "$ef" ] || { warn repo.env-file "missing env file: $ef (docker compose won't start without it)" "copy $ef from a working clone"; ENV_MISSING=1; }
    done < .claude/expected-env
    [ "$ENV_MISSING" = 0 ] && ok repo.env-file "all expected per-service .env present"
  fi
fi

# --------------------------------------- core personal tools (default stack)
# Installed by default via sdd-kit/setup-dev.sh: quality up, token spend down.
GROUP="personal"
for t in rtk graphify ast-grep; do
  if command -v "$t" >/dev/null 2>&1; then ok "personal.$t" "$t installed (core personal tool)"
  else warn "personal.$t" "$t missing" "run sdd-kit/setup-dev.sh (installs the default tool stack)"; fi
done
if grep -qs '"ponytail@ponytail"' "$HOME/.claude/settings.json" 2>/dev/null; then
  ok personal.ponytail "ponytail plugin enabled (core personal tool)"
else
  warn personal.ponytail "ponytail plugin not enabled" "run sdd-kit/setup-dev.sh"
fi

# ------------------------------------------------------------------- output
if [ "$JSON" = 1 ]; then
  python3 -c '
import json, sys
rows = []
for line in open(sys.argv[1]):
    level, group, code, message, nxt = line.rstrip("\n").split("\t")
    rows.append({"level": level, "group": group, "code": code,
                 "message": message, **({"next": nxt} if nxt else {})})
print(json.dumps({"findings": rows,
                  "summary": {"ok": sum(r["level"] == "ok" for r in rows),
                              "warn": sum(r["level"] == "warn" for r in rows),
                              "fail": sum(r["level"] == "fail" for r in rows)}}, indent=1))
' "$FINDINGS"
else
  echo "[sdd-doctor] summary: $PASS ok, $WARN warning(s), $FAIL failure(s)"
  if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo "[sdd-doctor] 0 issues found"
  elif [ "$FAIL" -gt 0 ]; then
    echo "next: run the 'next:' commands on the FAIL items above, then re-run make sdd-doctor"
  else
    echo "next: review the WARN items above (advisory — nothing blocks)"
  fi
fi
[ "$FAIL" -gt 0 ] && exit 1
exit 0
