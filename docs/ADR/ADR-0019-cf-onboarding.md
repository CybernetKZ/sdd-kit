# ADR-0019. Онбординг conversation_flow: полная конвертация docs/ в OpenSpec, параллельный LIVING SPEC

Статус: **принято**. Дата: 2026-08-03 (grill-сессия по PLAN_CF_MIGRATION.md).

Частично отменяет ADR-0015 в части «conversation_flow вне кита»: репозиторий входит в scope sdd-kit. Спец-код под conversation_flow разрешён внутри кита (профиль + payload + конвертеры).

## Проблема

В conversation_flow с 2026-07-29 лежит байт-свежая установка sdd-kit, которая на 100% вакуумна: `openspec/` пуст (0 файлов), гейты проходят «не найдено — ОК», всё untracked. Реальный SDD репо — свой: LIVING SPEC `docs/DOCUMENTATION.md` (9470 строк, v1.81.0) + 83 ТЗ в `docs/patches/` + цепочка скиллов `/patch → /patch-review → /patch-implement`. Две системы не ссылаются друг на друга; `sdd-doctor` предлагает удалить рабочий процесс репо.

## Решение

1. **Полная конвертация всего `conversation_flow/docs/`** в формат OpenSpec, LLM-часть — на недорогих моделях (sonnet):
   - `DOCUMENTATION.md` → `openspec/specs/<capability>/spec.md` (~20 capabilities) — рерайт в Requirement/Scenario (в исходнике 0 MUST, механическая конвертация невозможна);
   - 83 патча → `openspec/changes/archive/tz-0NN-*/` (proposal.md из ТЗ, tasks.md из критериев приёмки); оригиналы `docs/patches/` не удаляются, в каждом архивном change — ссылка на оригинал;
   - `integration-guide.md` и `cybernetrag_openapi.json` → два контракта в store cybernet-specs.
2. **Размещение — по двум уровням ADR-0001**: внутренние спеки живут и меняются в самом conversation_flow (канон); в cybernet-specs — только 2 кросс-репо контракта. Полный сконвертированный набор дополнительно хранится в `sdd-kit/profiles/conversation_flow/` как стартовый слепок: install копирует его только при отсутствии в репо (repo-owned после установки, в `--refresh`-manifest не входит).
3. **Верификация — полная, по протоколу store** (STORE_VERIFICATION): каждая capability после конвертации сверяется с кодом отдельным агентом, каждое Requirement подтверждено чтением кода, расхождения — в отдельный список дефектов.
4. **Порядок**: сначала вся конвертация + верификация, только потом первое ТЗ по новому процессу. До этого действует старый патч-процесс. Пилот — **реальное следующее ТЗ**, не синтетика.
5. **DOCUMENTATION.md ведётся параллельно** (обратная совместимость): канон — openspec-спеки; при каждом ТЗ агент генерирует из spec-дельты обновление соответствующего §, §17 changelog и версии `1.NN.0` — в тех же коммитах, что и код. При конфликте текстов прав openspec. Living-spec-фрагмент pre-commit (warn) остаётся постоянно.
6. **Язык**: репо-локальные спеки и proposal.md — русский, ключевые слова `### Requirement:` / `#### Scenario:` / WHEN / THEN — английские (нужны валидатору). Store-контракты — только английский.
7. **Нумерация**: двойная — сквозная `tz-NNN` (продолжает счёт ТЗ, следующий №85) как id change; YouTrack-id, если есть, пишется в proposal.md, не в имя.
8. **patch49-components.md** (незакоммиченные +129/−61, нарушение append-only) — закоммитить как есть: `docs/patches/` — легаси-формат, который данным решением замораживается; коммитит Даниил.
9. **repo-auditor** (домашний агент CF) поднимается в общие шаблоны кита `templates/agents/` и в kit_manifest — аддитивен, read-only, полезен всем профилям.

## Отложено в отдельный грилл

Дедупликация команд и скиллов: `/patch-review` ↔ `plan-griller` ↔ встроенные opsx-команды openspec ↔ `feature-flow`; там же — момент, когда install.sh перестаёт копировать агентов, дублируемых плагином code-conventions (`database-reviewer`). Требуется сверка текстов агентов/скиллов.

## Последствия

- `profiles/conversation_flow.env` обновляется: guard-префиксы возвращаются (после конвертации), `PROFILE_LIVING_SPEC=1` остаётся постоянно, новый `PROFILE_REVIEW_BASE=main`.
- В payload профиля появляются адаптированные скиллы `tz`/`tz-implement` (наследники `/patch`/`/patch-implement` с артефактом = OpenSpec change), полный слепок спек и AGENTS.md.
- 4 бага кита, найденных на этом репо, чинятся независимо (комментарии в `.spec-guard-paths` для doctor и living-spec-фрагмента; `SDD_REVIEW_BASE`; пропуск `openspec init` при пустых директориях).
- Глоссарий: статья «LIVING SPEC» обновлена (параллельный режим, канон — openspec).
