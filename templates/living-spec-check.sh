# shellcheck shell=bash
# Fragment concatenated into .git/hooks/pre-commit by sdd-kit/install.sh (not standalone).
# LIVING SPEC discipline (conversation_flow): production code touched ->
# docs/DOCUMENTATION.md (spec + changelog section) must be touched too. Warn-only.
if [ -f .spec-guard-paths ]; then
  CODE_TOUCHED=0
  while IFS= read -r prefix; do
    [ -n "$prefix" ] || continue
    if git diff --cached --name-only | grep -q "^$prefix"; then CODE_TOUCHED=1; break; fi
  done < .spec-guard-paths
  if [ "$CODE_TOUCHED" = 1 ] && ! git diff --cached --name-only | grep -q "^docs/DOCUMENTATION.md$"; then
    echo "pre-commit WARN: production code staged but docs/DOCUMENTATION.md is not." >&2
    echo "  LIVING SPEC + changelog update is part of DoD (see AGENTS.md)." >&2
  fi
fi

