# Ручной прогон sdd-kit с нуля (вы выполняете — я мониторю)

> Цель: найти дефекты кита, которые невозможно поймать субагентом. Журнал находок —
> [DRYRUN_WEB2318.md](DRYRUN_WEB2318.md). Полигон: **свежий клон WBN** в `~/dev/web-backend-new`.
> Эталон-донор (не трогаем): `~/cybernet/web-backend-new`.

## Почему вручную

Субагент физически не может: вызвать слэш-команду (`/opsx:propose`, `/graphify`),
запустить скилл по триггеру и — главное — **инициировать срабатывание хуков**
(PreToolUse/PreCompact живут только в вашей интерактивной сессии). Там и прячется
оставшаяся фрикция: P1 (слэш-команды) это уже подтвердил.

## Мой мониторинг

После каждого блока я сам смотрю `git status`/`diff`, созданные артефакты,
`openspec validate`, `sdd-doctor`. **От вас нужно минимум** — «M1.2 done»; вывод
вставляйте только если он неожиданный. Дальше: заношу в журнал, чиню в ките,
`--refresh`, говорю «дальше».

---

## M0. Чистый полигон (выполнить один раз)

Донор `~/cybernet/web-backend-new` только читаем. 22 файла `.env*` уже упакованы мной
в `/tmp/wbn-env-backup.tgz` (проверено). Если хотите пересобрать архив сами:

```bash
cd /home/octrow/cybernet/web-backend-new
find . -type f \( -name '.env' -o -name '.env.test' -o -name '.env.prod' -o -name '.env.capture' \) \
  -not -path './node_modules/*' > /tmp/envlist.txt
tar czf /tmp/wbn-env-backup.tgz -T /tmp/envlist.txt     # 22 файла
```

Снести старую копию и склонировать заново (ветка `dev` — рабочая база по воркфлоу;
на `main`/`stage` pre-commit кита блокирует коммиты):

```bash
rm -rf /home/octrow/dev/web-backend-new
git clone -b dev https://github.com/CybernetKZ/web-backend-new.git /home/octrow/dev/web-backend-new
cd /home/octrow/dev/web-backend-new
tar xzf /tmp/wbn-env-backup.tgz            # разложит 22 .env по своим директориям
git status -s | head                        # ожидание: пусто (все .env в .gitignore)
```

Установить кит с нуля — **интерактивно, отвечая Enter на дефолты** (это и есть тест
установщика; `SDD_KIT_ASSUME_YES` не используем):

```bash
/home/octrow/cybernet/sdd-kit/install.sh --repo-only
```

Что смотреть по ходу: вопросы понятны? дефолты разумные? не просит ли лишнего?
В конце — список ручных шагов (там должен быть п. 4b про `make sdd-index`).

**Замечание про ruff**: у донора есть свои `.ruff.toml` (корень и `backend/`), они
не в git. В чистом клоне их не будет, и кит положит свой `ruff.toml` — это штатный
путь для нового репо, оставляем как есть (заметим, если помешает `make sdd-test`).

---

## M1. Хуки (главный блок — только реальная сессия)

Открыть Claude Code в `/home/octrow/dev/web-backend-new`.

| # | Что сделать | Ожидаемое |
|---|---|---|
| M1.1 | Попросить отредактировать файл под guard-путём (напр. `backend/app/agent_wb/model/agent_wb.py`) **без активной change** | `spec-guard.cjs` блокирует (exit 2), сообщение зовёт создать change |
| M1.2 | Создать change (любым путём) и повторить правку | правка проходит |
| M1.3 | Попросить закоммитить с `--no-verify` | `block-no-verify.cjs` блокирует |
| M1.4 | Довести сессию до авто-компакта | появился `.claude/last-session-state.md`; **diff-секция не пустая** (чинили хардкод `dev`) |
| M1.5 | Правка вне guard-путей (напр. `README.md`) | хуки молчат |

## M2. Pre-commit на живых коммитах

| # | Что сделать | Ожидаемое |
|---|---|---|
| M2.1 | Закоммитить правку `.md`-файла | `make sdd-check` **пропущен** («no spec-related changes staged») |
| M2.2 | Закоммитить правку в `openspec/` или `AGENTS.md` | `sdd-check` реально отрабатывает |
| M2.3 | Попытаться закоммитить строку `AKIA0000000000000000` в тестовом файле | блок по секретам |
| M2.4 | Закоммитить `.py` с кривым форматированием | ruff автофиксит и ре-стейджит |
| M2.5 | Попробовать коммит в `dev` напрямую | warn (не блок); в `main` — блок |

## M3. Скилл целиком по триггеру

| # | Что сделать | Ожидаемое |
|---|---|---|
| M3.1 | В новой сессии: «сделай WEB-2318» (текст тикета под рукой) | скилл `feature-flow` подхватывается сам |
| M3.2 | Пройти шаг 1 | создан `openspec/changes/<id>/intake.md` (конвенция C6); store опрошен правильными командами (C3) |
| M3.3 | Дойти до шага 2 | planner подхватил `intake.md` и свернул в proposal; для deep-тира завёл `design.md` (P6) |
| M3.4 | Шаг 3 | `test-author` пишет тесты по Scenario и показывает RED |

## M4. Слэш-команды и graphify

| # | Что сделать | Ожидаемое |
|---|---|---|
| M4.1 | `/opsx:propose "WEB-2318: web-call session"` | change создаётся; сравню с CLI-путём из planner.md (P1) |
| M4.2 | `/graphify` в свежем клоне (индекса нет) | первичная сборка через сессию, без API-ключа |
| M4.3 | После M4.2: `make sdd-index` | инкрементальный апдейт, ключ не нужен |
| M4.4 | `graphify explain "verify_api_key"`, `graphify affected "AgentWb"` | символьные пробы дают код, не шум (новая формулировка в скилле) |

## M5. Make-цели и store

| # | Команда | Ожидаемое |
|---|---|---|
| M5.1 | `make sdd-doctor` | 0 fail; warn'ы понятны |
| M5.2 | `make sdd-test` | нет `warning: overriding recipe`; ruff/pytest идут или честный skip |
| M5.3 | `make sdd-check` | зелёный; spec-lint назван advisory |
| M5.4 | `make sdd-review` | AI-ревью на вашей подписке (я запустить не могу) |
| M5.5 | `openspec store list` → `openspec list --specs --store cybernet-specs` → `openspec show external-webapi-authorization --type spec --store cybernet-specs` | store доступен из свежего клона, 8 спек |

---

## Порядок

**M0** → M1 (хуки) → M2 (pre-commit) → M3 (скилл) → M4 → M5.

Между блоками я чиню найденное и раскатываю. Перезапуск сессии нужен только после
моих правок `.claude/settings.json` — предупрежу отдельно.

## Что я делаю в фоне

Держу журнал актуальным, перепроверяю результаты по файлам (не по пересказу),
чиню кит, раскатываю `--refresh` по 6 боевым репо + полигон.
