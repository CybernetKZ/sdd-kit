# Аудит 2026-08-05: docs/ (агент 5/5, sonnet)

Зона: docs/ADR (реестр), живые доки docs/, docs/archive (группой).
Контекст: сверка после ADR-0026.

## 1. docs/ADR/ (0001–0026)

- Нумерация без дыр, имена по схеме `ADR-NNNN-slug.md`, README-индекс перечисляет все 26 — OK.
- **ISSUE**: ADR-0013 в README-индексе значится «принято», хотя в файле статус
  «принято, часть "владелец флага" снята (ADR-0026)». Аналогичный частичный
  supersede ADR-0011 в индексе отражён. Поправить строку 0013.

## 2. Живые доки

| Файл | Вердикт | Комментарий |
|---|---|---|
| `GLOSSARY.md` | OK | Живой, актуален после ADR-0026 |
| `RAISE-intake-process.md` | OK | Канон RAISE (ADR-0009) |
| `DEFECTS_CF.md` (76K) | OK | Живой реестр дефектов миграции CF, активно используется (tools/cf, tz-скиллы). Кандидат на разбивку по волнам при следующей правке |
| `DEFECTS_BACKLOG.md` (25K) | **ISSUE / ARCHIVE-CANDIDATE** | Почти весь объём — тикет-материал чужих репо (WBN/VA/PCA/cybernet3.0); живых ссылок на кит — 2 пункта. Вынести kit-пункты в живой TODO, остальное в архив/целевые репо |
| `ideas.md` (29K) | **ISSUE** | Не backlog идей, а вставленная статья с Habr (CodeGraph vs Graphify), 0 ссылок в репо — мисфайл. Переименовать/переместить в архив как research |
| `RUNBOOK_WEB2316.md` | OK (с оговоркой) | Активный бенчмарк-прогон; содержит устаревшие `make sdd-*` (стартовал до ADR-0026). Обновить команды; по завершении — в архив по образцу DRYRUN_* |
| `presentations/PRESENTATION_PLAN.md` | ARCHIVE-CANDIDATE | Одноразовая презентация (Web-2305), устаревшие `make sdd-check` в слайдах |
| `reviews/prompt-checklist.md` | OK (dormant) | Референс авторства промптов; в рабочем потоке не вызывается |
| `reviews/WEB-2256-review.md` | ARCHIVE-CANDIDATE | Ревью одного коммита WBN, закрытая задача |

## 3. docs/archive/

- Всё содержимое действительно архивное; «живых» файлов, случайно попавших в архив, нет.
- **ISSUE**: `docs/archive/README.md` не индексирует 19 из ~32 файлов
  (DRYRUN_*, HANDOFF_CF_PHASE3, NEXT_STEPS, ONBOARDING, PLAN_*, pre-commit-recommendations,
  PROPOSAL_langfuse, REPORT_TBD_PROJECTSTORE, SDD_KIT_LAYERS, SPEC_MINER_PILOT,
  STORE_VERIFICATION, autoreview.yml, sdd-ci.yml). Плюс мёртвая ссылка на
  `HubTalk_AI_Platform_Comparison_RU.docx` (файла нет).
- Живой код ссылается на архив корректно (uninstall.sh использует архивные yml
  как эталоны удаления — по замыслу).

## Топ-5 находок

1. `docs/archive/README.md` — индекс устарел наполовину (19 файлов без записи) + мёртвая ссылка на .docx.
2. `docs/ideas.md` — статья с Habr под видом идей, мисфайл.
3. `docs/DEFECTS_BACKLOG.md` — смесь 2 живых kit-пунктов и массива чужого тикет-материала.
4. ADR-0013: статус в README-индексе разошёлся с файлом.
5. Три one-off артефакта вне архива: `reviews/WEB-2256-review.md`, `presentations/PRESENTATION_PLAN.md`, `RUNBOOK_WEB2316.md` (последний активен, но с устаревшими `make sdd-*`).
