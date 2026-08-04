#!/usr/bin/env bash
# scripts/sdd/test.sh — single-entry test gate (ex `make sdd-test`, ADR-0026).
# Run on demand only — there is no server CI to run it as a job (ADR-0023);
# NOT part of check.sh, so pre-commit stays fast. Each half no-ops with a
# clear echo when the repo has nothing of that kind to run; a real run that
# fails exits non-zero (this script is meant to go red when it should).
# Monorepos (configs/tests per service, not at the root): set SDD_TEST_CMD in
# env and this script delegates to it wholesale.
set -u

if [ -n "${SDD_TEST_CMD:-}" ]; then
  echo "sdd-test: delegating to SDD_TEST_CMD: $SDD_TEST_CMD"
  exec sh -c "$SDD_TEST_CMD"
fi

FAILED=0

if [ -f ruff.toml ] || [ -f .ruff.toml ] || { [ -f pyproject.toml ] && grep -q '^\[tool\.ruff\]' pyproject.toml; }; then
  echo "sdd-test: ruff config found — running ruff check ."
  if command -v ruff >/dev/null 2>&1; then RUFF="ruff"
  elif command -v uvx >/dev/null 2>&1; then RUFF="uvx ruff"
  else echo "FAIL: ruff config found but neither ruff nor uvx is installed"; FAILED=1; RUFF=""; fi
  [ -n "$RUFF" ] && { $RUFF check . || FAILED=1; }
else
  echo "sdd-test: no ruff config at the repo root — lint skipped (per-service configs? set SDD_TEST_CMD)"
fi

if [ -d tests ] || [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -q '^\[tool\.pytest' pyproject.toml; }; then
  echo "sdd-test: tests found — running pytest -q"
  if command -v pytest >/dev/null 2>&1; then PYTEST="pytest"
  elif command -v uv >/dev/null 2>&1; then PYTEST="uv run pytest"
  elif command -v uvx >/dev/null 2>&1; then PYTEST="uvx pytest"
  else echo "FAIL: tests found but neither pytest, uv, nor uvx is installed"; FAILED=1; PYTEST=""; fi
  [ -n "$PYTEST" ] && { $PYTEST -q || FAILED=1; }
else
  echo "sdd-test: no tests at the repo root — skipped (per-service tests? set SDD_TEST_CMD)"
fi

exit "$FAILED"
