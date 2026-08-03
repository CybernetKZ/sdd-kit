# AGENTS.md - context for AI agents

<!-- Limit: 500 lines. Enforced by `make sdd-check`. -->
<!-- CLAUDE.md in this repository is a symlink to this file (ADR-0002). -->

Local, uncommitted workflow rules live in `CLAUDE.local.md` (graph-first
navigation, tool tiering, "never commit"). Extra Cursor skills for this repo:
`.cursor/skills/` (`work-stack-backend`, `backend-workflow`, `fastapi-pro`,
`python-pro`, `postgres`, `security-audit`, ...).

## What this service is

`voice-agent-constructor-backend` (VA / VAC) is a **single FastAPI service** that
is the *constructor* - the configuration plane - for AI voice agents. It owns
everything a voice agent is made of, but it does not place or handle calls: the
calling platform lives in the sibling repo `web-backend-new` (WBN), and VAC
publishes agent configuration to it.

What it owns:

- **Agents** and their full configuration cascade: language, LLM settings, ASR
  settings, TTS settings, VAD settings, main prompt, tools, background noise,
  post-call-analysis templates and segments, controller/telephony/call settings.
- **Provider catalogues**: `llm` / `llm_provider`, `asr` / `asr_provider`,
  `tts` / `tts_provider` / `tts_model` / `tts_type`, `vad`, `language`, `gender`,
  `background` - DB-driven, seeded by migrations, no hardcoded provider names.
- **Agent templates** (`agent_template`, `template_topic`): serialize a working
  agent into an `AgentTemplateConfigV1` blob and instantiate new agents from it
  via "default cascade + overlay".
- **Knowledge bases** (`knowledge_base`, `knowledge_base_file`): file upload to
  S3-compatible storage plus sync to an external RAG service over HTTP.
- **Conversation flows** (`conversation_flow`): versioned flow content (JSONB
  nodes) with validation status, rename/copy under a lock.
- **Tools** (`tool`): OpenAI-function-compatible tool definitions bound to agents.
- **Agent -> WBN sync**: RabbitMQ RPC (`AgentWbRpcClient` / consumer) plus a
  TaskIQ worker that retries and dead-letters `CREATE/UPDATE/DELETE_AGENT_WB`.

Stack (from `backend/pyproject.toml`): Python 3.11, FastAPI, Pydantic v2 +
pydantic-settings, SQLAlchemy 2.0 (async, asyncpg), Alembic, PostgreSQL 17,
Redis (cashews cache), FastStream (RabbitMQ), TaskIQ + taskiq-aio-pika, boto3
(S3), loguru, pytest + pytest-asyncio.

Two HTTP surfaces from one process (`backend/main.py`):

- public API - `api/v1/*`, mounted under `settings.API_URL`;
- internal API - `api/internal/v1/*`, a **mounted sub-application** at
  `/internal`, guarded by an `x-api-key` middleware
  (`api/internal/middleware/security.py`); see
  `backend/internal_endpoints_readme.md`;
- health probes - `/health/live`, `/health/ready`, `/health` (readiness returns
  503 in production mode during graceful shutdown).

## Commands

Everything runs through Docker Compose from the repository root
(`docker-compose.yml`; `docker-compose-local.yml` is the canonical local variant,
`docker-compose.prod.yml` for prod). Compose services: `va-backend`,
`va-backend-taskiq-worker-kb-rag-sync`, `va-backend-taskiq-worker-agent-wb-sync`,
`va-db`, `va-redis`, `va-pgadmin-cybernet`.

Run locally:

- `make setup` - create the external `cybernet-network` and the pgadmin volume
  (required once; the `migrate*` targets depend on it).
- `make build` / `make build_no_cache` - build images.
- `make run` - start everything detached; `make run_verbose` - foreground.
- `make deploy` - stop, build, wait for `va-db` healthy, then start.
- `make status` / `make logs [service]` / `make stop` / `make down`.
- `make enter_backend` - shell inside the running `va-backend` container.
- API on `localhost:8010` (`/docs`), internal API on `/internal/docs`, debugger
  port `5688`, Postgres on `5442`, Redis on `6389`, pgAdmin on `5010`.

Database and migrations:

- `make create_db` / `make drop_db` - run `database/create_db.py` / `drop_db.py`.
- `make migrate` - `alembic revision --autogenerate`; note the message is
  **hardcoded** to `"auto-migration from CI/CD"`, there is no `name=` argument.
  Fix the message in the generated file yourself.
- `make migrate_upgrade` / `make migrate_downgrade` - `alembic upgrade head` /
  `alembic downgrade` (one step).

Tests:

- `make test` currently runs only two unit files
  (`tests/unit/test_kb_delete_agent_cleanup.py`,
  `tests/unit/test_agent_conversation_flow_lock.py`); the whole `tests/api/v1/*`
  block is commented out in the `Makefile`. Failures are collected into
  `test_errors.tmp` and printed, and **`make test` still exits 0** - read its
  output, do not trust the exit code.
- Full suite (what CI does not run for you yet):
  `docker compose run --rm va-backend sh -c "export ENV='TEST' && pytest -s -v --disable-warnings"`.
  Add a path to scope it, e.g. `... pytest tests/unit`.
- `pytest` config is in `backend/pyproject.toml`: `asyncio_mode = "auto"`,
  `testpaths = ["tests"]`.
- Postman/Newman collections live in `backend/tests/*.postman_collection.json`
  and `postman-collections/`; rules in
  `docs/va-project-rules/POSTMAN_TEST_RULES.md`.

SDD checks:

- `make sdd-check` (from `Makefile.sdd`) - asserts `AGENTS.md` exists and is
  ≤500 lines, warns on leftover template placeholders, and runs
  `npx @fission-ai/openspec@1.7.0 validate --all --strict`. This is the required
  PR gate (`.github/workflows/sdd-ci.yml`).

## Module map

Everything lives under `backend/` (one service, no sub-services).

```
backend/
├── main.py                # FastAPI app + internal sub-app, lifespan, graceful shutdown
├── api/v1/<module>/       # public REST endpoints, one package per domain module
├── api/internal/          # internal API: v1/<module>/, deps/verify_api_key.py,
│                          #   middleware/security.py (x-api-key + Bearer fallback)
├── app/<module>/          # domain modules: model/ + repo/ + schema/ + service/
│   ├── agent/             # Agent + all per-component settings, RPC read model
│   ├── agent_template/    # templates, topics, config serializer/applier
│   ├── asr/               # ASR engines and providers
│   ├── auth/              # UserData, cross-firm permission checks (RBAC via WBN)
│   ├── background/        # background-noise assets bound to agents
│   ├── base/              # BaseModel/BaseRepo/BaseSchema/BaseService, cache,
│   │                      #   enum.py, datetime_utils.py, s3_service, icon_storage
│   ├── conversation_flow/ # flow content, versions, validation state
│   ├── gender/            # voice gender reference data
│   ├── knowledge_base/    # KB + files, rag_service_client, rag_sync_worker_service
│   ├── language/          # languages and language↔TTS compatibility
│   ├── llm/               # LLM models and providers
│   ├── tool/              # tool definitions, internal_tool_service
│   ├── tts/               # TTS models/providers/types, tts_method_resolution
│   └── vad/               # VAD settings reference data
├── background_workers/    # TaskIQ: brokers/, runners/ (worker entrypoints), tasks/
│                          #   agent_wb_sync_tasks.py, kb_rag_sync_tasks.py
├── core/                  # config.py (nested BaseSettings), graceful_shutdown.py,
│                          #   agent_template_seed.py, main_prompts.py, images.py
├── database/              # Base, async session/engine, redis_client_manager,
│                          #   create_db.py, drop_db.py
├── messaging/             # FastStream RabbitMQ: broker, publisher_service,
│                          #   agent_wb_rpc_client.py, agent_wb_rpc_consumer.py
├── middleware/            # graceful_shutdown_middleware.py
├── migrations/            # Alembic env + versions/ (47 revisions)
├── scripts/               # one-off ops scripts (migrate_icons_to_s3.py, sql/)
├── static/icons/          # bundled provider/language icons
├── tests/                 # unit/, integration/, api/v1/, schema/, shutdown/,
│                          #   conftest.py, Postman collections
└── values/                # Helm values per deployable (backend + 2 taskiq workers)
```

Repository root, outside `backend/`:

- `openspec/` - specs and changes (see below).
- `docs/` - a **separate git repository** shared with WBN; VA docs are indexed in
  `docs/MAP_VA.md` (folders `va-project-logic/`, `va-project-rules/`, `va-asr/`,
  `va-tts/`, `va-llm/`, `va-devops/`, `va-graceful-shutdown/`, `va-not-task/`).
- `openapi/` - a small standalone docs/schema project (its own Dockerfile,
  Makefile and `redoc-static.html`).
- `extra_scripts/` - also a separate git repository: `extract_service_logic/`,
  `graceful-shutdown-test-app/`, style tests.
- `config/redis/redis.conf`, `postman-collections/`, `.github/workflows/`
  (per-environment CI/CD: STAGE/PROD k8s, USA, UZ, Mexico, db-backup, sdd-gate,
  PR-source-branch check).

## Specs and contracts

- Capability specs for this repository: `openspec/specs/` - currently
  **`openspec/specs/agent-configuration/spec.md`** (~704 lines, extracted by
  `spec-miner` from `app/agent/service/agent_service.py`,
  `api/v1/agent/agent.py`, `app/agent/model/agent.py`). It is the normative
  description of agent creation, the default provider cascade, template
  instantiation, lifecycle (update/delete/copy), the per-component configuration
  surfaces and the integration-facing read model and its cache. Read it before
  touching anything under `app/agent/`.
- Changes go through `openspec/changes/<id>/` (rule: no code without a spec; for
  refactoring/tooling use `skip_specs: true` in the change metadata). Completed
  changes are archived in `openspec/changes/archive/`.
- Config: `openspec/config.yaml` (`schema: spec-driven`).
- **spec-guard is enabled in this repository** (ADR-0003, layer 2):
  `.spec-guard-paths` lists `backend/`, and `.claude/settings.json` wires
  `.claude/hooks/spec-guard.cjs` as a `PreToolUse` hook on `Write|Edit`. Editing
  any file under `backend/` is blocked unless an active change exists under
  `openspec/changes/<id>/`. Create the change first, then write code.
- A second hook, `.claude/hooks/block-no-verify.cjs`, blocks git hook bypasses
  (`--no-verify`) on `Bash`.
- Cross-service contracts with WBN (RabbitMQ RPC actions, agent read model) are
  described in `docs/va-not-task/RPC_IMPLEMENTATION.md`,
  `docs/va-not-task/RPC_SUMMARY.md` and `docs/va-not-task/RPC Logic Analysis.md`;
  the code is the source of truth (`app/base/enum.py` `RPCRequestAction` /
  `RPCResponseStatus`, `app/agent/schema/rpc_schemas.py`).

## Do not edit by hand

- `backend/migrations/versions/*.py` - Alembic revisions. Generate with
  `make migrate`, then review; never hand-write a new revision file. Several
  large ones are data seeds (`bdf2b27166df_insert_initial_data.py`,
  `e2d8a9c3f4b6_add_parakeet_11labs_aws.py`, ...).
- `docs/MAP_VA.md` and `docs/MAP.md` - regenerated by `python3 docs/build_map.py`
  and automatically by the `docs/.githooks/pre-commit` hook.
- `graphify-out/` - knowledge graph output, rebuilt by a post-commit hook
  (`.graphifyignore` controls scope).
- `openapi/openapi.json`, `openapi/redoc-static.html` - generated from the app.
- `backend/.env*` - environment files, not in git; the tracked sample is
  `backend/voice-agent-constructor-backend.env`.
- Caches and artifacts: `.ruff_cache/`, `.mypy_cache/`, `.complexipy_cache/`,
  `.pytest_cache/`, `logs/`, `backend/log/`, `*.log`, `test_errors.tmp`, and the
  `*.dump` database dumps at the root.

## Repository rules

1. **Layering is strict.** `api/v1/<module>` (endpoints, DI, status codes) ->
   `app/<module>/service` (all business logic) -> `app/<module>/repo` (all DB
   access) -> `app/<module>/model`. Endpoints hold no business logic; services
   issue no queries; repos hold no business rules.
2. **Base classes are mandatory.** Models inherit `BaseModel`
   (`app/base/model/base_model.py`: `id` BigInteger + `uuid` + `created_at` /
   `updated_at` / `deleted_at` + `enabled`), schemas inherit `BaseSchema`,
   services inherit `BaseService`, repos inherit `BaseRepo`. Use SQLAlchemy 2.0
   style - `Mapped[...]` + `mapped_column()`, `relationship(back_populates=...)`,
   `TYPE_CHECKING` imports for relationship types. Never `Column()`.
3. **Naming follows this code, not WBN's.** `BaseRepo` exposes generic
   `get_by_id` / `get_by_uuid` / `get_list` / `get_by_filters`; module repos add
   `fetch_*` and `find_*` query helpers (see `app/agent/repo/agent_repo.py`).
   Services expose `get_*` / `create` / `update` / `delete` and return schemas,
   not ORM rows - mapping goes through `BaseMapper.to_dto` / `to_entity`.
   snake_case for functions and variables, PascalCase for classes,
   UPPER_SNAKE_CASE for constants. Deletes are soft (`deleted_at`).
4. **Datetime discipline is test-enforced.** Import `datetime`, `date`, `time`,
   `timedelta`, `timezone`, `ZoneInfo` **only** from `app.base.datetime_utils`;
   `pytz` is banned. `tests/unit/test_no_raw_datetime_imports.py` and
   `tests/unit/test_no_pytz.py` scan `app/`, `api/`, `core/`, `messaging/`,
   `background_workers/` and fail on violations. The only escape hatch is an
   explicit `# DEVIATION:<ticket>` marker. Store aware UTC datetimes
   (`get_current_datetime()`).
5. **No magic literals.** Repeating text values (statuses, messages, actions,
   details) go into an enum in `app/base/enum.py` (33 enums today, e.g.
   `Message`, `RPCRequestAction`, `RagKnowledgeBaseStatus`, `DeploymentMode`);
   configuration numbers, timeouts, limits and endpoints go into
   `core/config.py` - nested `BaseSettings` groups reached as
   `settings.redis.*`, `settings.rabbitmq.*`, `settings.s3.*`,
   `settings.shutdown.*`, `settings.taskiq_worker.*`, `settings.agent_prompt.*`.
   Provider names and endpoints belong in the database, not in code.
6. **Call functions with named arguments** whenever there is more than one
   argument (`service.get_agent(db=db, uuid=uuid)`), matching the existing style
   in `main.py`, the services and the repos.
7. **Errors are `HTTPException`.** No custom exception hierarchy in services;
   raise `HTTPException(status_code=..., detail=Message.<ENUM>)` from services
   and endpoints. Log with `loguru` (`logger.exception` inside `except`) and
   never swallow an exception silently.
8. **Async all the way.** `AsyncSession`, `asyncpg`, `httpx.AsyncClient`, async
   FastStream/TaskIQ. Do not introduce sync DB access or blocking I/O into
   request paths; long-running work becomes a TaskIQ task under
   `background_workers/tasks/`, with its runner registered as a compose service.
9. **Graceful shutdown is a contract.** Any new long-lived resource (broker,
   client, pool) must register a cleanup callback via
   `graceful_shutdown_manager.register_cleanup_callback()` in the `main.py`
   lifespan, keeping the existing order (broker -> cache -> RAG client -> Redis ->
   DB). Coverage lives in `tests/shutdown/` and
   `tests/test_graceful_shutdown.py`.
10. **Cache invalidation is part of the change.** Agent read models are cached
    with `cashews` (`app/base/cache.py`, `app/base/cache_utils.py`); any write
    path that changes agent configuration must invalidate the matching keys -
    see `tests/unit/test_agent_kb_cache_invalidation.py` and
    `tests/unit/test_kb_delete_agent_cleanup.py`.
11. **`app/agent/service/agent_service.py` is a 7311-line monolith** (~145
    methods) and its router `api/v1/agent/agent.py` is 1749 lines with 49 route
    handlers - the next largest router has 12. **Do not add new endpoint or
    business logic to either file.** New agent-adjacent behaviour goes into a
    focused service module (the pattern already used by `agent_rpc_service.py`,
    `agent_asr_settings_service.py`, `post_call_analysis_segment_service.py`,
    `agent_config_serializer.py`, `agent_config_applier.py`) with its own router
    package under `api/v1/`.
12. **Stay in scope.** Implement only what the ticket asks. If you find an
    unrelated bug, write a short note so a separate ticket can be opened instead
    of fixing it in the same change. Verify claims against the code, not against
    docs or old reports - several `docs/va-*` files describe superseded
    behaviour.
