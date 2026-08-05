# ADR-0026. Бриф побеждает: выпил флагов, Makefile, living-spec-check, store-CI; PR/YouTrack по команде

Статус: **принято** (grill-сессия «sdd-kit VS BRIEF-CONCEPT.md», Daniil, 2026-08-04).
Дата: 2026-08-04.

## Контекст

Повторная сверка кита с BRIEF-CONCEPT.md нашла шесть веток, где расхождение
либо не решено, либо решено, но не записано. Итог: почти везде прав бриф —
раздел «НЕ нужно усложнения» исполняется буквально, а не «решено иначе».

## Решения

1. **PR + YouTrack — агент по явной команде.** Дефолт фаз 7+8 feature-flow —
   человек (PR и смена статуса — внешние необратимые действия). Добавляется
   опция: по явной команде разработчика агент сам делает `gh pr create` и
   двигает тикет через youtrack-mcp. Автоматизации без команды нет.
2. **Feature-флаги выпилены подчистую.** Удаляются `feature_flags.py`,
   таргет sdd-flags, lifecycle-тексты из feature-flow/агентов/доков и статьи
   глоссария; без архива (возврат — из git-истории). Флаг при нужде — обычный
   переключатель в конфигурации без реестра, сроков и владельца.
   Supersedes ADR-0007 целиком; из ADR-0011 выпадает флаговая механика
   (недоделанное не мержим: ветка ≤2 дней — единственное правило), из
   ADR-0013 — владелец флага; остальное в 0011/0013 в силе.
3. **Makefile.sdd убран.** Таргеты разложены на мелкие скрипты
   (`scripts/sdd/*.sh` в целевом репо: check, test, review, index);
   pre-commit, агенты и доки зовут скрипты напрямую. install.sh перестаёт
   нести Makefile.sdd и не трогает Makefile репозитория.
4. **living-spec-check.sh удалён совсем** (вместе со сплайсом в pre-commit и
   профилем LIVING SPEC-warning). Вопрос «есть ли на main новая документация,
   требующая конвертации в openspec» закрывает существующий
   `tools/cf/main-drift.sh` (drift-виды 1–2), запускаемый по требованию.
5. **store-ci.yml выпилен.** «Без CI» — без исключений: уходит и из
   templates, и из install.sh (профиль store). Валидация store — локально
   перед пушем (`openspec validate` в pre-commit клона store). Уточняет
   ADR-0023 §5 до конца.
6. **Профили и тулзы «депрекейтнутых» репо не трогаем** (profiles/*.env,
   profiles/web-backend-new/ и profiles/voice-agent-constructor-backend/): есть
   не просят, WBN — площадка бенчмарка.

## Последствия

- install.sh: −Makefile.sdd, −living-spec-check, −store-ci.yml, −feature_flags.py,
  +копирование scripts/sdd/*.sh; uninstall.sh — зеркально.
- templates: удалить feature_flags.py, Makefile.sdd, living-spec-check.sh,
  store-ci.yml; добавить scripts/sdd/.
- Тексты (WORKFLOW.md, README.md, feature-flow, planner/plan-griller/
  backend-reviewer, GLOSSARY.md): вычистить флаги и `make sdd-*` → скрипты.
- ADR-0007 помечен superseded; в 0011/0013 — пометки о снятой флаговой части.
- Реализация выпила — отдельной задачей, этот ADR только фиксирует решения.
