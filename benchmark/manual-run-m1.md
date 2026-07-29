# Ручной прогон m1 — стартовый снапшот (кондуктор)

Дата подготовки: 2026-07-29. Статус: **готов к «старт nude»**.

## Зафиксировано

| Параметр | Значение |
|---|---|
| SHA обоих клонов (dev) | `8d5620b0cbe7ef0c736440dd0d952c89de734062` |
| nude-клон | `refactor_v4/nude-claude/web-backend-new` (без каких-либо agent-артефактов; в репо только `.cursor/`) |
| sdd-клон | `refactor_v4/sdd-kit-claude/web-backend-new`, bench-base = SHA + kit-коммит (AGENTS.md заполнен, spec `api-gateway-authorization` 16 req, store `cybernet-specs` подключён — 8+ спеков, вкл. external-webapi-authorization; `make sdd-check` OK) |
| push | отключён в обоих клонах (`push URL = DISABLED`) |
| claude CLI | 2.1.220 (одинаковый для обеих арм) |
| OTEL-коллектор | docker `bench-otel`, :4317, file exporter → `~/bench/otel/data/` |
| pytest baseline | 4 known failures в ОБОИХ клонах (graceful_shutdown ×3 + openapi/docs rate-limit) — гейт считает только НОВЫЕ падения |
| ruff baseline | считается по изменённым файлам на «стоп» (CPY001 исключён как репо-шум) |
| конфиги арм | nude → `CLAUDE_CONFIG_DIR=~/bench/cfg-a` + `--strict-mcp-config` (проверено: 0 mcp/skills/plugins/hooks; в cfg-a только theme+credentials; паразитный `.claude/settings.local.json` из клона удалён); sdd → `~/bench/cfg-b` **+ tools** (см. ниже) |
| sdd-арма tools (арма = «sdd-kit+tools») | MCP: youtrack ✔ (потребовался пин `mcp<2` в `.mcp.json` — mcp 2.x выпилил FastMCP; пин закоммичен в bench-base, НУЖНО ВНЕСТИ В ШАБЛОН KIT'А), context7 ✔, serena ✔, headroom ✔, searxng ✔ (приходит с аккаунта claude.ai); plugin: ponytail 4.7.0; skill: graphify (символлинк в cfg-b/skills) + готовый кэш `graphify-out/` 1.5G скопирован в клон (в `.git/info/exclude`, в диффы не попадёт); project MCP предодобрены, trust выставлен |
| модели | main = **opus** в обеих армах (реальный воркфлоу: opus планирует/дирижирует, sonnet-субагенты исполняют; fable для особо сложных — тогда в обеих армах). OTEL пишет разбивку по моделям |

## Ожидаю от тебя перед «старт nude»
1. Текст задачи (один и тот же для обеих арм).
2. Модель/effort (рекомендация: sonnet, effort по умолчанию, одинаково).
3. Подтверждение критерия финиша (по MANUAL.md §1.4).

Экспорт-блоки — в MANUAL.md §1–2 (пути уже соответствуют refactor_v4/*).
