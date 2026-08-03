# DEFECTS_CF — дефекты, найденные при миграции conversation_flow (ADR-0019)

Дата начала: 2026-08-03. Формат: как DEFECTS_BACKLOG.md — записано, не чинилось; тикет-материал.
Источники: `## Mismatches and defects` двух store-дельт (фаза 2) + отчёты верификаторов capability-спек (фаза 3, дополняется).

## Фаза 2 — контракт дозвонщика (add-cf-dialer-integration-api), 12 шт.

Полные формулировки — в дельте `cybernet-specs/openspec/changes/add-cf-dialer-integration-api/specs/cf-dialer-integration-api/spec.md`.

| # | Уровень | Суть |
|---|---|---|
| D1 | HIGH (security) | Гайд требует HTTPS для webhook URL; код принимает http/https — `allow_http` no-op (`api/webhooks.py:76-79`, `webhooks/service.py:14-17`) |
| D2 | HIGH (contract) | Webhook `call.status` = `ended\|active`, REST `status` = `queued\|ringing\|ongoing\|ended\|failed` — одно имя поля, два словаря; `"failed"` в событии не приходит никогда (`webhooks/payloads.py:226`) |
| D3 | MEDIUM | Объект звонка отдаёт 5 недокументированных полей: `media_started_at`, `talk_from`, `talk_to`, `events`, `cost` |
| D4 | MEDIUM | Транскрипт-тёрны отдают недокументированные `pending`/`ts`/`spoke_at`; `pending` семантически значим |
| D5 | MEDIUM | Recording-блок вебхука: недокументированные `audio_started_at`/`audio_ended_at`/`coverage`; форма `recording` в REST и вебхуке различается |
| D6 | MEDIUM | `/v1` шире гайда: turns, TTS-cache, 6 привилегированных операций каталога под тем же key-auth |
| D7 | LOW | Обещанный `404` на неизвестный `agent_id` в `POST /v1/calls/phone` не случается — там `403`; `404` только у `/v1/calls/web` |
| D8 | LOW | `error.message` на 422 — массив, не строка (`api/main.py:611-617`) |
| D9 | LOW | `ring_duration <= 0` валидируется после лимитов транка — `429` может маскировать документированный `400` |
| D10 | LOW | `observer_incident.severity` молча дефолтится в `medium` |
| D11 | LOW | `ping` шлёт реальный `agent_id` (не `""`) и опускает `flow_version`/`flow_version_id`/`metadata` |
| D12 | LOW | `has_more` считается по префильтр-итогу; `next_cursor: null` (а не отсутствует) на последней странице |

## Фаза 2 — контракт RAG (add-cf-rag-contract), 13 шт.

Полные формулировки — в дельте `cybernet-specs/openspec/changes/add-cf-rag-contract/specs/cf-rag-contract/spec.md`.

| # | Уровень | Суть |
|---|---|---|
| R1 | HIGH | Лимиты `SearchRequest` (limit 1..100, threshold 0..1) не энфорсятся в `KnowledgeSearchSettings` — `limit: 500` даёт 422 без ретрая, RAG у флоу молча выключен навсегда |
| R2 | HIGH | Мягкая деградация ловит только `RagError`; парсинг ответа внутри — изменение схемы `SearchResponse` продюсером роняет тёрн `ValidationError`'ом |
| R3 | MEDIUM | Method-agnostic retry-цикл ретраит оба POST без объявленной идемпотентности |
| R4 | MEDIUM | `GET /knowledge-bases/{id}` пагинирует вложенные `files` по 10, CF не шлёт параметров — безопасно случайно |
| R5 | LOW | OpenAPI объявляет `maximum: 1000` и «≤ 100» на одном параметре |
| R6 | LOW | 4 операции объявляют голый `200 {}` рядом с типизированным 201 |
| R7 | MEDIUM (perf) | `vector_embedding` обязателен в каждом результате поиска на латентном пути — CF его выбрасывает |
| R8 | LOW | CF ослабляет 3 обязательных поля ответа (осознанная толерантность, но слепота к регрессии продюсера) |
| R9 | MEDIUM | §11.9 пинит литеральный адрес `http://10.0.2.7:5002` |
| R10 | MEDIUM | §11.9 vs OpenAPI: разные имена S3-бакета (`stage-v3-rag-files` vs `cybernetrag-kb-bucket`) — read-grant требует подтверждения |
| R11 | LOW | Дублированный enum file-status в документе |
| R12 | LOW | `RagUnavailable` покрывает только transport-fail: hard-down → 502, refused → 503 |
| R13 | LOW | Отрицательный `RAG__RETRIES` даёт `TypeError` из `raise None`, утекает через R2 |

## Фаза 3 — верификация capability-спек (дополняется)

_MISMATCH-вердикты верификаторов добавляются сюда по волнам._
