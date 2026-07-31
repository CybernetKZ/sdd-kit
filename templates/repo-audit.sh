#!/bin/sh
# sdd-kit repo audit: report agent-tooling clutter in this repository.
# Informational by default (always exit 0); SDD_AUDIT_STRICT=1 exits 1 on warnings.
# Run via `make sdd-audit` or directly: sh .claude/scripts/repo-audit.sh [--json]
#
# Finding format (ADR-0008): {level, group, code, message, next}; --json for machines.

JSON=0; [ "${1:-}" = "--json" ] && JSON=1
FINDINGS="$(mktemp)"; trap 'rm -f "$FINDINGS"' EXIT
WARNINGS=0

# emit <level> <group> <code> <message> [next]
emit() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5:-}" >> "$FINDINGS"
  if [ "$JSON" = 0 ]; then
    case "$1" in
      info) echo "  info: [$3] $4" ;;
      warn) echo "  WARN: [$3] $4"; [ -n "${5:-}" ] && echo "        next: $5" ;;
    esac
  fi
}
note() { emit info clutter "$@"; }
warn() { WARNINGS=$((WARNINGS + 1)); emit warn clutter "$@"; }

[ "$JSON" = 0 ] && echo "[repo-audit] $(basename "$(pwd)")"

# 1. MCP servers: only the project set (context7, youtrack) is expected.
if [ -f .mcp.json ]; then
  EXTRA=$(python3 -c "
import json
allowed = {'context7', 'youtrack'}
servers = set(json.load(open('.mcp.json')).get('mcpServers', {}))
print(' '.join(sorted(servers - allowed)))
" 2>/dev/null)
  [ -n "$EXTRA" ] && warn mcp.extra ".mcp.json has extra MCP servers: $EXTRA (expected: context7, youtrack)" "remove them from .mcp.json or justify in AGENTS.md"
else
  warn mcp.missing ".mcp.json is missing" "run sdd-kit/bootstrap.sh"
fi

# 2. Configs of other agent tools — dead weight unless the team actually uses them.
for d in .cursor .cursorrules .windsurf .windsurfrules .serena .aider .roo .clinerules GEMINI.md; do
  [ -e "$d" ] && warn foreign.config "foreign agent-tool config: $d" "delete if unused: rm -r $d"
done
[ -e CLAUDE.local.md ] && note claude.local "CLAUDE.local.md present (personal file, fine — must stay untracked)"

# 3. Skills: only the openspec-* set installed by OpenSpec init is expected.
if [ -d .claude/skills ]; then
  for s in .claude/skills/*/; do
    [ -d "$s" ] || continue
    name=$(basename "$s")
    case "$name" in openspec-*|feature-flow|incident-flow) ;;
      *) warn skill.extra "unexpected skill: .claude/skills/$name" "delete if unused: rm -r .claude/skills/$name" ;;
    esac
  done
fi

# 4. Agents: the sdd-kit set (4 reviewers + planner + plan-griller) is expected.
if [ -d .claude/agents ]; then
  for a in .claude/agents/*.md; do
    [ -f "$a" ] || continue
    name=$(basename "$a" .md)
    case "$name" in python-reviewer|fastapi-reviewer|database-reviewer|code-reviewer|planner|plan-griller) ;;
      *) note agent.extra "extra agent: .claude/agents/$name.md (keep only if actively used)" ;;
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
  [ -n "$PLUGINS" ] && note plugin.local "plugins enabled in settings.local.json: $PLUGINS"
fi

if [ "$JSON" = 1 ]; then
  python3 -c '
import json, sys
rows = []
for line in open(sys.argv[1]):
    level, group, code, message, nxt = line.rstrip("\n").split("\t")
    rows.append({"level": level, "group": group, "code": code,
                 "message": message, **({"next": nxt} if nxt else {})})
print(json.dumps({"findings": rows,
                  "summary": {"info": sum(r["level"] == "info" for r in rows),
                              "warn": sum(r["level"] == "warn" for r in rows)}}, indent=1))
' "$FINDINGS"
elif [ "$WARNINGS" -gt 0 ]; then
  echo "[repo-audit] $WARNINGS warning(s). This report is advisory — deleting is a human decision."
else
  echo "[repo-audit] clean"
fi
[ "$WARNINGS" -gt 0 ] && [ "${SDD_AUDIT_STRICT:-0}" = "1" ] && exit 1
exit 0
