# mine-section — конвертация раздела LIVING SPEC в capability-спеку OpenSpec

Инструкция для sonnet-агента (ADR-0019: конвертация на недорогих моделях).
Запуск: агенту дают capability-имя + список разделов/строк `docs/DOCUMENTATION.md`.

## Вход

- Репозиторий: `/home/octrow/cybernet/conversation_flow`
- Разделы `docs/DOCUMENTATION.md` (номера § и диапазоны строк — в задании)
- Карта тестов: `tests/README.md` (домен → файлы `test_patchNN.py`)
- Карта кода: §14 DOCUMENTATION.md (аннотированное дерево с тегами «ТЗ №N §M»)

## Выход

`openspec/specs/<capability>/spec.md` в РЕПО-формате (ADR-0017, не store!):

```markdown
# <capability>

> Last verified: 2026-08-03 (commit <hash из задания>)

## Purpose
<2-4 строки, по-русски>

## Requirements

### Requirement: <короткое имя по-английски>
<!-- id: <capability>.<kebab-slug> -->
<!-- enforced: path/to/file.py:Class.method -->
Тело по-русски. Модальность обязательна: система SHALL <...>.

#### Scenario: <имя>
- **WHEN** <условие, по-русски после ключевого слова>
- **THEN** <результат>
```

## Правила

1. **Это рерайт, не копирование**: в исходнике 0 MUST — каждое индикативное
   утверждение («порядок оценки переходов: Always → equation → prompt →
   default») переписывается как Requirement с SHALL и хотя бы одним Scenario.
2. Язык: тело русское, ключевые слова `### Requirement:` / `#### Scenario:` /
   SHALL / WHEN / THEN — английские (нужны `openspec validate --strict`).
3. `enforced:`-якоря — только реальные пути/символы: перед записью проверить
   Grep'ом, что файл и символ существуют. Источники якорей: §14, инлайновые
   пути в тексте раздела, `tests/README.md`.
4. Каждый Requirement уникальный `id:` вида `<capability>.<slug>`; ключи
   метаданных только `id`/`entities`/`enforced` (whitelist spec-lint).
5. Ничего не выдумывать: не описано в § и не видно в коде — не писать.
   Сомнение — пометить обычным текстом в теле («_проверить: …_» или ссылка
   на номер в DEFECTS_CF) и внести в отчёт. НЕ использовать HTML-комментарии
   вида `<!-- verify: ... -->` — spec-lint принимает только ключи
   `id`/`entities`/`enforced`, остальное даёт unknown_key.
6. Расхождение текста § с кодом — НЕ чинить молча: писать поведение КОДА
   (код важнее спеки), а расхождение — в отчёт (секция Mismatches, попадёт
   в DEFECTS_CF.md).
7. История (§17), UI-скриншоты, туториалы — не конвертируются.
8. Финальная проверка (обе обязаны пройти):
   `cd conversation_flow && npx -y @fission-ai/openspec@1.7.0 validate --all --strict`
   и `python3 .claude/scripts/spec-lint.py` (0 METADATA-ошибок по своей спеке).

## Отчёт агента

Terse: requirement/scenario count, использованные якоря (файлы), список
Mismatches (файл:строка + суть), что осталось непокрытым и почему.
