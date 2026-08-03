# patch2change — конвертация архивных ТЗ в openspec/changes/archive/

Инструкция для sonnet-агента. Механическая конвертация, batch по диапазону
номеров. Оригиналы `docs/patches/` НЕ трогать (append-only, ADR-0019 п.8).

## Выход (на каждый patchNN)

`conversation_flow/openspec/changes/archive/tz-0NN-<slug>/`:

- `proposal.md` — шапка:
  ```markdown
  # tz-0NN — <заголовок из H1 патча>

  > Конвертировано из [docs/patches/patchNN-<name>.md](../../../../docs/patches/patchNN-<name>.md)
  > (архив ТЗ, ADR-0019). Оригинал — источник истины для истории.
  > Реализовано: см. §17 changelog DOCUMENTATION.md, версия 1.NN.0.
  ```
  затем: блок-цитата зависимостей из шапки патча (как есть), `## Контекст`
  (= §0 патча, сжатый до сути), `## Что сделано` (= перечень §1..§N патча,
  по строке на §), `## Вне scope` (как в патче).
- `tasks.md` — критерии приёмки патча как выполненные чекбоксы:
  `- [x] <критерий>` (дословно из «## Критерии приёмки»), последней строкой
  `- [x] tests/test_patchNN.py зелёные` (если файл существует — проверить ls).
- Спек-дельты НЕ генерировать: поведение уже влито в LIVING SPEC и будет
  покрыто майнингом capability-спек. В proposal.md последней строкой:
  `> Спек-дельта не восстанавливалась: поведение покрывается openspec/specs/ (фаза 3 миграции).`

## Правила

1. slug = kebab из имени файла патча (без `patchNN-`).
2. №33 существует в одном тексте при двух исторических использованиях —
   конвертировать существующий файл как tz-033, в proposal.md отметить дубль.
3. `requirement-branding.md`, `requirement-living-documentation.md`,
   `prompt-conversation-flow-clone.md`, `addon-visual-editor.md` — без номеров:
   tz-000-branding, tz-000-living-documentation, tz-001-clone (=ТЗ №1),
   tz-001a-visual-editor.
4. Русский язык, ничего не выдумывать, не переоценивать: только перенос.
5. Валидация в конце batch'а: `npx -y @fission-ai/openspec@1.7.0 validate --all --strict`
   (архивные changes не должны его ломать).

## Отчёт агента

Terse: список созданных tz-* директорий, пропуски/аномалии (нет секции
критериев, нет теста и т.п.).
