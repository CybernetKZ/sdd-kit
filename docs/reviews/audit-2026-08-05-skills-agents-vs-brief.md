# Аудит 2026-08-05: скиллы и агенты vs BRIEF-CONCEPT + skill-creator

Проверка 9 файлов (feature-flow, incident-flow, 7 агентов) против
BRIEF-CONCEPT.md и чеклиста Anthropic skill-creator
(docs/archive/skill-creator.md). Три субагента: выжимка чеклиста (sonnet),
ревью агентов (opus), ревью скиллов (sonnet); сводка и фильтрация — сессия.

## Чеклист skill-creator (выжимка, с привязкой к строкам источника)

- description = единственный триггер: «что» + «когда» в description, не в теле;
  лимит 1024 символа, рекомендация ~100-200 слов; imperative («Use when…»);
  intent-focused; «pushy» триггер-фразы — хорошо (модели undertrigger);
  без `<`/`>`; отличим от соседей (строки 68, 4436-4441).
- name: kebab-case `^[a-z0-9-]+$`, ≤64, без ведущих/двойных дефисов (~4756-4761).
- Разрешённые ключи frontmatter скилла: name, description, license,
  allowed-tools, metadata, compatibility (~4733).
- Progressive disclosure: тело <500 строк; references по явному указателю
  «когда читать»; reference >300 строк — TOC (89-99). Канон кита жёстче:
  workflow-SKILL.md ≤60 строк (ADR-0024) — осознанное ужесточение.
- Стиль: imperative; объяснять «почему», не голые MUST; ALL CAPS
  ALWAYS/NEVER — yellow flag; убирать «not pulling its weight»; не overfit;
  явные шаблоны вывода — хорошо (118-140, 299-305).

## Вердикт сводный

Хорошее: оба скилла проходят name/frontmatter/progressive disclosure
(взаимные указатели «когда читать» — образцовые); карта брифа → фазы сходится
с учётом записанных отклонений; shared-блоки ревьюеров побайтово синхронны
(сверено программно по 7 маркерам); модели planner/plan-griller=opus,
test-author/executor=sonnet — по карте; `ADR-XXXX` в промптах — 0 (ADR-0022);
правило языка есть у всех, кроме planner.

### P0 — реальные баги (подтверждены грепом в сессии)

1. **planner.md:26-46 — непинованный `openspec`.** install.sh:44-50 прямо
   запрещает глобальный бинарь (дрейф, P0-1); в целевом репо его может не
   быть → команды планнера падают или подцепляют дрейфующую версию. Та же
   голая форма: templates/AGENTS.md:28-38, feature-flow/references/details.md:31-34.
   Фикс: пин `npx -y @fission-ai/openspec@1.7.0` (шорткат `$OS`) во всех трёх
   местах + обновить счётчик пинов в README.
2. **Путь ревью инертен к frontmatter.** review.sh:38 зовёт `claude -p` без
   `--model` (бриф: «opus: ревью имплементации»; model: sonnet ревьюеров в
   этом пути не применяется вовсе — агент-файлы там лишь «правила» через
   review-prompt.md). Shared-блок «Tool-assisted checks»
   (backend-reviewer.md:115-130 / database-reviewer.md:93-108) неисполним в
   этом пути (`Bash` не в --allowedTools) и дублирует сбор лидов review.sh
   с ДРУГИМИ порогами (radon --min B vs -n C; vulture default vs
   --min-confidence 80; semgrep p/security-audit vs --config auto). Плюс
   BASE_BRANCH в блоке не читает SDD_REVIEW_BASE — база диффа расходится.
   Фикс: `--model opus` в review.sh (или записать отклонение от брифа
   отдельным решением); в shared-блок — «если /tmp/tools.txt существует —
   читай его, не перезапускай тулзы»; выровнять пороги;
   `BASE_BRANCH=${SDD_REVIEW_BASE:-…}`.
3. **Триггеры ревьюеров ломают порядок feature-flow.**
   backend-reviewer.md:3 «MUST BE USED immediately after backend code
   changes» приглашает автовызов посреди работы executor — а порядок
   фиксирован (ревью = шаг 6, после зелёных тестов, «never swapped»).
   database-reviewer.md:3 зовёт агента в момент НАПИСАНИЯ запроса, а тело —
   ревью диффа. Отличимость трёх ревьюеров (backend/database/generic
   code-reviewer) из описаний не считывается. Фикс: переписать оба
   description — «Use on a finished branch diff - feature-flow step 6,
   before the PR - not per-edit», развести зоны (SQL/ORM/миграции ↔
   application-level Python), убрать MUST BE USED.

### P1 — контракты, ссылки, канонические пути

4. **planner.md — нет output-контракта и правила языка отчёта** (единственный
   такой агент). Фикс: секция `## Report (Russian)` со строками
   Change/tier/validate, Graph probes, UNVERIFIED, вердикт
   `READY FOR GRILL`/`BLOCKED:`.
5. **executor.md:53-59 и test-author.md:78-90 — нет машиночитаемого
   вердикта** (проза; у гриллера/ревьюеров вердикт-строка есть). Фикс:
   `Verdict: DONE`/`BLOCKED: task <N>`; `Verdict: RED CONFIRMED (<n>/<m>)`.
6. **test-author.md:75 — висячая ссылка на QA-SDD-PROCESS.md** (в целевом
   репо файла нет, kit_manifest его не копирует). Фикс: убрать скобку.
7. **executor.md:38 и test-author.md:52-60 обходят канонический
   scripts/sdd/test.sh** (теряется SDD_TEST_CMD; test-author вручную
   переизобретает докер-логику). Фикс: «repo's runner is `bash
   scripts/sdd/test.sh` (honors SDD_TEST_CMD)»; докер-абзац ужать.
8. **plan-griller.md:3 — description молчит про pre-pass** (план-ревью слито
   в шаг 1b по ADR-0025 — сессия может искать несуществующий plan-reviewer);
   plan-griller.md:36 «the ponytail lens» без оговорки «дисциплина, не скилл»
   (сабагент скиллы звать не может; planner:18-26 такую оговорку несёт).
9. **database-reviewer: DB-probe + N/A-escape из ADR-0020 §1 не
   реализованы** (три голых psql без проверки досягаемости БД; install.sh
   ставит агента безусловно). Асимметрия hardening-преамбулы: pre-report
   gate / zero-findings-valid / confidence-filtering есть только у
   backend-reviewer и не помечены shared block. Фикс: probe `psql -c 'select
   1'` + N/A-режим; преамбулу — shared block в оба файла (доменные списки
   ложных срабатываний оставить разными).

### P2 — стиль (yellow flags)

10. feature-flow/SKILL.md:51,52,54 — капс `WITH`/`AGENT`/`ALWAYS` без причины
    рядом; details.md:177 vs 193 — `ONLY`/`only` вразнобой; SKILL.md:3 —
    триггер-фраза "possible new task" — калька, заменить на «новая задача».
11. database-reviewer.md:42 «no exceptions» и planner.md:83 «Never split a
    non-epic» — абсолюты без причины; переформулировать с «почему».
12. Маркер `shared block` на однострочном «Untrusted input» вводит в
    заблуждение: те же полторы строки без маркера в 5 других агентах —
    пометить как общий hardening-канон всех агентов кита.
13. В шапку BRIEF-CONCEPT стоит дописать решённое отклонение: «opus-оркестратор
    параллельных sonnet-имплементаторов» → один последовательный executor,
    оркестратор = сессия (details.md:138: parallel executors — later step).

### Отклонено фильтром сессии (не находки)

- «incident-flow 61 строка» — устарело: файл уже 60 строк (проверено wc -l).
- «grill без формата рекомендаций» — ложная: `Recommended answer` вшит в
  plan-griller.md:23,57,68; details.md не обязан дублировать (ADR-0024).
- «descriptions короче 100-200 слов» — осознанная краткость (ADR-0024);
  расширение только там, где краткость съела отличимость (находка 3).
- Переименование `executor` → change-executor — выгода спорная, тянет
  манифест install.sh и feature-flow; отложено.
- Модели «opus/sonnet на бегу» из брифа — решено иначе (пин, ADR-0010/0013),
  зафиксировано в шапке брифа.

## Сверка openspec-команд с context7 (/fission-ai/openspec, 2026-08-05)

Все формы, которые используют planner/plan-griller/AGENTS.md/details.md/скрипты,
подтверждены официальной документацией:

| Команда кита | Статус по docs |
|---|---|
| `openspec new change <id>` (+ `--json`) | ✓ |
| `openspec status --change <name>` (+ `--store`) | ✓ |
| `openspec instructions <artifact> --change <id> --json` | ✓ |
| `openspec validate <item> --strict` / `--all --strict` | ✓; у validate НЕТ флага `--change` — одиночный item только позиционным аргументом (кит так и делает) |
| `openspec store list` / `store register <path> --id <id>` | ✓ |
| `openspec show <spec> --type spec --store <id>` | ✓ |
| `openspec list --specs --store <id>` | ✓ (list переключается changes/specs, --store поддержан для list/show/status/validate/archive) |

Расхождений НЕ найдено. Нюанс: в свежих доках появились context-store /
initiatives (пост-1.7.0, в разработке) — к пину 1.7.0 не относятся; ещё один
аргумент за пин и против глобального бинаря (P0-находка 1: сам вызов должен
быть `npx -y @fission-ai/openspec@1.7.0`, иначе дрейф в эти новые формы).

## Статус: правки применены 2026-08-05

Все P0/P1/P2 внесены («выполняй»). По открытому вопросу применена буква
брифа: `claude -p ... --model opus` в review.sh (комментарий в скрипте
объясняет, что frontmatter-модель ревьюеров действует только в
сабагент-пути). Откат на модель сессии — одна строка, если opus окажется
дорог. Дополнительно: пин openspec размечен `openspec-pin` во всех местах
вызова (README теперь отсылает к grep, а не считает руками); в шапку
BRIEF-CONCEPT дописано отклонение «оркестратор = сессия, executor
последовательный» (ADR-0021).
