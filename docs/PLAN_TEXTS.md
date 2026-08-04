# PLAN_TEXTS — ревизия текстов кита (skills/agents/prompts/tools)

Дата: 2026-08-04. Основание: grill-сессия → ADR-0022 (конвенции текстов).
Дирижёр — главная сессия Claude Code; работа — сабагентам (opus/sonnet).
Коммиты делает Daniil после ревью диффов каждой волны.

Приоритет при конфликте правок: правильность → эффективность промпта →
дедупликация → экономия токенов (ADR-0022 п.1).

## Найденный дрейф (входной список, дополняется волнами)

- `WORKFLOW.md` «Where the named pieces live»: нет строки `executor` (ADR-0021).
- `WORKFLOW.md` дублирует feature-flow: тиры, эпики, disputed tests,
  who-writes-tests — канон уезжает в skills (ADR-0022 п.3).
- `feature-flow` ~30 ADR-тегов; store-команды openspec повторены трижды
  (feature-flow, incident-flow, AGENTS.md) — оставить один полный вариант,
  остальным по одной строке.
- `planner.md`: CLI-шпаргалка дублирует openspec-propose skill — сверить и
  оставить ссылку + минимум; ADR-теги.
- `plan-griller.md`: description во frontmatter разросся до абзаца — критичную
  часть (одноразовый отчёт, нет канала к разработчику) перенести в тело,
  description сжать до триггера использования.
- `test-author.md` / `executor.md`: добавить русский язык отчётов (ADR-0022 п.4).
- `backend-reviewer.md` / `database-reviewer.md`: shared-блоки без sync-маркера;
  пояснения findings — на русский, формат строки/вердикты английские.
- `repo-auditor.md`: единственный русский агент — перевести промпт на EN
  (вывод RU); нет untrusted-input преамбулы; нет `model:` во frontmatter.
- `AGENTS.md`: store-команды дублируют feature-flow; graphify-блок почти
  дословно повторён в feature-flow/incident-flow — оставить канон здесь,
  в skills сослаться.
- `tools/cf/mine-section.md`: захардкожен абсолютный путь `/home/octrow/...`.
- Конфиги/скрипты: ADR-теги в комментариях — по ADR-0022 п.2 комментарии кода
  это доки, теги можно оставить; выправить только устаревшие формулировки.

## Волна 0 — эталон (research, 1 сабагент sonnet)

Вход: доки Anthropic (subagents, skills, system prompts, prompt engineering),
лучшие примеры agent-файлов. Выход: `docs/reviews/prompt-checklist.md` —
чеклист «как писать skill/agent текст» (структура, frontmatter description,
императивы, output-контракт, чего не писать). Этот чеклист — вход каждого
рерайт-сабагента волн 1–3.

## Волна 1 — канон (opus, последовательно: файлы связаны)

Файлы: `templates/skills/feature-flow/SKILL.md`,
`templates/skills/incident-flow/SKILL.md`, `WORKFLOW.md`.

1. feature-flow: вычистить ADR-теги (правило остаётся фразой), вобрать
   канон-куски из WORKFLOW (если чего-то не хватает), русские вопросы
   разработчику/автору тикета, дедуп store/graphify-блоков (ссылка на
   AGENTS.md), пройтись чеклистом волны 0.
2. incident-flow: то же, синхронно с feature-flow (она на него ссылается).
3. WORKFLOW.md: сжать до обзора (диаграммы, карта инструментов, статус),
   добавить grounding-таблицу «правило/кусок → ADR», добавить executor
   в таблицу pieces, убрать продублированные разделы.

Критерий приёмки: ни одного `ADR-` в текстах skills; каждый удалённый из
WORKFLOW раздел имеет строку-ссылку; grounding-таблица покрывает все теги,
которые были вычищены из промптов.

## Волна 2 — агенты (7 файлов, параллельные сабагенты; opus для
plan-griller/reviewers, sonnet для остальных)

Каждому сабагенту: файл + чеклист волны 0 + выжимка решений ADR-0022 +
список дрейфа выше. Правки:

- `planner.md`, `plan-griller.md`, `executor.md`, `test-author.md`:
  ADR-теги → фразы; русский вывод человеку; сжать frontmatter description;
  сверить CLI-факты (openspec 1.7.0) перед сокращением шпаргалок.
- `backend-reviewer.md`, `database-reviewer.md`: sync-маркеры вокруг shared
  блоков; RU-пояснения findings; выправить дрейф чеклистов, если найдётся.
- `repo-auditor.md`: перевод промпта на EN (вывод RU), untrusted-input
  преамбула, `model:` во frontmatter (предложение: sonnet).

Критерий приёмки: файл самодостаточен, description ≤ 2 предложений-триггеров,
output-контракт явный, языковая политика соблюдена.

## Волна 3 — мелкие файлы и конфиги (sonnet, параллельно)

- `templates/AGENTS.md`: стать каноном store/graphify-команд; TODO-скелет
  оставить.
- `templates/review-prompt.md`: RU-пояснения findings (синхронно с волной 2).
- `templates/autoreview.yml`, `templates/sdd-ci.yml`, `templates/Makefile.sdd`,
  `templates/living-spec-check.sh`: комментарии/echo/usage + мелкая логика,
  если всплывёт; после правок прогнать `make sdd-check` и, где есть,
  self-check.

## Волна 4 — tools/cf/* (sonnet, light pass, остаются русскими)

`main-drift.sh` (комментарии/usage/echo; логика — только с `--self-check`
зелёным), `mine-section.md` (убрать абсолютный путь), `patch2change.md`,
`sync-main.md`, `verify-section.md` — фактический дрейф и неясные строки,
без реструктуризации. Заморозка после фазы 3 CF.

## Волна 5 — сверка и dry-run

1. Дирижёр читает все диффы целиком: кросс-ссылки (skills ↔ AGENTS.md ↔
   WORKFLOW), не потерялось ли правило при вычистке тегов (grep по каждому
   ADR-номеру: правило либо в grounding-таблице, либо фразой в тексте).
2. `make sdd-check` в тестовом репо после `install.sh --repo-only`.
3. Обновить GLOSSARY.md и статус-таблицу WORKFLOW.md.
4. Dry-run на реальном тикете с новыми текстами — репозиторий выбрать здесь
   (кандидаты: WBN с benchmark-сетапом, conversation_flow/test-sdd-kit).
5. Ревью Daniil → коммиты Daniil.

## Чего в плане нет (осознанно)

- Сборка агентов из фрагментов — отклонена (ADR-0022 п.5): дубли осознанные.
- Перевод tools/cf/* на английский — отклонён (ADR-0022 п.4, исключение).
- Рефакторинг логики скриптов — только мелочи по пути, не цель.
