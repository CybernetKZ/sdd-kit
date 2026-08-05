# Аудит 2026-08-05: tools + profiles (агент 4/5, sonnet)

Зона: tools/cf/*, profiles/**. Контекст: сверка после ADR-0026; tools/cf заморожены
после фазы 3 CF (ADR-0022), профили deprecated-репо осознанно оставлены (ADR-0026 §6).

Ключевая находка: **`tools/skills/` не существует** (ни в дереве, ни в git-истории).
Содержимое пер-репозиторных вещей живёт в `profiles/<repo>/`. Единственное упоминание
`tools/skills/…` — в ADR-0026 §6, это битый путь в тексте ADR, а не дубль структуры.

## Сводная таблица

| Файл | Вердикт | Что не так | Рекомендация |
|---|---|---|---|
| `tools/cf/main-drift.sh` | OK | 399 строк, но 3 логических блока + встроенный self-check (~100 строк) — оправданно для read-only скрипта без зависимостей | Вынос self-check в отдельный файл — низкий приоритет, скрипт заморожен |
| `tools/cf/mine-section.md` | OK | — | — |
| `tools/cf/patch2change.md` | OK | — | — |
| `tools/cf/sync-main.md` | OK | Все перекрёстные пути существуют | — |
| `tools/cf/verify-section.md` | OK | — | — |
| `profiles/conversation_flow.env` | OK | Комментарий про main-drift.sh согласован с ADR-0026 §4 | — |
| `profiles/*.env` (остальные 6) | OK | Сорсятся `load_profile()` по basename репо — механизм рабочий | — |
| `profiles/conversation_flow/.claude/skills/tz*/SKILL.md` (3) | OK | Уже на `scripts/sdd/check.sh`, актуальны | — |
| `profiles/web-backend-new/AGENTS.md` | **ISSUE** | `:55` — `make sdd-check … defined in Makefile.sdd` — противоречит ADR-0026 §3 | Заменить на `bash scripts/sdd/check.sh` |
| `profiles/voice-agent-constructor-backend/AGENTS.md` | **ISSUE** | `:99-104` — `make sdd-check (from Makefile.sdd)` как «required PR gate» — двойной анахронизм (Makefile + CI-гейт) | Синхронизировать с ADR-0026 |
| `docs/ADR/ADR-0026-brief-wins-cleanup.md:38` | **ISSUE** | Путь `tools/skills/…` не существует; реально `profiles/…` | Поправить путь (только путь, не решение) |

## Топ-5 находок

1. **ADR-0026 §6 ссылается на несуществующий `tools/skills/…`** — реальный путь `profiles/<repo>/`.
2. **`profiles/web-backend-new/AGENTS.md:55`** — устаревший `make sdd-check`/`Makefile.sdd`; копируется install.sh в свежие клоны WBN.
3. **`profiles/voice-agent-constructor-backend/AGENTS.md:99-104`** — тот же анахронизм, назван «required PR gate».
4. `tools/skills/` физически отсутствует — несоответствие было в постановке аудита/тексте ADR, не в файловой системе.
5. `main-drift.sh` — вынос self-check возможен, но низкий приоритет (скрипт заморожен по ADR-0022).

Примечание: решение ADR-0026 §6 «профили deprecated-репо не трогаем» касалось факта
их сохранения, а не терпимости к фактическим противоречиям внутри них — устаревшие
команды в двух AGENTS.md чинить стоит.
