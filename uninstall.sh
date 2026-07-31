#!/usr/bin/env bash
# SDD uninstall for a repository: reverses install.sh --repo-only.
# Usage: sdd-kit/uninstall.sh [--force] /path/to/repo
#
# Safety rule: a file is deleted ONLY when it is byte-identical to the kit
# template (or profile payload) that installed it. Anything the team modified
# is kept, with a WARN and the exact manual command. --force deletes the
# kit-installed files even when they were modified (AGENTS.md and openspec/
# are still treated as team content: rename/ask logic applies, never force).
# Data (openspec/ specs, store registration) is only touched after an
# explicit yes.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; shift; fi
REPO="${1:?Usage: uninstall.sh [--force] /path/to/repo}"
REPO="$(cd "$REPO" && pwd)"
cd "$REPO"

say()  { echo "[sdd-kit] $*"; }
warn() { echo "[sdd-kit] WARN: $*" >&2; }

REMOVED=0; KEPT=0
INTERACTIVE=0; [ -t 0 ] && INTERACTIVE=1
ASSUME_YES=0; [ "${SDD_KIT_ASSUME_YES:-0}" = "1" ] && ASSUME_YES=1

REPO_NAME="$(basename "$REPO")"
PROFILE_IS_STORE=0
if [ -f "$KIT/profiles/$REPO_NAME.env" ]; then
  # shellcheck disable=SC1090
  . "$KIT/profiles/$REPO_NAME.env"
  say "profile: $REPO_NAME"
fi
STORE_ID="${SDD_STORE_ID:-cybernet-specs}"

ask() { # explicit yes required; non-TTY: yes only with SDD_KIT_ASSUME_YES=1
  local q="$1" answer=""
  if [ "$INTERACTIVE" = 1 ]; then
    printf '[sdd-kit] %s [y/N] ' "$q"
    read -r answer || answer=""
    case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
  fi
  [ "$ASSUME_YES" = 1 ] && { say "auto-yes (SDD_KIT_ASSUME_YES=1): $q"; return 0; }
  return 1
}

# rm_ours <source-in-kit> <dest> — delete dest only when identical to source
# (--force: delete even when it differs).
rm_ours() {
  local src="$1" dst="$2"
  [ -e "$dst" ] || return 0
  if [ -f "$src" ] && cmp -s "$src" "$dst"; then
    rm "$dst"; REMOVED=$((REMOVED+1)); say "removed: $dst"
  elif [ "$FORCE" = 1 ]; then
    rm "$dst"; REMOVED=$((REMOVED+1)); say "removed: $dst (forced: differed from the kit version)"
  else
    KEPT=$((KEPT+1))
    warn "kept: $dst differs from the kit version (team edits?)"
    echo "        next: diff \"$src\" \"$dst\" && rm \"$dst\"  # or re-run with --force" >&2
  fi
}

# ------------------------------------------------------------------ store repo
if [ "$PROFILE_IS_STORE" = 1 ]; then
  rm_ours "$KIT/templates/store-ci.yml" .github/workflows/store-ci.yml
  OPENSPEC="npx -y @fission-ai/openspec@1.7.0" # openspec-pin
  command -v openspec >/dev/null 2>&1 && OPENSPEC="openspec"
  if $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]" \
     && ask "Unregister store '$STORE_ID' on this machine? (files stay untouched)"; then
    $OPENSPEC store unregister "$STORE_ID" && say "unregistered: store '$STORE_ID'"
  fi
  say "done (store profile): removed $REMOVED, kept $KEPT"
  exit 0
fi

# --------------------------------------------------- 1. hooks, scripts, agents
for f in block-no-verify.cjs pre-compact.cjs spec-guard.cjs block-no-verify.js pre-compact.js spec-guard.js; do
  rm_ours "$KIT/templates/$f" ".claude/hooks/$f"
done
rm_ours "$KIT/templates/settings.json" .claude/settings.json
for f in spec-lint.py sdd-doctor.sh review-prompt.md; do
  rm_ours "$KIT/templates/$f" ".claude/scripts/$f"
done
# repo-audit.sh was merged into sdd-doctor.sh — the template is gone, so it
# cannot be byte-compared; leave the old copy and name the exact command.
if [ -f .claude/scripts/repo-audit.sh ]; then
  if [ "$FORCE" = 1 ]; then
    rm .claude/scripts/repo-audit.sh; REMOVED=$((REMOVED+1))
    say "removed: .claude/scripts/repo-audit.sh (retired: merged into sdd-doctor.sh)"
  else
    KEPT=$((KEPT+1)); warn "kept: .claude/scripts/repo-audit.sh (retired: merged into sdd-doctor.sh)"
    echo "        next: rm .claude/scripts/repo-audit.sh" >&2
  fi
fi
for a in backend-reviewer database-reviewer planner plan-griller; do
  rm_ours "$KIT/templates/agents/$a.md" ".claude/agents/$a.md"
done
rm_ours "$KIT/templates/skills/feature-flow/SKILL.md" .claude/skills/feature-flow/SKILL.md
rm_ours "$KIT/templates/skills/incident-flow/SKILL.md" .claude/skills/incident-flow/SKILL.md
rm -f .claude/last-session-state.md .claude/expected-env

# ------------------------------------------------------------ 2. CI workflows
rm_ours "$KIT/templates/sdd-ci.yml" .github/workflows/sdd-ci.yml
rm_ours "$KIT/templates/autoreview.yml" .github/workflows/autoreview.yml

# ------------------------------------------------- 3. Makefile.sdd + include
rm_ours "$KIT/templates/Makefile.sdd" Makefile.sdd
if [ -f Makefile ] && grep -q "Makefile.sdd" Makefile; then
  sed -i.bak '/-include Makefile.sdd/d' Makefile && rm -f Makefile.bak
  # drop the blank line the install-time append left at EOF
  printf '%s' "$(cat Makefile)" > Makefile.tmp
  if [ -s Makefile.tmp ]; then printf '\n' >> Makefile.tmp; fi
  mv Makefile.tmp Makefile
  say "removed: '-include Makefile.sdd' line from Makefile"
  # installer-created Makefile contained only that line — drop it when empty
  [ -s Makefile ] || { rm Makefile; say "removed: Makefile (was include-only)"; }
fi

# ------------------------------------------------------------- 4. small files
# ruff.toml may be the repo's OWN config (the installer adds the kit one only
# when none exists) — force applies only when it carries the kit header.
if [ -f ruff.toml ] && ! cmp -s "$KIT/templates/ruff.toml" ruff.toml \
   && ! head -1 ruff.toml | grep -q '^# Ruff defaults for'; then
  KEPT=$((KEPT+1)); warn "kept: ruff.toml (no kit header — looks like the repo's own config)"
else
  rm_ours "$KIT/templates/ruff.toml" ruff.toml
fi
rm_ours "$KIT/templates/feature_flags.py" feature_flags.py
rm -f .spec-guard-paths && say "removed: .spec-guard-paths"

# .mcp.json: ours contains only context7/youtrack (+ our shape) — else keep.
if [ -f .mcp.json ]; then
  if python3 -c "
import json, sys
servers = set(json.load(open('.mcp.json')).get('mcpServers', {}))
sys.exit(0 if servers <= {'context7', 'youtrack'} else 1)
" 2>/dev/null; then
    rm .mcp.json; REMOVED=$((REMOVED+1)); say "removed: .mcp.json"
  elif [ "$FORCE" = 1 ]; then
    rm .mcp.json; REMOVED=$((REMOVED+1)); say "removed: .mcp.json (forced: had extra servers)"
  else
    KEPT=$((KEPT+1)); warn "kept: .mcp.json has servers beyond context7/youtrack — remove ours by hand"
  fi
fi

# ------------------------------------------------------- 5. git pre-commit hook
if [ -f .git/hooks/pre-commit ]; then
  if grep -q "sdd-kit git pre-commit hook" .git/hooks/pre-commit; then
    rm .git/hooks/pre-commit; REMOVED=$((REMOVED+1)); say "removed: .git/hooks/pre-commit"
  elif grep -q "sdd-check" .git/hooks/pre-commit; then
    if [ "$FORCE" = 1 ]; then
      rm .git/hooks/pre-commit; REMOVED=$((REMOVED+1)); say "removed: .git/hooks/pre-commit (forced: was hand-merged)"
    else
      KEPT=$((KEPT+1)); warn "kept: .git/hooks/pre-commit was hand-merged — remove the sdd-check lines yourself"
    fi
  fi
fi

# ------------------------------------- 6. AGENTS.md / CLAUDE.md (restore names)
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = "AGENTS.md" ]; then
  rm CLAUDE.md; say "removed: CLAUDE.md symlink"
fi
if [ -f AGENTS.md ]; then
  if cmp -s "$KIT/templates/AGENTS.md" AGENTS.md \
     || { [ -f "$KIT/profiles/$REPO_NAME/AGENTS.md" ] && cmp -s "$KIT/profiles/$REPO_NAME/AGENTS.md" AGENTS.md; }; then
    rm AGENTS.md; REMOVED=$((REMOVED+1)); say "removed: AGENTS.md (unmodified kit/payload copy)"
  elif [ ! -e CLAUDE.md ] && ask "Rename AGENTS.md back to CLAUDE.md? (the installer renamed it on install)"; then
    if git ls-files --error-unmatch AGENTS.md >/dev/null 2>&1; then
      git mv AGENTS.md CLAUDE.md
    else
      mv AGENTS.md CLAUDE.md
    fi
    say "renamed: AGENTS.md -> CLAUDE.md"
  else
    KEPT=$((KEPT+1)); warn "kept: AGENTS.md (has team content)"
    echo "        next: mv AGENTS.md CLAUDE.md  # if the installer renamed your CLAUDE.md on install" >&2
  fi
fi

# ------------------------------------------------------ 7. openspec/ and store
if [ -d openspec ]; then
  if ask "Delete openspec/ entirely? Specs and changes are LOST (not recoverable outside git)"; then
    rm -rf openspec; REMOVED=$((REMOVED+1)); say "removed: openspec/"
    # openspec init --tools claude also dropped its commands/skills into .claude/
    rm -rf .claude/commands/opsx .claude/skills/openspec-*
    rmdir .claude/commands 2>/dev/null || true
    say "removed: .claude/commands/opsx + .claude/skills/openspec-* (openspec tooling)"
  else
    KEPT=$((KEPT+1)); warn "kept: openspec/ (specs + changes)"
    echo "        next: rm -rf openspec  # when you are sure" >&2
  fi
fi
OPENSPEC="npx -y @fission-ai/openspec@1.7.0" # openspec-pin
command -v openspec >/dev/null 2>&1 && OPENSPEC="openspec"
if $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]" \
   && ask "Unregister central store '$STORE_ID' on this machine? (other repos may still use it; files stay)"; then
  $OPENSPEC store unregister "$STORE_ID" && say "unregistered: store '$STORE_ID'"
fi

# -------------------------------------------------------------- 8. empty dirs
for d in .claude/hooks .claude/scripts .claude/agents .claude/skills/feature-flow \
         .claude/skills/incident-flow .claude/skills .claude .github/workflows .github; do
  [ -d "$d" ] && rmdir "$d" 2>/dev/null && say "removed: $d/ (empty)" || true
done

say "done: removed $REMOVED, kept $KEPT (kept items listed above with a next: command)"
[ "$KEPT" -gt 0 ] && say "re-run from a terminal to answer the interactive questions, if any were skipped"
exit 0
