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
  bad tool.ruff "ruff unavailable — the pre-commit hook and make sdd-test depend on it" "uv tool install ruff"
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

MISSING_STATIC=""
for t in radon complexipy vulture semgrep; do
  command -v "$t" >/dev/null 2>&1 || MISSING_STATIC="$MISSING_STATIC $t"
done
if [ -z "$MISSING_STATIC" ]; then
  ok tool.static-review "static review tools (radon, complexipy, vulture, semgrep)"
else
  note tool.static-review "static review leads missing:$MISSING_STATIC — make sdd-review works, just with fewer leads" "sdd-kit/install.sh --machine-only"
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

  # ADR-0023 §2: "the file exists" is not enough. conversation_flow carried a
  # 9-byte AGENTS.md containing the literal text "AGENTS.md" — a botched symlink
  # that every check passed while every agent read an empty project context.
  # FAIL, not warn: an empty agent context silently degrades every downstream
  # step, and the fix is a one-liner (restore from git history or the kit).
  if [ -f AGENTS.md ]; then
    AGENTS_REAL_LINES=$(grep -cv '^[[:space:]]*$' AGENTS.md 2>/dev/null || echo 0)
    if [ ! -s AGENTS.md ]; then
      bad repo.agents-md-content "AGENTS.md is empty (0 bytes) — agents get no project context" \
        "restore it: git show <ref>:AGENTS.md > AGENTS.md, or cp sdd-kit/templates/AGENTS.md AGENTS.md"
    elif [ "$AGENTS_REAL_LINES" -le 1 ] && grep -qx '[[:space:]]*AGENTS\.md[[:space:]]*' AGENTS.md; then
      bad repo.agents-md-content "AGENTS.md contains only the text 'AGENTS.md' — this is a botched symlink, not a context file" \
        "restore the real content: git log --oneline -- AGENTS.md, then git show <ref>:AGENTS.md > AGENTS.md"
    elif [ "$AGENTS_REAL_LINES" -lt 10 ]; then
      bad repo.agents-md-content "AGENTS.md has only $AGENTS_REAL_LINES non-blank line(s) — too little to be a real project context" \
        "fill it in from sdd-kit/templates/AGENTS.md (module map, rules, spec chain)"
    else
      ok repo.agents-md-content "AGENTS.md has real content ($AGENTS_REAL_LINES non-blank lines)"
    fi
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

  # repo.hooks: a present .claude/settings.json is not proof the kit hooks it
  # ships (.claude/hooks/*.cjs) actually run — a repo that already had its own
  # settings.json before the kit was installed keeps its hooks untouched by
  # put(), so block-no-verify.cjs/spec-guard.cjs/pre-compact.cjs can sit on
  # disk copied but never referenced. Check every installed .cjs hook is
  # mentioned somewhere in settings.json's hooks tree, not just that the file
  # exists.
  if [ -f .claude/settings.json ]; then
    UNWIRED_HOOKS=$(python3 -c "
import json, glob, os, sys

try:
    data = json.load(open('.claude/settings.json'))
except Exception:
    print('<unreadable>')
    sys.exit(0)

commands = ' '.join(
    h.get('command', '')
    for groups in data.get('hooks', {}).values()
    for g in groups
    for h in g.get('hooks', [])
)
missing = [
    os.path.basename(f) for f in sorted(glob.glob('.claude/hooks/*.cjs'))
    if os.path.basename(f) not in commands
]
print(' '.join(missing))
" 2>/dev/null)
    if [ "$UNWIRED_HOOKS" = "<unreadable>" ]; then
      warn repo.hooks ".claude/settings.json is not valid JSON — cannot verify kit hooks are wired" "fix the JSON syntax, then re-run"
    elif [ -n "$UNWIRED_HOOKS" ]; then
      warn repo.hooks "hook file(s) in .claude/hooks/ not referenced by .claude/settings.json: $UNWIRED_HOOKS — copied but inactive" "run sdd-kit/install.sh --repo-only $ROOT (wires them in additively, keeps your own hooks)"
    else
      ok repo.hooks "Claude hooks configured (.claude/settings.json, all .claude/hooks/*.cjs wired)"
    fi
  else
    warn repo.hooks "no .claude/settings.json — hooks (spec-guard, no-verify, format) inactive" "run sdd-kit/install.sh --repo-only $ROOT"
  fi
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

  # Code graph (ADR-0004: navigation/context only, never a gate — so absence is
  # info, never fail). ADR-0023 §3 makes graphify-out/graph.json a committed team
  # artifact, so it is reported whether or not the graphify CLI is installed
  # locally: a teammate's clone can carry the graph without the tool.
  if [ -f graphify-out/graph.json ]; then
    if find graphify-out/graph.json -mtime +30 -print 2>/dev/null | grep -q .; then
      warn repo.graph "code graph graphify-out/graph.json is older than 30 days — intake answers will miss recent code" \
        "make sdd-index (AST-only refresh, no API key needed)"
    else
      ok repo.graph "code graph present and recent (graphify-out/graph.json)"
    fi
  else
    note repo.graph "no code graph (graphify-out/graph.json) — intake and planning fall back to grep" \
      "make sdd-index, or run the interactive '/graphify' command in Claude Code for the first build"
  fi

  if [ -f .git/hooks/pre-commit ] && grep -q sdd-check .git/hooks/pre-commit 2>/dev/null; then
    ok repo.pre-commit "pre-commit hook runs sdd-check"
  else
    warn repo.pre-commit "pre-commit hook missing or lacks sdd-check" "run sdd-kit/install.sh --repo-only $ROOT"
  fi

  # Central spec store (ADR-0001, ADR-0023 §1): registered on this machine, the
  # registered path really exists, and the clone is not ancient. The registry is
  # machine-level and there is no sync by design ("no sync, ever") — freshness is
  # a deliberate `git pull`, so a stale clone is exactly what needs reporting.
  if [ -f openspec/config.yaml ] && grep -q '^references:' openspec/config.yaml; then
    STORE_ID="$(sed -n 's/^[[:space:]]*-[[:space:]]*//p' openspec/config.yaml | head -1)"
    OPENSPEC="openspec"; command -v openspec >/dev/null 2>&1 || OPENSPEC="npx -y @fission-ai/openspec@1.7.0" # openspec-pin
    STORE_PATH="$($OPENSPEC store list 2>/dev/null \
      | awk -v id="$STORE_ID" '$1 == id { sub(/^[^ \t]+[ \t]+/, ""); print; exit }')"
    case "$STORE_PATH" in "~/"*) STORE_PATH="$HOME/${STORE_PATH#\~/}" ;; esac
    if [ -z "$STORE_PATH" ]; then
      warn repo.store "store '$STORE_ID' referenced by openspec/config.yaml but not registered on this machine" \
        "run sdd-kit/install.sh --machine-only (clones to ~/cybernet/$STORE_ID and registers it)"
    elif [ ! -d "$STORE_PATH" ]; then
      warn repo.store "store '$STORE_ID' registered at $STORE_PATH, but that path does not exist — every spec reference resolves to nothing" \
        "re-clone it and re-register: run sdd-kit/install.sh --machine-only"
    else
      ok repo.store "store '$STORE_ID' registered ($STORE_PATH)"
      STORE_COMMIT_TS="$(git -C "$STORE_PATH" log -1 --format=%ct 2>/dev/null || true)"
      if [ -z "$STORE_COMMIT_TS" ]; then
        note repo.store-fresh "store $STORE_PATH is not a git clone — freshness cannot be checked" \
          "re-clone from the store remote so 'git pull' can refresh it"
      else
        STORE_AGE_DAYS=$(( ( $(date +%s) - STORE_COMMIT_TS ) / 86400 ))
        if [ "$STORE_AGE_DAYS" -gt 30 ]; then
          warn repo.store-fresh "store clone's last commit is $STORE_AGE_DAYS days old (no auto-sync by design) — contracts may be out of date" \
            "git -C $STORE_PATH pull"
        else
          ok repo.store-fresh "store clone is current (last commit $STORE_AGE_DAYS day(s) ago)"
        fi
      fi
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
      case "$name" in openspec-*|feature-flow|incident-flow|tz|tz-review|tz-implement|grilling|grill-me|grill-with-docs|domain-modeling) ;;
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
