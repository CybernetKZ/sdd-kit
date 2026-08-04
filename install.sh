#!/usr/bin/env bash
# SDD installer — one entry point for both halves of the setup:
#
#   1. REPO section    SDD assets in a repository: openspec, AGENTS.md, local
#                      gates, hooks, agents, skills, pre-commit. Idempotent:
#                      never overwrites existing files, only adds what is missing.
#                      No CI workflows: ADR-0023 §5 retired server-side gates.
#   2. MACHINE section the central spec store (clone at a fixed path + register)
#                      and per-developer tools (ponytail, rtk, graphify,
#                      ast-grep, and the opt-in ones). Touches no repository.
#
# Usage:
#   sdd-kit/install.sh [/path/to/repo]              both sections (repo first)
#   sdd-kit/install.sh --repo-only [/path/to/repo]  repo assets only
#   sdd-kit/install.sh --machine-only               developer tools only
#   sdd-kit/install.sh --refresh [/path/to/repo]    update the kit-owned files
#
# --refresh re-copies ONLY the kit-owned manifest (hooks, agents, skills,
# scripts, scripts/sdd/*, pre-commit) when the target drifted from
# the template, and reports a per-file (+added/-removed) summary. Repo-owned
# files (AGENTS.md, .spec-guard-paths, .claude/expected-env,
# ruff.toml, openspec/**, .mcp.json, .claude/settings.json) are never touched
# wholesale. The one exception: .claude/settings.json's `hooks` block is
# additively merged (merge_settings_hooks(), both on install and --refresh) —
# any kit hook copied into .claude/hooks/ that is not yet referenced gets
# wired in; a repo's own hook entries (e.g. pretooluse_guard.py) are never
# removed, reordered, or replaced.
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
# scripts/sdd/{check,test}.sh + pre-commit and PreToolUse hooks — all local
# (ADR-0023 §5: there are no server-side gates).
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"

# openspec CLI, single source of the pin for this script: always the pinned npx
# version, never an unpinned global `openspec` binary (a global install can
# drift ahead of this script's tested version and silently change generator
# output - P0-1). The other pin lives in templates/scripts/sdd/check.sh, which
# runs standalone inside target repos.
# openspec-pin
OPENSPEC="npx -y @fission-ai/openspec@1.7.0"

# Central spec store (ADR-0001, ADR-0023 §1): ONE clone per machine at a fixed
# path, registered in openspec's machine-level registry. Override per machine/org.
STORE_ID="${SDD_STORE_ID:-cybernet-specs}"
STORE_DIR="${SDD_STORE_DIR:-$HOME/cybernet/cybernet-specs}"
STORE_GIT="${SDD_STORE_GIT:-https://github.com/octrow/cybernet-specs.git}"

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
      sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'
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

# ------------------------------------------------------- central spec store --
# store_registered_at <path> — true when STORE_ID is registered at exactly <path>.
store_registered_at() {
  $OPENSPEC store list 2>/dev/null \
    | awk -v id="$STORE_ID" -v p="$1" '$1 == id { sub(/^[^ \t]+[ \t]+/, ""); if ($0 == p) print "yes" }' \
    | grep -q '^yes$'
}

# ensure_store — ADR-0023 §1: the store is a plain clone at a fixed machine
# path, registered once. Not a submodule and not a per-repo copy: openspec's
# registry maps one id to ONE path per machine, so extra checkouts are read by
# nothing and silently drift.
#
# Idempotent by construction:
#   - an existing git clone is REUSED, never re-cloned and never pulled behind
#     the developer's back ("no sync, ever" is the store's design — freshness is
#     a deliberate `git pull`); we only report how old its last commit is.
#   - `openspec store register` on an already-registered id+path is a no-op that
#     prints "Registry: already registered" and exits 0 (verified against the
#     pinned CLI 1.7.0), and `--id` is passed explicitly so the id never gets
#     inferred from a folder name. We still check `store list` first, so the
#     common case prints one honest "already registered" line and costs nothing.
ensure_store() {
  if [ -d "$STORE_DIR/.git" ]; then
    say "exists:  $STORE_DIR (last commit $(git -C "$STORE_DIR" log -1 --format='%cr' 2>/dev/null || echo '?') — refresh when needed: git -C $STORE_DIR pull)"
  elif [ -e "$STORE_DIR" ]; then
    warn "$STORE_DIR exists but is not a git clone — move it aside and re-run, or set SDD_STORE_DIR"
    return 0
  elif ask_install "Clone the central spec store to $STORE_DIR?" y \
       "git clone $STORE_GIT $STORE_DIR"; then
    mkdir -p "$(dirname "$STORE_DIR")"
    if git clone "$STORE_GIT" "$STORE_DIR"; then
      say "cloned:  $STORE_DIR"
    else
      warn "clone failed: $STORE_GIT — register the store later: $OPENSPEC store register $STORE_DIR --id $STORE_ID"
      return 0
    fi
  else
    return 0
  fi

  if store_registered_at "$STORE_DIR"; then
    say "ok:      store '$STORE_ID' already registered at $STORE_DIR"
  elif $OPENSPEC store register "$STORE_DIR" --id "$STORE_ID"; then
    say "registered: store '$STORE_ID' from $STORE_DIR"
  else
    warn "could not register store '$STORE_ID' — do it later: $OPENSPEC store register $STORE_DIR --id $STORE_ID"
  fi
}

put() { # put <template> <destination> — copies only when the destination is missing
  if [ -e "$2" ]; then say "exists:  $2 (left alone)"; else
    mkdir -p "$(dirname "$2")"; cp "$KIT/templates/$1" "$2"; say "created: $2"; fi
}

# ---------------------------------------------------------- openspec skill stamp
# ADR-0020 §8: `.claude/skills/openspec-*/SKILL.md` are vendor-generated by
# `openspec init`/`openspec update` (or restored verbatim from a git seed ref) —
# without `disable-model-invocation: true` in their frontmatter they autotrigger
# and let the model jump straight into openspec/changes/, skipping feature-flow's
# intake -> tier -> grill -> RED-tests gate. Checked against the pinned CLI
# (@fission-ai/openspec, see $OPENSPEC): its own skill templates do NOT emit this
# field, so nothing upstream protects it — we own the stamp.
#
# stamp_openspec_skill_flag <path to one SKILL.md> — bash 3.2-safe, no GNU sed -i.
stamp_openspec_skill_flag() {
  local f="$1" tmp
  [ -f "$f" ] || return 0

  if [ "$(sed -n '1p' "$f")" != "---" ]; then
    warn "left alone: $f (no YAML frontmatter — not stamping disable-model-invocation)"
    return 0
  fi
  if ! awk 'NR>1 && /^---$/ { found=1; exit } END { exit !found }' "$f"; then
    warn "left alone: $f (frontmatter has no closing ---, not stamping)"
    return 0
  fi

  # Owner already said `false` explicitly — that's a deliberate override, not
  # vendor noise. Never clobber it silently.
  if awk 'NR==1 { next } /^---$/ { exit } /^disable-model-invocation:[[:space:]]*false[[:space:]]*$/ { f=1 } END { exit !f }' "$f"; then
    warn "left alone: $f (disable-model-invocation: false — explicit owner override)"
    return 0
  fi
  if awk 'NR==1 { next } /^---$/ { exit } /^disable-model-invocation:[[:space:]]*true[[:space:]]*$/ { f=1 } END { exit !f }' "$f"; then
    say "ok:      $f already has disable-model-invocation: true"
    return 0
  fi

  tmp="$(mktemp "${f}.XXXXXX")" || { warn "mktemp failed for $f — not stamping"; return 0; }
  awk '
    NR==1 { print; next }
    !done && /^---$/ { print "disable-model-invocation: true"; print; done=1; next }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
  say "stamped: $f (disable-model-invocation: true)"
}

# stamp_openspec_skills — sweep every openspec-* skill in the repo, whatever
# produced it (fresh `openspec init`, seed-ref restore, or a prior run).
stamp_openspec_skills() {
  local f
  for f in .claude/skills/openspec-*/SKILL.md; do
    [ -e "$f" ] || continue
    stamp_openspec_skill_flag "$f"
  done
}

# ensure_openspec_claude_tooling — (re)generate the .claude/skills/openspec-*
# and .claude/commands/opsx/* Claude Code tooling for an openspec/ that
# already exists (seed-restored, or "left alone" because it predated the kit)
# but may be missing that tooling entirely.
#
# `openspec init --tools claude` unconditionally rewrites every skill/command
# file ("Refreshed: Claude Code") even when nothing changed — verified against
# the pinned CLI (@fission-ai/openspec 1.7.0): re-running it on an already-
# tooled repo wipes hand-edits (e.g. our own disable-model-invocation stamp).
# `openspec update` is the idempotent, version-aware counterpart: a no-op when
# already current, and it restores only what is missing — but it detects
# "configured" by the presence of a prior tooling file and otherwise prints
# "No configured tools found" and does nothing. So: use `update` whenever any
# tooling marker already exists (repairs partial/missing skills without
# touching the rest), and fall back to `init --tools claude` only when there
# is no marker at all (first time — nothing to preserve, safe to create).
# Neither command touches openspec/specs, openspec/changes, or config.yaml
# content (checked empirically in the sandbox before writing this).
ensure_openspec_claude_tooling() {
  if { [ -d .claude/skills ] && ls -d .claude/skills/openspec-* >/dev/null 2>&1; } \
     || [ -d .claude/commands/opsx ]; then
    say "syncing OpenSpec Claude Code tooling (openspec update)..."
    $OPENSPEC update
  else
    say "generating OpenSpec Claude Code tooling (openspec init --tools claude)..."
    $OPENSPEC init --tools claude
  fi
  strip_opsx_commands
}

# strip_opsx_commands — ADR-0020 §8: the openspec-* skills are the only
# supported entry point; the /opsx:* slash commands duplicate them and bypass
# the disable-model-invocation stamp's intent (they are not skills, so the
# stamp does not apply to them). `openspec init --tools claude` and `openspec
# update` both write .claude/commands/opsx/*.md unconditionally alongside the
# skills (checked empirically) — delete that directory right after every
# generation/sync call, but never touch anything else a repo may keep under
# .claude/commands/: only opsx/ is ours, and the parent is removed too only
# if stripping opsx/ left it empty.
strip_opsx_commands() {
  [ -d .claude/commands/opsx ] || return 0
  rm -rf .claude/commands/opsx
  say "removed: .claude/commands/opsx (ADR-0020 §8 — openspec-* skills cover this, not slash commands)"
  if [ -d .claude/commands ] && [ -z "$(find .claude/commands -mindepth 1 -print -quit 2>/dev/null)" ]; then
    rmdir .claude/commands
    say "removed: .claude/commands (now empty)"
  fi
}

# ------------------------------------------------------------- kit manifest --
# The kit-owned files: ONE source of truth, used by both the install pass
# (put(), never overwrites) and `--refresh` (overwrites what drifted).
# Format per line: "<path under templates/> <destination relative to the repo>".
#
# Deliberately NOT here — repo-owned, never overwritten by --refresh:
#   AGENTS.md, CLAUDE.md, .spec-guard-paths,
#   .claude/expected-env, ruff.toml, openspec/**, .mcp.json,
#   .claude/settings.json (never wholesale-rewritten; its `hooks` block is
#   additively merged by merge_settings_hooks() — see that function for why:
#   the kit hooks it copies into .claude/hooks/ are useless if nothing in
#   settings.json invokes them, so wiring them in is part of installing them,
#   not a repo-owned decision; existing hook entries are never touched).
#
# Deliberately NOT here either — ADR-0023 §5 / ADR-0026 §5 retired server-side
# gates: the sdd-ci.yml / autoreview.yml / store-ci.yml workflows are no longer
# installed anywhere. Every gate is local now (pre-commit, spec-guard,
# block-no-verify, scripts/sdd/{check,test,review}.sh).
#
# .git/hooks/pre-commit is listed but never copied verbatim: it is written by
# assemble_pre_commit(), so both loops special-case it.
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
agents/executor.md .claude/agents/executor.md
agents/repo-auditor.md .claude/agents/repo-auditor.md
skills/feature-flow/SKILL.md .claude/skills/feature-flow/SKILL.md
skills/feature-flow/references/details.md .claude/skills/feature-flow/references/details.md
skills/incident-flow/SKILL.md .claude/skills/incident-flow/SKILL.md
skills/grilling/SKILL.md .claude/skills/grilling/SKILL.md
skills/grill-me/SKILL.md .claude/skills/grill-me/SKILL.md
skills/grill-with-docs/SKILL.md .claude/skills/grill-with-docs/SKILL.md
skills/domain-modeling/SKILL.md .claude/skills/domain-modeling/SKILL.md
skills/domain-modeling/CONTEXT-FORMAT.md .claude/skills/domain-modeling/CONTEXT-FORMAT.md
skills/domain-modeling/ADR-FORMAT.md .claude/skills/domain-modeling/ADR-FORMAT.md
spec-lint.py .claude/scripts/spec-lint.py
sdd-doctor.sh .claude/scripts/sdd-doctor.sh
review-prompt.md .claude/scripts/review-prompt.md
scripts/sdd/check.sh scripts/sdd/check.sh
scripts/sdd/test.sh scripts/sdd/test.sh
scripts/sdd/review.sh scripts/sdd/review.sh
scripts/sdd/index.sh scripts/sdd/index.sh
scripts/sdd/doctor.sh scripts/sdd/doctor.sh
pre-commit-hook.sh .git/hooks/pre-commit
EOF
}

# assemble_pre_commit <destination> — writes the pre-commit hook. (The old
# LIVING SPEC splice is gone, ADR-0026 §4: doc drift is checked on demand via
# tools/cf/main-drift.sh, not warned about at commit time.)
assemble_pre_commit() {
  local dst="$1"
  cp "$KIT/templates/pre-commit-hook.sh" "$dst"
  chmod +x "$dst"
}

# merge_settings_hooks <destination settings.json> — additively wires any kit
# hook (block-no-verify.cjs, spec-guard.cjs, pre-compact.cjs) that install.sh
# already copied into .claude/hooks/ but that is not yet referenced anywhere
# in the destination's `hooks` object. Two callers: the install pass (after
# `put settings.json`, since a pre-existing settings.json is left alone by
# put() and may predate the kit) and `--refresh` (refresh_settings_hooks()).
#
# Why additive-merge instead of "detect and warn": the warn-only path (the
# old refresh_settings_hooks()) left the three kit hooks on disk but
# unreachable — files present, protection off, and only --refresh users ever
# saw the warning. Wiring them in immediately means the hooks that were just
# installed actually run, with zero new manual steps.
#
# Safety, so this never becomes the thing it was written to prevent:
#   - only ADDS hook entries; an existing command string anywhere in the
#     destination's hooks tree is left exactly where it is — never removed,
#     reordered, or replaced. A repo's own hook (e.g. pretooluse_guard.py in
#     conversation_flow) always survives untouched.
#   - idempotent: a kit hook command already present (from a prior run, or a
#     repo that wired it by hand) is skipped, so re-running adds nothing new.
#   - atomic write (tmp file + `os.replace`), so a crash mid-write cannot
#     leave a half-written settings.json.
#   - json.load/json.dump (python3), never sed/awk on JSON.
#   - a destination that isn't valid JSON is left untouched and reported —
#     never blindly overwritten.
merge_settings_hooks() {
  local dst="$1" out
  [ -f "$dst" ] || return 0
  out="$(python3 - "$KIT/templates/settings.json" "$dst" <<'PY'
import json, os, sys

kit_path, dst_path = sys.argv[1], sys.argv[2]

with open(kit_path) as f:
    kit = json.load(f)
try:
    with open(dst_path) as f:
        dst = json.load(f)
except Exception as exc:
    print(f"UNREADABLE:{exc}")
    sys.exit(0)

if not isinstance(dst.get("hooks"), dict):
    dst["hooks"] = {}

def command_set(groups):
    cmds = set()
    for g in groups:
        for h in g.get("hooks", []):
            c = h.get("command")
            if c:
                cmds.add(c)
    return cmds

added = []
for event, kit_groups in kit.get("hooks", {}).items():
    dst_groups = dst["hooks"].setdefault(event, [])
    existing = command_set(dst_groups)
    for kg in kit_groups:
        matcher = kg.get("matcher")
        for h in kg.get("hooks", []):
            cmd = h.get("command")
            if not cmd or cmd in existing:
                continue
            target = next((g for g in dst_groups if g.get("matcher") == matcher), None)
            if target is None:
                target = {"matcher": matcher, "hooks": []} if matcher is not None else {"hooks": []}
                dst_groups.append(target)
            target.setdefault("hooks", []).append(h)
            existing.add(cmd)
            label = event + (f"/{matcher}" if matcher else "")
            added.append(f"{label}: {cmd}")

if added:
    tmp = dst_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(dst, f, indent=2)
        f.write("\n")
    os.replace(tmp, dst_path)
    for line in added:
        print(f"ADDED:{line}")
PY
)"
  case "$out" in
    *UNREADABLE:*)
      warn "$dst is not valid JSON — could not check/wire kit hooks; fix it manually, then re-run"
      return 0 ;;
  esac
  if [ -z "$out" ]; then
    say "ok:      $dst — kit hooks already wired"
  else
    while IFS= read -r line; do
      case "$line" in
        ADDED:*) say "wired:   $dst — ${line#ADDED:}" ;;
      esac
    done <<EOF
$out
EOF
  fi
}

# load_profile <repo-basename> — resets the PROFILE_* globals to their defaults
# and then sources profiles/<repo-basename>.env if it exists. Shared by the
# install pass and --refresh (which needs PROFILE_IS_STORE).
load_profile() {
  PROFILE_STORE=1            # 1 = wire this repo to the central spec store (default)
  PROFILE_IS_STORE=0         # 1 = this repo IS the store (minimal install)
  PROFILE_SKIP_PY=0          # 1 = not a Python repo (no ruff.toml)
  PROFILE_SPEC_GUARD_PATHS=""
  PROFILE_ENV_FILES=""       # newline-separated per-service .env paths sdd-doctor should check exist
  PROFILE_OPENSPEC_SEED_REF="" # git ref holding openspec/; restored instead of `openspec init` when openspec/ is empty
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

  # ------------------------------------------------------------ 0. dependencies
  [ -d .git ] || fail "$REPO is not a git repository"
  command -v git >/dev/null 2>&1 || fail "git not found. Install git and re-run."
  if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
    fail "node/npx not found. Install Node.js 20+ from https://nodejs.org or via nvm:
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && nvm install 22"
  fi

  say "using pinned openspec CLI: @fission-ai/openspec@1.7.0 (via npx)"

  # The store repo needs only itself: local registration + validate gate.
  if [ "$PROFILE_IS_STORE" = 1 ]; then
    if ! $OPENSPEC store list 2>/dev/null | grep -q "^${STORE_ID}[[:space:]]"; then
      $OPENSPEC store register "$REPO" --id "$STORE_ID"
      say "registered: this repo as store '$STORE_ID'"
    else
      say "ok:      store '$STORE_ID' already registered on this machine"
    fi
    # ADR-0026 §5: no CI, no exceptions — the store validates locally at commit
    # time via a minimal pre-commit hook (was store-ci.yml on every PR).
    if [ -e .git/hooks/pre-commit ]; then
      grep -q "openspec" .git/hooks/pre-commit \
        && say "exists:  .git/hooks/pre-commit (already validates specs)" \
        || warn ".git/hooks/pre-commit exists without openspec validate — add '$OPENSPEC validate --all --strict' to it manually"
    else
      printf '#!/bin/sh\n# sdd-kit store pre-commit: the only gate (no CI, ADR-0026 §5)\nnpx -y @fission-ai/openspec@1.7.0 validate --all --strict\n' > .git/hooks/pre-commit
      chmod +x .git/hooks/pre-commit
      say "created: .git/hooks/pre-commit (openspec validate --all --strict)"
    fi
    say "done (store profile). Gate: openspec validate --all --strict runs at commit time."
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
  if [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then
    # ADR-0002 violation: AGENTS.md and CLAUDE.md exist as two separate real
    # files. Which one is canonical (and what to carry over from the other)
    # is a human decision — the installer must not guess-merge them. Staying
    # silent here is worse than the noise: it would leave a real project
    # context (often the pre-existing CLAUDE.md) diverging from an AGENTS.md
    # scaffold, exactly the drift ADR-0002 exists to prevent.
    AGENTS_LINES=$(wc -l < AGENTS.md | tr -d ' ')
    CLAUDE_LINES=$(wc -l < CLAUDE.md | tr -d ' ')
    warn "AGENTS.md ($AGENTS_LINES lines) and CLAUDE.md ($CLAUDE_LINES lines) exist as two separate files — ADR-0002 requires CLAUDE.md to be a symlink to AGENTS.md. Not auto-merging: picking the canonical file is a human decision."
    if [ "$CLAUDE_LINES" -gt "$AGENTS_LINES" ]; then
      say "next: CLAUDE.md is larger — it is likely the real project context and AGENTS.md an unfilled scaffold. Move CLAUDE.md's content into AGENTS.md, then: git rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
    else
      say "next: review both files, merge whichever holds the real content into AGENTS.md (the canonical file), then: git rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
    fi
  elif [ ! -e CLAUDE.md ]; then
    ln -s AGENTS.md CLAUDE.md; say "created: CLAUDE.md -> AGENTS.md"
  fi

  # ----------------------------------------------------------------- 4. OpenSpec
  # B4 (ADR-0019): empty dirs (0 files) count as missing — a bare openspec/ skeleton
  # must not block init forever.
  if [ ! -d openspec ] || [ -z "$(find openspec -type f -print -quit 2>/dev/null)" ]; then
    # ponytail: seed from a git ref, not a vendored copy — the specs already live in
    # the repo's own history, so there is nothing to keep in sync here.
    local SEED_REF=""
    for r in "origin/$PROFILE_OPENSPEC_SEED_REF" "$PROFILE_OPENSPEC_SEED_REF"; do
      [ -n "$PROFILE_OPENSPEC_SEED_REF" ] || break
      if [ -n "$(git ls-tree -r --name-only "$r" -- openspec 2>/dev/null | head -1)" ]; then SEED_REF="$r"; break; fi
    done
    # Declining is a deliberate "scaffold an empty skeleton" — not the missing-ref
    # error below, so clear the profile ref along with SEED_REF.
    if [ -n "$SEED_REF" ] \
       && ! ask "restore openspec/ ($(git ls-tree -r --name-only "$SEED_REF" -- openspec | wc -l | tr -d ' ') files) from $SEED_REF?" y; then
      SEED_REF=""; PROFILE_OPENSPEC_SEED_REF=""
    fi
    if [ -n "$SEED_REF" ]; then
      git checkout "$SEED_REF" -- openspec
      # Symmetry with the rest of the install (everything else lands
      # untracked): unstage so `git status` reads the
      # same way everywhere and a stray `git commit` right after install
      # doesn't silently pick up only openspec/ while leaving the rest of
      # the install for later. Restricted to the openspec pathspec, so any
      # unrelated staged content the caller already had stays untouched.
      git reset -- openspec >/dev/null 2>&1 || true
      say "restored: openspec/ from $SEED_REF ($(find openspec -type f | wc -l | tr -d ' ') files, untracked — review and commit)"
      # The seed ref carries openspec/ content only — the vendor-generated
      # .claude/skills/openspec-* tooling never lived on that branch, so it
      # must be (re)generated here or the repo ends up with a seeded
      # openspec/ and zero openspec skills.
      ensure_openspec_claude_tooling
      # B5: the seed ref is a fixed historical snapshot — it has no idea what
      # landed on HEAD since it was cut. Checking `is-ancestor SEED_REF HEAD`
      # alone is not enough: it also fails (correctly, but for the WRONG
      # reason) when the seed branch has simply moved ahead of HEAD and
      # already contains every HEAD commit — that case is not stale. The
      # actual defect is commits that exist on HEAD but were never seen by
      # the seed, so count those directly.
      BEHIND_COUNT=$(git rev-list --count "$SEED_REF..HEAD" 2>/dev/null || echo '?')
      if [ "$BEHIND_COUNT" != 0 ]; then
        warn "openspec/ seed '$SEED_REF' has not seen $BEHIND_COUNT commit(s) that are on HEAD — restored specs/changes may be stale or already implemented"
        say "next: re-run spec-lint for freshness and review openspec/changes/* (not archive/) against HEAD — archive any change whose work already landed"
        CHANGE_CANDIDATES=""
        for d in openspec/changes/*/; do
          [ -d "$d" ] || continue
          cname=$(basename "$d")
          [ "$cname" = archive ] && continue
          tzid=$(printf '%s' "$cname" | grep -oE '^tz-[0-9]+' | head -1)
          [ -n "$tzid" ] || continue
          if git log --oneline "$SEED_REF..HEAD" 2>/dev/null | grep -qi "$tzid"; then
            CHANGE_CANDIDATES="$CHANGE_CANDIDATES $cname"
          fi
        done
        [ -n "$CHANGE_CANDIDATES" ] && say "next: candidates already touched on HEAD (each change's tz-NNN appears in git log $SEED_REF..HEAD, verify before archiving):$CHANGE_CANDIDATES"
      fi
    elif [ -n "$PROFILE_OPENSPEC_SEED_REF" ]; then
      # A profile that names a seed ref HAS specs to restore. Falling through to an
      # empty init here swaps hundreds of Requirements for a skeleton that passes
      # `openspec validate` trivially — the failure has to be loud, not a warning.
      # Happens for real when the seed branch is merged+deleted, or on a shallow
      # single-branch CI clone that never fetched it.
      warn "shallow CI clone? try: git fetch origin '$PROFILE_OPENSPEC_SEED_REF'"
      warn "ref gone for good? point PROFILE_OPENSPEC_SEED_REF at the branch that carries"
      warn "openspec/, or drop it from the profile to scaffold an empty skeleton on purpose."
      fail "openspec seed ref '$PROFILE_OPENSPEC_SEED_REF' not found (or has no openspec/)"
    else
      say "initializing OpenSpec (--tools claude)..."
      $OPENSPEC init --tools claude
      strip_opsx_commands
    fi
  else
    say "exists:  openspec/ (left alone)"
    # A pre-existing openspec/ (predates the kit, or came from a migration
    # branch) is not proof the Claude tooling was ever generated for it —
    # repair/generate it the same way the seed-restore path does.
    ensure_openspec_claude_tooling
  fi

  # -------------------------------- 4a. stamp disable-model-invocation (ADR-0020 §8)
  # Runs unconditionally after the block above, regardless of which branch fired:
  # covers skills freshly written by `openspec init`, skills that already existed
  # (openspec/ left alone), and — belt and suspenders — a seed-ref restore, which
  # only checks out openspec/ but may leave pre-existing skill files in place.
  stamp_openspec_skills

  # ----------------------------------------- 4b. central spec store (PROFILE_STORE)
  local CFG
  if [ "$PROFILE_STORE" = 1 ]; then
    # Same clone+register step the machine section runs (ADR-0023 §1) — the repo
    # itself only needs the `references:` line below.
    ensure_store
    CFG=openspec/config.yaml
    if [ -f "$CFG" ] && ! grep -q '^references:' "$CFG"; then
      printf '\n# Central contract store (ADR-0001), registered via `openspec store register`\nreferences:\n  - %s\n' "$STORE_ID" >> "$CFG"
      say "appended: references: $STORE_ID to $CFG"
    fi
  fi

  # ---------------------------------- 5. kit-owned files (the manifest, once)
  # Hooks, agents, skills, scripts (incl. scripts/sdd/). Same list that
  # `--refresh` re-copies later; .git/hooks/pre-commit is assembled in 8b.
  local m_src m_dst
  while read -r m_src m_dst; do
    [ -n "$m_src" ] || continue
    [ "$m_dst" = "$KIT_PRE_COMMIT_DST" ] && continue
    put "$m_src" "$m_dst"
  done <<EOF
$(kit_manifest)
EOF

  # 5a. Makefile: gone (ADR-0026 §3) — the command surface is scripts/sdd/*.sh,
  # copied by the manifest above; nothing is appended to the repo's Makefile.
  if [ -f Makefile ] && grep -q "Makefile.sdd" Makefile; then
    warn "Makefile still includes Makefile.sdd (retired, ADR-0026 §3) — remove the '-include Makefile.sdd' line and delete Makefile.sdd"
  fi

  # --------------------------------- 6b. ruff config (only when none exists)
  if [ "$PROFILE_SKIP_PY" = 1 ]; then
    say "skipped: ruff.toml (profile: not a Python repo)"
  elif [ -e ruff.toml ] || [ -e .ruff.toml ] \
     || grep -rls --include=pyproject.toml '^\[tool\.ruff' . >/dev/null 2>&1; then
    say "exists:  ruff config (repo's own — left alone)"
  else
    put ruff.toml ruff.toml
  fi

  # ----- 7. Claude Code settings (NOT in the manifest: repos add own hooks).
  #          A brand-new settings.json is the kit template verbatim (nothing
  #          to merge). A pre-existing one is left alone by put() — but the
  #          kit hooks just copied into .claude/hooks/ in step 5 are dead
  #          unless something in settings.json invokes them, so wire in
  #          whichever ones are missing (additive, never touches the rest).
  put settings.json .claude/settings.json
  merge_settings_hooks .claude/settings.json

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
      warn "$PRE_COMMIT exists without sdd-check — add 'bash scripts/sdd/check.sh' to it manually (template: $KIT/templates/pre-commit-hook.sh)"
    fi
  else
    assemble_pre_commit "$PRE_COMMIT"
    say "created: $PRE_COMMIT (hygiene checks + scripts/sdd/check.sh before every commit)"
  fi

  # ------------------- 8c. graph is a committed team artifact (ADR-0023 §3)
  # graphify-out/graph.json is built once per team and committed; drop the
  # exclude entry older installs wrote so the graph can actually be tracked.
  if grep -qx "graphify-out/" .git/info/exclude 2>/dev/null; then
    sed -i '\|^graphify-out/$|d' .git/info/exclude
    say "removed: stale .git/info/exclude entry graphify-out/ (the graph is committed now, ADR-0023)"
  fi

  # ----------------- 8d. build/update the code graph (consent, default yes)
  # One command installs everything: if graphify is on the machine, build the
  # graph now (AST path needs no key) or incrementally update a stale one.
  # A first-time SEMANTIC build (docs) still needs an LLM key or an interactive
  # /graphify session — 'scripts/sdd/index.sh' prints that guidance itself. Advisory.
  if command -v graphify >/dev/null 2>&1; then
    if [ -f graphify-out/graph.json ]; then
      if ask "Update the code graph (graphify-out/, AST-only, no key)?" y; then
        bash scripts/sdd/index.sh || true
      fi
    elif ask "Build the code graph now (graphify-out/ is missing)?" y; then
      bash scripts/sdd/index.sh || true
    fi
  else
    say "skipped: code graph (graphify not installed — run install.sh --machine-only)"
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
  say "  2) every gate is local (ADR-0023 §5 — no CI workflows are installed):"
  say "     the pre-commit hook runs scripts/sdd/check.sh; run scripts/sdd/test.sh"
  say "     and scripts/sdd/review.sh yourself before opening a PR"
  say "  3) seed the specs: run the spec-miner agent one capability at a time"
  say "  3b) code graph: the install step above builds/updates it when it can;"
  say "      a FIRST build over docs needs semantic extraction — on a Claude"
  say "      subscription run the interactive '/graphify' command once, then"
  say "      install/refresh keeps it updated with no key (AST-only)"
  say "  4) AI review runs locally: 'scripts/sdd/review.sh' (your own subscription login;"
  say "     tokens are per-developer — nothing to configure server-side)"
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

# .claude/settings.json is never wholesale-rewritten: a repo may have added
# its own hooks (pretooluse_guard.py in conversation_flow). Delegates to the
# same merge_settings_hooks() the install pass uses, so a repo that installed
# before this existed (or drifted since) gets caught up on --refresh too.
refresh_settings_hooks() {
  [ -f .claude/settings.json ] || { say "missing:   .claude/settings.json (run install.sh --repo-only)"; return 0; }
  merge_settings_hooks .claude/settings.json
}

# .git/hooks/pre-commit: a hand-merged hook (repo's own checks) is never
# overwritten.
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
    # ADR-0026 §5: nothing kit-owned lives in the store repo anymore (the
    # pre-commit validate hook is written once by the install pass).
    if [ -f .github/workflows/store-ci.yml ]; then
      warn "store-ci.yml is retired (ADR-0026 §5) — delete .github/workflows/store-ci.yml; the gate is the local pre-commit hook"
    fi
    say "refresh done (store profile): nothing to refresh"
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

  # ADR-0020 §8: re-stamp on every refresh too — `.claude/skills/openspec-*` is
  # NOT under openspec/ (that tree is repo-owned and refresh never touches it),
  # and a plain `openspec update` between refreshes regenerates those SKILL.md
  # files without the flag. Idempotent, and never overwrites an explicit
  # `disable-model-invocation: false`, so it is safe to run unconditionally.
  stamp_openspec_skills

  # same as install step 8c: the graph is committed now (ADR-0023), drop the
  # exclude entry older installs wrote
  if grep -qx "graphify-out/" .git/info/exclude 2>/dev/null; then
    sed -i '\|^graphify-out/$|d' .git/info/exclude
    say "removed: stale .git/info/exclude entry graphify-out/ (committed artifact, ADR-0023)"
  fi

  if [ "$REFRESHED" = 0 ]; then
    say "refresh done: 0 files refreshed (everything already matches the kit)"
  else
    say "refresh done: $REFRESHED file(s) refreshed — review with git diff before committing"
  fi

  # Keep the committed graph fresh on the same command (ADR-0025 §1): an
  # existing graph updates incrementally via AST, no key needed. Advisory.
  if command -v graphify >/dev/null 2>&1 && [ -f graphify-out/graph.json ]; then
    if ask "Update the code graph (graphify-out/, AST-only, no key)?" y; then
      bash scripts/sdd/index.sh || true
    fi
  fi
}

# =========================================================== MACHINE SECTION ==
# Per-DEVELOPER tools (machine-level, run once). Nothing here touches a repo.
# CORE tools (quality up, token spend down) default to yes; the rest opt-in.
machine_section() {
  local DONE=0 SKIPPED=0

  # ------------------------------------------------------ 0. central spec store
  # ADR-0023 §1: the store registry is machine-level, so cloning+registering it
  # belongs here, not in every repo. Runs before the tools prompt on purpose —
  # declining the optional tooling must not skip the store the specs live in.
  ensure_store

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

  # ------------------------------------------------------------------ 4a. ruff
  # The pre-commit hook and scripts/sdd/test.sh lean on ruff; uvx works as a slower
  # fallback, a native install is what the doctor recommends.
  if command -v ruff >/dev/null 2>&1; then
    say "ok:      ruff already installed"
  elif ask_install "Install ruff? (linter/formatter used by the pre-commit hook and scripts/sdd/test.sh)" y \
       "uv tool install ruff"; then
    uv tool install ruff \
      && { DONE=$((DONE+1)); say "installed: ruff"; } \
      || say "ruff install failed — pre-commit falls back to 'uvx ruff'"
  else SKIPPED=$((SKIPPED+1)); fi

  # ----------------------------------------- 4b. static review tools (leads)
  # radon/complexipy/vulture/semgrep feed 'scripts/sdd/review.sh' with static leads
  # (/tmp/tools.txt); the reviewer verifies each lead in code before reporting.
  if command -v radon >/dev/null 2>&1 && command -v complexipy >/dev/null 2>&1 \
     && command -v vulture >/dev/null 2>&1 && command -v semgrep >/dev/null 2>&1; then
    say "ok:      static review tools already installed (radon, complexipy, vulture, semgrep)"
  elif ask_install "Install static review tools? (radon, complexipy, vulture, semgrep — leads for scripts/sdd/review.sh)" y \
       "uv tool install radon && uv tool install complexipy && uv tool install vulture && uv tool install semgrep"; then
    for t in radon complexipy vulture semgrep; do
      command -v "$t" >/dev/null 2>&1 || uv tool install "$t" \
        || say "$t install failed — sdd-review works without it (fewer leads)"
    done
    DONE=$((DONE+1)); say "installed: static review tools"
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
