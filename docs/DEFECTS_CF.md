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
