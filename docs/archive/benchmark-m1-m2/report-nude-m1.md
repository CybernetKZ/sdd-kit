# Отчёт: ручная сессия nude-claude (m1, WEB-2314)

Сессия `f643387d`, 20:06-21:29 локального (~83 мин wall), конфиг `cfg-a`
(0 mcp/skills/plugins/hooks), `--strict-mcp-config`, main = opus.

## Стоимость и токены (OTEL, по моделям)

| Модель | Cost | input | output | cacheRead | cacheCreate |
|---|---|---|---|---|---|
| **opus-5** (main brain) | **$18.25** | 13.8k | **160k** | 20.5M | 443k |
| **sonnet-5** (субагенты) | **$10.14** | 4.4k | **166k** | 15.9M | 751k |
| haiku-4.5 (фон) | $0.002 | 1.6k | 32 | 0 | 0 |
| **Итого** | **$28.39** | | 326k | 36.4M | 1.19M |

- Cache hit rate ≈ 99.9% (opus: 20.5M cacheRead vs 13.8k uncached input).
- Opus = 64% стоимости при 49% output-токенов - дирижирование дорогое.
- Компактификаций: 0 (окно не переполнялось).

## Паттерн работы (из транскрипта)

Человеческих промптов: **4** = ровно твой реальный воркфлоу из INIT.md:
1. "старт nude" (маркер);
2. **PLAN** по задаче (проверить кодбазу и т.д.);
3. **implement PLAN** через sonnet-субагентов, чат = main brain/conductor;
4. **Review PR** (uncommitted vs dev) против цели задачи.

Субагентов: **8** - 1 разведчик на opus ("Gateway anatomy"), 7 на sonnet:
поиск RAG API, git-прецеденты добавления роутов, проверка SSO user-context,
имплементация generalization, фикс SSO, тесты gateway, проверка docs/deploy.

Инструменты main-сессии: Bash 66, Edit 22, Read 13, Agent 8, Write 4,
AskUserQuestion 1.

## Результат

- Дифф: **+1102/−74, 20 файлов** - существенно шире headless-прогонов:
  затронут не только api-gateway (rules, middleware, route_handler,
  request_forwarder, config, enum, schema + 6 тест-файлов + main.py +
  web_api_authorization.md), но и **sso-service** (key_service,
  jwt_redis_strategy + тесты) - SSO user-context для API-ключей.
- **Гейты: PASS.** pytest gateway: 52 passed, 3 failed - все три
  предсуществующие флейки graceful_shutdown (одна baseline-флейка
  с openapi/docs теперь даже проходит); новых падений нет; добавлено
  ~20 проходящих тестов. Ruff: новых нарушений по существу нет
  (E902 - артефакт замера на новом файле; в новых тестах есть SLF001
  "доступ к приватным членам" - стилистическая мелочь, CPY001 -
  репо-шум, исключён).

## Сравнение с headless-пилотом той же задачи (справочно)

| | headless A-1 (sonnet solo) | ручная nude m1 (opus+sonnet) |
|---|---|---|
| Cost | $4.71 | $28.39 (×6) |
| Wall | 12 мин | 83 мин |
| Дифф | +138/−7, 6 файлов | +1102/−74, 20 файлов |
| Scope | только gateway | gateway + SSO user-context + docs |

Интерактив с opus-дирижёром в ~6 раз дороже и в ~7 раз дольше, но сделал
заметно более полную работу (SSO-цепочка, которую headless-раны вообще не
трогали, широкая тестовая обвязка). Качество и "принял бы PR" - оценит
сравнение с sdd-сессией и/или судья.

Все артефакты: `/home/octrow/cybernet/refactor_v4/logs/manual-m1/` (дифф, транскрипт, гейты,
ruff before/after, OTEL).
