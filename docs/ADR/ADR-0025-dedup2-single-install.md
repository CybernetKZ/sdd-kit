# ADR-0025: Дедупликация №2 и «одна команда установки»

Статус: **принято, §4 superseded** (ADR-0027, 2026-08-05: feature-flow возвращается в плагин, но каноном остаётся версия кита; остальное в силе). Дата: 2026-08-04. Контекст: сверка с BRIEF-CONCEPT.md
нашла три упущения и вопрос «зачем дублирующие агенты/скиллы».

## Решения

1. **install.sh — единственное, что запускает пользователь.** Репо-установка
   сама предлагает (default yes) построить/обновить граф: есть graphify —
   `make sdd-index` (существующий граф — инкрементальный AST-апдейт; первый
   семантический билд по-прежнему требует ключ или интерактивный `/graphify` —
   sdd-index сам печатает это). Machine-only ставит статические ревью-тулзы
   radon/complexipy/vulture/semgrep (опционально, default yes).
2. **`make sdd-review` сам собирает статические leads**: /tmp/tools.txt по
   изменённым .py (radon cc, complexipy, vulture, semgrep); отсутствующая
   тулза молча пропускается — ревью просто получает меньше leads. Это
   замещает отчёт покойного autoreview.yml.
3. **План-ревью не отдельный агент, а pre-pass гриллера**: plan-griller
   получил шаг 1b (validate --strict, spec-lint, резолв `enforced:`-якорей,
   побуквенность MODIFIED) — жёсткие фейлы идут в вердикт `FIX THE PLAN:` как
   дефекты, не вопросы. Закрывает «review плана независимой сессией» из брифа
   без нового агента. CF-`/tz-review` остаётся до cutover (миграционный слой,
   там пара review→grill закреплена отдельным решением).
4. ~~**code-conventions больше не везёт feature-flow** (снят вместе с
   упоминаниями): граница — плагин = как пишется код (clean-code, gof,
   project-structure, report-session, KB-хуки), кит = как течёт задача.**Superseded ADR-0027**: feature-flow возвращается в плагин как переносимый артефакт, канон — версия кита; кит после переезда удаляет свою копию из templates.~~
5. **User-level ECC python/fastapi-reviewer заменены каноном
   backend-reviewer** кита (database-reviewer выровнен ранее); generic
   code-reviewer и spec-miner остаются. ~/.claude/CLAUDE.md обновлён.
6. **Модели/effort остаются пиновыми** во frontmatter (как раньше). Механика
   per-invocation override (`model`/`effort` в Agent-вызове, приоритет:
   env CLAUDE_CODE_SUBAGENT_MODEL > invocation > frontmatter > сессия) —
   доступный сессии инструмент для обоснованных исключений, не дефолт.
   Гигиена листинга скиллов: бюджет ~1% окна, description+when_to_use
   режется на 1536 символах — ключевой юзкейс первым (prompt-checklist).
