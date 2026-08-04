# Реестр ADR: SDD-стек

Это реестр решений SDD-стека.
У бенчмарка cc-bench СВОЙ реестр с теми же номерами: /home/octrow/cybernet/cc-bench/docs/adr/ (github.com/octrow/cc-bench)

## Индекс

| № | Название | Суть | Статус |
|---|---|---|---|
| [0001](ADR-0001-spec-location.md) | Где хранить спецификации | openspec/ в каждом репо + центральный store cybernet-specs для кросс-репо контрактов | принято |
| [0002](ADR-0002-agent-context-format.md) | Формат файла контекста агента | AGENTS.md - канон, CLAUDE.md - симлинк на него, лимит 500 строк | принято |
| [0003](ADR-0003-enforcement.md) | Принуждение к правилам | обязательный CI-гейт (make test) на pull request + PreToolUse-хуки как быстрая подсказка; активация отложена, см. ADR-0015 | принято, активация отложена |
| [0004](ADR-0004-harness-cleanup.md) | Чистка обвеса harness | убрали неиспользуемые MCP/скиллы/ECC-плагин до внедрения SDD | см. примечание |
| [0005](ADR-0005-hubtalk-backend-gap.md) | Бэкенд-гэп HubTalk | анализ бэкенд-пробела вынесен в отдельный тикет, назначение ответственного отложено Daniil | отложено |
| [0006](ADR-0006-tbd-disciplines.md) | Trunk-Based: дисциплины, не отказ от PR | гейты возраста ветки и размера PR поверх сохранённого PR-флоу; сегодня advisory, мерж не держат (ADR-0015) | см. примечание |
| [0007](ADR-0007-feature-flags.md) | Feature-флаги | свой минимальный реестр флагов на stdlib (env-var + `имя -> expires`), без внешних платформ; с 2026-08-01 - инструмент по требованию, не шаг процесса (ADR-0015) | принято, минимизирован 2026-07-31, dormant 2026-08-01 |
| [0008](ADR-0008-projectstore-rejected.md) | ProjectStore | плагин отклонён; забрали только PreCompact-hook и формат находок doctor | принято |
| [0009](ADR-0009-raise-intake.md) | RAISE дополняет SDD-стек | RAISE решает, что берём в работу; SDD-стек - как из тикета получается код | см. примечание |
| [0010](ADR-0010-task-tiers-models.md) | Тиры задач и модели | три тира (light/standard/deep) с одинаковыми гейтами, модели закреплены в скиллах/агентах | см. примечание |
| [0011](ADR-0011-sdd-tbd-flags-seam.md) | Стык SDD+RAISE+TBD | один change на эпик, флаги вкл/выкл по средам, handoff после мержа | см. примечание |
| [0012](ADR-0012-workflow-clarity.md) | Уточнения WORKFLOW | термины, спорный тест, QA-fallback, эпик, статус | принято |
| [0013](ADR-0013-flag-owner-epic-models.md) | Владелец флага, эпик, модели | гриль-сессия №2: owner владеет флагом, 1 задача = 1 PR, payload профилей | принято |
| [0014](ADR-0014-drop-headroom.md) | Headroom выпилен | 0-2% сжатия, ломает префикс prompt-кэша, +45..62% к счёту; экономия остаётся за rtk/ponytail/graphify | принято |
| [0015](ADR-0015-advisory-first.md) | Advisory-first | branch protection не включаем: серверные гейты - сигналы; флаги - по требованию (dormant); store - контекст для агента; conversation_flow вне кита | принято |
| [0016](ADR-0016-test-author-agent.md) | Тесты пишет агент test-author | тесты до кода пишет выделенный агент по спек-дельте; владение фазой 3 человеком-QA - целевое состояние | принято |
| [0017](ADR-0017-spec-metadata-convention.md) | Метаданные спек | локальные спеки репо - с `id`/`enforced` (их читает spec-lint), контракты стора - проза + якоря `file.py:line` | принято |
| [0018](ADR-0018-store-edit-from-repo-change.md) | Правка стор-контракта из репо-change | текст спеки правится только отдельным change/PR в cybernet-specs; в `tasks.md` репо-change'а обязательна задача-связка; архивация ждёт стор-PR | принято |
| [0019](ADR-0019-cf-onboarding.md) | Онбординг conversation_flow | полная конвертация docs/ в OpenSpec (спеки в репо, 2 контракта в store, слепок в профиле кита), DOCUMENTATION.md ведётся параллельно агентом из дельты; частично отменяет "CF вне кита" из ADR-0015 | принято |
| [0020](ADR-0020-dedup-commands-reviewers.md) | Дедупликация команд и ревьюеров | database-reviewer слит (канон кит), tz-review + plan-griller - оба шага, HIGH=Warning канон, drift-check kit↔plugin, opsx -> скиллы с disable-model-invocation, фиксы planner/plan-griller/openspec-1.7.0 | принято |
| [0021](ADR-0021-executor-tier-pipeline.md) | Executor, тир->конвейер, провенанс гриля | реализация - субагент `executor` на sonnet (строго по tasks.md, стоп при отклонении, без коммитов); таблица "тир -> конвейер -> модели" в SKILL §1b; `## Grill` с шапкой провенанса; закрывает бэклог kit-flow(1-3) | принято |
| [0022](ADR-0022-prompt-text-conventions.md) | Конвенции текстов промптов | правило в промпте фразой, ADR-теги только в grounding-таблице WORKFLOW.md; промпты EN, вывод человеку RU, машинные теги EN (искл.: tools/cf/* RU); skills - канон процедуры, WORKFLOW - обзор; дубли ревьюеров осознанные с sync-маркером | принято |
| [0023](ADR-0023-repo-wiring-local-first.md) | Подключение репо: store, граф, без CI | store одним клоном в фикс-пути (ставит install.sh, машинный реестр = один путь на id); graphify-out/ коммитится, след `Graph probes:` в proposal.md; серверный CI выпилен (шаблоны в архиве) - гейты только локальные; CF: AGENTS.md восстановлен, patch-* скиллы сняты | принято |
| [0024](ADR-0024-brevity-conventions.md) | Краткость: оркестрация в скилле, знания в references | SKILL.md workflow-скилла ≤60 строк (фазы/гейты/делегирование); справочный материал -> references/*.md, доменные правила репо -> AGENTS.md; таблица тиров §1b остаётся в feature-flow; агенты самодостаточны (режется проза, не чеклисты); вендоренные grill-скиллы не редактируются | принято |
| [0025](ADR-0025-dedup2-single-install.md) | Дедупликация №2 + одна команда установки | install сам строит/обновляет граф (consent, default yes) и ставит radon/complexipy/vulture/semgrep; sdd-review сам собирает /tmp/tools.txt; план-ревью = pre-pass 1b гриллера (не новый агент); code-conventions без feature-flow; user-level ECC-ревьюеры заменены каноном кита; модели пиновые, per-invocation override - исключение | принято |
