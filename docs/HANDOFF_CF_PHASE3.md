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

## Незавершённое

1. ✅ ~~fixup `tenancy-auth`~~ — добит: 26 Req + 1 Inv, TA1–TA8 отражены, все гейты зелёные.
2. **Верификаторы двух спек**: `editor-ui` (12 Req + 3 Inv) и `rag` (12 Req). Остальные 18 из 20 верифицированы.
3. **Fixup'ы по итогам верификации волны 4** (задания сформированы, не запущены):
   - `cost-analytics`: MISMATCH `reports-filter` (`load_test` не в `ALLOWED_FILTER_KEYS` — CA3), якорь `rate-snapshot` → `analytics/service.py:_compute_cost` (CA5), пополнить инвариант `known-gaps` асимметрией CancelledError в chunks-пути, MISSING (UI-блок себестоимости, обнуление usage при хендоффе №28, атрибуция TTS-фолбэка, `recording_link` в пресете `full`, нормативная граница «сырой транскрипт в отчёт не выгружается»).
   - `monitoring`: уточнить формулировку `system-health-endpoints` («без API-ключа» ≠ «без аутентификации» — эндпоинт под `/api/*` и гейтится middleware), добавить MinIO-метрики (`:9000/minio/v2/metrics/cluster`, `MINIO_PROMETHEUS_AUTH_TYPE=public`, источник `MinioDiskLow`).
   - `timezones`: правок не требуется (дефектов нет), только пробелы тестов.
3. **7 спек ушли в STALE после мержа main** (`975eeaf3`, поверх него `4e9f2c4d` «настраиваемый пул соединений к БД» и `e62d5e5d` «порт health-сервера голосового воркера из env»). Изменилось +231/−121 в четырёх файлах-якорях:

   | Файл | STALE-спеки |
   |---|---|
   | `livekit_agent/agent.py` (+246/−…) | `voice-pipeline`, `call-control`, `tts` |
   | `storage/db.py` (+60) | `persistence-versioning`, `timezones` |
   | `storage/repos/__init__.py` (+15) | `tenancy-auth` |
   | `livekit_agent/worker_load.py` (+31) | `monitoring` |

   Нужно: ре-верифицировать затронутые Requirements против нового кода и обновить маркеры `Last verified` на актуальный коммит. **Особое внимание V2** (6 из 9 `_upgrade_to_*` выполняют DDL на Postgres) — `storage/db.py` как раз менялся, дефект мог быть починен или изменён. Это нормальная работа механизма spec-lint, а не поломка: он ровно для этого и нужен.

## Что дальше по плану
2. Закрыть пробелы покрытия G1–G6 из DEFECTS_CF: G1 transfer-рантайм §8.9 ТЗ №28 (в `call-control`), G2 авто-завершение, G3 fast-hangup, G4 ТЗ №83 tail-commit, G5 каталог голосов TTS, G6 лог TTS-чанков.
3. Слепок `openspec/**` → `sdd-kit/profiles/conversation_flow/` (ADR-0019 решение 2).
4. Шапка DOCUMENTATION.md: «канон поведения — openspec/specs/, документ ведётся параллельно (ADR-0019)»; `docs/patches/README.md`: «архив закрыт на №84».
5. Фаза 4: payload-скиллы `tz`/`tz-review`/`tz-implement`, deprecated-пометка patch-трилогии, пилот на реальном ТЗ №85.
6. Фаза 5: включить `PROFILE_SPEC_GUARD_PATHS` (14 префиксов), `SPEC_LINT_STRICT=1`.

## Открытые вопросы Даниилу

- `feature-flow`/`incident-flow` вернулись в CF и закоммичены (`b30c5659`) — `--refresh` их восстановил, т.к. P0-4 (гейтирование манифеста профилем) не сделан. Решить: делать P0-4 или оставить.
- Коммиты всей работы (кит + CF + store), PR store-контрактов и ревью владельцами WBN/VA.
- Триаж 48 дефектов в тикеты — приоритет 2 CRITICAL (V1a webhook_deliveries, V1b copilot).

## Промпт для продолжения

```
Продолжаем миграцию conversation_flow, фаза 3. Прочитай
sdd-kit/docs/HANDOFF_CF_PHASE3.md (состояние), PLAN_CF_MIGRATION.md (план),
DEFECTS_CF.md (59 дефектов, 3 CRITICAL), tools/cf/*.md (инструкции конвейера).

Ты — дирижёр: работу делают субагенты (opus/sonnet), ты держишь состояние,
пишешь дефекты в DEFECTS_CF.md и обновляешь план/handoff. Коммиты — только Даниил.

Все 20 capabilities смайнены, validate --all --strict зелёный. Незавершённое —
раздел «Незавершённое» этого файла: (1) добить fixup tenancy-auth, (2) пять
верификаторов (cost-analytics, monitoring, timezones, editor-ui, rag),
(3) voice-pipeline стала STALE после мержа main — перепроверить и обновить
маркер. Верификатор всегда НЕ автор спеки и обязан опровергать: на волнах 1-4
заявление майнера «расхождений нет» семь раз скрывало реальные баги, включая
CRITICAL. Затем пробелы G1-G8, слепок openspec/** в профиль кита, шапки
DOCUMENTATION.md и docs/patches/README.md, и фаза 4 (скиллы tz/tz-review/
tz-implement, пилот на реальном ТЗ №85).
```
