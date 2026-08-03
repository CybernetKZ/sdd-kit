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
| ~~R1~~ | **ОТОЗВАН 2026-08-03, дельта исправлена** | ❌ Ложноположительный. `KnowledgeSearchSettings._threshold_range` (0..1) и `._limit_range` (1..100) в `engine/schema.py:697-709` **энфорсят** границы (ValueError при выходе), существуют с исходного коммита ТЗ №42 (`29e0a64d` — проверено `git show`). Найден майнером `rag` при перекрёстной сверке, подтверждён мной лично, пункт удалён из store-дельты; требование про форму `POST /search` переписано (границы зеркалятся и энфорсятся на стороне CF при сохранении флоу, остаточный риск — они не пинятся контрактом, нужна ручная сверка, если CybernetRAG изменит свои) |

Прим.: остальные 12 пунктов дельты перепроверены построчно по коду и OpenAPI — **все подтверждены**, ни один не выдуман; в самой дельте они перелитерованы a–l после удаления ложного.
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

## Пробелы покрытия конвертации (не дефекты кода — работа фазы 3)

Подтверждено верификаторами волны 3: следующие реализованные и протестированные куски §8 не покрыты НИ ОДНОЙ capability-спекой — закрываются волной 4.

| # | Что | Где код | Кто подтвердил |
|---|---|---|---|
| G1 | **Transfer-рантайм** (§8.9, ТЗ №28 cold/warm): hold, брифинг, бридж и наблюдение за ним, хендофф, запись после перевода | `livekit_agent/agent.py:1630-2009` (`_cold_transfer`/`_warm_transfer`/`handle_transfer`) | telephony делегировал в call-control (`telephony/spec.md:385-391`), call-control не взял — верификатор call-control подтвердил дыру |
| G2 | Пайплайн авто-завершения (§8.8 §6): `auto_end_call` → `end_reason` → `POST /api/calls/{room}/status` → `compute_disposition`/`AUTO_END_DISPOSITIONS` → гейт ТЗ №21 → `call_ended.disconnect_reason` | `livekit_agent/agent.py`, `analytics/` | верификатор call-control |
| G3 | Быстрое завершение по брошенной трубке (§8.13 §3): `participant_disconnected` → событие `hangup` → немедленное закрытие джоба вместо ожидания `silence_timeout` | `livekit_agent/agent.py` | верификатор call-control (grep: `participant_disconnected` нет ни в одной спеке) |
| G4 | ТЗ №83: коммит хвоста речи (`commit_speech_tail`, `HANGUP_COMMIT_TIMEOUT`) | `livekit_agent/` | верификатор call-control |
| G5 | Справочник голосов TTS — CRUD/lifecycle (§8.14 §2): сид+trilateral merge, custom-запись/архив, массовая замена source→target (`drafts_only\|republish`), `api/tts_voices.py`, привилегированные `/v1/tts-voices/*` | `storage/tts_voice_presets.py`, `api/tts_voices.py` | верификатор tts (в flow-schema только форма поля) |
| G6 | Лог TTS-чанков звонка (§8.12 §1): `VoicePublisher.tts_chunks` (потолок 500), персист в `sessions.meta.tts_chunks`, отдача в `GET /api/sessions/{id}`, раскладка по репликам в транскрипте | `livekit_agent/publisher.py`, `api/voice.py`, `api/main.py` | верификатор tts |
| G7 | UI-слои: `AsrModelPicker/AsrModelsPage` (asr), `VoicesPage/VoicePicker` (tts) — не Requirement и не в исключениях | `editor/src/` | верификаторы asr, tts |
| G9 | `resolve_health_port()` + подключение к запуску `WorkerOptions(port=…)` через `_worker_kwargs` (`agent.py:2321-2334`, уточнение N3): — порт health/status-сервера голосового воркера из `CFLOW_AGENT_HEALTH_PORT` (чтобы несколько LiveKit-агентов на одном хосте не конфликтовали за bind) не покрыт ни одной спекой. Это внутренний health-сервер библиотеки livekit-agents, к Prometheus-пайплайну `monitoring` отношения не имеет — место требования: capability, владеющая пулом голосовых воркеров | `livekit_agent/worker_load.py:61-88` (мерж `e62d5e5d`) | fixup monitoring |
| G8 | **Сквозной пробел между двумя спеками**: §10.6 UI предложений Copilot (diff-рендер, счётчик 1/N, ✓/✗, Undo) — `editor-ui/spec.md:14` отдаёт Copilot отдельной capability, а `copilot/spec.md` UI не берёт. Плюс §10.4: эндпоинт фидбека `POST .../feedback` (`api/copilot.py:372-377`) и шаринг `?copilot=<id>`; §10.5: контракт TestCase/asserts (типы ассертов, `max_turns` 12 с потолком `MAX_TURNS_HARD=40`, `simulate.py:25,124` — клэмп не специфицирован и не тестируется) | `editor/src/copilot/`, `api/copilot.py`, `copilot/simulate.py` | верификатор copilot |

### Расхождения в самой LIVING SPEC (не в спеках openspec)

| # | Где | Суть |
|---|---|---|
| L2 | DOCUMENTATION.md §9 (стр. ~3833-3834) | «Внутренние id в UI не показываются» — контр-пример в коде: `canvas/NodeCard.tsx:123` рендерит `node.name \|\| node.id`, а пустое `name` схемой разрешено. Либо править формулировку, либо валидировать непустоту имени (см. EU3). Найдено верификатором editor-ui |
| L1 | DOCUMENTATION.md §10.4 | «переписки персистентны (`data/copilot/`)» — устаревшая формулировка: фактически БД-таблицы `copilot_conversations`/`messages`/`proposals`. Найдено верификатором copilot; правится при следующем обновлении документа |

## Фаза 3 — верификация capability-спек (дополняется)

### Волна 1: flow-execution (верификация 2026-08-03, opus)

Спека: 17 req — 12 CONFIRMED чисто, 5 с находками. Доки/спека против кода:

| # | Уровень | Тип | Суть |
|---|---|---|---|
| E1 | HIGH | код или док | Уровень `default` у ГОВОРЯЩЕГО узла недостижим: §4:574 и порядок Always→equation→prompt→default обещают его всем узлам, но движок ходит по default только у silent-узлов (`engine.py:745`), transfer-fallback (`:1833`) и flex (`flex.py:379`). `conversation`-узел с единственным default-ребром (схема разрешает) — вечный STAY. Теста нет |
| E2 | HIGH | код | У flex нет silent-fallback: `_advance_flex` просто останавливается на `hops_exceeded` (`flex.py:348-352`) и непройденном silent-ребре (`:374-378`) — тихий тёрн, ровно та регрессия, которую ТЗ №90 чинило для rigid |
| E3 | MEDIUM | код | Flex на equation-переходе говорит И переходит (`flex.py:297-300`) — недокументированное исключение из execute-XOR-transition (или баг) |
| E4 | LOW | код | Неизвестный `decision` классификатора молча коэрсится в STAY внутри `_classify` (`engine.py:640-644`); ветка `[WARN] классификатор вернул неизвестный переход` (`:583-588`) — мёртвый код |
| E5 | LOW | док/спека | `history_window`: нечисловое значение даёт `ValueError` на конструировании, отрицательное клампится к 4 — а не «дефолт 40», как писали док и спека |

### Волна 2: persistence-versioning (верификация 2026-08-03, opus) — 3 MISMATCH, из них CRITICAL

15 req: 12 CONFIRMED, 3 MISMATCH. **V1 воспроизведён исполнением кода** (агент написал тесты, прогнал, удалил): изоляция организаций (ТЗ №40) НЕ универсальна — заявление спеки «энфорсинг централизован в репозиториях» ложно.

| # | Уровень | Тип | Суть |
|---|---|---|---|
| V1a | **CRITICAL** | код (утечка данных) | `WebhookDeliveryRepository.get/list/retry` (`storage/repos/webhooks.py:283,298`): у `WebhookDeliveryRow` нет `organization_id` и нет join'а к endpoint/session. Воспроизведено: org B получает delivery org A (url + payload). Достижимо по HTTP без route-guard: `GET /api/webhooks/deliveries` (`api/webhooks.py:146`), `POST …/{id}/retry` (`:166`) — **retry перевыстреливает вебхук чужого тенанта** |
| V1b | **CRITICAL** | код (утечка данных) | `CopilotRepository.get/delete/append_turn` (`storage/repos/copilot.py:245,250,280`): `s.get(CopilotConversationRow, id)` без гейта через `flow_id`. Воспроизведено: org B читает переписку org A |
| V1c | **HIGH** | код (утечка данных) | `ComponentRepository.usage` (`storage/repos/components.py:143`, также `_payload:567`, `flow_component_status:395`) и `observers.py:124`: `select(...).where(component_id==)` без `_scoped`. Воспроизведено: org A получает имя флоу org B **и его `organization_id`** |
| V1d | MEDIUM | код (деструктив, dead) | `telephony.py:136 unbind_agent` перебирает ВСЕ `SipTrunkRow` по `flow_name` — переименование агента-тёзки снесло бы привязки во всех орг. Вызывается только из теста |
| V1e | HIGH | код | `sessions.py:208`: при неудачном lookup флоу `organization_id` существующей сессии **перезаписывается** на `_stamp_org()` (= `org-root` для voice-воркера) — звонок тенанта молча уезжает в root |
| V2 | HIGH | код | `sqlite-idempotent-upgrade` не выполняется: 6 из 9 `_upgrade_to_*` (`storage/db.py:76-87`) без гварда `dialect != sqlite` и **выполняют DDL на Postgres при каждом старте приложения** (`_upgrade_to_multitenancy` безусловно шлёт `CREATE INDEX IF NOT EXISTS` по всем scoped-таблицам) — ровно та гонка «приложение vs раннер», которую требование объявляет предотвращённой |
| V3 | HIGH | код | `discard_draft` (`flows.py:524`) и `restore` (`:787`) копируют в черновик **инлайненный** published-документ: воспроизведено `['begin','component']` → `['begin','conversation','end']`. Черновик перестаёт быть символическим, флоу молча теряет синк с библиотекой, `_sync_component_refs` не вызывается → `component_refs` устаревают («используется в N агентах» завышено) |
| V4 | MEDIUM | код | `expand-contract`: сужающая смена типа (`alter_column(type_=…)`) линтером НЕ детектится, хотя требование объявляет её заблокированной; маркер `allow-destructive` файловый, не по-операционный |

Пробелы тестов, обнажившие V1–V3: нет тестов на cross-org для deliveries/copilot/component+observer usage; нет теста «на Postgres `_upgrade_to_*` — no-op» (поэтому V2 и не замечали); нет теста «discard/restore сохраняет черновик символическим».

### Волна 4: cost-analytics (верификация 2026-08-03, sonnet) — 1 MISMATCH, 5 новых дефектов

| # | Уровень | Тип | Суть |
|---|---|---|---|
| CA1 | MEDIUM (деньги, латентный) | код | `_pick_record` (`analytics/costs.py:64-95`): при ПУСТОМ входящем `model` (например `_stt_settings.model or ""`, `livekit_agent/agent.py:722`) условие матчит **любую** запись каталога того же провайдера, а не только записи с пустым полем модели. Это ровно та проблема, которую ТЗ №69 закрыло для LLM (`_llm_line`), но не портировало на ASR/TTS. Сегодня не эксплуатируется (по одной ASR-модели на провайдера в сидах) — активируется при добавлении custom-записей |
| CA2 | MEDIUM (деньги) | код | Отрицательные тарифы не валидируются: `_norm*` в `catalogs.py` и `api/llm_models.py` принимают `float` без `ge=0`. Отрицательная ставка даёт `computed`-строку с отрицательным `amount_microusd`, искажающим `total_microusd` |
| CA3 | LOW | код (MISMATCH спеки) | `reports/filters.py:14-38`: `ALLOWED_FILTER_KEYS` не включает `load_test`, который принимает `GET /api/sessions` (`api/routes/history.py:38,100`) — отчёт с тем же фильтром, что листинг, получает 400. Теста нет |
| CA4 | MEDIUM (латентный, класс V1) | код | `set_cost` и семейство (`set_disposition`, `set_call_status`, `set_health`, `set_analytics_status`, `save_analytics_batch`, `reconcile_talk_interval`, `storage/repos/sessions.py:848-861`) не делают org-check на уровне репозитория — в отличие от `get()` (`:627-629`). Сегодня безопасно только благодаря вызывающему коду (всегда после org-checked `get()` либо из воркер-контекста без scope); тот же паттерн, что дал CRITICAL в V1a/V1b/TA1 — сломается на первом admin/bulk-эндпоинте без предварительного `get()` |
| CA5 | INFO | спека (якорь) | Гарантия неизменности снапшота тарифа реализована в `analytics/service.py:_compute_cost` (`if entry.get("cost"): return`), а не в `analytics/costs.py:_rate_snapshot` (тот только строит dict), куда указывает `enforced:` |

Проверено чисто: арифметика микро-долларов без дрейфа float, идемпотентность `merge_analytics_cost`, заморозка тарифа при смене каталога, org-скоуп поиска тарифа и чтения стоимости, presign-утечки нет (`report_id` гейтится `_org_visible`), RBAC отчётов срабатывает до бизнес-логики, keyset-пагинация корректна.

Инвариант `known-gaps` неполон: не упоминает асимметрию «прерванный TTS-промах в chunks-пути не записывается» (`livekit_agent/tts_cache.py:15,77,224` — `CancelledError` до `_record_chunk`).

### Волна 4: tenancy-auth (верификация 2026-08-03, opus) — 2 MISMATCH, 8 новых дефектов

Капабилити безопасности; проверялось адресно: подделка контекста, обходы поддерева, fail-open в матрице ролей.

| # | Уровень | Тип | Суть |
|---|---|---|---|
| TA1 | **CRITICAL** | код (захват аккаунта между тенантами) | `UserRepository.create` (`storage/repos/accounts.py:427-438`) ищет архивную строку по email **глобально**, не проверяя, что её `organization_id` в поддереве вызывающего админа (`api/users.py:97-104`; route-guard `_require_org_in_subtree` проверяет только ЦЕЛЕВУЮ организацию). Любой админ любой организации «реинкарнирует» архивную учётку чужого тенанта в свою орг, **сохранив `keycloak_id`** — при следующем входе владелец этой Keycloak-идентичности резолвится по `sub` в организацию атакующего с назначенной им ролью |
| TA2 | MEDIUM (security) | код | `verify_token` (`api/auth.py:164-174`): `verify_aud` включается только при непустом `settings.audience` (дефолт пуст), `azp` не проверяется нигде — хотя `AuthSettings` (`:63-67`) заявляет, что `client_id` «ожидается в aud/azp». Любой RS256-токен того же realm, выпущенный ДРУГОМУ клиенту (включая ID-token и токены `admin-cli`/`account`), принимается как access-token кабинета |
| TA3 | MEDIUM | код (расширение V1b) | `DELETE /api/copilot/conversations/{id}` (`api/copilot.py:169` → `storage/repos/copilot.py:248`) удаляет переписку ЛЮБОЙ организации — V1b не только утечка, но и межорганизационное разрушающее действие. Плюс `CopilotRepository.list()` без `flow_name` (`:205-212`) отдаёт переписки всех организаций через `GET /api/copilot/conversations` |
| TA4 | LOW (security) | код | Email уникален глобально (`accounts.py:427-429`) → `POST /api/users` с чужим email отдаёт 400 «уже существует»: оракул перечисления email между организациями |
| TA5 | LOW (security) | код | `_internal_token_valid` (`api/auth.py:246-249`) сравнивает сервисный токен обычным `==`, не `secrets.compare_digest`. Токен даёт полный root-admin без scope — нужно constant-time |
| TA6 | LOW | док/спека (мёртвый код) | `api/auth.py:293-294` — ветка «организация не найдена» для архивной цели недостижима: `is_in_subtree` отваливает раньше (`list_all` фильтрует архивные). Fail-closed, вреда нет; сценарий спеки описывал несуществующее поведение |
| TA7 | LOW | спека | Спека утверждала, что `organization_id` меняется через `PATCH /api/users/{id}` — в коде `UserUpdate` (`api/users.py:65-67`) такого поля нет, `UserRepository.update` (`accounts.py:451-464`) правит только `display_name`/`role`. Перевод между организациями возможен только реинкарнацией (см. TA1) |
| TA9 | MEDIUM (security) | код (периметр) | **`/metrics` открыт без аутентификации вообще**: и `/metrics` (`api/main.py:356`), и `/healthz` (`:390`) зарегистрированы прямо на `app`, ВНЕ префиксов `/api/*` и `/v1/*`, на которые смотрит auth-middleware (`api/auth.py:323-358`) — поэтому их нет и в `_EXEMPT_PATHS`: middleware их просто не видит. Любой, кто достучится до порта 8100 (проброшенного/выставленного), читает операционные метрики: объём звонков, доля ошибок LLM, глубина очередей. `/healthz` открытым быть должен (liveness, данных не отдаёт) — вопрос только к `/metrics`, ограничение нужно на уровне ingress/LB либо в коде. Найдено верификатором monitoring |
| DB1 | MEDIUM (эксплуатация) | код + комментарий | Ручка тюнинга пула даёт эффект, ПРОТИВОПОЛОЖНЫЙ задокументированному. `storage/db.py:91-97`: комментарий утверждает «0 у pool_size/max_overflow осмыслен (без постоянных/без overflow)», и валидация пропускает `0` (`invalid = value < 0`). Но в SQLAlchemy `pool_size=0` означает **отсутствие лимита размера пула**, а не «ноль постоянных соединений». Оператор, выставивший `db_pool_size: 0` / `CFLOW_DB_POOL_SIZE=0` с намерением сэкономить соединения, получает неограниченный пул на процесс → исчерпание `max_connections` Postgres на нескольких репликах, ровно тот риск, о котором предупреждает сам коммит `4e9f2c4d`. Теста на `resolve_pool_options(0)` нет. Владелец — capability конфигурации/эксплуатации, не `tenancy-auth`. Найдено при ре-верификации STALE, проверено дирижёром лично |
| TA8 | INFO | уточнение V1c | Утечка ограничена СПИСКОМ ССЫЛОК: сама сущность гейтится `_visible_row`/`_org_visible` (`components.py:140`, `observers.py:119`), но `ComponentRefRow`/`ObserverReactionRow` выбираются без scope (`components.py:143-148`, `observers.py:122-128`) — для shared-компонента каталога видны `flow_name` + `organization_id` чужих орг. Формулировку V1c уточнить |

**Подтверждено чистым по отдельному запросу (2026-08-03, ре-верификация после мержа `4e9f2c4d` «настраиваемый пул соединений»):** новый пул НЕ ломает contextvar-tenancy. Скоуп живёт только в python-contextvar (`storage/tenancy.py:40`), ставится и сбрасывается на HTTP-запрос в `finally` (`api/auth.py:337-341`, `:355-358`, `:363-365`), в БД попадает исключительно как bound-параметр или значение колонки (`storage/repos/base.py:31-59`), сравнения `_org_visible` идут в python после выборки. Grep по всей репозитории на `SET LOCAL|set_config|current_setting|ROW LEVEL SECURITY|search_path|SET SESSION` — 0 совпадений; Postgres RLS не используется, connection-хуки есть только для SQLite (`storage/db.py:48,52`). Переиспользование физического соединения между запросами не может перенести чужой контекст, потому что переносить нечего. Зафиксировано инвариантом `tenancy-auth.scope-not-in-connection-state`. Обратная сторона той же механики (пре-существующая, не регрессия): вне HTTP-контекста scope = `None` и фильтр не применяется — воркеры/скрипты/голосовой агент ходят по всем организациям осознанно (`storage/tenancy.py:8-11`).

Подтверждено чистым: подпись RS256 по JWKS realm, `exp`, fail-closed при неизвестной роли, `is_in_subtree` не пускает вверх/вбок (`home` берётся из БД, не из заголовка), формат и хеширование API-ключей, `temp_password` не логируется. V1a подтверждён и оказался хуже описания: у `WebhookDeliveryRow` вообще нет `organization_id`, а payload доставки содержит ПД звонка.

Значимый пропуск майнинга (закрывается fixup'ом): весь realm/dev-auth слой — `sslRequired: none` в dev vs `external` в бою, `make dev-auth` с direct grant, **exempt-пути периметра** (`_EXEMPT_PATHS = {/api/auth/config}`, `_PUBLIC_RECORDING = /api/recordings/rec-[0-9a-f]+` — GET без входа), `_MEMBER_DENIED_EXPORT`, `sha256Fallback` для insecure context, запрет архивации собственной организации.

### Ре-верификация после мержа main (2026-08-03, opus): voice-pipeline / call-control / tts

Дифф `d397ef9c..b3db66a2` вне docs/openspec — четыре файла. В `livekit_agent/agent.py` (+246/−115) поведенческих изменений **три**: снятие всех `# noqa` с переупорядочиванием импортов (~90% диффа, сдвиг всех последующих строк ровно на −1), уточнение ветки «порт `/metrics` занят» (`:2298-2312`), новый `resolve_health_port()` → `WorkerOptions(port=…)` (`:2321-2334`). Контрольная сверка счётчиков (`auto_end_call` 6/6, `ctx.shutdown` 6/6, `session.aclose` 6/6, `ctx.room.on` 6/6, `add_shutdown_callback` 5/5, `os.getenv` 0/0) — новых путей завершения звонка, ветвлений и чтений env нет. **MISMATCH поведения — ноль**, правок «code beats spec» не потребовалось. VP1–VP4, T1, T2 — все **UNCHANGED**: лежат в файлах, которых мерж не касался (`engine/engine.py`, `state.py`, `realtime_*.py`, `voice_config.py`, `api/telephony.py`, `ttscache/`). T1 перепроверен адресно: `_check_limits` (`api/telephony.py:309`) вызывается ровно из одного места — `:483` (исходящий), `transfer_dial` (`:761-816`) его не зовёт, обход anti-toll-fraud жив.

| # | Уровень | Тип | Суть |
|---|---|---|---|
| M1 | **MEDIUM (методология)** | спека + инструмент | **Майнер сфабриковал якорь на несуществующий символ**: два Requirement в `tts/spec.md` ссылались на `livekit_agent/agent.py:build_agent_session` — символа нет и никогда не было (`git grep` по `d397ef9c` и по HEAD — пусто, единственные вхождения во всём дереве были в самой спеке). Прошло все гейты: `openspec validate` символы не проверяет, spec-lint проверяет существование ФАЙЛА, но не символа/строки внутри него. Значит любой галлюцинированный якорь вида `file.py:symbol` невидим для обоих гейтов. Исправлено (перенацелено на `tts_build.py:build_session_tts` + `agent.py:665-696`), но **нужна доработка кита**: spec-lint должен резолвить символьные якоря (grep `def <symbol>`/`class <symbol>`) и валить UNRESOLVED. Это единственный найденный класс дефекта, который конвейер пропускал систематически. **Кит починен:** `templates/spec-lint.py::resolve_anchor` теперь валидирует суффикс якоря (номера строк, диапазоны, символы, списки через запятую, многофайловые якоря через `;`) и заодно считает в свежесть ВСЕ названные файлы, а не только первый — прежний парсер брал `split(":",1)[0]`, поэтому правки во втором и далее файлах многофайлового якоря вообще не замечались. Регрессия закреплена: `python3 .claude/scripts/spec-lint.py --self-check` (14 кейсов, 7 из них раньше проходили гейт). Раскатка на остальные 6 репо — за Даниилом (`install.sh --refresh`) |
| N1 | LOW | тест (приёмка по исходникам) | `tests/test_ops_scaling.py:52-59` (`test_worker_options_receive_resolved_port`) читает ТЕКСТ `agent.py` и грепает `_worker_kwargs["port"]`; `WorkerOptions` не конструируется ни в одном тесте. Если в пиненной `livekit-agents 1.6.4` поле называется иначе, каждый воркер с заданным `CFLOW_AGENT_HEALTH_PORT` падает `TypeError` на старте, а `make test` остаётся зелёным. То же у `test_metrics_port_conflict_is_warned` (`:62-69`) — грепает текст на `log.warning`. Верификатор не смог подтвердить наличие поля (`livekit-agents` в окружении не установлена) — отсюда LOW, а не MEDIUM. **Проверить при живом окружении** |
| N2 | LOW | пробел спеки | Новая деградация «порт `/metrics` занят → при раздельных `PROMETHEUS_MULTIPROC_DIR` метрики этого процесса не отдаёт НИКТО» (`livekit_agent/agent.py:2298-2312`) не покрыта `monitoring/spec.md`: `metrics-endpoint` описывает порты и формат, `multiprocess-aggregation` — агрегацию, конфликт bind не описан нигде. При этом `monitoring/spec.md` уже помечена `verified b3db66a2` — пробел закрыт формально, но не содержательно |
| N3 | INFO | уточнение G9 | G9 якорит только `worker_load.py:61-88` (`resolve_health_port`); вторая половина — подключение к запуску, `WorkerOptions(port=…)` через `_worker_kwargs` (`agent.py:2321-2334`). Границы capability подтверждены: `voice-pipeline` — per-job рантайм, пул воркеров и health-порт вне её scope, так что G9 остаётся дырой МЕЖДУ capability, а не MISSING внутри voice-pipeline |

### Волна 4: editor-ui (верификация 2026-08-03, sonnet) — 11/12 CONFIRMED + 3 Inv, 1 MISMATCH

| # | Уровень | Тип | Суть |
|---|---|---|---|
| EU1 | HIGH | спека + код | `editor-ui.i18n-no-hardcoded-strings` формулирует безусловный SHALL, но в живых компонентах есть нетранслированные строки. Часть — намеренные техтермины на канвасе (`canvas/NodeCard.tsx:77` `Begin`, `:102` `Exit`, `:127` `global`, `:128` `skip`, `:131-133` `tools`), часть — реальные пропуски: лейблы полей `model`/`base_url`/`temperature`/`provider` в `shell/ModelsSettingsCard.tsx:81,89,107,180,191,318` стоят РЯДОМ с корректно локализованным `t('settings.models.apiKeyOptional')` (`:97`) — то есть это не недоделанный экран, а забытые лейблы; плюс `shell/OrganizationPage.tsx:327` (`Email`), `shell/LlmModelsPage.tsx:197`, `panels/ModelOverrideForm.tsx:73`, `panels/VoiceSection.tsx:387` (`punctuate`). Гарантию не ловит НИ ОДИН тест: `tests/test_i18n.py` проверяет только сами файлы локалей, а не то, что компоненты через них ходят (грепа исходников на литералы нет). Решение по разделению «намеренный техтермин / забытый лейбл» — за владельцем UI. Проверено дирижёром лично |
| EU2 | MEDIUM | тест (ложная гарантия) | `tests/test_i18n.py:108` — `test_default_scripts_bcp47` берёт `list(...)[:80]` из 2095 плоских ключей, то есть проверяет ~4% строк. Кириллица, просочившаяся в `uz-Latn.json` после 80-го ключа, тестом не будет замечена. Полным грепом на момент проверки (2095/2095) кириллицы нет — сейчас не баг, но заявленной гарантии тест не даёт. Проверено дирижёром лично |
| EU3 | LOW-MEDIUM | код | `canvas/NodeCard.tsx:123` — `{node.name \|\| node.id}`: при пустом `name` (схема `Node.name: str = ""`, `engine/schema.py:753`, непустота не валидируется в `engine/validate.py`) карточка показывает пользователю внутренний id. Противоречит §9 LIVING SPEC («внутренние id в UI не показываются», стр. ~3833-3834) — см. L2. В спеке не зафиксировано вообще (MISSING). Проверено дирижёром лично |

Спека-side MISSING: «пользователь видит только имена узлов, внутренние id в UI не показываются» (§9); debounce автосейва 1.2 с; конвенция «язык и тема настраиваются только в Настройках» (дубли переключателей убраны 2026-07-17). Остальной объём §9 сознательно вне scope по `## Purpose` (делегирован в `persistence-versioning`/`flow-schema`/`copilot`). Инвариант `i18n-new-locale-no-code-change` анкорит `locales/en.json`, тогда как механизм живёт в `i18n/index.ts` (`LOCALES`/`DEFAULT_SCRIPT`) — уточнить якорь. Тестов у фронта нет в принципе: в `editor/package.json` нет `test`-скрипта и ни одного `*.test.*` в `editor/src` — 5 из 12 Requirements без покрытия по этой причине.

### Волна 4: rag (верификация 2026-08-03, sonnet) — 10/12 CONFIRMED, 2 MISMATCH, 1 CRITICAL

| # | Уровень | Тип | Суть |
|---|---|---|---|
| RG1 | **CRITICAL** | код (межтенантная мутация + разрушение чужого ресурса, класс V1) | Организация-потомок может править и уничтожать базы знаний организации-предка. Два независимых слоя без строгой проверки: **(а) repo** — `add_file` (`storage/repos/knowledge.py:105-115`) и `delete_file` (`:160-173`) вызывают `self._row(s, kb_id)` **без** `for_update=True`, а `_row` (`:186-195`) применяет строгий `_org_visible` ТОЛЬКО в ветке `for_update`, иначе `_org_catalog_visible` (своя + предки). Docstring класса (`:32-33`) заявляет «правки/удаление — только записи своей организации» — для этих двух методов неверно. **(б) API** — все деструктивные роуты `api/knowledge_bases.py` гейтятся `storage.knowledge_bases.get(kb_id)` (каталожная видимость!) и вызывают внешний RAG/S3 **до** строгой локальной операции: `rename_knowledge_base` (`:253-261`) переименовывает БЗ в CybernetRAG, затем локальный `rename` кидает KeyError → клиент видит 404, но переименование в источнике истины уже произошло; `delete_knowledge_base` (`:274-285`) удаляет БЗ в RAG, чистит все S3-объекты по префиксу `{kb_id}/` и лишь потом `delete()` молча возвращает `False`; `delete_document` (`:363-375`) удаляет файл в RAG; `upload_document` (`:288-356`) отравляет чужую БЗ реальным документом (S3 + регистрация в RAG + строка проекции). Тестов на межорганизационный доступ в этой capability нет вообще (grep `organization_id`/`org_scope` по `test_patch42.py`/`test_patch43.py` — 0 совпадений). Проверено дирижёром лично по коду (после истории с ложным R1) |
| RG2 | HIGH | код (расширение R2 на API-слой) | Гарантия мягкой деградации при битом ответе RAG не соблюдается в кабинете: `_parse_kb`/`_parse_kb_list`/`_parse_files` на `None`/неожидаемой форме кидают `pydantic.ValidationError`, а роуты `api/knowledge_bases.py` ловят только `RagError`; общего `exception_handler(Exception)` в `api/main.py` нет → unhandled 500. Теста на «пустой/битый ответ RAG» нет |

Спека-side (MISMATCH, требует fixup): `rag.projection-tenancy` заявляет `_org_visible` на «правках/удалении» — верно лишь для `rename`/`delete`/`set_status`, но не для `add_file`/`delete_file`; `rag.cabinet-api` не описывает ни отсутствие проверки владения перед внешним вызовом, ни путь `ValidationError`. MISSING: запрет полей `knowledge_base_ids`/`knowledge_search` на немых узлах (`engine/schema.py:893-900`, тест есть); IAM минимальных прав S3 из §11.9 §6 не отмечен даже как осознанное исключение. R13 (`RAG__RETRIES` ≤ 0 → `raise None` → TypeError, `rag/client.py:236-260`) подтверждён логикой, теста нет.

### Волна 3: voice-pipeline (верификация 2026-08-03, opus) — 4 MISMATCH, 25 req

| # | Уровень | Тип | Суть |
|---|---|---|---|
| VP1 | **HIGH** | код (гонка) | `cancel_end()` (`engine/engine.py:1968-1989`) и `start()` (`:300-325`) мутируют `SessionState` **вне `_turn_lock`** (замок держит только `process_user_input`, `:347`). `_take_pending_end` гарантирует лишь однократное потребление pending-end: если `cancel_end` побеждает в гонке, его `_finish_cancel_end`/`_arrive`/`_say` идут в одном executor-потоке, пока новый тёрн `process_user_input` (с замком) идёт в другом — ровно та конкурентная мутация состояния, которую ТЗ №72 §2 объявляет невозможной. Теста на `start`/`cancel_end` вне замка нет |
| VP2 | MEDIUM | код | Усечение при barge-in не адресовано тёрном: `amend_last_agent_utterance` (`engine.py:436`) / `state.amend_last_agent_block` (`state.py:236`) режут ПОСЛЕДНИЙ блок агента. Если прерванный item тёрна N приходит после того, как реплика N+1 уже в истории, усекается реплика N+1. Асимметрия с `confirm_spoken(turn)`/`attach_turn_metrics(turn)`, которые адресованы тёрном |
| VP3 | MEDIUM | код + док | Realtime: собственный тул агента с именем `search_knowledge_base` перехватывается синтетическим RAG-хендлером в рантайме (`realtime_runtime.py:301-307`) при наличии блока `knowledge` — вопреки спеке и §8.15 («собственный тул агента выигрывает»). Правило держится только на этапе компиляции (`realtime_compile.py:287`); рантайм-перехват не покрыт тестом |
| VP4 | INFO (security) | код | `provider_params` из флоу логируется дословно для deepgram/soniox STT (`voice_config.py:747,777`) — единственный канал, через который секрет, положенный оператором в параметры провайдера, попадёт в логи, несмотря на env-only политику ключей |

Спека-side (исправлено fixup'ом, не дефекты кода): Scenario «отсутствие таймингов LiveKit не синтезируется» противоречил соседнему требованию и коду (`agent.py:951-955` оценивает по своим якорям с маркером `estimated`); `message-timestamps` заявлял `ts` «на всех каналах», а realtime-путь (`realtime_runtime.py:91-93`) пишет историю без `ts`/`spoke_at`/`turn`/`pending`; три неточных якоря.

### Волна 3: tts (верификация 2026-08-03, sonnet) — 18/18 CONFIRMED, 1 новый дефект кода

| # | Уровень | Тип | Суть |
|---|---|---|---|
| T2 | **HIGH** | код (нет org-скоупа, класс V1) | Кросс-тенантная коллизия TTS-кэша по имени агента. `flows` имеет `UniqueConstraint("organization_id","name")` (`storage/models.py:464`) — имя уникально только внутри org; весь стек `ttscache` (`store.py` index/denylist, `service.py:delete/purge/deny/is_denied`) ключуется одной строкой `agent`, без `organization_id` (`index:agent:<name>`, `deny:agent:<name>`), а `purge_chunks`/`S3ColdStore.list_keys` сканируют весь namespace `cflow:ttscache:*`. Следствие: у двух орг с одноимённым агентом («support», «sales-bot») purge/denylist/`scope=workspace` (в т.ч. через публичный `/v1`) задевают кэш ЧУЖОЙ организации; «весь кэш workspace» = весь общий Redis/S3. Тестов на org-изоляцию в ttscache нет вообще |

### Волна 3: telephony (верификация 2026-08-03, sonnet) — 15/15 CONFIRMED, 1 новый дефект кода

| # | Уровень | Тип | Суть |
|---|---|---|---|
| T1 | **HIGH** (финансовый) | код (обход лимита) | Anti-toll-fraud лимиты `_check_limits` (max_concurrent_calls / max_calls_per_minute) **не применяются** к `POST /api/calls/{room}/transfer/dial` (`api/telephony.py:761-816`) — там только `_check_destination` (allowed_destinations) через `_resolve_transfer_target`. Транк можно накрутить произвольным числом INVITE-ног повторными transfer/dial, не задев лимиты транка. Спека описывает это честно (не MISMATCH спеки) — дефект кода |

Пробелы тестов: нет теста на `lk-sync-best-effort`, на org-scope-ветку inbound-маршрутизации (`organization_id` транка), на сбой durable-записи в `_register_call`. Anchor-gap: `telephony.amd-reaction-disposition` не якорит `livekit_agent/agent.py:2239` (`_handle_voicemail`), где реально исполняется ветвление `on_detected`.

### Волна 3: observers (верификация 2026-08-03, sonnet) — 1 MISMATCH + подтверждение V1c

| # | Уровень | Тип | Суть |
|---|---|---|---|
| O1 | LOW | док/спека | `CompiledObserver._event_key` (`engine/schema.py:2210`) нормализует имя (`.strip().lower().replace("-","_").replace(" ","_")`) ДО проверки `OBSERVER_NAME_RE` — заглавные буквы, дефисы и пробелы не отклоняются, а молча принимаются (`test_observers_patch53.py:131`: `spec(name="Do Not Call").name == "do_not_call"`). Реально отклоняются: нелатинские символы, ведущая цифра, пустое имя, длина >64 |
| V1c+ | **HIGH** (подтверждён независимо) | код (утечка) | `ObserverRepository.usage()` (`storage/repos/observers.py:116-138`, запрос `:122-127`) — тот же `select(ObserverReactionRow)` без `_scoped`. Достижим через `GET /api/observers/{id}/usage` (`api/observers.py:175-180`) для любого видимого library-детектора; возвращает `flow` + `organization_id` ВСЕХ организаций. Остальные методы файла (`for_agent`, `_check_name`, `_ref_row`, `ObserverIncidentRepository.*` включая `summary_for_calls`) заскоупены корректно — `usage()` единственный. Cross-org теста нет |

### Волна 3: asr (верификация 2026-08-03, sonnet) — 1 MISMATCH

| # | Уровень | Тип | Суть |
|---|---|---|---|
| A1 | MEDIUM | код (мёртвый код) | `deprecated_asr_warnings` (`engine/asrrefs.py:186`) корректна, но **нигде не вызывается** вне тестов: в `api/routes/flows.py` подключены три её аналога — `deprecated_ref_warnings`/`deprecated_voice_warnings`/`deprecated_realtime_warnings` (`:132,135,141` publish, `:230` validate), а ASR-сестра пропущена. Публикация/валидация флоу с устаревшим `asr_ref` сегодня **не даёт предупреждения вообще**. Теста тоже нет |

Проверено и чисто: `AsrModelRepository` наследует scoped-методы без обхода (в отличие от паттерна V1); ключи провайдеров не логируются, `check_asr_model` возвращает только имя env-переменной. Пробел тестов: `mode="republish"` для ASR не покрыт (у TTS-аналога тест есть).

### Волна 1: flow-schema (верификация 2026-08-03, sonnet)

28/28 CONFIRMED, 0 MISMATCH кода; 5 пробелов полноты спеки (component-узел, KnowledgeSearchSettings-форма, overrides.voice, поля GlobalSettings/Node, якорь function-http-validation) — чинятся fixup-агентом, в дефекты не идут.
