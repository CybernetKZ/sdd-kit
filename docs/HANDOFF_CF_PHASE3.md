# Handoff: миграция conversation_flow, фаза 3 (2026-08-03)

Передача состояния для продолжения после `/compact`. Канон плана — [PLAN_CF_MIGRATION.md](PLAN_CF_MIGRATION.md), решения — [ADR-0019](ADR/ADR-0019-cf-onboarding.md), [ADR-0020](ADR/ADR-0020-dedup-commands-reviewers.md), дефекты — [DEFECTS_CF.md](DEFECTS_CF.md).

## Что сделано

**Фаза 0 (кит)** — B1–B4 (comment-strip в doctor и living-spec, `SDD_REVIEW_BASE` из `origin/HEAD`, `openspec init` на пустых dirs); `repo-auditor` в `templates/agents/` + манифест; P0-2 (planner получил Write/Edit), P0-3 (plan-griller переписан в one-shot, 48 строк), P0-1-пин (`$OPENSPEC` всегда `npx -y @fission-ai/openspec@1.7.0`); кэши вычищены; `planner`/`feature-flow` перенацелены с `commands/opsx/` на `skills/openspec-propose/`.

**Фаза 1 (CF)** — `openspec init` на 1.7.0; `commands/opsx/` удалены, 6 openspec-скиллов проштампованы `disable-model-invocation: true`; AGENTS.md канонический (246 строк) + `CLAUDE.md` симлинк + `docs/DEPLOY_USA.md` (311 строк); patch49 проверен (только переформат).

**Фаза 2 (store)** — два change в `cybernet-specs`: `add-cf-dialer-integration-api` (26 Req/81 Sc, 12 расхождений) и `add-cf-rag-contract` (13 Req/30 Sc, 13 расхождений); `references: cybernet-specs` в CF. PR/ревью/apply — за Даниилом.

**Фаза 3 (конвертация)** — инструментарий `sdd-kit/tools/cf/` (`mine-section.md`, `verify-section.md`, `patch2change.md`); архив: 87 `openspec/changes/archive/tz-*` (все патчи + 4 безномерных, оригиналы целы).

Спеки (конвейер майнер→скептик-верификатор→fixup):

| Волна | Capability | Req | Верификация |
|---|---|---|---|
| 1 | flow-schema | 34 | 28 CONFIRMED, 5 пробелов закрыты |
| 1 | flow-execution | 23 | 3 MISMATCH → E1–E5 |
| 2 | webhooks | 11 | 11/11, D-ссылки исправлены |
| 2 | public-api-v1 | 13 | чисто + web-статус добавлен |
| 2 | persistence-versioning | 24 | 3 MISMATCH → V1–V4 (2 CRITICAL) |
| 3 | recording | 7 | 7/7 чисто |
| 3 | mcp | 11 + 2 Inv | 11/11, инварианты безопасности |
| 3 | telephony | 15 | 15/15 + T1 |
| 3 | tts | 18 | 18/18 + T2 |
| 3 | call-control | 11 | 11/11, якорь исправлен |
| 3 | asr | 16 | 1 MISMATCH → A1 |
| 3 | observers | 24 | 1 MISMATCH → O1 + V1c |
| 3 | voice-pipeline | 25 | 4 MISMATCH → VP1–VP4 |

**Итог фазы 3 на 2026-08-03:** 20 capability-спек, **366 Requirements** (+ инварианты), 87 архивных changes.
Гейты: `openspec validate --all --strict` = 20 passed / 0 failed; `spec-lint` = 0 metadata violations,
FRESH=13 / STALE=7 (причина STALE — мерж main, см. п. 3 «Незавершённое»).
Дефектов в реестре: **65** (3 CRITICAL, 7 HIGH, 1 отозван как ложный). Топ-3 в тикеты первыми:
1. **TA1 CRITICAL** — межтенантный захват аккаунта: реинкарнация архивной учётки чужого тенанта с сохранением `keycloak_id` (`storage/repos/accounts.py:427-438`, `api/users.py:97-104`).
2. **V1a CRITICAL** — `webhook_deliveries` без `organization_id` и без route-guard; `retry` перевыстреливает вебхук чужого тенанта, payload содержит ПД звонка.
3. **V1b/TA3 CRITICAL** — copilot-переписки: чтение, `list()` без параметра отдаёт все организации, `DELETE` удаляет чужую переписку.

## Параллельная работа Даниила (не часть CF-миграции, но влияет на кит)

**ADR-0021 — executor, тир→конвейер, провенанс гриля** (принят, раскатан по 7 репо):
артефакты — `ADR-0021-executor-tier-pipeline.md` + строка в индексе ADR; `templates/agents/executor.md`
(в манифесте `install.sh` и в списке известных агентов `sdd-doctor`); `feature-flow/SKILL.md` §1b/§2/§4;
`plan-griller.md`; глоссарий (статьи «executor», «провенанс гриля»); бэклог kit-flow(1–3) закрыт.
На полигоне executor лежит, доктор чист (0 fail, extra-agent не флажится).

Учесть при продолжении CF-миграции: `executor` — новый агент кита, поедет в CF при `--refresh`;
таблица «тир → конвейер → модели» из §1b — ориентир для payload-скиллов `tz`/`tz-implement` фазы 4;
шапка провенанса `## Grill` обязательна и в CF-changes.

## Волна 4 (завершена частично; 2026-08-03, лимит сессии в 20:40)

Смайнены ВСЕ оставшиеся capability — итого **20 из 20** по плану, `openspec validate --all --strict` = 20 passed / 0 failed:

| Capability | Req | Верификация |
|---|---|---|
| tenancy-auth | 26+1 Inv (fixup добит) | **opus: 2 MISMATCH + 9 дефектов, вкл. TA1 CRITICAL** |
| cost-analytics | 20+2 Inv | sonnet: 19/20 CONFIRMED, 1 MISMATCH + 5 дефектов (CA1–CA5) |
| editor-ui | 12+3 Inv | ⏳ **не верифицирована** |
| copilot | 11+1 Inv | sonnet: 11/11 CONFIRMED, V1b подтверждён независимо |
| rag | 12 | ⏳ **не верифицирована**; при сверке со store **нашла ложный R1** |
| monitoring | 31/53 Sc+2 Inv | sonnet: 31/31 CONFIRMED, ПД в лейблах нет, alerts.yml чист; **TA9** — `/metrics` без аутентификации |
| timezones | 16/33 Sc+3 Inv | sonnet: 16/16 CONFIRMED + 3 Inv; инвариант `no-utc-fallback` **подтверждён** (фолбэк недостижим по всей цепочке) — дефектов нет |
| voice-pipeline (fixup волны 3) | 17→31 | ✅ 4 MISMATCH исправлены, 7 Req добавлено |

Также: **R1 отозван как ложноположительный** (валидаторы границ `limit`/`threshold` существуют с ТЗ №42) — store-дельта `add-cf-rag-contract` исправлена, остальные 12 её пунктов перепроверены построчно и подтверждены.

## Финал фазы 3 (2026-08-03, вечер): все 20 спек верифицированы, все STALE закрыты

**Верификация завершена — 20 из 20.** Последние две: `editor-ui` (11/12 CONFIRMED + 3 Inv, 1 MISMATCH → EU1–EU3) и `rag` (10/12, 2 MISMATCH → **RG1 CRITICAL**, RG2 HIGH). Fixup'ы по обеим, а также по `cost-analytics` и `monitoring`, прогнаны и зелёные.

**Четвёртый CRITICAL — RG1** (проверен дирижёром лично по коду, как после истории с ложным R1): организация-потомок правит и уничтожает базы знаний организации-предка. Два слоя: `storage/repos/knowledge.py:186-195` — `_row()` применяет строгий `_org_visible` только при `for_update=True`, а `add_file`/`delete_file` его не передают; и все деструктивные роуты `api/knowledge_bases.py` гейтятся каталожной видимостью и зовут внешний RAG/S3 ДО строгой локальной операции (`delete_knowledge_base:274-285` уносит базу в CybernetRAG и чистит префикс S3, потом `delete()` тихо возвращает `False`).

**Ре-верификация STALE — все 7 закрыты, спеки FRESH=20 / STALE=0.** Результаты:
- **V2 UNCHANGED** — `4e9f2c4d` тронул только `create_db_engine`; ни `init_db`, ни один из девяти `_upgrade_to_*`; соотношение 3 гейченных / 6 безусловных DDL на Postgres сохранилось, съехали лишь номера строк (+54).
- **Пул соединений НЕ ломает contextvar-tenancy** (главный вопрос ре-верификации, доказано): скоуп только в `storage/tenancy.py:40` + bound-параметрах SQL, `SET LOCAL|set_config|current_setting|RLS|search_path` — 0 совпадений по репозиторию, connection-хуки только для SQLite. Зафиксировано новым инвариантом `tenancy-auth.scope-not-in-connection-state`.
- `livekit_agent/agent.py` +246/−115 — поведенческих изменений три (снятие `noqa` с переупорядочиванием импортов даёт сдвиг строк на −1, уточнение ветки занятого порта `/metrics`, новый `resolve_health_port`). **MISMATCH поведения ноль**; VP1–VP4, T1, T2 — все UNCHANGED (лежат в файлах, которых мерж не касался). T1 перепроверен адресно: `_check_limits` зовётся ровно из одного места (`api/telephony.py:483`), `transfer_dial` его не зовёт.

**M1 — найден и починен класс дефекта, который конвейер пропускал систематически.** Майнер сфабриковал якорь `livekit_agent/agent.py:build_agent_session` — символа нет и никогда не было, но якорь прошёл ВСЕ гейты: `openspec validate` символы не смотрит, spec-lint проверял существование файла и брал `split(":",1)[0]`. Починка кита в `templates/spec-lint.py::resolve_anchor`: валидируются номера строк, диапазоны, символы, списки через запятую и многофайловые якоря через `;`; заодно в свежесть теперь считаются все названные файлы, а не только первый (правки во втором и далее файлах многофайлового якоря раньше не замечались вообще). Регрессия закреплена: `spec-lint.py --self-check`, 14 кейсов, 7 из них раньше гейт проходили. Прогон по 20 живым спекам CF — 0 ложных срабатываний. **Раскатка на остальные 6 репо — за Даниилом** (`install.sh --refresh`).

**Итоговые цифры:** 20 спек, **372 Requirements + 18 Invariants**, 87 архивных changes. `openspec validate --all --strict` = 20 passed / 0 failed; `spec-lint` = FRESH 20 / STALE 0, 0 metadata violations; `make sdd-check` = OK. Дефектов в реестре **69** (4 CRITICAL, 9 HIGH). Новые пробелы: G9 (health-порт воркера), L2 (§9 «id не показываются» против `NodeCard.tsx:123`), N1–N3, DB1, M1.

**DB1 (MEDIUM, эксплуатация)** — ручка тюнинга даёт эффект, противоположный задокументированному: комментарий `storage/db.py:91-97` утверждает, что `pool_size=0` значит «без постоянных соединений», а в SQLAlchemy это «без лимита размера пула». Оператор, экономящий соединения, получает неограниченный пул на процесс.

Сделаны шапки: `docs/DOCUMENTATION.md` (канон — `openspec/specs/`, документ ведётся параллельно), `docs/patches/README.md` (архив закрыт на ТЗ №84, сверено по факту: последний — `tz-084-programmatic-end-worker-handoff`).

## Незавершённое

1. ✅ ~~fixup `tenancy-auth`~~, ✅ ~~верификаторы `editor-ui` и `rag`~~, ✅ ~~fixup'ы волны 4 (`cost-analytics`, `monitoring`, `rag`, `editor-ui`; `timezones` правок не требовал)~~, ✅ ~~ре-верификация всех 7 STALE-спек~~ — см. раздел «Финал фазы 3» выше.
2. **Пробелы покрытия G1–G9** — не закрыты (это следующая содержательная работа фазы 3).
3. **Слепок `openspec/**` → `sdd-kit/profiles/conversation_flow/`** (ADR-0019 решение 2) — теперь можно: спеки застабилизировались, все гейты зелёные.
4. Мелочи, вскрытые последней волной: якорь EU-инварианта `i18n-new-locale-no-code-change` уже поправлен; расхождение «5 из 12 непокрываемых Requirements в editor-ui» — верификатор заявил 5, fixup грепом нашёл 4 и честно отказался придумывать пятый, нужна сверка; N1 (тест `test_worker_options_receive_resolved_port` проверяет ТЕКСТ `agent.py`, а не конструирует `WorkerOptions`) — перепроверить при живом окружении с установленной `livekit-agents 1.6.4`.

## Что дальше по плану
2. Закрыть пробелы покрытия G1–G6 из DEFECTS_CF: G1 transfer-рантайм §8.9 ТЗ №28 (в `call-control`), G2 авто-завершение, G3 fast-hangup, G4 ТЗ №83 tail-commit, G5 каталог голосов TTS, G6 лог TTS-чанков.
3. Слепок `openspec/**` → `sdd-kit/profiles/conversation_flow/` (ADR-0019 решение 2).
4. Шапка DOCUMENTATION.md: «канон поведения — openspec/specs/, документ ведётся параллельно (ADR-0019)»; `docs/patches/README.md`: «архив закрыт на №84».
5. Фаза 4: payload-скиллы `tz`/`tz-review`/`tz-implement`, deprecated-пометка patch-трилогии, пилот на реальном ТЗ №85.
6. Фаза 5: включить `PROFILE_SPEC_GUARD_PATHS` (14 префиксов), `SPEC_LINT_STRICT=1`.

## Открытые вопросы Даниилу

- `feature-flow`/`incident-flow` вернулись в CF и закоммичены (`b30c5659`) — `--refresh` их восстановил, т.к. P0-4 (гейтирование манифеста профилем) не сделан. Решить: делать P0-4 или оставить.
- Коммиты всей работы (кит + CF + store), PR store-контрактов и ревью владельцами WBN/VA.
- Триаж 69 дефектов в тикеты — приоритет 4 CRITICAL: TA1 (захват аккаунта между тенантами), V1a (webhook_deliveries), V1b/TA3 (copilot), **RG1 (базы знаний RAG)**.
- Раскатать починенный `spec-lint.py` (M1) на остальные 6 репо: `install.sh --refresh`.

## Промпт для продолжения

```
Продолжаем миграцию conversation_flow, фаза 3. Прочитай
sdd-kit/docs/HANDOFF_CF_PHASE3.md (состояние), PLAN_CF_MIGRATION.md (план),
DEFECTS_CF.md (59 дефектов, 3 CRITICAL), tools/cf/*.md (инструкции конвейера).

Ты — дирижёр: работу делают субагенты (opus/sonnet), ты держишь состояние,
пишешь дефекты в DEFECTS_CF.md и обновляешь план/handoff. Коммиты — только Даниил.

Конвертация и верификация ЗАВЕРШЕНЫ: 20 спек, 372 Requirements + 18 Invariants,
87 архивных changes; validate --all --strict = 20/0, spec-lint FRESH=20/STALE=0,
make sdd-check OK. Шапки DOCUMENTATION.md и docs/patches/README.md проставлены.

Осталось по разделу «Незавершённое»: (1) пробелы покрытия G1-G9 из DEFECTS_CF,
(2) слепок openspec/** в sdd-kit/profiles/conversation_flow/, (3) фаза 4 —
payload-скиллы tz/tz-review/tz-implement, deprecated-пометка patch-трилогии,
пилот на реальном ТЗ №85, (4) фаза 5 — PROFILE_SPEC_GUARD_PATHS, SPEC_LINT_STRICT=1.

Верификатор всегда НЕ автор спеки и обязан опровергать: заявление майнера
«расхождений нет» скрывало реальные баги семь раз, включая 4 CRITICAL. Каждое
CRITICAL-заявление агента перепроверяй сам по коду — один дефект (R1) уже
оказался ложным. Помни M1: майнер способен сфабриковать якорь на несуществующий
символ — spec-lint это теперь ловит (--self-check), но раскатка фикса по
остальным 6 репо ещё не сделана.
```
