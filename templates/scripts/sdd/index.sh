#!/usr/bin/env bash
# scripts/sdd/index.sh — codebase knowledge graph (ex `make sdd-index`,
# ADR-0026): builds/updates graphify-out/graph.json over source code +
# openspec/ + docs/. Manual invocation only — run it yourself before a big
# intake (ticket/spec verification); NOT part of check.sh/pre-commit (there
# is no server CI, ADR-0023), and it never spawns background processes.
# ADR-0004: graphify is navigation/context ONLY, never a CI gate — its edges
# are INFERRED (best-effort relationships), not verified facts; treat graph
# answers as leads to check against the actual code, not ground truth.
set -u

command -v graphify >/dev/null 2>&1 || { echo "graphify not installed — run sdd-kit/install.sh --machine-only"; exit 0; }

if [ -f graphify-out/graph.json ]; then
  echo "sdd-index: existing graph found — incremental update (AST-only, no LLM key needed)"
  graphify update . || echo "sdd-index: update failed (see output above) — advisory, not a gate"
elif [ -n "${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}${ANTHROPIC_API_KEY:-}${OPENAI_API_KEY:-}${MOONSHOT_API_KEY:-}${DEEPSEEK_API_KEY:-}" ]; then
  echo "sdd-index: no graph yet — building index over code + openspec/ + docs/"
  graphify extract . --out . || echo "sdd-index: build failed (see output above) — advisory, not a gate"
else
  echo "sdd-index: no graph yet and no LLM API key in env (docs need semantic extraction)."
  echo "  On a Claude subscription: run the interactive '/graphify' command in Claude Code"
  echo "  (uses your session, no API key). After the first build, 'scripts/sdd/index.sh'"
  echo "  keeps the graph updated with no key (AST-only). Advisory, not a gate."
fi
