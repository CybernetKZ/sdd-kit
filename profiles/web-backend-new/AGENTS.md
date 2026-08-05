# AGENTS.md - context for AI agents

<!-- Limit: 500 lines. Checked by scripts/sdd/check.sh. -->
<!-- CLAUDE.md in this repo is a symlink to this file (ADR-0002). -->

Extra Cursor rules for this repo: `.cursor/rules/web-backend-new-rules.mdc`,
`.cursor/rules/newman-postman-review.mdc`.

## What this repo is

`web-backend-new` is a **monorepo of several services** that together form an
outbound/inbound calling platform driven by AI voice agents: a call campaign is
uploaded and validated, turned into per-call dial jobs, dispatched to Asterisk at
a controlled speed, and after each call the transcript/outcome is analysed and
retries are scheduled. Services talk over RabbitMQ queues and Redis streams
(`TELEPHONY_IN`, `CHAT_IN`, `POST_CALL_ANALYTICS_LLM_REPORT`) and share one
PostgreSQL database.

- `backend/` - main FastAPI app: REST API (`api/v1`, `api/internal/v1`), call
  campaigns, calls/call events, firms/users, DB models and Alembic migrations,
  background task workers, WebSockets.
- `validation-service/` + `validation-worker` - validates uploaded call-campaign
  files (RabbitMQ `VALIDATION_IN` -> `VALIDATION_OUT`).
- `asterisk-json-creator-llm/` - turns a `CallBatchMessage` into Asterisk call
  files + `EngineRedisJson` (agent prompt/config) and `XADD`s them to
  `stream:call_campaign_{uuid}`.
- `call-dispatcher-llm/` - manager/worker dispatcher: pops dial jobs per campaign,
  honours campaign speed, working hours and retry timing.
- `post-call-processor-llm/` - consumes telephony and judge/LLM report streams,
  resolves the call outcome, writes results to DB/S3, fires agent webhooks and
  schedules retries (timer-based and cycle-gated).
- `post-chat-processor/` - the same post-processing role for chat conversations
  (`CHAT_IN`).
- `sso-service/` - authentication / SSO (own Alembic migrations).
- `api-gateway-service/` - edge proxy: SSO auth middleware, rate limiting,
  route rules, WebSocket proxying, graceful shutdown.

Supporting dirs: `docs/` (documentation, see `docs/MAP.md`), `openspec/` (specs),
`scripts/` and `extra_scripts/` (ops and analysis tooling), `config/`,
`postman-collections/`, per-service `values/` (Helm values).

## Commands

Everything runs through Docker Compose from the repo root (`docker-compose.yml`);
`make` with no target prints the full help.

- `make help` - list all targets (default goal).
- `make build` / `make build_no_cache` - build images.
- `make run` - start all services detached; `make run_verbose` - foreground.
- `make build_run` / `make run_rebuild` - build then start.
- `make watch` - Compose watch mode (auto rebuild on change).
- `make status` / `make logs [service]` / `make stop` / `make down`.
- `make enter_backend` - shell inside the running backend container.
- `make test` - backend tests: `docker compose run --rm backend sh -c "export ENV='TEST' && pytest"`.
- `bash scripts/sdd/check.sh` - SDD checks (AGENTS.md present and ≤500 lines, `openspec validate --all --strict`).
- `make migrate name="..."` - autogenerate an Alembic revision for backend.
- `make migrate_upgrade` / `make migrate_downgrade` - apply / revert one migration.
- `make create_db` / `make drop_db` / `make clear_redis_cache`.
- `make poetry_install` - `poetry install --no-root` inside the backend container.
- `make update_env` - regenerate `.env` files from their `.env.example` (`scripts/update_env.sh`).
- `make check_network` / `make check_rabbitmq` / `make monitor_resource_usage` - diagnostics.
- `./run_e2e_test.sh` - end-to-end scenario run.
- `post-call-processor-llm/run_tests.py` + `post-call-processor-llm/docker-compose.test.yml` - PCP test runner (its tests are not part of `make test`).

Compose files: `docker-compose.yml` (default local/dev), `docker-compose-local.yml`,
`docker-compose.prod.yml`, `docker-compose.web2001-local-e2e.yml` and
`docker-compose.web2001-judge-local.override.yml` (E2E overrides).

## Module map

Top level - one service per directory (see the service list above). Each service
has its own `pyproject.toml` / `poetry.lock`, `Dockerfile.<service>`, `main.py`
and `values/` for deployment.

### backend/ (see also "Project Structure" below)

`api/v1` and `api/internal/v1` (endpoints) -> `app/{module}/service` (business
logic) -> `app/{module}/repo` (DB access) -> `app/{module}/model`; `app/base/`
holds base classes and enums, `core/` config and security, `database/` engine,
session, triggers and helpers, `migrations/` Alembic, `messaging/` RabbitMQ,
`background_task_workers/` async workers, `websockets_service/` WS handlers.

### post-call-processor-llm/

```
post-call-processor-llm/
├── main.py               # entrypoint: starts telephony/judge consumers + maintenance
├── service/              # business logic: telephony_consumer, judge_consumer,
│                         #   call_processor, telephony_outcome_resolver,
│                         #   retry_service / retry_scheduling, business_rules/,
│                         #   agent_webhook_sender, s3_storage, db_service
├── repo/                 # data access only: db_read, db_write*, cache_redis*,
│                         #   engine_redis* clients
├── core/                 # config, enum, redis_manager, graceful_shutdown,
│                         #   instance_hex_manager (per-pod consumer groups)
├── schema/schema.py      # Pydantic schemas
├── model/model.py        # SQLAlchemy models (shared DB)
├── background_workers/archive/  # call-event archive worker (own Dockerfile)
├── util/                 # s3_audio, working_hours, misc helpers
└── tests/                # unit/, integration/, fixtures/ (+ tests-cross/)
```

### docs/

`docs/MAP.md` is the generated index of all WBN docs (`docs/MAP_VA.md` for the
sibling VA repo). Docs are grouped by folder: `wbn-project-logic/` (cross-service
logic and contracts), `wbn-project-rules/`, `wbn-post-call-processor/`,
`wbn-call-campaigns/`, `wbn-call-events/`, `wbn-migrations/`, `wbn-incidents/`,
`wbn-devops/`, `wbn-ci-cd/`, plus `WEB-####` task folders.

## Specs and contracts

- Capability specs for this repo: `openspec/specs/`; config: `openspec/config.yaml`.
- Changes go through `openspec/changes/<id>/` (rule: **no code without a spec**;
  for refactoring/tooling work set `skip_specs: true` in the change metadata).
  Completed changes live in `openspec/changes/archive/`.
- `bash scripts/sdd/check.sh` runs `openspec validate --all --strict` - it must stay green.
- Shared cross-service contracts belong in the central store repo (ADR-0001),
  wired in via `references:` in `openspec/config.yaml`.
- Until that move is done, the **source of truth for Redis keys, streams, TTLs and
  owner/consumer** is in `docs/wbn-project-logic/`:
  - `POST_CALL_PROCESSOR_LLM_REDIS_CONTRACT.md` - normative table of all Redis
    keys/streams (any doc that disagrees with it is wrong).
  - `TELEPHONY_IN_REDIS_STREAM_CONTRACT.md` - the `TELEPHONY_IN` stream contract.
  - `OVERALL LOGIC_240526.md` - narrative cross-service boundary contract
    (BACKEND -> ASTERISK-JSON-CREATOR -> CALL-DISPATCHER -> POST-CALL-PROCESSOR /
    POST-CHAT-PROCESSOR).

## Generated, do not hand-edit

- `backend/migrations/versions/*.py` - Alembic revisions; create them with
  `make migrate name="..."` (autogenerate), never hand-write a new file.
  Same for `sso-service/migrations/versions/` (gitignored, see `.gitignore`).
- `docs/MAP.md`, `docs/MAP_VA.md` - regenerated by `python3 docs/build_map.py`,
  and automatically on commit via the `docs/` submodule hook `docs/.githooks/pre-commit`.
- `docs/wbn-project-logic/_traces_*/` - per-service call traces generated by
  `extra_scripts/extract_service_logic/` (see the command in `OVERALL LOGIC_240526.md`).
- `graphify-out/` (root and per-service) - graphify output, driven by `.graphifyignore`.
- `.env` files produced by `make update_env` / `scripts/update_env.sh` - edit the
  `.env.example` source instead.
- Coverage/test artifacts (`htmlcov/`, `*.log`, `reports/`) - regenerate, don't edit.

---

# Repository rules (backend/)

Here are some best practices and rules you must follow:

- You use Python 3.11
- Frameworks:
    - pydantic v2
    - fastapi
    - sqlalchemy 2.0
    - PostgreSQL 16
    - Redis 7.2
    - RabbitMQ 3

## Task Scope

- Never go beyond the scope of the task described in YouTrack. Implement only what the ticket asks for.
- If a related issue or bug is discovered along the way, write a short mini-report (so a systems analyst can open a separate task for it) and do NOT fix it in the current code/PR.

## Core Rules

### Models (SQLAlchemy 2.0)

- All models inherit from `BaseModel` (app/base/model/base_model.py)
- BaseModel provides: id, uuid, created_at, updated_at, deleted_at, enabled
- Use `Mapped[]` type annotations
- Use `mapped_column()` not `Column()`
- Define relationships with `Mapped[]` and `relationship()` and `back_populates`

### Schemas (Pydantic v2)

- All schemas inherit from `BaseSchema` (app/base/schema/base_schema.py)
- Use built-in Pydantic v2 methods (model_validator, field_validator, computed_field)
- Create separate schemas: Base, Create, Update, Read, optional ReadShort
- Leverage `model_validate()` for ORM conversion
- avoid use dataclass -> instead pydantic

### Services

- Inherit from `BaseService` (app/base/service/base_service.py)
- Handle all business logic !!! This is IMPORTANT!
- Method names for retrieval start with `get_`
- Return schemas, not ORM models
- Use dependency injection for repositories

### Repositories

- Inherit from `BaseRepo` (app/base/repo/base_repo.py)
- Handle only direct database operations !!! This is IMPORTANT!
- Method names for retrieval start with `fetch_`
- Return ORM models or None
- Use async sessions

### API Endpoints

- Located in `api/v1/{module}/` and `internal/api/v1/{module}`
- Use dependency injection for services
- Return appropriate HTTP status codes

## Naming Conventions

- ALWAYS: Clear and full names. BAD: campaign / Campaign; GOOD: call_campaign / CallCampaign. EXCEPTION: inside the `call_campaign` or `external_campaign` service/repo (e.g. backend/app/call_campaign/service/*, .../repo/*), the short name `campaign` / `Campaign` is allowed.
- Functions/Variables: snake_case
- Classes: PascalCase
- Constants: UPPER_SNAKE_CASE
- Repo methods: fetch_* (e.g., fetch_by_id)
- Service methods: get_* (e.g., get_user_profile)

## Best Practices

1. Simplicity: Write clear, simple code
2. Functions/methods should be reasonable length: (not trivial and not overloaded).
3. Type Hints: Use type hints where useful
4. Keep comments/docstrings brief and direct: prefer one-line docstrings/comments.
5. PEP 8: Follow strictly
6. Async: Use async/await consistently
7. Error Handling: DO NOT use custom exceptions in services, use HTTPException in endpoints and services
8. Use Enums for Predefined Text: For any repeating text values like statuses, details or types (e.g., "active", "
   admin"), you MUST use an Enum from app/base/enums.py. Exceptions ONLY for logging.
9. Use Settings for Numbers: For any configuration numbers (e.g., page sizes, retry counts), you MUST use the settings
   object from core/config.py.
10. Use Explicit Function Arguments: When calling a function with more than one argument, you MUST name each argument
    explicitly.
    Correct:

```
service.get_events(
    db=db,
    limit=limit
)
```

Wrong:

```
service.get_events(db, limit)
```

## Key Patterns

- Pagination: Use `PaginatedResponse` from base schema
- Soft Deletes: Use deleted_at field
- UUID: Every model has both id and uuid
- Timestamps: Automatic created_at/updated_at
- Enabled Flag: Use for active/inactive states

## Don'ts

- Don't mix sync and async code
- Don't return ORM models from services
- Don't put business logic in endpoints
- Don't put database queries in services (use repos)

## File Organization

Each module follows the pattern:

- `model/` - Database models
- `repo/` - Database operations
- `schema/` - Request/response models
- `service/` - Business logic
- API endpoint in `api/v1/{module}/`

## Project Structure

```
backend/
├── api/v1/           # API endpoints
├── app/              # Business logic modules
│   ├── {module}/
│   │   ├── model/    # SQLAlchemy models
│   │   ├── repo/     # Database operations
│   │   ├── schema/   # Pydantic schemas
│   │   └── service/  # Business logic
│   └── base/         # Base classes & utilities
├── background_task_workers/  # Async task workers
├── core/             # Config & security
├── database/         # DB setup & migrations
├── messaging/        # Message queue services
└── websockets_service/  # WebSocket handlers
```

## Additional Rules
- Always treat the codebase as the single source of truth for investigations; verify claims against actual code, not just docs or incident reports.
- Make minimal, in-scope changes only. Do not fix unrelated tests, refactor beyond the ticket, or reclassify/harden extra paths unless explicitly asked; prefer a single narrow gate over broad recovery logic.
- Follow a plan -> implement (TDD) -> code review -> live/dev verification -> docs workflow for ticket work, and confirm the fix against the original ticket spec before declaring done.
- Incident and technical reports intended for the team should be written in Russian when requested; default review comments to the established Russian style.
