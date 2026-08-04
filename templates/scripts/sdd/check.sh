#!/usr/bin/env bash
# scripts/sdd/check.sh — the SDD gate (ex `make sdd-check`, ADR-0026).
# Run from the repo root; pre-commit runs it too.
set -u

fail() { echo "FAIL: $1"; echo "next: $2"; exit 1; }

[ -f AGENTS.md ] || fail "AGENTS.md is missing" "run sdd-kit/install.sh --repo-only on this repo"
[ "$(wc -l < AGENTS.md)" -le 500 ] || fail "AGENTS.md is longer than 500 lines" "move detail into openspec/specs/ or docs/, keep AGENTS.md a map"
# ADR-0023 §2: "exists and <=500 lines" passed a 9-byte AGENTS.md whose whole
# content was the text "AGENTS.md" (a botched symlink) — agents read nothing.
[ "$(grep -cv '^[[:space:]]*$' AGENTS.md)" -ge 10 ] || fail "AGENTS.md is broken/empty — restore it (a one-line file is a botched symlink)" "git log --oneline -- AGENTS.md, then: git show <ref>:AGENTS.md > AGENTS.md"
grep -q TODO AGENTS.md && echo "WARN: AGENTS.md still contains TODO items"

# ADR-0002: AGENTS.md is canonical, CLAUDE.md must be a symlink to it.
# WARN, never FAIL: pre-commit runs this script, so a FAIL here blocks every
# commit in the repo until a human merges two real context files — an
# editorial decision that must not hold the working tree hostage (ADR-0015).
if [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
  echo "WARN: AGENTS.md and CLAUDE.md both exist as separate files (ADR-0002: CLAUDE.md must be a symlink to AGENTS.md)"
  echo "next: pick the canonical file (usually the larger, real one), merge any missing content from the other into it, git rm the other, then: ln -s AGENTS.md CLAUDE.md"
elif [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" != "AGENTS.md" ]; then
  echo "WARN: CLAUDE.md is a symlink but does not point to AGENTS.md (ADR-0002) — points to $(readlink CLAUDE.md)"
fi

# openspec-pin: this pin is independent of install.sh's on purpose — the
# script runs standalone inside the target repo (pre-commit and manual runs,
# no server CI — ADR-0023), with no sdd-kit checkout around. Bump both.
if [ -d openspec ]; then
  command -v node >/dev/null || fail "node not found in PATH" "install Node >= 20 (nvm install 20) — openspec validate runs via npx"
  node -e 'process.exit(parseInt(process.versions.node) >= 20 ? 0 : 1)' || fail "openspec needs Node >= 20, found $(node -v) at $(command -v node)" "use Node >= 20 in THIS environment (nvm use 20); if the commit came from an IDE, fix the IDE's PATH/terminal and restart it"
  npx -y @fission-ai/openspec@1.7.0 validate --all --strict || { echo "next: fix the specs listed above, then re-run scripts/sdd/check.sh"; exit 1; }
else
  fail "openspec/ directory is missing" "run sdd-kit/install.sh --repo-only on this repo"
fi

# spec-lint is ADVISORY here: it exits 0 unless SPEC_LINT_STRICT=1, so its
# output is a report, not a gate. Its findings are printed, never swallowed.
# TODO: set SPEC_LINT_STRICT=1 locally (there is no server CI to flip this
# in, ADR-0023) once the specs stabilize — then this becomes a real gate
# and the summary line below must say so.
if [ -f .claude/scripts/spec-lint.py ]; then
  python3 .claude/scripts/spec-lint.py || exit 1   # non-zero only with SPEC_LINT_STRICT=1
fi

echo "sdd-check: OK — gates passed (AGENTS.md, openspec validate); agent-context symlink and spec-lint are advisory"
