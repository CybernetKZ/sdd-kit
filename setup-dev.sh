#!/usr/bin/env bash
# Per-DEVELOPER setup (machine-level, run once): offers the team's recommended
# personal tools. Everything is opt-in — each tool asks before installing.
# Repo-level assets are bootstrap.sh's job; nothing here touches a repo.
# Usage: sdd-kit/setup-dev.sh
set -u

say()  { echo "[setup-dev] $*"; }
DONE=0; SKIPPED=0

ask() {
  local q="$1" answer=""
  if [ ! -t 0 ]; then say "no TTY — skipping question: $q"; return 1; fi
  printf '[setup-dev] %s [y/N] ' "$q"
  read -r answer || answer=""
  case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------- 1. ponytail
# Lazy-senior-developer skill: less code, fewer tokens (plugin by Dietrich Gebert).
if grep -qs '"ponytail@ponytail"' "$HOME/.claude/settings.json" 2>/dev/null; then
  say "ok:      ponytail already enabled"
elif ask "Install ponytail? (Claude Code plugin: minimal working solutions, saves tokens)"; then
  if claude plugin marketplace add DietrichGebert/ponytail \
     && claude plugin install ponytail@ponytail; then
    DONE=$((DONE+1)); say "installed: ponytail (restart Claude Code to activate)"
  else
    say "manual:  run inside Claude Code: /plugin marketplace add DietrichGebert/ponytail then /plugin install ponytail"
  fi
else SKIPPED=$((SKIPPED+1)); fi
# Note: "caveman" is not a standalone tool — it exists only as a benchmark arm
# inside the ponytail repo. Ponytail covers the same ground.

# --------------------------------------------------------------------- 2. rtk
# Compresses shell output before it hits the context (git log -> hash+subject).
if command -v rtk >/dev/null 2>&1; then
  say "ok:      rtk already installed ($(rtk --version 2>/dev/null || echo '?'))"
elif ask "Install rtk? (token-saving shell-output proxy, adds one Claude hook)"; then
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
    && rtk init -g \
    && { DONE=$((DONE+1)); say "installed: rtk + global hook (restart Claude Code)"; } \
    || say "rtk install failed — see https://github.com/rtk-ai/rtk"
else SKIPPED=$((SKIPPED+1)); fi

# ------------------------------------------------------------------ 3. gh-axi
# Agent-ergonomic gh wrapper: compact TOON output, next-step hints.
# Prereq: gh CLI authenticated.
if [ -d "$HOME/.claude/skills/gh-axi" ]; then
  say "ok:      gh-axi skill already installed"
elif ask "Install gh-axi? (compact GitHub CLI output for agents; needs gh auth)"; then
  npx -y skills add kunchenguid/gh-axi --skill gh-axi -g \
    && { DONE=$((DONE+1)); say "installed: gh-axi skill (~/.claude/skills/gh-axi)"; } \
    || say "gh-axi install failed — see https://github.com/kunchenguid/gh-axi"
else SKIPPED=$((SKIPPED+1)); fi

# ----------------------------------------------------- 4. chrome-devtools-axi
# Browser-debugging wrapper over chrome-devtools-mcp (frontend work).
if [ -d "$HOME/.claude/skills/chrome-devtools-axi" ]; then
  say "ok:      chrome-devtools-axi skill already installed"
elif ask "Install chrome-devtools-axi? (browser debug loop for frontend work)"; then
  npx -y skills add kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi -g \
    && { DONE=$((DONE+1)); say "installed: chrome-devtools-axi skill"; } \
    || say "install failed — see https://github.com/kunchenguid/chrome-devtools-axi"
else SKIPPED=$((SKIPPED+1)); fi

# ---------------------------------------------------------------- 5. Graphify
# Repo-to-knowledge-graph: navigation/context aid, never a CI gate.
if command -v graphify >/dev/null 2>&1; then
  say "ok:      graphify already installed"
elif ask "Install Graphify? (codebase knowledge graph; PyPI package is 'graphifyy')"; then
  uv tool install "graphifyy[postgres,sql]" \
    && graphify install --platform claude \
    && { DONE=$((DONE+1)); say "installed: graphify CLI + claude skill"; } \
    || say "graphify install failed — see https://github.com/safishamsi/graphify"
else SKIPPED=$((SKIPPED+1)); fi

# ---------------------------------------------------------------- 6. Headroom
# Context compression MCP. Real win is context-window space, not cost
# (cached input re-reads already cost ~10%). PyPI name is headroom-ai —
# plain 'headroom' is an unrelated package.
if command -v headroom >/dev/null 2>&1; then
  say "ok:      headroom already installed"
elif ask "Install Headroom? (context compression MCP; optional)"; then
  uv tool install headroom-ai \
    && claude mcp add --scope user headroom -- headroom mcp serve \
    && { DONE=$((DONE+1)); say "installed: headroom + user-scope MCP entry"; } \
    || say "headroom install failed — see https://github.com/chopratejas/headroom"
else SKIPPED=$((SKIPPED+1)); fi

say "summary: $DONE installed, $SKIPPED declined"
say "restart Claude Code so new plugins/hooks/skills take effect"
