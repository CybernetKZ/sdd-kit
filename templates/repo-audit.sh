#!/bin/sh
# sdd-kit repo audit: report agent-tooling clutter in this repository.
# Informational by default (always exit 0); SDD_AUDIT_STRICT=1 exits 1 on warnings.
# Run via `make sdd-audit` or directly: sh .claude/scripts/repo-audit.sh

WARNINGS=0
note() { echo "  info: $*"; }
warn() { echo "  WARN: $*"; WARNINGS=$((WARNINGS + 1)); }

echo "[repo-audit] $(basename "$(pwd)")"

# 1. MCP servers: only the project set (context7, youtrack, chrome-devtools for frontend) is expected.
if [ -f .mcp.json ]; then
  EXTRA=$(python3 -c "
import json
allowed = {'context7', 'youtrack', 'chrome-devtools'}
servers = set(json.load(open('.mcp.json')).get('mcpServers', {}))
print(' '.join(sorted(servers - allowed)))
" 2>/dev/null)
  [ -n "$EXTRA" ] && warn ".mcp.json has extra MCP servers: $EXTRA (expected: context7, youtrack, chrome-devtools)"
else
  warn ".mcp.json is missing (run sdd-kit/bootstrap.sh)"
fi

# 2. Configs of other agent tools — dead weight unless the team actually uses them.
for d in .cursor .cursorrules .windsurf .windsurfrules .serena .aider .roo .clinerules GEMINI.md; do
  [ -e "$d" ] && warn "foreign agent-tool config: $d (delete if unused)"
done
[ -e CLAUDE.local.md ] && note "CLAUDE.local.md present (personal file, fine — must stay untracked)"

# 3. Skills: only the openspec-* set installed by OpenSpec init is expected.
if [ -d .claude/skills ]; then
  for s in .claude/skills/*/; do
    [ -d "$s" ] || continue
    name=$(basename "$s")
    case "$name" in openspec-*|feature-flow) ;; *) warn "unexpected skill: .claude/skills/$name" ;; esac
  done
fi

# 4. Agents: the four sdd-kit reviewers are expected; anything else is worth a look.
if [ -d .claude/agents ]; then
  for a in .claude/agents/*.md; do
    [ -f "$a" ] || continue
    name=$(basename "$a" .md)
    case "$name" in python-reviewer|fastapi-reviewer|database-reviewer|code-reviewer) ;;
      *) note "extra agent: .claude/agents/$name.md (keep only if actively used)" ;;
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
  [ -n "$PLUGINS" ] && note "plugins enabled in settings.local.json: $PLUGINS"
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo "[repo-audit] $WARNINGS warning(s). This report is advisory — deleting is a human decision."
  [ "${SDD_AUDIT_STRICT:-0}" = "1" ] && exit 1
else
  echo "[repo-audit] clean"
fi
exit 0
