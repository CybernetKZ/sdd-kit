#!/bin/sh
# sdd-kit git pre-commit hook: cheap hygiene checks + SDD gate.
# Rationale for the check selection: refactor_v4/pre-commit-recommendations.md.

# protected branches: block direct commits to release branches, warn on dev
# (branch protection on the server is the real gate — this is the local echo of it).
# Bypass for a deliberate exception: SDD_ALLOW_PROTECTED=1 git commit ...
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "${SDD_ALLOW_PROTECTED:-0}" != "1" ]; then
  case "$BRANCH" in
    main|master|prod|stage)
      echo "pre-commit: direct commit to '$BRANCH' is blocked — use a branch + pull request (SDD_ALLOW_PROTECTED=1 to override)" >&2
      exit 1 ;;
    dev)
      echo "pre-commit: WARN — committing directly to 'dev'; prefer a branch + pull request" >&2 ;;
  esac
fi

# branch age (ADR-0006): warn-only echo of the CI gate — rebase daily, split big changes
case "$BRANCH" in
  dev|main|master|prod|stage) ;;
  *)
    if MB=$(git merge-base origin/dev HEAD 2>/dev/null); then
      AGE=$(( ( $(date +%s) - $(git show -s --format=%ct "$MB") ) / 86400 ))
      [ "$AGE" -gt 2 ] && echo "pre-commit: WARN — branch diverged from dev $AGE days ago; rebase or split the OpenSpec change (CI fails at 5 days)" >&2
    fi ;;
esac

STAGED=$(git diff --cached --name-only --diff-filter=ACM)

# new git submodules / nested repos are almost always an accident here
if git diff --cached --raw | grep -q ' 160000 '; then
  echo "pre-commit: staged change adds a git submodule/nested repo — commit blocked" >&2
  exit 1
fi

if [ -n "$STAGED" ]; then
  # unresolved merge conflict markers
  if echo "$STAGED" | xargs -r grep -lE '^(<{7}|>{7}) ' -- 2>/dev/null | grep -q .; then
    echo "pre-commit: unresolved merge conflict markers in staged files — commit blocked" >&2
    exit 1
  fi

  # accidental large files (dumps, audio, venv artifacts)
  for f in $STAGED; do
    if [ -f "$f" ] && [ "$(wc -c < "$f")" -gt 5242880 ]; then
      echo "pre-commit: $f is larger than 5 MB — commit blocked (use storage, not git)" >&2
      exit 1
    fi
  done

  # ruff on staged Python: autofix lint + format, then re-stage (non-blocking, like CI reviewdog reports the rest)
  PY=$(echo "$STAGED" | grep -E '\.py$' || true)
  if [ -n "$PY" ]; then
    RUFF=""
    if command -v ruff >/dev/null 2>&1; then RUFF="ruff"
    elif command -v uvx >/dev/null 2>&1; then RUFF="uvx ruff"
    fi
    if [ -n "$RUFF" ]; then
      echo "$PY" | xargs -r $RUFF check --fix --quiet -- 2>/dev/null || true
      echo "$PY" | xargs -r $RUFF format --quiet -- 2>/dev/null || true
      echo "$PY" | xargs -r git add --
    else
      echo "pre-commit: ruff not found (install ruff or uv) — skipping lint/format" >&2
    fi
  fi

  # forgotten debug statements in Python
  if [ -n "$PY" ] && echo "$PY" | xargs -r grep -nE '^[^#]*(breakpoint\(\)|pdb\.set_trace\(\))' -- 2>/dev/null | grep -q .; then
    echo "pre-commit: breakpoint()/pdb.set_trace() left in staged Python — commit blocked" >&2
    exit 1
  fi

  # secrets: private keys and well-known token prefixes
  if echo "$STAGED" | xargs -r grep -lE "BEGIN .*PRIVATE KEY|sk-ant-[a-zA-Z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[bposar]-[A-Za-z0-9-]{10,}" -- 2>/dev/null | grep -q .; then
    echo "pre-commit: secret material (private key / API token) in staged files — commit blocked" >&2
    exit 1
  fi

  # invalid JSON / TOML / YAML (TOML and YAML checks skip silently if the parser is unavailable)
  for f in $STAGED; do
    case "$f" in
      *.json)
        python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null \
          || { echo "pre-commit: invalid JSON: $f — commit blocked" >&2; exit 1; }
        ;;
      *.toml)
        python3 -c "import sys
try: import tomllib
except ImportError: sys.exit(0)
tomllib.load(open(sys.argv[1],'rb'))" "$f" \
          || { echo "pre-commit: invalid TOML: $f — commit blocked" >&2; exit 1; }
        ;;
      *.yml|*.yaml)
        python3 -c "import sys
try: import yaml
except ImportError: sys.exit(0)
list(yaml.safe_load_all(open(sys.argv[1])))" "$f" 2>/dev/null \
          || { echo "pre-commit: invalid YAML: $f — commit blocked" >&2; exit 1; }
        ;;
    esac
  done
fi

# SDD gate: AGENTS.md + openspec validate + spec-lint (warn-only by default)
make sdd-check || { echo "pre-commit: make sdd-check failed — commit blocked" >&2; exit 1; }
