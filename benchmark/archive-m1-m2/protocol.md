# Benchmark protocol — FROZEN 2026-07-29

Do not edit after the first measured run. Deviations go to `deviations.md`.

## Design

- Task: **Web-2314** only (user decision 2026-07-29; ticket is Blocked until
  ~2026-08-03, so no one will merge a competing fix mid-benchmark).
  Caveat, recorded up front: n=1 task means the result characterizes sdd-kit
  on THIS task type (multi-file gateway/auth feature), not in general.
- Arms: A `nude` (clean CLAUDE_CONFIG_DIR, no sdd-kit), B `sdd` (clean
  CLAUDE_CONFIG_DIR + sdd-kit bootstrap + seeded specs).
- **3 runs × 2 arms = 6 headless sessions**, order A,B,B,A,A,B, sequential.
- Repo: fresh `git clone https://github.com/CybernetKZ/web-backend-new`
  per arm; branch `dev`; SHA recorded in `results/sha.txt` before run 1 and
  identical in both clones. Committed repo assets (.claude/skills, openspec/,
  CLAUDE.md) stay as-is in BOTH arms — identical baseline, recorded.
- Identical prompt in both arms: `prompt.md` (below), pasted verbatim.
  No YouTrack MCP inside measured runs.

## Fixed run parameters

| Parameter | Value |
|---|---|
| Command | `claude -p "$(cat prompt.md)" --model sonnet --permission-mode acceptEdits --allowedTools "Bash(*)"` |
| Model | sonnet pinned via `--model` (fresh config dirs have no default; user's daily default is fable — must NOT leak in). Same binary version both arms (2.1.220). Per-model token/cost breakdown extracted per run from OTEL `model` attribute — any fable/opus/haiku usage is visible. |
| Env | `CLAUDE_CONFIG_DIR` per arm; OTEL vars per PLAN-benchmark.md Phase 3 |
| Failed run (crash, API outage) | rerun once with same tag + note in deviations.md; agent giving up ≠ failure — scored task_success=0 |

## Primary metric

**$ per accepted task** = median cost_usd / median task_success (0/0.5/1).
Threshold to call sdd-kit useful: arm B ≥25% better on primary metric OR
equal cost with fewer failed binary gates, with within-arm IQR smaller than
the between-arm gap. Anything else = "no signal".
Secondary: binary-gate pass rate, read:edit ratio, cache hit rate.
sdd-kit bootstrap+seeding cost recorded separately → break-even statement.

## Task: Web-2314

**Ticket text (verbatim, fetched 2026-07-29):**

> **Web-2314 — Прокинуть Internal RAG API в External gateway**
>
> И не забыть чтобы была авторизация

**Prompt for both arms** (`prompt.md`): the ticket text above plus one
neutral framing line: "Implement this ticket in this repository. Work until
done: code, tests, and a clean lint/type/test run."

### Acceptance criteria (protocol-authored — ticket is thin; approved by Daniil before run 1)

1. External clients can reach the internal RAG/knowledge-base API
   (`vac-knowledge-base` target: `GET /api/v1/knowledge-base`,
   `GET /api/v1/knowledge-base/{uuid}`) through the external gateway surface.
2. Authorization enforced on every new external route (API-key /
   `allowed_roles` per `ext_endpoints_auth_rules.yml` pattern) — unauthorized
   request rejected; test proves it.
3. Follows the existing external-exposure pattern
   (`backend/api/external/v1/web_api/call_campaign.py` +
   `ext_endpoints_auth_rules.yml` call-campaign block).
4. Tests added for auth-positive and auth-negative paths; existing tests stay green.
5. No changes to RAG business logic (lives in VAC, out of scope).

Grading: 1 = all five; 0.5 = routes work but auth tests missing or pattern
violated; 0 = doesn't work or auth missing.

### Expected blast radius (scope creep = files outside this list)

- `api-gateway-service/app/core/ext_endpoints_auth_rules.yml`
- `api-gateway-service/app/core/internal_endpoints_auth_rules.yml`
- `api-gateway-service/app/auth/auth_rules.py`
- `api-gateway-service/app/proxy/route_handler.py`, `request_forwarder.py`
- `api-gateway-service/app/tests/*` (auth/forwarding tests)
- `backend/api/external/v1/web_api/*` (new router + `__init__.py`) — optional wrapper path
- `backend/app/**/external_*` schemas/service if wrapper path chosen
- `backend/tests/*` for the wrapper
- arm B only: `openspec/changes/<id>/**` (spec artifacts don't count as creep)

## Binary gates (per run, before any subjective scoring)

1. diff applies cleanly on the recorded SHA
2. ruff clean on changed files
3. type check clean (mypy/pyright — whatever repo CI uses)
4. test suite green
5. zero files outside blast radius (list violations regardless)

## Quality rubric (blind review, 1–5 each; written before any run)

1. Correctness vs acceptance criteria
2. Readability / simplicity (no speculative abstractions)
3. Repo-convention fit (matches call-campaign external pattern)
4. Test quality (auth-negative case present, meaningful asserts)
5. "Would I merge this" gut score

Review is blind: arm markers stripped, 6 diffs shuffled by conductor,
judged by an opus subagent that never sees arm labels.

## Definitions

- **Intervention**: any human re-prompt after the initial `claude -p` (headless
  target: 0; if a run stalls it is scored as-is, not nudged).
- **Attempt/run**: one `claude -p` invocation from clean SHA to final diff.
- **Dead-end branch**: agent edits then fully reverts a file (from diff of
  intermediate commits if any, else from transcript tool log — diagnostic only).
