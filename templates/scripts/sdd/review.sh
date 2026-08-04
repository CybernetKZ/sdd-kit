#!/usr/bin/env bash
# scripts/sdd/review.sh — AI review of your current branch (ex `make
# sdd-review`, ADR-0026), on YOUR machine with YOUR subscription login (no
# shared tokens; there is no server CI — this is the only review step, run
# before opening the PR).
# The prompt itself lives in .claude/scripts/review-prompt.md, used only by
# this script (the old .github/workflows/autoreview.yml is archived, ADR-0023).
# default review base = the repo's actual default branch (origin/HEAD),
# fallback dev (B3, ADR-0019); override with SDD_REVIEW_BASE.
set -u

BASE="${SDD_REVIEW_BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' | grep . || echo dev)}"

command -v claude >/dev/null || { echo "FAIL: claude CLI not found"; echo "next: install Claude Code and log in"; exit 1; }
test -f .claude/scripts/review-prompt.md || { echo "FAIL: .claude/scripts/review-prompt.md is missing"; echo "next: run sdd-kit/install.sh --repo-only on this repo"; exit 1; }

git diff "$BASE"...HEAD > /tmp/sdd-review.diff
test -s /tmp/sdd-review.diff || { echo "sdd-review: 0 changes vs $BASE — nothing to review"; exit 0; }

# Static-tool leads for the reviewer (/tmp/tools.txt). Each tool is optional:
# missing tools are skipped silently, the review just gets fewer leads.
rm -f /tmp/tools.txt
FILES=$(git diff --name-only "$BASE"...HEAD -- '*.py' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
if [ -n "$FILES" ]; then
  { command -v radon      >/dev/null && echo "== radon cc (complexity C+)" && echo "$FILES" | xargs radon cc -n C -s 2>/dev/null
    command -v complexipy >/dev/null && echo "== complexipy"               && echo "$FILES" | xargs complexipy -d low 2>/dev/null
    command -v vulture    >/dev/null && echo "== vulture (dead code)"      && echo "$FILES" | xargs vulture --min-confidence 80 2>/dev/null
    command -v semgrep    >/dev/null && echo "== semgrep (security, auto)" && echo "$FILES" | xargs semgrep scan --quiet --config auto 2>/dev/null
  } > /tmp/tools.txt || true
  if [ -s /tmp/tools.txt ]; then echo "sdd-review: static leads in /tmp/tools.txt"; else rm -f /tmp/tools.txt; fi
fi

claude -p "$(cat .claude/scripts/review-prompt.md)" --allowedTools "Read,Grep,Glob"
