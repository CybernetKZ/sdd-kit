#!/usr/bin/env bash
# SDD uninstall for a repository: reverses install.sh --repo-only.
# Usage: sdd-kit/uninstall.sh [--force] /path/to/repo
#
# Safety rule: a file is deleted ONLY when it is byte-identical to the kit
# template (or profile payload) that installed it. Anything the team modified
# is kept, with a WARN and the exact manual command. --force deletes the
# kit-installed files even when they were modified (AGENTS.md and openspec/
# are still treated as team content: rename/ask logic applies, never force).
# Data (openspec/ specs) is only touched after an explicit yes. The central
# store registration is machine-wide state: it is unregistered only on an
# interactive yes or with --force — an unattended run (no TTY /
# SDD_KIT_ASSUME_YES=1) keeps it and prints the manual command.
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

# unregister_store <question> — the central store is machine-wide state shared
# by every repo, so it is NEVER unregistered unattended: an explicit interactive
# yes or --force is required (SDD_KIT_ASSUME_YES alone is not enough).
unregister_store() {
  local q="$1" cmd="$OPENSPEC store unregister $STORE_ID"
  if [ "$FORCE" = 1 ]; then
    $OPENSPEC store unregister "$STORE_ID" && say "unregistered: store '$STORE_ID' (--force)"
    return 0
  fi
  if [ "$INTERACTIVE" = 0 ]; then
    say "kept: store '$STORE_ID' registration (unattended run — machine-wide state)"
    echo "        next: $cmd  # or re-run uninstall.sh --force" >&2
    return 0
  fi
  printf '[sdd-kit] %s [y/N] ' "$q"
  local answer=""; read -r answer || answer=""
  case "$answer" in
    [yY]|[yY][eE][sS]) $OPENSPEC store unregister "$STORE_ID" && say "unregistered: store '$STORE_ID'" ;;
    *) say "kept: store '$STORE_ID' registration"; echo "        next: $cmd" >&2 ;;
  esac
}

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

# del <path...> — remove a kit-installed file; when git tracks it, remove it
# through git so the index stays coherent. A plain rm on a tracked file leaves
# an unstaged deletion that the next install turns into a phantom
# "deleted + untracked" pair in git status.
del() {
  local p
  for p in "$@"; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      git rm -q -f -- "$p" || rm -f "$p"
    else
      rm -f "$p"
    fi
  done
}

# kit_had <dest> — true when dest is byte-identical to ANY version of ANY kit
# template ever committed. A repo installed from an older kit revision carries
# stale-but-genuine kit files; without this check every one of them is reported
# as "team edits?" and left behind, so uninstall never actually uninstalls.
KIT_BLOBS=""
kit_had() {
  local blob
  if [ -z "$KIT_BLOBS" ]; then
    # --no-abbrev: without it --raw prints short hashes that never match hash-object
    KIT_BLOBS="$(git -C "$KIT" log --all --format= --raw --no-abbrev \
      -- templates docs/archive profiles 2>/dev/null | awk '{print $3"\n"$4}' | sort -u)"
    [ -n "$KIT_BLOBS" ] || KIT_BLOBS="none"  # not a git checkout — do not re-run per file
  fi
  blob="$(git hash-object -- "$1" 2>/dev/null)" || return 1
  printf '%s\n' "$KIT_BLOBS" | grep -qx "$blob"
}

# rm_ours <source-in-kit> <dest> — delete dest only when it is a kit file:
# identical to the current template, or to one of its earlier committed versions
# (--force: delete even when it differs).
rm_ours() {
  local src="$1" dst="$2"
  [ -e "$dst" ] || return 0
  if [ -f "$src" ] && cmp -s "$src" "$dst"; then
    del "$dst"; REMOVED=$((REMOVED+1)); say "removed: $dst"
  elif kit_had "$dst"; then
    del "$dst"; REMOVED=$((REMOVED+1)); say "removed: $dst (older kit version)"
  elif [ "$FORCE" = 1 ]; then
    del "$dst"; REMOVED=$((REMOVED+1)); say "removed: $dst (forced: differed from the kit version)"
  else
    KEPT=$((KEPT+1))
    warn "kept: $dst differs from the kit version (team edits?)"
    echo "        next: diff \"$src\" \"$dst\" && rm \"$dst\"  # or re-run with --force" >&2
  fi
}

# rm_retired <dest> <why> — a kit file whose template no longer exists
# (ADR-0026 removed it outright, no archive), so there is nothing to
# byte-compare against: remove on --force, otherwise name the exact command.
rm_retired() {
  local dst="$1" why="$2"
  [ -e "$dst" ] || return 0
  if [ "$FORCE" = 1 ]; then
    del "$dst"; REMOVED=$((REMOVED+1)); say "removed: $dst (retired: $why)"
  else
    KEPT=$((KEPT+1)); warn "kept: $dst (retired: $why)"
    echo "        next: rm \"$dst\"" >&2
  fi
}

# ------------------------------------------------------------------ store repo
if [ "$PROFILE_IS_STORE" = 1 ]; then
  rm_retired .github/workflows/store-ci.yml "no CI, no exceptions — ADR-0026 §5"
  OPENSPEC="npx -y @fission-ai/openspec@1.7.0" # openspec-pin
  command -v openspec >/dev/null 2>&1 && OPENSPEC="openspec"
  if $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
    unregister_store "Unregister store '$STORE_ID' on this machine? (files stay untouched)"
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
# python leaves __pycache__ next to spec-lint.py — a kit byproduct, not team content
[ -e .claude/scripts/spec-lint.py ] || rm -rf .claude/scripts/__pycache__
# repo-audit.sh was merged into sdd-doctor.sh — the template is gone, so it
# cannot be byte-compared; leave the old copy and name the exact command.
if [ -f .claude/scripts/repo-audit.sh ]; then
  if [ "$FORCE" = 1 ]; then
    del .claude/scripts/repo-audit.sh; REMOVED=$((REMOVED+1))
    say "removed: .claude/scripts/repo-audit.sh (retired: merged into sdd-doctor.sh)"
  else
    KEPT=$((KEPT+1)); warn "kept: .claude/scripts/repo-audit.sh (retired: merged into sdd-doctor.sh)"
    echo "        next: rm .claude/scripts/repo-audit.sh" >&2
  fi
fi
for a in backend-reviewer database-reviewer planner plan-griller test-author executor repo-auditor; do
  rm_ours "$KIT/templates/agents/$a.md" ".claude/agents/$a.md"
done
rm_ours "$KIT/templates/skills/feature-flow/SKILL.md" .claude/skills/feature-flow/SKILL.md
rm_ours "$KIT/templates/skills/feature-flow/references/details.md" .claude/skills/feature-flow/references/details.md
rm_ours "$KIT/templates/skills/incident-flow/SKILL.md" .claude/skills/incident-flow/SKILL.md
rm_ours "$KIT/templates/skills/grilling/SKILL.md" .claude/skills/grilling/SKILL.md
rm_ours "$KIT/templates/skills/grill-me/SKILL.md" .claude/skills/grill-me/SKILL.md
rm_ours "$KIT/templates/skills/grill-with-docs/SKILL.md" .claude/skills/grill-with-docs/SKILL.md
rm_ours "$KIT/templates/skills/domain-modeling/SKILL.md" .claude/skills/domain-modeling/SKILL.md
rm_ours "$KIT/templates/skills/domain-modeling/CONTEXT-FORMAT.md" .claude/skills/domain-modeling/CONTEXT-FORMAT.md
rm_ours "$KIT/templates/skills/domain-modeling/ADR-FORMAT.md" .claude/skills/domain-modeling/ADR-FORMAT.md
del .claude/last-session-state.md .claude/expected-env

# ------------------------------------------------------------ 2. CI workflows
# Retired by ADR-0023 §5 (no server-side gates) — install.sh no longer copies
# these, but repos installed before that still carry them, so keep removing
# them. The templates now live in docs/archive/, which is what rm_ours compares
# against.
rm_ours "$KIT/docs/archive/sdd-ci.yml" .github/workflows/sdd-ci.yml
rm_ours "$KIT/docs/archive/autoreview.yml" .github/workflows/autoreview.yml

# -------------------------------------- 3. scripts/sdd + legacy Makefile.sdd
for f in check.sh test.sh review.sh index.sh doctor.sh; do
  rm_ours "$KIT/templates/scripts/sdd/$f" "scripts/sdd/$f"
done
rmdir scripts/sdd scripts 2>/dev/null || true
# Makefile.sdd is retired (ADR-0026 §3) — repos installed before still carry it.
rm_retired Makefile.sdd "targets moved to scripts/sdd/*.sh — ADR-0026 §3"
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
rm_retired feature_flags.py "flags cut entirely — ADR-0026 §2"
# .spec-guard-paths is the team's list of guarded code paths — it is data, not a
# template copy, so it gets the same identical-only rule as everything else:
# removed when it still matches what the profile wrote, kept otherwise.
if [ -e .spec-guard-paths ]; then
  if [ -n "${PROFILE_SPEC_GUARD_PATHS:-}" ] \
     && printf '%s\n' "$PROFILE_SPEC_GUARD_PATHS" | cmp -s - .spec-guard-paths; then
    del .spec-guard-paths; REMOVED=$((REMOVED+1)); say "removed: .spec-guard-paths"
  elif [ "$FORCE" = 1 ]; then
    del .spec-guard-paths; REMOVED=$((REMOVED+1)); say "removed: .spec-guard-paths (forced: differed from the profile)"
  else
    KEPT=$((KEPT+1)); warn "kept: .spec-guard-paths differs from the profile list (team edits?)"
    echo "        next: rm .spec-guard-paths  # or re-run with --force" >&2
  fi
fi

# .mcp.json: ours contains only context7/youtrack (+ our shape) — else keep.
if [ -f .mcp.json ]; then
  if python3 -c "
import json, sys
servers = set(json.load(open('.mcp.json')).get('mcpServers', {}))
sys.exit(0 if servers <= {'context7', 'youtrack'} else 1)
" 2>/dev/null; then
    del .mcp.json; REMOVED=$((REMOVED+1)); say "removed: .mcp.json"
  elif [ "$FORCE" = 1 ]; then
    del .mcp.json; REMOVED=$((REMOVED+1)); say "removed: .mcp.json (forced: had extra servers)"
  else
    KEPT=$((KEPT+1)); warn "kept: .mcp.json has servers beyond context7/youtrack — remove ours by hand"
  fi
fi

# ------------------------------------------------------- 5. git pre-commit hook
if [ -f .git/hooks/pre-commit ]; then
  if grep -q "sdd-kit git pre-commit hook" .git/hooks/pre-commit; then
    rm .git/hooks/pre-commit; REMOVED=$((REMOVED+1)); say "removed: .git/hooks/pre-commit"
  elif grep -q "scripts/sdd/check.sh" .git/hooks/pre-commit; then
    if [ "$FORCE" = 1 ]; then
      rm .git/hooks/pre-commit; REMOVED=$((REMOVED+1)); say "removed: .git/hooks/pre-commit (forced: was hand-merged)"
    else
      KEPT=$((KEPT+1)); warn "kept: .git/hooks/pre-commit was hand-merged — remove the scripts/sdd/check.sh lines yourself"
    fi
  fi
fi

# ------------------------------------- 6. AGENTS.md / CLAUDE.md (restore names)
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = "AGENTS.md" ]; then
  del CLAUDE.md; say "removed: CLAUDE.md symlink"
fi
if [ -f AGENTS.md ]; then
  if cmp -s "$KIT/templates/AGENTS.md" AGENTS.md \
     || { [ -f "$KIT/profiles/$REPO_NAME/AGENTS.md" ] && cmp -s "$KIT/profiles/$REPO_NAME/AGENTS.md" AGENTS.md; }; then
    del AGENTS.md; REMOVED=$((REMOVED+1)); say "removed: AGENTS.md (unmodified kit/payload copy)"
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
if $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
  unregister_store "Unregister central store '$STORE_ID' on this machine? (other repos may still use it; files stay)"
fi

# -------------------------------------------------------------- 8. empty dirs
for d in .claude/hooks .claude/scripts .claude/agents \
         .claude/skills/feature-flow/references .claude/skills/feature-flow \
         .claude/skills/incident-flow .claude/skills/grilling .claude/skills/grill-me \
         .claude/skills/grill-with-docs .claude/skills/domain-modeling \
         .claude/skills .claude .github/workflows .github; do
  [ -d "$d" ] && rmdir "$d" 2>/dev/null && say "removed: $d/ (empty)" || true
done

say "done: removed $REMOVED, kept $KEPT (kept items listed above with a next: command)"
[ "$KEPT" -gt 0 ] && say "re-run from a terminal to answer the interactive questions, if any were skipped"
exit 0
