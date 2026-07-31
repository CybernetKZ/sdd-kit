#!/usr/bin/env bash
# Per-DEVELOPER setup (machine-level, run once): installs the team's
# recommended personal tools.
#
# CORE tools (quality up, token spend down) install BY DEFAULT [Y/n]:
#   ponytail (lean code), rtk (shell-output compression), graphify (repo
#   knowledge graph: faster/cheaper code analysis), ast-grep (structural
#   codemods).
# OPTIONAL tools stay opt-in [y/N]: gh-axi, chrome-devtools-axi, serena.
#
# Env: SDD_KIT_ASSUME_YES=1 (core installs without questions; optional
# still asks / skips on no-TTY).
# Repo-level assets are bootstrap.sh's job; nothing here touches a repo.
# Usage: sdd-kit/setup-dev.sh
set -u

say()  { echo "[setup-dev] $*"; }
DONE=0; SKIPPED=0

ask() { # opt-in [y/N] — optional tools
  local q="$1" answer=""
  if [ "${SDD_KIT_ASSUME_YES:-0}" = 1 ]; then return 0; fi
  if [ ! -t 0 ]; then say "no TTY — skipping question: $q"; return 1; fi
  printf '[setup-dev] %s [y/N] ' "$q"
  read -r answer || answer=""
  case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

ask_core() { # default-yes [Y/n] — core tools; installs on no-TTY too
  local q="$1" answer=""
  if [ "${SDD_KIT_ASSUME_YES:-0}" = 1 ] || [ ! -t 0 ]; then return 0; fi
  printf '[setup-dev] %s [Y/n] ' "$q"
  read -r answer || answer=""
  case "$answer" in [nN]|[nN][oO]) return 1 ;; *) return 0 ;; esac
}

# ================================ CORE (default install) ====================

# ---------------------------------------------------------------- 1. ponytail
# Lazy-senior-developer skill: less code, fewer tokens (plugin by Dietrich Gebert).
if grep -qs '"ponytail@ponytail"' "$HOME/.claude/settings.json" 2>/dev/null; then
  say "ok:      ponytail already enabled"
elif ask_core "Install ponytail? (minimal working solutions, saves tokens)"; then
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
elif ask_core "Install rtk? (token-saving shell-output proxy, adds one Claude hook)"; then
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh \
    && rtk init -g \
    && { DONE=$((DONE+1)); say "installed: rtk + global hook (restart Claude Code)"; } \
    || say "rtk install failed — see https://github.com/rtk-ai/rtk"
else SKIPPED=$((SKIPPED+1)); fi

# ---------------------------------------------------------------- 3. Graphify
# Repo-to-knowledge-graph: faster code analysis at lower token cost
# (graph query instead of grep-and-read). Navigation/context aid, never a CI gate.
if command -v graphify >/dev/null 2>&1; then
  say "ok:      graphify already installed"
elif ask_core "Install Graphify? (codebase knowledge graph; PyPI package is 'graphifyy')"; then
  uv tool install "graphifyy[postgres,sql]" \
    && graphify install --platform claude \
    && { DONE=$((DONE+1)); say "installed: graphify CLI + claude skill"; } \
    || say "graphify install failed — see https://github.com/safishamsi/graphify"
else SKIPPED=$((SKIPPED+1)); fi

# Headroom was removed from the stack — see docs/ADR/ADR-0014-drop-headroom.md
# (compresses ~0-2%, breaks the prompt-cache prefix, net +45..62% cost).

# ---------------------------------------------------------------- 4. ast-grep
# AST-based structural search & rewrite (codemods) — the only code-rewriting
# tool in the stack; language-agnostic (Python + the React frontend).
if command -v ast-grep >/dev/null 2>&1 || command -v sg >/dev/null 2>&1; then
  say "ok:      ast-grep already installed"
elif ask_core "Install ast-grep? (structural codemods for bulk mechanical refactors)"; then
  uv tool install ast-grep-cli \
    && { DONE=$((DONE+1)); say "installed: ast-grep (binary: ast-grep / sg)"; } \
    || say "ast-grep install failed — see https://github.com/ast-grep/ast-grep"
else SKIPPED=$((SKIPPED+1)); fi

# ================================ OPTIONAL (opt-in) ==========================

# ------------------------------------------------------------------ 5. gh-axi
# Agent-ergonomic gh wrapper: compact TOON output, next-step hints.
# Prereq: gh CLI authenticated.
if [ -d "$HOME/.claude/skills/gh-axi" ]; then
  say "ok:      gh-axi skill already installed"
elif ask "Install gh-axi? (compact GitHub CLI output for agents; needs gh auth)"; then
  npx -y skills add kunchenguid/gh-axi --skill gh-axi -g \
    && { DONE=$((DONE+1)); say "installed: gh-axi skill (~/.claude/skills/gh-axi)"; } \
    || say "gh-axi install failed — see https://github.com/kunchenguid/gh-axi"
else SKIPPED=$((SKIPPED+1)); fi

# ----------------------------------------------------- 6. chrome-devtools-axi
# Browser-debugging wrapper over chrome-devtools-mcp (frontend work).
if [ -d "$HOME/.claude/skills/chrome-devtools-axi" ]; then
  say "ok:      chrome-devtools-axi skill already installed"
elif ask "Install chrome-devtools-axi? (browser debug loop for frontend work)"; then
  npx -y skills add kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi -g \
    && { DONE=$((DONE+1)); say "installed: chrome-devtools-axi skill"; } \
    || say "install failed — see https://github.com/kunchenguid/chrome-devtools-axi"
else SKIPPED=$((SKIPPED+1)); fi

# ------------------------------------------------------------------ 7. serena
# Semantic code navigation/editing MCP (LSP-backed): find_symbol /
# references instead of reading whole files — fewer tokens, better targeting.
# Opt-in: an earlier team trial left .serena/ litter that repo-audit flags.
if claude mcp list 2>/dev/null | grep -q '^serena:'; then
  say "ok:      serena MCP already registered"
elif ask "Install serena? (semantic code navigation MCP via uvx; leaves .serena/ dirs — repo-audit flags them)"; then
  claude mcp add --scope user serena -- \
      uvx --from "git+https://github.com/oraios/serena" \
      serena start-mcp-server --context ide-assistant \
    && { DONE=$((DONE+1)); say "installed: serena user-scope MCP entry (uvx, no local install needed)"; } \
    || say "serena registration failed — see https://github.com/oraios/serena"
else SKIPPED=$((SKIPPED+1)); fi

say "summary: $DONE installed, $SKIPPED declined"
say "restart Claude Code so new plugins/hooks/skills take effect"
