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

Гейты: `openspec validate --all --strict` и `spec-lint.py` зелёные, все спеки FRESH.
Дефектов в реестре: **48** (2 CRITICAL cross-org утечки, 6 HIGH).

## Что в работе (волна 4, запущена)

Fixup `voice-pipeline` (4 MISMATCH + 6 групп пропусков) и 7 майнеров: `tenancy-auth`, `rag`, `cost-analytics`, `editor-ui`, `copilot`, `monitoring`, `timezones`.

## Что дальше

1. Верификаторы на каждую спеку волны 4 (по `tools/cf/verify-section.md`, модель: opus на `tenancy-auth` — там V1a–V1e; sonnet на остальные), затем fixup'ы. MISMATCH'и → DEFECTS_CF.
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
DEFECTS_CF.md (48 дефектов), tools/cf/*.md (инструкции конвейера).

Ты — дирижёр: работу делают субагенты (opus/sonnet), ты держишь состояние,
пишешь дефекты в DEFECTS_CF.md и обновляешь план. Коммиты — только Даниил.

Следующий шаг: верификаторы на спеки волны 4 (tenancy-auth, rag,
cost-analytics, editor-ui, copilot, monitoring, timezones) по
tools/cf/verify-section.md — каждый НЕ автор спеки, задача опровергать;
на предыдущих волнах «расхождений нет» шесть раз скрывало реальные баги.
Затем fixup'ы, пробелы G1-G6, слепок в профиль, шапки документов.
```
