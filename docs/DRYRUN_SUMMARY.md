# Итоги ручного прогона sdd-kit M0-M5

Дата: 2026-08-03. Полигон: свежий клон `~/dev/web-backend-new` (ветка dev).
План: [DRYRUN_MANUAL_PLAN.md](DRYRUN_MANUAL_PLAN.md).
Полный журнал: [DRYRUN_WEB2318.md](DRYRUN_WEB2318.md).
Тестовый тикет: WEB-2318 (server-to-server эндпоинт для браузерной WebRTC-сессии).

Цель была не выполнить тикет, а сломать кит и починить. Все 5 блоков пройдены.

## Счёт

- Найдено за прогон: **13 дефектов** (M0: 5, M1: 3, M2: 3, M3: 1+план, M4: 1+инфо, M5: 2).
- Все закрыты в ките и раскатаны `--refresh` по 6 боевым репо + полигон.
- Коммиты кита: `bc84837` … `4efd857` (10 фиксов за прогон).

## Высокие (3)

| # | Что было | Что сделано |
|---|---|---|
| M0-4 | `/graphify` - Unknown command: скилл лежал в `~/.agents/skills/`, симлинка в `~/.claude/skills/` не было, install.sh проверял только CLI и говорил "ok". Все подсказки кита "run /graphify" были невыполнимы | Симлинк создаётся install.sh автоматически (`link_graphify_skill`) |
| M2-1 | `AGENTS.md` и `CLAUDE.md` заигнорированы трекаемым `.gitignore` WBN (строки 147-148) - главный артефакт кита никогда не доедет до git/CI/коллег, а доктор молчал | Доктор WARN'ит "present but gitignored". **Снятие игнора - открытое решение владельца в репо WBN** (донор тоже затронут) |
| M4-1 | `graphify affected` - выдуманная команда: G3-фикс вписал её в feature-flow, incident-flow и шаблон AGENTS.md, не проверив | Заменена на проверенный `query "<sym>"` (BFS fan-out ≈ blast radius); точные reverse deps - grep/ast-grep |

## Средние (5)

| # | Что было | Что сделано |
|---|---|---|
| M0-1 | Wrap-up install.sh требовал включить branch protection - вразрез с ADR-0015 | Один пункт: "enforcement advisory по умолчанию; включение - отдельное решение владельца" |
| M0-5 | `graphify-out/` (30 МБ graph.json) не заигнорирован - одна `git add .` до случайного коммита | install.sh и `--refresh` пишут его в `.git/info/exclude` |
| M2-3 | Ruff-автофикс полностью откатывал staged-правку, и git создавал **пустой коммит** (проверка git на "пусто" идёт до pre-commit) | Хук после ре-стейджа проверяет `git diff --cached --quiet` и отбивает коммит |
| M3-1 | Два чекаута WBN делят имя compose-проекта - test-author гонял тесты по чужому дереву | test-author.md: секция "Running inside Docker" (`docker compose run --rm --no-deps`, проверка bind mount) |
| M5-2 | `make sdd-test` врал в монорепо: "no ruff config / no tests" при живых `backend/pyproject.toml` и 827 тестах | `SDD_TEST_CMD` override (корневой Makefile до `-include Makefile.sdd` или env) + честные сообщения "at the repo root" |

## Низкие и косметика (5)

- M0-2: двойное сообщение про AGENTS.md при установке - убрано.
- M0-3 / M3-2: неточные ожидания в самом плане прогона - план поправлен
  (git status не пуст из-за путей вне .gitignore WBN; ruff-конфиг WBN в
  `backend/pyproject.toml`; intake.md штатно сворачивается planner'ом и удаляется).
- M1-1: сообщение spec-guard читалось как "skip_specs вместо change" - переформулировано.
- M1-3: pre-compact диффил от `origin/HEAD` (= main) и тянул чужие dev-коммиты
  в survival-пакет - теперь база `origin/dev`, если есть.
- M2-2: spec-lint дампил JSON в stdout на каждом коммите - теперь только по `--json`.
- M5-1: доктор флажил штатного `repo-auditor` как "extra agent" - добавлен в список известных.

## Что подтвердилось (фиксы прошлых волн работают)

- Хуки: spec-guard блокирует без change и молчит вне guard-путей; block-no-verify
  ловит `--no-verify`; pre-compact пишет survival-пакет с реальной веткой.
- Pre-commit: sdd-check пропускается без спек-изменений и реально гоняет validate
  при них; секреты (AKIA...) блокируются; ruff автофиксит; dev - warn, main - блок.
- Скилл feature-flow прошёл полный цикл на WEB-2318 сам: триггер по "сделай
  WEB-2318", YouTrack 403 -> fallback на вставленный текст, store-контракт
  реально применён (Bearer+401 отклонены), все 3 ложных утверждения тикета
  найдены заново, intake -> proposal/design/spec-delta/tasks, test-author с RED
  и 3 выигранными диспутами (ADR-0016), честный отчёт "что не сделано".
- Graphify: первичная сборка через `/graphify` без ключа, `make sdd-index`
  инкрементально без ключа, `explain`/`query` дают код, а не шум.
- Store: из свежего клона доступны все 8 спек, show отдаёт полный контракт.

## Открытое

1. **Решение владельца**: убрать `AGENTS.md`/`CLAUDE.md` из `.gitignore` WBN
   и закоммитить (иначе кит остаётся локальным для каждого разработчика).
2. **Бэклог kit-flow(1-3)** (пожелания владельца, DEFECTS_BACKLOG.md):
   явный шаг "сложность -> workflow -> модель", ревью плана отдельным шагом,
   исполнение утверждённого плана дешёвой моделью (sonnet), возможно параллельно.
3. Отложенное: C1/C7 (YouTrack MCP - лицензия), kit-flag(1) (где физически
   ставится флаг на stage/prod), kit-frontend(1) (фронтовый профиль).
