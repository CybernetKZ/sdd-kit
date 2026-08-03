#!/usr/bin/env bash
# sdd-doctor: checks that the machine + repo have everything SDD work needs,
# plus an `audit` section for agent-tooling clutter (merged from repo-audit.sh).
# Advisory: exits 1 only when a REQUIRED tool is missing. Installed by sdd-kit.
#
# Finding format (ADR-0008, ported from ProjectStore's doctor): every check
# emits {level, group, code, message, next} where `next` is the exact fix
# command. Human output by default; `--json` prints the findings as JSON.
set -u

JSON=0; [ "${1:-}" = "--json" ] && JSON=1
FINDINGS="$(mktemp)"; trap 'rm -f "$FINDINGS"' EXIT
PASS=0; WARN=0; FAIL=0; INFO=0
GROUP="machine"

# emit <level> <code> <message> [next]
emit() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$GROUP" "$2" "$3" "${4:-}" >> "$FINDINGS"
  if [ "$JSON" = 0 ]; then
    case "$1" in
      ok)   echo "  ok:   [$2] $3" ;;
      info) echo "  info: [$2] $3"; [ -n "${4:-}" ] && echo "        next: $4" ;;
      warn) echo "  WARN: [$2] $3"; [ -n "${4:-}" ] && echo "        next: $4" ;;
      fail) echo "  FAIL: [$2] $3"; [ -n "${4:-}" ] && echo "        next: $4" ;;
    esac
  fi
}
ok()   { PASS=$((PASS+1)); emit ok   "$@"; }
note() { INFO=$((INFO+1)); emit info "$@"; }
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

  if [ -f AGENTS.md ]; then
    if git check-ignore -q AGENTS.md 2>/dev/null; then
      warn repo.agents-md "AGENTS.md present but gitignored — it will never reach git/CI/teammates" \
        "remove AGENTS.md (and CLAUDE.md) from .gitignore, then commit the file"
    else
      ok repo.agents-md "AGENTS.md present"
    fi
  else
    warn repo.agents-md "AGENTS.md missing" "run sdd-kit/install.sh --repo-only $ROOT"
  fi

  # ADR-0002: CLAUDE.md must be a symlink to AGENTS.md. Only meaningful once
  # AGENTS.md exists (the branch above already reports its absence).
  if [ -f AGENTS.md ]; then
    if [ ! -e CLAUDE.md ]; then
      note repo.claude-symlink "CLAUDE.md absent (optional — some tools/OSes don't need it)" "ln -s AGENTS.md CLAUDE.md"
    elif [ -L CLAUDE.md ]; then
      CLAUDE_TARGET=$(readlink CLAUDE.md)
      if [ "$CLAUDE_TARGET" = "AGENTS.md" ]; then
        if git check-ignore -q CLAUDE.md 2>/dev/null; then
          warn repo.claude-symlink "CLAUDE.md -> AGENTS.md but gitignored — it will never reach git/CI/teammates" \
            "remove CLAUDE.md from .gitignore, then commit the symlink"
        else
          ok repo.claude-symlink "CLAUDE.md -> AGENTS.md"
        fi
      else
        warn repo.claude-symlink "CLAUDE.md is a symlink but points to '$CLAUDE_TARGET', not AGENTS.md (ADR-0002)" \
          "rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
      fi
    else
      AGENTS_LINES=$(wc -l < AGENTS.md | tr -d ' ')
      CLAUDE_LINES=$(wc -l < CLAUDE.md | tr -d ' ')
      if [ "$CLAUDE_LINES" -gt "$AGENTS_LINES" ]; then
        warn repo.claude-symlink "AGENTS.md ($AGENTS_LINES lines) and CLAUDE.md ($CLAUDE_LINES lines) are two separate files, and CLAUDE.md is the bigger one — the canonical file is likely mixed up (ADR-0002: AGENTS.md must be canonical, CLAUDE.md a symlink to it)" \
          "review both, move CLAUDE.md's real content into AGENTS.md, then: git rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
      else
        warn repo.claude-symlink "AGENTS.md ($AGENTS_LINES lines) and CLAUDE.md ($CLAUDE_LINES lines) are two separate files (ADR-0002: CLAUDE.md must be a symlink to AGENTS.md)" \
          "review both, merge whichever holds real content into AGENTS.md, then: git rm CLAUDE.md && ln -s AGENTS.md CLAUDE.md"
      fi
    fi
  fi

  [ -f .claude/settings.json ] && ok repo.hooks "Claude hooks configured (.claude/settings.json)" \
    || warn repo.hooks "no .claude/settings.json — hooks (spec-guard, no-verify, format) inactive" "run sdd-kit/install.sh --repo-only $ROOT"
  if [ -f .spec-guard-paths ]; then
    # count only real prefixes: skip comments and blank lines (same rule as spec-guard.cjs)
    GUARD_PATHS=$(grep -cv -e '^[[:space:]]*#' -e '^[[:space:]]*$' .spec-guard-paths || true)
    if [ "${GUARD_PATHS:-0}" -gt 0 ]; then
      ok repo.spec-guard "spec-guard enabled ($GUARD_PATHS guarded path(s))"
    else
      warn repo.spec-guard ".spec-guard-paths has no path prefixes (comments only) — spec-guard hook is a no-op" "add code path prefixes, one per line"
    fi
  else
    warn repo.spec-guard "no .spec-guard-paths — spec-guard hook is a no-op" "create .spec-guard-paths (code path prefixes, one per line)"
  fi

  # graphify index (navigation/context only, ADR-0004 — never a gate, so this
  # is info-level even when absent). Only reported when the CLI is installed.
  if command -v graphify >/dev/null 2>&1; then
    if [ -f graphify-out/graph.json ]; then
      note repo.graphify-index "graphify index: present (graphify-out/graph.json)"
    else
      note repo.graphify-index "graphify index: absent (optional, navigation-only)" "make sdd-index"
    fi
  fi

  if [ -f .git/hooks/pre-commit ] && grep -q sdd-check .git/hooks/pre-commit 2>/dev/null; then
    ok repo.pre-commit "pre-commit hook runs sdd-check"
  else
    warn repo.pre-commit "pre-commit hook missing or lacks sdd-check" "run sdd-kit/install.sh --repo-only $ROOT"
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

  # ------------------------------------------------------------------ audit
  # Clutter audit (merged from repo-audit.sh): agent-tooling that accumulates
  # in a repo. All findings are warn/info — deleting is a human decision.
  GROUP="audit"
  [ "$JSON" = 0 ] && echo "--- audit ---"

  # 1. MCP servers: only the project set (context7, youtrack) is expected.
  if [ -f .mcp.json ]; then
    EXTRA=$(python3 -c "
import json
allowed = {'context7', 'youtrack'}
servers = set(json.load(open('.mcp.json')).get('mcpServers', {}))
print(' '.join(sorted(servers - allowed)))
" 2>/dev/null)
    if [ -n "$EXTRA" ]; then
      warn audit.mcp-extra ".mcp.json has extra MCP servers: $EXTRA (expected: context7, youtrack)" "remove them from .mcp.json or justify in AGENTS.md"
    else
      ok audit.mcp "MCP servers: only context7/youtrack"
    fi
  else
    warn audit.mcp-missing ".mcp.json is missing" "run sdd-kit/install.sh --repo-only $ROOT"
  fi

  # 2. Configs of other agent tools — dead weight unless the team actually uses them.
  for d in .cursor .cursorrules .windsurf .windsurfrules .serena .aider .roo .clinerules GEMINI.md; do
    [ -e "$d" ] && warn audit.foreign-config "foreign agent-tool config: $d" "delete if unused: rm -r $d"
  done
  [ -e CLAUDE.local.md ] && note audit.claude-local "CLAUDE.local.md present (personal file, fine — must stay untracked)"

  # 3. Skills: only the openspec-* set + the kit's flows are expected.
  #    tz/tz-review/tz-implement come from a profile payload (ADR-0019 phase 4,
  #    conversation_flow) — known, not junk, so do not tell anyone to delete them.
  if [ -d .claude/skills ]; then
    for s in .claude/skills/*/; do
      [ -d "$s" ] || continue
      name=$(basename "$s")
      case "$name" in openspec-*|feature-flow|incident-flow|tz|tz-review|tz-implement) ;;
        patch|patch-review|patch-implement)
          note audit.skill-deprecated "deprecated skill kept on purpose: .claude/skills/$name (ADR-0019 §4 — retained to read the archived patch docs under docs/patches/, banner-marked DEPRECATED since 2026-08-03)" ;;
        *) warn audit.skill-extra "unexpected skill: .claude/skills/$name" "delete if unused: rm -r .claude/skills/$name" ;;
      esac
    done
  fi

  # 3b. Skills: openspec/ present but missing (some of) the 6 openspec-* skills
  #     means the Claude Code tooling was never generated for it — the bug
  #     this check exists for: openspec/ restored from a seed ref, or a
  #     pre-existing openspec/ left alone, without `openspec init --tools
  #     claude` / `openspec update` ever running. openspec-propose missing is
  #     called out by name: templates/agents/planner.md and
  #     templates/skills/feature-flow/SKILL.md hardcode
  #     `.claude/skills/openspec-propose/SKILL.md` as the path a subagent
  #     follows in lieu of invoking the skill directly — without the file,
  #     that documented path is just broken, not merely "a skill missing".
  #     Advisory only (ADR-0015 advisory-first) — the doctor diagnoses, it
  #     never blocks.
  if [ -d openspec ] && [ -n "$(find openspec -type f -print -quit 2>/dev/null)" ]; then
    MISSING_OS_SKILLS=""
    UNSTAMPED_OS_SKILLS=""
    for want in openspec-explore openspec-propose openspec-apply-change \
                openspec-update-change openspec-sync-specs openspec-archive-change; do
      if [ ! -f ".claude/skills/$want/SKILL.md" ]; then
        MISSING_OS_SKILLS="$MISSING_OS_SKILLS $want"
      elif ! grep -q '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' ".claude/skills/$want/SKILL.md"; then
        UNSTAMPED_OS_SKILLS="$UNSTAMPED_OS_SKILLS $want"
      fi
    done
    if [ -n "$MISSING_OS_SKILLS" ]; then
      EXTRA_HINT=""
      case " $MISSING_OS_SKILLS " in
        *" openspec-propose "*) EXTRA_HINT=" (openspec-propose is hardcoded in templates/agents/planner.md and templates/skills/feature-flow/SKILL.md — its absence breaks the documented path, not just a missing skill)" ;;
      esac
      warn audit.skill-missing "openspec/ exists but missing skill(s):$MISSING_OS_SKILLS$EXTRA_HINT" "run: sdd-kit/install.sh --repo-only $ROOT  (regenerates the openspec-* skills)"
    elif [ -n "$UNSTAMPED_OS_SKILLS" ]; then
      warn audit.skill-unstamped "openspec skill(s) present but missing disable-model-invocation: true:$UNSTAMPED_OS_SKILLS (ADR-0020 §8)" "run: sdd-kit/install.sh --repo-only $ROOT  (stamps them)"
    else
      ok audit.skill-openspec "all 6 openspec-* skills present and stamped"
    fi
  fi

  # 3c. ADR-0020 §8: /opsx:* slash commands are vendor noise left by `openspec
  #     init --tools claude` / `openspec update` — the openspec-* skills are
  #     the supported entry point, and the commands sit outside the
  #     disable-model-invocation stamp's reach. install.sh strips this
  #     directory right after every generation/sync call, but a manual
  #     `openspec update` run later re-creates it — catch that here.
  if [ -d .claude/commands/opsx ]; then
    warn audit.opsx-commands ".claude/commands/opsx present (ADR-0020 §8: openspec-* skills are the supported entry point, not /opsx:* slash commands)" "rm -rf .claude/commands/opsx"
  fi

  # 4. Agents: the sdd-kit set (2 reviewers + planner + plan-griller + test-author) is expected.
  if [ -d .claude/agents ]; then
    for a in .claude/agents/*.md; do
      [ -f "$a" ] || continue
      name=$(basename "$a" .md)
      case "$name" in backend-reviewer|database-reviewer|planner|plan-griller|test-author|repo-auditor|executor) ;;
        *) note audit.agent-extra "extra agent: .claude/agents/$name.md (keep only if actively used)" ;;
      esac
    done
  fi

  # 5. Local settings: plugins silently enabled per-repo are a common leftover.
  if [ -f .claude/settings.local.json ]; then
    PLUGINS=$(python3 -c "
import json
d = json.load(open('.claude/settings.local.json'))
print(' '.join(sorted(k for k, v in d.get('enabledPlugins', {}).items() if v)) if isinstance(d.get('enabledPlugins'), dict) else ' '.join(d.get('enabledPlugins', [])))
" 2>/dev/null)
    [ -n "$PLUGINS" ] && note audit.plugin-local "plugins enabled in .claude/settings.local.json: $PLUGINS"
  fi
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
                              "info": sum(r["level"] == "info" for r in rows),
                              "warn": sum(r["level"] == "warn" for r in rows),
                              "fail": sum(r["level"] == "fail" for r in rows)}}, indent=1))
' "$FINDINGS"
else
  echo "[sdd-doctor] summary: $PASS ok, $INFO info, $WARN warning(s), $FAIL failure(s)"
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
