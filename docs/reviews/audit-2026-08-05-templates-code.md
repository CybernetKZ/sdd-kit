# Аудит 2026-08-05: шаблоны-код (агент 2/5, opus)

Зона: templates/pre-commit-hook.sh, templates/scripts/sdd/*, templates/sdd-doctor.sh,
templates/spec-lint.py, templates/*.cjs, settings.json, ruff.toml, review-prompt.md,
templates/AGENTS.md. Контекст: сверка после ADR-0026.

## Сводная таблица

| Файл | Вердикт | Что не так | Рекомендация |
|---|---|---|---|
| `templates/pre-commit-hook.sh` → `.git/hooks/pre-commit` | **ISSUE** | Больше не содержит литерала `sdd-check`, а `install.sh:782` и `sdd-doctor.sh:236` именно его грепают → вечный ложный WARN. Устаревшие CI-упоминания в комментах (`:19`, `:46`). `for f in $STAGED` / `xargs grep` ломаются на именах с пробелами | Переключить детекторы на `scripts/sdd/check.sh`; вычистить 2 CI-комментария |
| `templates/scripts/sdd/check.sh` | OK | Путь в манифесте совпадает с тем, что зовёт pre-commit. Дублирует AGENTS.md/CLAUDE.md-логику из sdd-doctor.sh и install.sh (см. находку 4) | — |
| `templates/scripts/sdd/test.sh` | OK | README называет «advisory», скрипт выходит non-zero — терминология, не баг | — |
| `templates/scripts/sdd/review.sh` | ISSUE (minor) | Жёсткие `/tmp/sdd-review.diff`, `/tmp/tools.txt` — коллизии между репо/сессиями. Отсутствие базы диффа (`origin/dev`) не детектится: пустой файл → ложный «0 changes» | Уникальные tmp-имена; `git rev-parse --verify "$BASE"` до диффа |
| `templates/scripts/sdd/index.sh` | OK | — | — |
| `templates/scripts/sdd/doctor.sh` | ISSUE | Шим `exec bash .claude/scripts/sdd-doctor.sh` — единственный скрипт с телом в другом дереве; относительный путь ломает запуск не из корня. Doctor добавлен вне перечня ADR-0026 §3 | `cd "$(git rev-parse --show-toplevel)"` перед exec (или перенос тела) |
| `templates/sdd-doctor.sh` | **ISSUE** | (а) `:236` ложный WARN repo.pre-commit; (б) не проверяет `scripts/sdd/*.sh`, `spec-lint.py`, `review-prompt.md` — ядро новой поверхности; (в) `:206` «format» hook в тексте — такого хука нет; (г) `:123` `grep -cv ... || echo 0` даёт `"0\n0"` на пустом AGENTS.md; (д) 434 строки линейного кода. Флаги/Makefile.sdd НЕ проверяет — чисто | Добавить группу repo.sdd-scripts; поправить (а),(в),(г); разбить на функции |
| `templates/spec-lint.py` | ISSUE (minor) | (а) `:259-260` устаревший совет «CI needs fetch-depth: 0»; (б) `:213-214` мёртвый archive-фильтр (glob физически не матчит archive); (в) `main()` 165 строк, `parse_spec()` 84; (г) `self_check()` не убирает mkdtemp | Переписать (а) на `git fetch --unshallow`; удалить (б); вынести отчёт в report() |
| `templates/block-no-verify.cjs` | ISSUE (minor) | `:43-58` self-check недостижим (`--test` после подписки на stdin); коммент говорит `.js`, файл `.cjs` | Перенести `--test` до stdin; поправить имя |
| `templates/spec-guard.cjs` | OK | `:25` коммент «pre-compact.js» → файл `.cjs` | Поправить комментарий |
| `templates/pre-compact.cjs` | OK | — | — |
| `templates/settings.json` | OK | Хуки сходятся с манифестом и merge_settings_hooks | — |
| `templates/ruff.toml` | OK | — | — |
| `templates/review-prompt.md` | OK | Ссылки валидны; `/tmp/tools.txt` совпадает с review.sh | — |
| `templates/AGENTS.md` | OK | Команды уже `scripts/sdd/*.sh`. Не в манифесте — осознанно (repo-owned) | — |

Побочно: `templates/.ruff_cache/` — мусор (в .gitignore, не отслеживается). Права
рассинхронизированы (775 vs 664) — безвредно, все зовутся через интерпретатор.

## Топ-5 находок

1. **Регрессия ADR-0026: детект pre-commit-хука сломан** (`sdd-doctor.sh:236`, `install.sh:782` грепают `sdd-check`, которого в хуке больше нет) → ложный WARN в корректно установленном репо.
2. **Доктор не видит новую командную поверхность**: ни одной проверки существования `scripts/sdd/{check,test,review,index,doctor}.sh`, `.claude/scripts/spec-lint.py`, `.claude/scripts/review-prompt.md`. Пропажа = блокированные коммиты или неработающее ревью при «0 issues» от доктора.
3. **`scripts/sdd/doctor.sh` — индирекция с относительным путём**; запуск из подкаталога ломается. spec-lint.py в `.claude/scripts/` оправдан (библиотечный ассет check.sh), doctor — публичная команда.
4. **Тройной дубль AGENTS.md/CLAUDE.md-логики** с расходящимися вердиктами: `check.sh:8-24` (WARN), `sdd-doctor.sh:106-167` (FAIL/WARN), `install.sh:599-625`. Кандидат на общий подключаемый фрагмент.
5. **Мёртвый код и протухший CI-текст в spec-lint.py** (`:213-214` недостижимый archive-фильтр; `:259-260` совет про CI, которого нет; `main()` 165 строк).
