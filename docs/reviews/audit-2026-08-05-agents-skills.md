# Аудит 2026-08-05: агенты и скиллы (агент 3/5, sonnet)

Зона: templates/agents/*, templates/skills/*. Контекст: сверка после ADR-0026;
конвенции ADR-0022 (языки, без ADR-тегов в промптах) и ADR-0024 (SKILL.md ≤60 строк).

## Сводная таблица

| Файл | Строк | Вердикт | Что не так |
|---|---|---|---|
| `agents/backend-reviewer.md` | 160 | OK | Дубли с database-reviewer размечены `shared block`, побайтово синхронны |
| `agents/database-reviewer.md` | 138 | OK | Зеркально |
| `agents/planner.md` | 105 | OK | RU/EN разделены по ADR-0022 |
| `agents/plan-griller.md` | 83 | OK | — |
| `agents/test-author.md` | 89 | OK | — |
| `agents/executor.md` | 59 | OK | — |
| `agents/repo-auditor.md` | 76 | OK | Промпт EN, вывод RU — по ADR-0022 |
| `skills/feature-flow/SKILL.md` | 56 | OK | ≤60 строк, без ADR-тегов |
| `skills/feature-flow/references/details.md` | 198 | **ISSUE** | 4 голых тега `ADR-0026 §N` (строки 85, 153, 178, 195) — нарушение ADR-0022 п.2 |
| `skills/incident-flow/SKILL.md` | 61 | ISSUE (minor) | 1 строка сверх цели ≤60 (ADR-0024) |
| `skills/grilling/SKILL.md` | 14 | OK | Вендорено, не редактируется |
| `skills/grill-me/SKILL.md` | 11 | OK | House rule (RU) консистентен |
| `skills/grill-with-docs/SKILL.md` | 14 | OK | Fallback на docs/ADR + GLOSSARY консистентен |
| `skills/domain-modeling/SKILL.md` | 76 | OK | Вендорено, ссылки валидны |
| `skills/domain-modeling/CONTEXT-FORMAT.md` | 60 | OK | — |
| `skills/domain-modeling/ADR-FORMAT.md` | 47 | OK | Свой `docs/adr/` не конфликтует: grill-with-docs переключает на существующий реестр |

Устаревших упоминаний `make sdd-*`, `Makefile.sdd`, `feature_flags`, `FLAG_`,
`living-spec`, CI-гейтов не найдено — чистка ADR-0026 прошла полностью.

## Топ-5 находок

1. **`feature-flow/references/details.md:85,153,178,195`** — голые теги `ADR-0026 §1/§2` в агентском тексте; единственное реальное расхождение с ADR-0022 во всём наборе. Заменить на формулировку правила без тега.
2. **`incident-flow/SKILL.md`** (61 строка) — на 1 строку выше цели ADR-0024; подрезать при следующей правке.
3. **Дубли backend/database-reviewer** — здоровое состояние по ADR-0022 п.5, но зона риска: маркер есть, синхронизация не автоматизирована.
4. Все 7 агентов и 6 скиллов корректно подключены (install/uninstall/README/WORKFLOW/sdd-doctor) — сирот и битых ссылок нет; пути `scripts/sdd/*.sh` в промптах — это пути целевого репозитория, сверено с манифестом.
5. Языковая конвенция ADR-0022 выдержана во всех файлах (промпты EN, человеку RU, машинные теги EN).
