# Ручной бенчмарк m2 — WEB-2234

Задача: **WEB-2234 — API upload xlsx сравнивает ненормализованные номера**
(https://support.cyber-net.ai/issue/Web-2234, blocked-статус игнорируем).
Текст тикета (одинаковый для обеих арм): `~/bench/prompt-m2.md` — вставь сам,
без походов в YouTrack из сессии nude (в sdd-сессии youtrack-mcp разрешён как
часть kit'а, но стартовый текст тот же).

Порядок m2 (чередование с m1): **сначала sdd, потом nude**.
Критерий финиша тот же, что в m1: код + тесты + ruff зелёный + «открыл бы PR».

Подготовка: `! bash /home/octrow/cybernet/refactor_v4/sdd-kit/benchmark/archive-m1-m2/prepare-m2.sh`
Снапшот: `refactor_v4/logs/prep-m2-snapshot.txt` (SHA заполняется скриптом).

## Сессия 1 — sdd

```bash
cd /home/octrow/cybernet/refactor_v4/sdd-kit-claude/web-backend-new

export CLAUDE_CONFIG_DIR=$HOME/bench/cfg-b
export CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=otlp OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_METRIC_EXPORT_INTERVAL=10000
export OTEL_RESOURCE_ATTRIBUTES="arm=sdd,task=WEB-2234,run=m2"

claude --model opus
```

Внутри: «старт sdd» кондуктору → `/feature-flow WEB-2234` или текст тикета →
работа по методологии → ревью → Ctrl+D → «стоп sdd».
Project MCP (context7, youtrack) при вопросе о доверии — одобри.

## Сессия 2 — nude (после полного завершения сессии 1)

```bash
cd /home/octrow/cybernet/refactor_v4/nude-claude/web-backend-new

export CLAUDE_CONFIG_DIR=$HOME/bench/cfg-a
export CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_METRICS_EXPORTER=otlp OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_METRIC_EXPORT_INTERVAL=10000
export OTEL_RESOURCE_ATTRIBUTES="arm=nude,task=WEB-2234,run=m2"

claude --model opus --strict-mcp-config
```

Внутри: «старт nude» → тот же текст тикета из `~/bench/prompt-m2.md` →
обычная работа (opus main + sonnet-субагенты) → Ctrl+D → «стоп nude».

## Правила (кратко, полные в MANUAL.md)

- Один текст задачи, вставленный одинаково; сессии последовательно.
- Модельный воркфлоу одинаковый: opus main + sonnet-субагенты.
- На «стоп» назови число ручных вмешательств (вырулить агента).
- Не смотри метрики первой армы до завершения второй.

## Снапшот старта (заполняет кондуктор после prepare-m2.sh)

- base SHA: _см. prep-m2-snapshot.txt_
- клоны: пересозданы, push отключён, .env скопированы
- арма B: kit установлен (обновлённый: mcp<2 пин, core-тулзы), AGENTS.md
  курированный, спеки посеяны, graphify-кэш скопирован, состояние закоммичено
  в bench-base
- арма A: голая, `--strict-mcp-config`
- конфиги: cfg-a (пустой), cfg-b (serena, headroom, ponytail, graphify skill)
- OTEL: bench-otel :4317

## Журнал m2

- **старт sdd: 2026-07-30T02:04:07+05:00** — клон чист на bench-base
  (cf346556, base 8d5620b0), cfg-b, claude 2.1.220, теги
  `arm=sdd,task=WEB-2234,run=m2`.
- **стоп sdd: 2026-07-30T03:00:23+05:00** — wall clock 56.3 мин;
  сессия 3683267c, 3 промпта (`/feature-flow WEB-2234`, `/opsx:apply`,
  «run the reviewer agents on the diff»); $12.73 (opus $10.66 out 56k
  cacheR 13.3M; sonnet $2.06 out 37k; haiku ~$0); дифф 632 строки:
  call_service.py + новый тест (9 passed) + openspec/changes; ruff: 0 новых
  в call_service.py, в новом тесте 4×SLF001 + 1×PT011; артефакты в
  logs/manual-m2/.
- **старт nude: 2026-07-30T11:16:10+05:00** — клон чист на bench-base
  (8d5620b0), cfg-a, `--strict-mcp-config`, теги `arm=nude,task=WEB-2234,run=m2`.
- **стоп nude: 2026-07-30T11:54:54+05:00** — wall clock 38.7 мин; сессия
  bb3dfff0, 4 промпта (PLAN по тексту тикета из docs/ → implement → review →
  implement suggestions in scope); $8.13, ТОЛЬКО opus (out 66k, cacheR 10.0M;
  sonnet-субагентов не было — отклонение от заявленного воркфлоу); дифф
  +322/−5, 3 файла (call_service.py, config.py, новый тест 264 строки);
  тесты 13 passed (новый) + 84 passed (юнит-сьюты рядом); ruff: prod-код
  29→29 и 6→6 (0 новых), новый тест 18×SLF001; тикет+plan.md лежали в
  gitignored docs/ (заархивированы в logs/manual-m2/WEB-2234-nude-m2-docs).
  Отклонение протокола: метрики sdd-армы были показаны до старта nude.
- Ручные вмешательства (по определению Daniil = число user input):
  sdd = 3, nude = 4.
