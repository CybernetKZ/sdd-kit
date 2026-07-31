# План обновления sdd-kit (упрощение)

> Дата: 2026-07-31. Основа: [SDD_KIT_LAYERS.md](SDD_KIT_LAYERS.md) (послойный аудит).
> Номера в скобках — пункты из таблиц переусложнений там же.
> Порядок фаз — по эффекту на диффу; внутри фазы задачи независимы.

Прогресс: `[ ]` → `[x]`. Каждая фаза заканчивается проверкой и отдельным коммитом.

---

## Фаза 1. Включить главный гейт (без этого остальное — косметика)

Сегодня блокирует только локальный pre-commit, обходимый `--no-verify` (риск, названный ещё в ADR-0003).

- [ ] 1.1 Закоммитить `sdd-ci.yml` в целевые репо (WBN, VA-ctor, VA-postcall, cybernet3.0, conversation_flow, WFN) — bootstrap кладёт файл, но он не в git.
- [ ] 1.2 Включить branch protection на `dev` в каждом репо: required check `sdd-gate`, запрет прямых пушей.
- [ ] 1.3 Включить protection в `cybernet-specs` (store) и после этого убрать `push: main` триггер из `templates/store-ci.yml` (2.8).

**Проверка**: тестовый PR с невалидной спекой падает на CI; прямой push в dev отклоняется сервером.

---

## Фаза 2. Feature flags: 112 → ~25 строк

Решение: флаги **остаются** (пока действует FAIL>5д на возраст ветки — это единственный клапан для эпиков), но только как dead-flag reaper.

- [x] 2.1 `templates/feature_flags.py`: `FLAGS: dict[str, str]` (имя → expires ISO-дата); `is_enabled()` как есть; `check()` только expires + `GRACE_DAYS=7`. Удалить `FlagMeta`, `owner`, `ticket`, `spec=`, `_store_expires()` (rglob-скан store).
- [x] 2.2 Обновить docstring — он становится каноном lifecycle (owner/ticket живут в OpenSpec change и git blame; кросс-репо = одинаковая дата в двух репо + строка в контракт-спеке).
- [x] 2.3 Решить установку (0.5): добавить `put feature_flags.py` в bootstrap.sh **или** оставить ручное копирование, но написать это в README и убрать иллюзию «гейт работает» (сейчас `make sdd-flags` всегда зелёный в свежем репо). Рекомендация: `put` — одна строка, гейт становится настоящим.
- [x] 2.4 Синхронизировать доки:
  - ADR-0007: убрать «pydantic-settings», описать актуальный минимум; примечание о минимизации (6.1);
  - ADR-0011 §2 + WORKFLOW.md + GLOSSARY.md + feature-flow SKILL: вычеркнуть неимплементированную конвенцию «ON в dev/stage»; заменить на «имя флага и `FLAG_X=1` — в handoff-комментарии QA» (6.2);
  - ADR-0013 §1: примечание, что поля owner в коде больше нет (владелец — из change);
  - ADR/README.md: строка про 0007 (6.1);
  - lifecycle флага в остальных доках (WORKFLOW, ONBOARDING, GLOSSARY, SKILL §4b) сократить до 1 предложения + ссылка на ADR-0007 (6.5).
- [x] 2.5 Промпты: `plan-griller.md:28` — спрашивать только name/expires/поведение при OFF; `feature-flow` §4b сжать до ~5 строк + ссылки на ADR-0007/0011.

**Проверка**: `python3 feature_flags.py --check` — self-test (пустой реестр OK, флаг без expires FAIL, просроченный >7д FAIL); `make sdd-flags` в репо с реестром реально падает на просроченном флаге.

---

## Фаза 3. Ревьюеры 4 → 2

- [x] 3.1 Создать `templates/agents/backend-reviewer.md` (~120–150 строк, sonnet): слить python-reviewer + fastapi-reviewer + из code-reviewer взять анти-шум блок (confidence >80%, pre-report gate, «ноль находок — валидный результат») и бекенд-чеклист. Единые критерии вердикта: **Block = CRITICAL, Warning = HIGH** (разрешить противоречие в пользу code-reviewer). Read-only tools.
- [x] 3.2 Почистить `database-reviewer.md`: удалить Supabase/RLS/`auth.uid()`-контент; убрать Write/Edit из tools; те же критерии вердикта.
- [x] 3.3 Удалить `code-reviewer.md`, `python-reviewer.md`, `fastapi-reviewer.md` из templates и из bootstrap.sh (установка агентов).
- [x] 3.4 Общие блоки (Untrusted input, Spec Compliance, Review discipline, Tool-assisted checks) — один канонический текст в обоих оставшихся агентах, без вариаций (4.2). Параметризовать базу диффа: `${BASE_BRANCH:-origin/dev}` вместо хардкода (4.7).
- [x] 3.5 Обновить ссылки на 4 ревьюеров: `feature-flow` шаг 6, `incident-flow`, `autoreview.yml` (Task-промпт), `Makefile.sdd` (sdd-review), AGENTS.md-шаблон, README/WORKFLOW.
- [x] 3.6 Висячие ссылки (4.4): убрать «see skill: python-patterns / postgres-patterns / database-migrations»; `QA-SDD-PROCESS.md` — либо `put` в bootstrap, либо инлайн 3–4 правил QA в скиллы (рекомендация: инлайн, файл остаётся в ките как target-процесс).

**Проверка**: `grep -r "python-reviewer\|fastapi-reviewer\|code-reviewer" templates/ bootstrap.sh` — пусто (кроме changelog/архива); тестовое ревью диффа двумя агентами.

---

## Фаза 4. Честность гейтов

- [x] 4.1 `Makefile.sdd:45,47`: убрать фиктивный `|| exit 1` у spec-lint и заменить «all gates passed» на честное «gates passed (spec-lint advisory)» (2.1). TODO-строкой: включить `SPEC_LINT_STRICT=1` в CI, когда specs стабилизируются.
- [x] 4.2 AI-промпт в один файл `templates/review-prompt.md` → `.claude/scripts/review-prompt.md`; читать его и в `Makefile.sdd` (sdd-review), и в `autoreview.yml` (2.2).
- [x] 4.3 `autoreview.yml`: проверку `CLAUDE_CODE_OAUTH_TOKEN` — первым шагом job (или `if:` на job), чтобы radon/semgrep не жгли CI впустую (2.3).
- [x] 4.4 Удалить job `reviewdog-ruff` из `autoreview.yml` — не гейтит (`-fail-level=none`), дублирует pre-commit-автофикс (2.4). Линт-гейт — будущий `make test` в sdd-ci.
- [x] 4.5 Слить `repo-audit.sh` в `sdd-doctor.sh` (секция `audit`), один make-таргет `sdd-doctor`; удалить `SDD_AUDIT_STRICT`; personal-секцию (rtk/graphify/ponytail) убрать из doctor — это зона setup-dev (2.5). Обновить bootstrap (установка скриптов, финальный advisory-прогон) и Makefile.sdd.
- [x] 4.6 `feature-flow` шаг 7: пометить traceability gate и QA quality gate как «(planned)» — требование ADR-0012 п.8 (4.5/8).
- [x] 4.7 `QA-SDD-PROCESS.md`: шапка со статусом «target-процесс; примеры путей — из WBN» (6.4).
- [x] 4.8 Пороги PR — одно место истины (6.3): оставить правку в workflow (`PR_XL_LINES`), поправить ADR-0006 п.2 (профили порогов не реализованы).

**Проверка**: `make sdd-check` в репо со STALE-спекой — warn, не блок, и не рапортует «all gates passed» без оговорки; autoreview без секрета завершается за секунды.

---

## Фаза 5. Hooks + settings

- [x] 5.1 Удалить `templates/settings-living-spec.json` и развилку `bootstrap.sh:258-265`: всегда ставить `settings.json` + `spec-guard.js` (opt-in уже делает `.spec-guard-paths`) (1.1). Для conversation_flow решить: spec-guard включается тем же `.spec-guard-paths` — если LIVING-SPEC-репо не должен требовать openspec change, просто не заполнять файл или вынести это в профиль комментарием.
- [x] 5.2 Удалить `templates/format-py.js` и его блок из `settings.json` — pre-commit-ruff покрывает (1.2).
- [x] 5.3 `spec-guard.js:25-32`: walk-up → `process.env.CLAUDE_PROJECT_DIR || process.exit(0)` (1.3).
- [x] 5.4 `pre-compact.js:41`: хардкод `dev` → fallback `origin/HEAD` (1.4).
- [x] 5.5 `block-no-verify.js` — **не трогать** (1.5).

**Проверка**: self-test `block-no-verify.js --test`; spec-guard блокирует правку файла из `.spec-guard-paths` без активной change и молчит без файла.

---

## Фаза 6. Единый install.sh + чистка bootstrap / pre-commit

- [ ] 6.0 **Объединить `bootstrap.sh` + `setup-dev.sh` → `install.sh`** — один вход с вопросами, Enter = дефолт:
  - Один хелпер `ask "вопрос" default` (`[Y/n]` / `[y/N]`), Enter принимает дефолт; `SDD_KIT_ASSUME_YES=1` = все дефолты без вопросов (для CI-smoke); no-TTY = дефолты, но **без** молчаливых `curl|sh`-установок (то, что сейчас делает `ask_core`).
  - Структура — две секции с общим профилем и общими зависимостями:
    1. **Repo** (бывший bootstrap): openspec, youtrack-mcp, AGENTS.md, hooks, агенты, скиллы, CI, pre-commit — как сейчас, вопросы только там, где они уже есть (установить openspec глобально? продолжить без YouTrack? токен?).
    2. **Machine** (бывший setup-dev): «Установить dev-инструменты? [Y/n]» → по одному вопросу на инструмент (ponytail, rtk, graphify, ast-grep — default yes; gh-axi, chrome-devtools-axi, serena — default no). Секция пропускается целиком одним Enter'ом при «n» и при повторных запусках, если инструменты уже стоят.
  - Флаги для частичного запуска: `install.sh --repo-only` / `--machine-only` (замена двух старых скриптов); сами `bootstrap.sh` и `setup-dev.sh` оставить на один релиз как двухстрочные шимы (`exec ./install.sh --repo-only "$@"`), потом удалить.
  - Идемпотентность сохраняется: never-overwrite `put()`, повторный прогон — ноль изменений.
  - Обновить README/README_RU/ONBOARDING (инструкция установки — одна команда) и CI кита (`ci.yml`: shellcheck + bootstrap-smoke зовут `install.sh`).
- [x] ~~6.1~~ ОТМЕНЁН (payload-механизм теперь используется: profiles/voice-agent-constructor-backend/) — Удалить мёртвый шаг 2b «profile payload» (`bootstrap.sh:176-188`) (0.1).
- [ ] 6.2 `PROFILE_STORE=1` — дефолт в bootstrap; убрать строку из 6 профилей (0.2).
- [ ] 6.3 Один источник openspec-пина: git-check и `OPENSPEC=` до store-ветки, убрать дубли строк 74-76 (0.3).
- [ ] 6.4 LIVING-SPEC-вставка в pre-commit: заменить python3-хередок конкатенацией шаблонов при установке; guard `grep -q "make sdd-check"` при кастомном хуке (0.4).
- [ ] 6.5 `pre-commit-hook.sh:20-27`: убрать warn возраста ветки (эхо CI с хардкодом `origin/dev`, врёт для PR не-в-dev) (2.6).
- [ ] 6.6 `pre-commit-hook.sh:106`: гонять `make sdd-check` только если staged задевает `openspec/|AGENTS.md|feature_flags.py` — убирает npx-резолв на каждый коммит (2.7).
- [ ] 6.7 `.gitignore`: `**/.ruff_cache/`, `**/__pycache__/`; удалить кэши из дерева (0.6).
- [ ] 6.8 ~~Слить `ask`/`ask_core`~~ — поглощается 6.0 (0.7). Отдельно остаётся: вычистить остатки headroom из machine-секции (ADR-0014 принят, но headroom ещё упоминается в setup-dev.sh).
- [ ] 6.9 `incident-flow/SKILL.md`: переписать как diff от feature-flow (~30 строк: улики → root-cause → light-тир) (4.6).

**Проверка**: CI кита (`.github/workflows/ci.yml`) зелёный — shellcheck, smoke `SDD_KIT_ASSUME_YES=1 ./install.sh --repo-only` на пустом репо, идемпотентность (md5-diff двух прогонов); no-TTY-прогон не выполняет ни одного `curl|sh`; в smoke-репо больше нет `settings-living-spec.json`, `format-py.js`, 4 старых ревьюеров.

---

## Фаза 7. Раскатка по репо

Bootstrap never-overwrite: существующие репо обновлений **не получат** сами.

- [ ] 7.1 Для каждого целевого репо: удалить устаревшие файлы (`format-py.js`, старые ревьюеры, `settings-living-spec.json` если есть) и перезапустить `bootstrap.sh` для установки новых версий (или точечно скопировать изменённые шаблоны).
- [ ] 7.2 Обновить `.claude/settings.json` в репо, где он уже существовал до этого обновления (bootstrap его не тронет — merge руками).
- [ ] 7.3 Прогнать `make sdd-doctor` в каждом репо — ноль fail.

---

## Не трогать (зафиксировано аудитом)

- `block-no-verify.js`, `planner.md`, `plan-griller.md` — образцы минимализма.
- Паттерн «один `make sdd-check` → pre-commit + CI».
- `tbd-gates` в sdd-ci (возраст/размер PR + escape-hatch лейбл+обоснование).
- `spec-guard.js` по сути (только упрощение поиска корня, 5.3).

## Итоговый эффект (оценка)

| Метрика | До | После |
|---|---|---|
| Шаблонов-файлов | 27 | ~22 (−settings-living-spec, −format-py, −3 ревьюера, −repo-audit; +backend-reviewer, +review-prompt) |
| Строк промптов ревью | ~730 | ~300 |
| feature_flags.py | 112 | ~25 |
| Скриптов установки | 2 (bootstrap.sh 361 + setup-dev.sh 139) | 1 (`install.sh` ~400, `--repo-only`/`--machine-only`) |
| Advisory-каналов ruff/AI | 4 | 2 |
| Блокирующих гейтов, реально включённых | 1 (локальный, обходимый) | 2 контура ADR-0003 (server-side CI + хуки) |
