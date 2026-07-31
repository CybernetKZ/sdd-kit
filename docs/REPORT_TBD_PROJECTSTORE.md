# Отчёт: Trunk-Based Development + feature flags и SmartAndPoint/ProjectStore

Дата: 2026-07-30. Метод: два Opus-субагента (research + code-audit), синтез Fable 5.
Дополняет `TASK_SDD_SELECTION.md`, `SDD_EVALUATION.md`, ADR-0001…0005.

Обновление после grill-сессии 2026-07-30 (решения Daniil, зафиксированы в ADR-0006…0009):
- пороги гейтов включаем сразу, без спринта наблюдения; значения — на репозиторий
  в `profiles/<repo>.env`; лейбл-исключение вешает любой, но с обоснованием в PR;
- просроченный флаг: 7 дней WARN, потом FAIL (вместо FAIL сразу);
- кросс-репо флаги: дата `expires` живёт в спеке контракта в cybernet-specs, репо наследуют;
- рецепт миграции контрактов — секция в feature-flow, без отдельного skill;
- новое вводное: внутренний intake-процесс RAISE (RICE-приоритизация) — слой над
  SDD-стеком, стык описан в ADR-0009; спека обязательна и для urgent/багов (минимальная).

## Итог в двух строках

1. **TBD — принять частично.** Оставляем ветку → PR → dev, добавляем дисциплины TBD
   (лимит возраста ветки, лимит размера PR) и минимальные feature-флаги с датой смерти.
   Прямые коммиты в trunk — нет: они отключают все наши PR-гейты.
2. **ProjectStore — отклонить.** Это не store спек, а Obsidian-vault «память проекта».
   Проваливает критерий №1 (нет multi-repo) и №2 (doctor всегда exit 0 — не гейт).
   Забираем две идеи, сам плагин не ставим.

---

## Часть 1. Trunk-Based Development + feature flags

### Вердикт: adopt-partially

Сам trunkbaseddevelopment.com говорит: при обязательном code review правильный вариант
TBD — короткоживущие ветки + PR, а не прямые коммиты
(https://trunkbaseddevelopment.com/short-lived-feature-branches/).
Наш стек гейтов (spec-guard, sdd-gate, autoreview) — это и есть обязательное ревью.

Прямые коммиты в trunk мы уже «пробовали»: cybernet3.0 — 1780 коммитов прямо в dev,
покрытие тикетами 12.1% (`OUR_PATTERNS.md:27,31`). Убрать PR = убрать точку,
к которой прикреплён `sdd-ci.yml` (триггер только `pull_request`).

Цели DORA — про время жизни веток, а не про их отсутствие: ≤3 активных ветки,
merge в trunk минимум раз в день (https://dora.dev/capabilities/trunk-based-development/).
Это достижимо с PR.

Наша реальная проблема — размер батча: медиана PR в WBN 412 строк, но p90 = 4221 строка
и 62 файла (`OUR_PATTERNS.md:34-35`); 18.4% тикетов требуют >1 PR (`:46`).
Главный риск по DORA — тяжёлое медленное ревью заставляет копить большие батчи.
Значит блокирующим оставляем только быстрый `make sdd-check`; AI-ревью — advisory,
второй блокирующий LLM-проход не добавляем.

### Что добавить в sdd-kit

| # | Изменение | Где | Суть |
|---|---|---|---|
| 1 | Гейт возраста ветки | `templates/sdd-ci.yml` | merge-base с dev: WARN >2 дней, FAIL >5, лейбл `long-lived-ok` для исключений |
| 2 | Гейт размера PR | `templates/sdd-ci.yml` | `CodelyTV/pr-size-labeler`; месяц только лейблы, потом `fail_if_xl` (XL ≈ 1500 строк — калибровать по нашему p90, не проверено) |
| 3 | Локальный WARN возраста | `templates/pre-commit-hook.sh` | предупреждение «rebase или дели OpenSpec change»; только warn, не блок |
| 4 | Реестр флагов + expiry-гейт | новый `templates/feature_flags.py` + `make sdd-flags` | pydantic-settings `Flags` + метаданные `owner/ticket/expires`; просроченный флаг валит `sdd-check` («time bomb» Фаулера: https://martinfowler.com/articles/feature-toggles.html) |
| 5 | Правки feature-flow | `templates/skills/feature-flow/SKILL.md` | ветка живёт ≤2 дней — иначе дели change; флаг + `expires` объявляется в OpenSpec change; «удалить флаг» — задача в том же tasks.md |
| 6 | Рецепт миграции контрактов | `templates/AGENTS.md` или skill `migration-flow` | branch-by-abstraction + expand/contract для api/v1 и redis-стримов |

**Не берём:** Unleash / Flagsmith / OpenFeature-платформы. Они дают таргетинг по
пользователям, %-раскатку и UI — ничего из этого нет в требованиях, а стоят
self-hosted сервис + SDK в каждом репо. Если %-раскатка понадобится — путь миграции:
`openfeature-sdk` + flagd; чтобы он был дешёвым, реестр из п.4 пишем как функцию
`is_enabled("x")`, а не чтение settings в местах вызова.

**Флаги нужны в первую очередь для миграции HubTalk / отказа от Asterisk:**
абстракция над текущим поставщиком, конфиг-флаг выбирает реализацию, потом удаляем
(branch by abstraction, https://martinfowler.com/bliki/BranchByAbstraction.html).
Для redis-контрактов — expand/contract: новые поля optional → оба консюмера читают →
флаг переключает продюсера → старые поля удаляются до `expires`.
(не проверено: возможен ли dual-write на стороне HubTalk — зависит от ADR-0005.)

### Сравнение подходов

| Измерение | Сейчас: ветка → PR → dev, без лимитов | + дисциплины TBD (предложение) | Чистый trunk (прямо в dev) |
|---|---|---|---|
| Привязка SDD-гейтов | работает (PR-триггер) | без изменений | **ломается** — PR нет, гейтов нет |
| Цена интеграции/конфликтов | p90 PR 4221 строка — большие merge | маленькие батчи, ветки ≤2 дней | минимальная, но нужны быстрые тесты, которых нет |
| Переделки (сейчас 18.4%) | большие батчи прячут дефекты | должны упасть (не проверено — замерить в пилоте) | у cybernet3.0 с прямыми коммитами переделки 43.8% на тонкой выборке |
| Принудимость (вес 25) | branch guard + sdd-gate | +2 машинных чека, без ручных решений | худшая — гейтить нечего |
| Цена внедрения | 0 | 1 CI-файл + 1 make-таргет + 1 модуль-шаблон | высокая (культура + скорость тестов) |
| Незавершённая работа в dev | невозможна | нужны флаги для работы >1 дня | нужны флаги для всего |

### Порядок внедрения

1. Лейблы размера PR + WARN возраста ветки (ничего не блокирует) — спринт сбора базы.
2. `feature_flags.py` + `make sdd-flags`; первый потребитель — работа по HubTalk/Asterisk.
3. Только после замеров включить `fail_if_xl` и FAIL на 5 днях.

---

## Часть 2. ProjectStore vs openspec store vs Graphify

### Вердикт: отклонить (украсть 2 идеи)

ProjectStore (https://github.com/SmartAndPoint/ProjectStore) — не хранилище спек,
несмотря на имя. Это Claude Code-плагин «память проекта» поверх Obsidian-vault:
ADR, эпики, stories, kanban, session-continuity. Клон для проверки:
`/tmp/claude-1000/.../scratchpad/ProjectStore`.

Факты из кода:

- v0.13.0, 10 `.mjs`-скриптов (~2100 строк), zero deps; команды — LLM-промпты,
  файлы пишет агент (каждый артефакт = LLM-ход).
- Один vault на проект (`.claude/projectstore.json` → `vault_path`), поля `repo` нет
  нигде; `code_refs` резолвятся от корня одного проекта (`doctor.mjs:557`) —
  **multi-repo нет**.
- `doctor.mjs` — 17 детерминированных чеков, но `main()` всегда exit 0 —
  **гейтом быть не может** без обёртки.
- Зрелость: 48 коммитов одного человека, 5 звёзд, 0 issues, тестов и CI нет,
  последний коммит 2026-07-03 (полгода тишины на сегодня), pre-v1, MIT.

### Сравнение

| Ось | ProjectStore | `openspec store` | Graphify |
|---|---|---|---|
| Назначение | память проекта: решения, stories, доска | хранилище capability/delta-спек | производный граф знаний для навигации |
| Multi-repo | **нет** (один vault, refs от одного корня) | **да** (registry + `references:` в config.yaml) | **да** (merge нескольких репо в один граф) |
| CI-гейт | нет (doctor exit 0) | частично (`validate --strict`; cross-repo refs — warn-only) | никогда (INFERRED-рёбра, вне скоупа) |
| Интеграция с агентом | глубокая: 18 команд, 5 opus-агентов, 3 hooks | CLI + рендер `<referenced_stores>` | CLI + `--mcp` |
| Перекрытие с нашим | доска/stories = YouTrack; reviewer/critic = ECC-ревьюеры; archaeologist = spec-miner; codemap = Graphify | это наш выбранный слой | это наш выбранный слой |

По четырём узким местам (§3 TASK): спеки — слабее OpenSpec (нет delta, нет валидации);
кросс-репо контекст — **провал**; контракты — ноль; ревью — частично (проверка story
по acceptance criteria — угол, которого у наших ревьюеров нет, но требует vault и
opus/max на каждую story).

Единственный настоящий пробел, который он закрывает, — хранение rationale решений
с отклонёнными альтернативами. Мы это уже делаем руками (`ADR/`),
20-строчный шаблон ADR закрывает пробел без плагина.

Конфликты при гипотетическом внедрении: пишет agents-блок в `CLAUDE.md`
(а у нас `CLAUDE.md` — симлинк на `AGENTS.md`, канон ADR-0002, бюджет ≤500 строк);
18 команд + 5 агентов + 4 skills + 3 hooks — прямое противоречие ADR-0004
(чистка обвеса до внедрения).

### Две идеи, которые портируем в sdd-kit

1. **PreCompact-hook** (по образцу `hooks/pre-compact.mjs`): «пакет выживания» перед
   компакцией — активный `openspec/changes/<id>`, недавние правки. У нас PreCompact
   hook отсутствует.
2. **Форма находок doctor** `{group, level, code, message, file}` + точная команда
   фикса на каждую находку; и приём «перегенерируй производный файл настоящим
   генератором и сравни с закоммиченным» — чистый способ сделать производные
   вью гейтуемыми (пригодно для spec freshness в `spec-lint.py`).

### Строка для SDD_EVALUATION.md

> ProjectStore — отклонено: проваливает критерий 1 (один vault, нет multi-repo)
> и критерий 2 (doctor всегда exit 0, гейта нет); слой work-items дублирует YouTrack.
> Не путать с `openspec store` и нашим `cybernet-specs` — это три разные вещи.

---

## Сводный список действий

1. [x] sdd-kit: пункты 1-6 из части 1 — сделано 2026-07-30: job `tbd-gates` в
   `sdd-ci.yml`, WARN возраста ветки в pre-commit, `feature_flags.py` +
   `make sdd-flags` (в составе `sdd-check`), правки feature-flow (RICE-форма,
   лимит ветки, шаг 4b: флаги + expand/contract + branch by abstraction),
   `PROFILE_PR_XL_LINES` в профилях.
2. [x] sdd-kit: PreCompact-hook (`pre-compact.js` → `.claude/last-session-state.md`)
   и doctor-формат находок `{level, group, code, message, next}` + `--json`
   в `sdd-doctor.sh` и `repo-audit.sh` — сделано 2026-07-30.
3. [x] `SDD_EVALUATION.md`: строка «отклонено» для ProjectStore.
4. [ ] Пилот: замерить размер PR и переделки после включения блокирующих порогов.
