# PLAN-UNIFY-PLUGIN — унификация sdd-kit + code-conventions

Дата: 2026-08-05. Решения приняты на гриллинг-сессии, зафиксированы в ADR-0027.
Контекст: docs/sdd-kit-vs-code-conventions.md (в ~/cybernet/docs/), PORT-to-code-conventions.md (в репо плагина), ADR-0020, ADR-0025.

## Принятая модель

Два репо остаются. **sdd-kit** — provisioning и процесс (openspec/, AGENTS.md, scripts/sdd/, git pre-commit, .cjs-хуки, ruff.toml, .mcp.json, профили). **code-conventions** — единственный носитель сессионных артефактов: агенты + общие скиллы. Кит при установке включает плагин в целевом репо (enabledPlugins в .claude/settings.json).

Решения:

1. Архитектура: два репо; кит ставит плагин. Монорепо отклонён.
2. В плагин едут: 7 агентов кита + скиллы feature-flow, incident-flow, grilling, grill-me, grill-with-docs, domain-modeling. Enforcement-хуки (.cjs) остаются за китом.
3. Ревьюеры: старые 4 ECC-ревьюера плагина удаляются; канон — backend-reviewer + database-reviewer из кита (Block только на CRITICAL, ADR-0015/0020).
4. gherkin-spec: остаётся в плагине с границей «в репо с openspec/ — не применять, спеки в OpenSpec-формате».
5. feature-flow: канон — версия кита; feature-flow-spawned пересобирается поверх канона или выпиливается, если не используется; кит после переезда удаляет скилл из templates.
6. Каналы суждений: оба. YouTrack KB (Web-A-8) = живые суждения о стиле кода, без PR; ADR/GLOSSARY в ките = процессные решения, через PR. Прецеденс: repo AGENTS.md > KB > скиллы. Правило записывается в оба репо.
7. rtk/ponytail: CLI-бинари (rtk, graphify, ast-grep, ruff, radon/complexipy/vulture/semgrep) ставит кит --machine-only; Claude-Code-плагины (ponytail, rtk-plugin) — dependencies плагина через marketplace. Кит перестаёт ставить ponytail-плагин.
8. Скоуп: унификация + раскатка в conversation_flow + фикс дрейфа AGENTS.md. Активация spec-guard в CF — НЕ здесь (фаза 5 миграции CF, отдельный трек).
9. Фиксация: ADR-0027 (supersedes ADR-0020 §6, ADR-0025 §4) + этот план.

## Фаза 0 — Фиксация (sdd-kit)

- [x] ADR-0027 в docs/ADR/ + пометки superseded в ADR-0020 §6 / ADR-0025 §4 + строка в docs/ADR/README.md.
- [x] Этот файл.

## Фаза 1 — Переезд в code-conventions — DONE 2026-08-05

- [x] Агенты: 7 скопированы в agents/ плагина (подхват глобом agents/*.md); старых 4 ревьюеров как файлов не было — жили только в README, README поправлен.
- [x] Скиллы: feature-flow (канон кита заменил копию плагина), incident-flow, grilling, grill-me, grill-with-docs, domain-modeling; всем `triggers: none`.
- [x] feature-flow-spawned удалён: его смысл (изоляция дорогих стадий) покрыт субагентной схемой канона; восстановим из git-истории.
- [x] gherkin-spec: граница про openspec/ добавлена.
- [x] _NO_PATHS: пройдено (incident-flow ссылался на путь скилла — заменён вызовом по имени).
- [x] check.py ok (1 известный warning grill-me), claude plugin validate ok, тесты хуков ok; версия 1.0.0 → 1.1.0; README/EXTENDING/docs/youtrack-kb.md обновлены (в т.ч. правило каналов суждений).
- [x] Риск-проверка 1: потребителей superpowers не осталось → РЕШЕНИЕ (Daniil, 2026-08-05): убрать из dependencies, оставить опцией в marketplace.json; gate_override.py остаётся; версия → 1.1.1.
- [x] Риск-проверка 2: установленный плагин работает из кэша без marketplace; дыра — свежий clone без доступа к marketplace остаётся без агентов, фейл тихий → в фазу 2 добавлены: проверка в sdd-doctor + правило «--refresh удаляет копии только при подтверждённом плагине».

## Фаза 2 — Сжатие sdd-kit

- [ ] kit_manifest(): убрать агентов и переехавшие скиллы.
- [ ] --refresh: шаг «удалить byte-identical копии переехавших файлов из целевого репо» (правило uninstall).
- [ ] install.sh: прописывать marketplace + enabledPlugins (code-conventions@cybernet) в .claude/settings.json через merge-хелпер, аддитивно.
- [ ] --machine-only: убрать установку ponytail-плагина; CLI-бинари остаются.
- [ ] templates/skills/: удалить переехавшие скиллы (feature-flow и пр.) после подтверждения фазы 1.
- [ ] Доки: README, WORKFLOW.md; правило каналов суждений (п.6) в оба репо.

## Фаза 3 — Раскатка в conversation_flow

- [ ] --refresh на CF: включить плагин, вычистить byte-identical копии переехавших агентов/скиллов из .claude/; НЕ трогать tz/tz-review/tz-implement, хуки, openspec/.
- [ ] AGENTS.md: фикс дрейфа Makefile.sdd → scripts/sdd/*.sh (ADR-0026).
- [ ] Смоук: sdd-doctor, один /tz-цикл, проверить sweep_on_stop/inject_kb рядом с китовскими хуками.
- [ ] spec-guard не трогаем.

## Фаза 4 — Остальные репо (follow-up)

- [ ] --refresh по профилям: web-backend-new, voice-agent-constructor-backend, voice-agent-postcall-analitics-backend, web-frontend-new, cybernet3.0.
