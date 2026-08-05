# ADR-0020. Дедупликация команд и ревьюеров: kit ↔ code-conventions ↔ patch-цепочка ↔ opsx

Статус: **принято, §6 superseded** (ADR-0027, 2026-08-05: кит перестаёт копировать агентов/скиллы в целевой репо сразу, без условия "плагин обязателен для команды"; остальное в силе). Дата: 2026-08-03 (grill-сессия №2 по дедупликации, текстовый аудит 4 экосистем + интеграция PROMPT_AUDIT_SDD_KIT.md).

## Проблема

Построчная сверка (patch-review ↔ plan-griller ↔ 12 opsx/openspec-файлов ↔ feature-flow ↔ planner; ревьюеры кита ↔ 4 агента плагина code-conventions) показала: настоящих дублей - 10, ложных - 9, плюс 3 несовместимых словаря вердиктов и прямое противоречие (python-reviewer плагина блокирует merge на HIGH, кит и code-reviewer - предупреждают). Параллельный prompt-аудит (`~/cybernet/docs/PROMPT_AUDIT_SDD_KIT.md` + 4 приложения) независимо нашёл те же структурные дефекты у кита (plan-griller без канала диалога, planner без Write, мёртвые opsx-ссылки, автотриггеры openspec-скиллов в обход intake/tier/grill).

## Решения

1. **`database-reviewer` - слить, канон кит.** Китовая версия вбирает уникальное из плагина (RLS/Supabase, connection management, monitoring); плагин пересинхронизируется с кита. У плагинной копии забрать `Write`/`Edit` - ревьюер read-only. Дополнительно (prompt-audit P2-2/P0-4): probe наличия БД + N/A-escape; не ставить агента в репо без БД (PCA).
2. **`patch-review` ↔ `plan-griller` - НЕ дубли** (механический аудит документа vs интерактивный допрос; пересечение только "вердикт" и "сверяй с кодом"). В CF-профиле - **оба шага**: тонкий `tz-review` (наследник patch-review: формат, facts-vs-code грепом, brand-lint, номер, вердикт, документ не правит) бежит ПЕРЕД `plan-griller`. Отменяет наклон грилла №1 "всё в гриллер".
3. **Вердикты.** Канон: **HIGH = Warning** ("мерж с явным принятием риска"), Block только на CRITICAL - соответствует advisory-first (ADR-0015); `python-reviewer` плагина правится. Словарь plan-стадии двухсостоянный и единый: `готово к реализации`/`требует правок` ≡ `PLAN HOLDS`/`FIX THE PLAN` (в глоссарий). Контракт ревьюеров - по prompt-audit P0-8 (paste-ready блок, `LGTM - no CRITICAL/HIGH issues`, обязательные `Tests checked:`/`Residual risk:`).
4. **Копипаст-блоки (5 шт. × 4-12 копий).** Разовая синхронизация (канон - кит), дальше: kit↔plugin - drift-check CI-джоб в sdd-kit (WARN, сравнение по маркерам заголовков: feature-flow, database-reviewer, Spec Compliance, Review discipline, Tool-assisted checks, hardening-преамбула, verdict-критерии); внутри кита (70 общих строк backend/database-reviewer) - лёгкая equality-проверка в `install.sh --refresh` (prompt-audit P2-1), не CI.
5. **`feature-flow` плагина** (135-строчный до-OpenSpec предок) - пересинхронизировать с кита + явный блок деградации для непровиженных репо. Дрейф дальше ловит джоб из п. 4.
6. ~~**C2 (кит перестаёт копировать `database-reviewer`)** - только когда плагин code-conventions станет обязательным для команды; до этого задвоение безвредно (после слияния текст один).**Superseded ADR-0027**: условие снято, кит прекращает копировать агентов в целевые репо сразу при переезде в плагин, независимо от обязательности плагина для команды.~~
7. **Hardening-преамбула** (фильтр >80%, pre-report gate, "zero findings - валидно", false-positive список) бэкпортируется в `python-reviewer` и `fastapi-reviewer` плагина (у fastapi добавить и вердикт-формат - сейчас его нет вовсе).
8. **opsx/openspec-скиллы** - по вердикту prompt-аудита: один слой (`.claude/skills/openspec-*`), `.claude/commands/opsx/` удалить, в каждый SKILL.md штамповать `disable-model-invocation: true` **на этапе bootstrap** (файлы vendor-generated, ручная правка теряется при регенерации); `planner.md` перенацелить с `commands/opsx/propose.md` на путь скилла. Закрывает автотриггер-коллизию (openspec-скиллы перепрыгивали intake/tier/grill/tests feature-flow).
9. **Баги кита** (совпали в обоих аудитах, чинятся без вопросов): P0-2 planner получает `Write`,`Edit`; P0-3 plan-griller переписывается в one-shot (нумерованные вопросы BLOCKING/ASSUMABLE, paste-ready `## Grill`, вердикт одной строкой - главная сессия ведёт диалог и записывает); P0-1 регенерация openspec ≥1.7.0 в 4 отставших репо + пин версии в bootstrap (сначала подтвердить `openspec status --json` в 1.6.0-репо).

## Разграничение с prompt-аудитом

PROMPT_AUDIT_SDD_KIT.md §4 (P0-1...P2-9) - самостоятельный список работ по киту; этот ADR его не дублирует, а фиксирует только решения по дублям и точки стыка. Единственное расхождение: аудит отверг drift-CI для AGENTS.md-payload'ов (Option A - репо-файл авторитетен) - не конфликт: наш джоб из п. 4 покрывает kit↔plugin, чего аудит не рассматривал (плагин вне его корпуса).

## Последствия

- code-conventions: пересинк database-reviewer и feature-flow с кита, бэкпорт hardening + вердиктов, правка python-reviewer (HIGH=Warning) - работа на стороне плагина, решения зафиксированы здесь.
- sdd-kit: drift-check джоб; equality-проверка в `--refresh`; bootstrap-штамп `disable-model-invocation`; фиксы P0-1/P0-2/P0-3; `tz-review` в payload CF (дополняет ADR-0019 §3.2).
- Глоссарий: статья "вердикт" (единый словарь plan-стадии и контракт ревьюеров).
