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
- [x] feature-flow-spawned: сначала удалён (предпосылка «не используется»), но 2026-08-05 Георгий (godjan-cn) запушил в main его доработку (Claude+Codex) — предпосылка неверна. При merge main→dev восстановлена версия Георгия целиком (включая references/stages/). FOLLOW-UP: скилл ссылается на старые шаги feature-flow (§1b/§2, superpowers:brainstorming/writing-plans, docs/superpowers/plans/) — согласовать с Георгием пересборку поверх нового канона (planner/plan-griller).
- [x] gherkin-spec: граница про openspec/ добавлена.
- [x] _NO_PATHS: пройдено (incident-flow ссылался на путь скилла — заменён вызовом по имени).
- [x] check.py ok (1 известный warning grill-me), claude plugin validate ok, тесты хуков ok; версия 1.0.0 → 1.1.0; README/EXTENDING/docs/youtrack-kb.md обновлены (в т.ч. правило каналов суждений).
- [x] Риск-проверка 1: потребителей superpowers не осталось → РЕШЕНИЕ (Daniil, 2026-08-05): убрать из dependencies, оставить опцией в marketplace.json; gate_override.py остаётся; версия → 1.1.1.
- [x] Риск-проверка 2: установленный плагин работает из кэша без marketplace; дыра — свежий clone без доступа к marketplace остаётся без агентов, фейл тихий → в фазу 2 добавлены: проверка в sdd-doctor + правило «--refresh удаляет копии только при подтверждённом плагине».

## Фаза 2 — Сжатие sdd-kit (сделано 2026-08-05)

- [x] kit_manifest(): убрать агентов и переехавшие скиллы.
- [x] --refresh: шаг `cleanup_migrated()` — удалить byte-identical копии переехавших файлов из целевого репо (правило uninstall: текущий шаблон в `templates/_migrated/` ИЛИ любой blob из истории кита), только когда плагин подтверждён (enabledPlugins + реально установлен на машине); иначе файлы остаются с предупреждением.
- [x] install.sh: marketplace + enabledPlugins (code-conventions@cybernet) в `.claude/settings.json` — аддитивно, через `merge_settings()` (бывший `merge_settings_hooks()`); источник истины — `templates/settings.json`.
- [x] --machine-only: установка ponytail-плагина убрана (только сообщение, что он приходит зависимостью плагина); CLI-бинари остаются.
- [x] templates/skills/ + templates/agents/: переехавшие файлы перенесены в `templates/_migrated/` (не устанавливаются; нужны как эталон для byte-identical сравнения в refresh и uninstall).
- [x] sdd-doctor: проверка `repo.plugin` (enabledPlugins + наличие плагина на машине) + аудит `audit.{skill,agent}-migrated` для локальных копий-теней.
- [x] uninstall.sh: пути переехавших файлов переведены на `templates/_migrated/`; поведение (byte-identical, --force, kit_had по истории) не менялось.
- [x] Доки: README (таблица «What it installs», refresh/uninstall, --machine-only, правило каналов суждений), WORKFLOW.md, GLOSSARY (test-author/executor), templates/AGENTS.md (precedence). Правило каналов суждений в code-conventions — **не сделано** (этот проход трогал только sdd-kit).

## Фаза 3 — Раскатка в conversation_flow — DONE 2026-08-05

- [x] --refresh на CF: 7 файлов обновлено (block-no-verify.cjs, spec-guard.cjs, spec-lint.py, sdd-doctor.sh, review-prompt.md, scripts/sdd/review.sh, scripts/sdd/doctor.sh); в .claude/settings.json аддитивно добавлены `extraKnownMarketplaces.cybernet` + `enabledPlugins["code-conventions@cybernet"]`, свои hooks-записи CF (pretooluse_guard.py и др.) сохранены. Копии переехавших 7 агентов и 6 скиллов **оставлены** — плагина нет на машине, cleanup_migrated() отработал по правилу «не удалять без подтверждённого плагина» и предупредил. tz*/хуки/openspec/ не тронуты.
- [x] AGENTS.md: секция «Команды» переписана на `scripts/sdd/{check,doctor,test,review,index}.sh` (Makefile.sdd упразднён, ADR-0026); секция оснастки кита — на ADR-0027 (агенты + общие скиллы из плагина, копии в .claude/ помечены как тени), добавлен прецеденс «AGENTS.md > YouTrack KB > скиллы». 312 строк (гейт ≤500).
- [x] Смоук: sdd-doctor — 21 ok / 15 WARN / 0 FAIL (WARN: repo.plugin не установлен, spec-guard no-op, 13× shadow-копии); scripts/sdd/check.sh — OK (openspec validate --strict прошёл, spec-lint advisory). /tz-цикл не гоняли (интерактивный, отдельно).
- [x] spec-guard не трогали.
- **Осталось пользователю (интерактивно):** `claude plugin marketplace add CybernetKZ/code-conventions && claude plugin install code-conventions@cybernet`, затем повторный `sdd-kit/install.sh --refresh /home/octrow/cybernet/conversation_flow` — он снесёт byte-identical копии агентов/скиллов.

## Фаза 4 — Остальные репо (follow-up)

- [ ] --refresh по профилям: web-backend-new, voice-agent-constructor-backend, voice-agent-postcall-analitics-backend, web-frontend-new, cybernet3.0.
