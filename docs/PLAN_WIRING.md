# PLAN_WIRING — внедрение ADR-0023 (store фикс-путём, граф в git, CI выпилен, CF-конвергенция)

Дата: 2026-08-04. Основание: grill-сессия → ADR-0023.
Дирижёр — главная сессия; работа — сабагентам. Коммиты делает Daniil.
Приоритет репозиториев: conversation_flow; остальные пять — deprecated, пропуск.

## Волна A — sdd-kit: install.sh + sdd-doctor + sdd-check (sonnet, один агент)

1. install.sh --machine-only: клонировать `CybernetKZ/cybernet-specs` в
   `~/cybernet/cybernet-specs` (существующий клон переиспользовать) +
   `openspec store register`; идемпотентно.
2. install.sh --repo-only: НЕ копировать sdd-ci.yml / autoreview.yml;
   `git mv templates/sdd-ci.yml templates/autoreview.yml docs/archive/`;
   вычистить упоминания CI из финальных подсказок install.sh.
3. sdd-doctor: +проверка store (зарегистрирован, путь есть, давность pull —
   WARN), +проверка графа (graph.json есть, отставание от HEAD — WARN),
   +гард AGENTS.md (битый/пустой файл — FAIL, не только «есть и ≤500»);
   тот же гард — в make sdd-check.
4. Самопроверка: свежий scratch-репо, install.sh --repo-only → sdd-check
   зелёный, CI-файлы НЕ появились, sdd-doctor показывает новые секции.

## Волна B — sdd-kit: тексты под ADR-0023 (sonnet, один агент)

1. planner.md: строка `Graph probes: <символы>` / `graph absent: <почему>`
   в proposal.md (провенанс, не гейт); plan-griller.md: читать её.
2. feature-flow §7 / WORKFLOW.md (диаграмма SHIP, карта инструментов,
   Grounding, Status): «серверных гейтов нет, гейты только локальные»;
   tbd-дисциплины — процесс-правило без автоматики.
3. Makefile.sdd / комментарии: убрать упоминания CI-джобов там, где они
   описаны как живые.
4. AGENTS.md-шаблон: setup-шаг store (clone+register — делает install.sh).
5. Grounding-таблица: +строки ADR-0023.

## Волна C — conversation_flow (по одному шагу, с ревью Daniil между)

1. Восстановить AGENTS.md: `git show 9583b791:AGENTS.md` → сверить с новым
   шаблоном, дополнить store/graphify-разделы; CLAUDE.md-симлинк уже верен.
2. `install.sh --repo-only` — свежие промпты (dry-run ревизии ADR-0022).
3. Удалить `.claude/skills/{patch,patch-implement,patch-review}` и
   `.github/workflows/{sdd-ci.yml,autoreview.yml}`.
4. Построить граф: интерактивный `/graphify` (подписка, без ключа) по коду +
   openspec/ + docs/; закоммитить graphify-out/; далее `make sdd-index`
   перед большим intake.
5. Прогон: `make sdd-check` + sdd-doctor зелёные; tz-101 продолжает жить.

## Проверено грилл-сессией (правок не требует)

- Наш workflow ↔ workflow OpenSpec: фазы 1–6 ложатся на цикл
  new change → артефакты → validate → (реализация) → archive; эпик = один
  change, несколько PR; incident = light-тир с root-cause doc; расхождений
  с семантикой OpenSpec не найдено (WEB-2316/tz-101 — живое подтверждение:
  гриль с провенансом, 12 вопросов, план правился).
- Store-факты наших текстов совпадают со stores-beta гайдом (references,
  show --type spec --store, «no sync, ever» = ручной pull).

## Хвосты из прошлых сессий (не забыть)

- Dry-run ревизии текстов = волна C шаг 2 (закрывается здесь).
- tz-101: трейсеры `# spec:` не применимы к TS SDK — зафиксировать замену
  в change; store-контракт SDK: решение runbook «сразу в cybernet-specs»
  не исполнено и не отменено — свериться.
- patch2change.md: невнятная строка про ТЗ №33 — при следующем заходе в CF.
