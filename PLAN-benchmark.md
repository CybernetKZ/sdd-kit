# Benchmark plan: WBN with vs without sdd-kit

Conductor: this chat (Fable 5). Workers: subagents (opus for judgment-heavy
steps, sonnet for mechanical steps). Measured runs: headless `claude -p`,
same model + effort in every arm.

## Arms

| Arm | Config | How |
|-----|--------|-----|
| A `nude` | clean, no sdd-kit | fresh `CLAUDE_CONFIG_DIR=~/bench/cfg-a`, clone in `~/bench/nude-claude/web-backend-new` |
| B `sdd` | clean + sdd-kit artifacts | fresh `CLAUDE_CONFIG_DIR=~/bench/cfg-b`, clone in `~/bench/sdd-kit-claude/web-backend-new`, run `bootstrap.sh` |
| C `daily` (optional, round 2) | your real config, no sdd-kit | normal `~/.claude`, clone of A |

Same repo SHA in all clones — record it. Identical prompt in all arms
(ticket text fetched from YouTrack ONCE, pasted verbatim — no MCP calls
inside measured runs).

## Design

- **1 task (Web-2314, frozen 2026-07-29) × 3 runs × 2 arms = 6 headless
  sessions**, order A,B,B,A,A,B, sequential — never two clones at once.
  (Original 3-task design cut by user decision; n=1-task caveat recorded
  in `benchmark/protocol.md`.)
- **Primary metric: $ per accepted task** (cost_usd / task_success 0|0.5|1).
  Secondary: human interventions (headless → count of failed gates needing
  re-prompt). Everything else is diagnostics.
- sdd-kit bootstrap cost measured separately → break-even point.

## Phases (conductor + subagents)

### Phase 0 — freeze the protocol (conductor, this chat)
Write `protocol.md` before any run, never edit after:
task list + acceptance criteria, expected blast radius per task, quality
rubric (1–5 axes), success threshold, model/effort/permission-mode/CC
version, what to do with failed runs.

### Phase 1 — environment (sonnet subagent)
1. Inventory current global config (`~/.claude`: skills, plugins, hooks,
   rules, CLAUDE.md, MCP) → snapshot file. Nothing deleted — isolation via
   `CLAUDE_CONFIG_DIR` only.
2. Stand up OTEL collector (docker: otel-collector + file exporter is
   enough; no Grafana). Verify `claude_code.session.count` arrives from a
   smoke-test session.
3. Two clones, same SHA, `.env`/DB per clone on different ports.
4. Arm B: run `bootstrap.sh`, capture its cost/time, then spec-miner
   seeding per README — this cost is logged as "kit generation".
5. Verify arm B smoke session emits `skill_activated` — if the kit never
   activates, stop and fix before burning 18 runs.

### Phase 2 — task selection (conductor + YouTrack MCP, outside measured runs)
Fetch backlog/ready_to_go tasks assigned to me, shortlist 3 by type,
confirm with Daniil, paste final ticket texts into `protocol.md`.

### Phase 3 — measured runs (sonnet subagent per run, or plain Bash)
Per run:
```bash
export CLAUDE_CONFIG_DIR=~/bench/cfg-{a,b}
export CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=otlp \
  OTEL_LOGS_EXPORTER=otlp OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317 \
  OTEL_RESOURCE_ATTRIBUTES="arm=$ARM,task=$TASK,run=$N"
git -C $CLONE checkout -b bench/$TASK-$ARM-$N $SHA
claude -p "$(cat prompts/$TASK.md)" --permission-mode acceptEdits
git -C $CLONE diff > results/$TASK-$ARM-$N.diff
```
After each run: reset clone to SHA. Log wall-clock as reference only.

### Phase 4 — metric extraction (sonnet subagent)
Parse OTEL export per (arm,task,run): tokens by type, cost_usd, cache hit
rate, tool-call breakdown, read:edit file ratio, compactions, api errors,
skill_activated. Binary gates on each diff: applies cleanly, ruff, mypy,
tests green, scope creep vs frozen blast radius. → `results/metrics.csv`.

### Phase 5 — blind review (opus subagent)
Strip arm markers, shuffle the 18 diffs, score against the frozen rubric +
task_success 0/0.5/1. Judge never sees which arm is which; conductor holds
the key.

### Phase 6 — report (conductor)
Median + IQR per arm per task (never single-run averages). Verdict format:
"bugfix: X, feature: Y, refactor: Z; break-even at N tasks." If
within-arm variance > between-arm difference → result is "no signal", say
so.

## Skipped (add only if needed)
- Grafana/Prometheus — file exporter + a parse script covers 18 runs.
- Arm C, interactive-DX runs, enhanced tracing beta — round 2.
- Transcript-jsonl parsing — fallback only if OTEL export fails.
