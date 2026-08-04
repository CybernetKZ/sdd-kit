# Ручной прогон sdd-kit с нуля (вы выполняете - я мониторю)

> Цель: найти дефекты кита, которые невозможно поймать субагентом. Журнал находок -
> [DRYRUN_WEB2318.md](DRYRUN_WEB2318.md). Полигон: **свежий клон WBN** в `~/dev/web-backend-new`.
> Эталон-донор (не трогаем): `~/cybernet/web-backend-new`.

## Почему вручную

Субагент физически не может: вызвать слэш-команду (`/opsx:propose`, `/graphify`),
запустить скилл по триггеру и - главное - **инициировать срабатывание хуков**
(PreToolUse/PreCompact живут только в вашей интерактивной сессии). Там и прячется
оставшаяся фрикция: P1 (слэш-команды) это уже подтвердил.

## Мой мониторинг

После каждого блока я сам смотрю `git status`/`diff`, созданные артефакты,
`openspec validate`, `sdd-doctor`. **От вас нужно минимум** - "M1.2 done"; вывод
вставляйте только если он неожиданный. Дальше: заношу в журнал, чиню в ките,
`--refresh`, говорю "дальше".

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

Снести старую копию и склонировать заново (ветка `dev` - рабочая база по воркфлоу;
на `main`/`stage` pre-commit кита блокирует коммиты):

```bash
rm -rf /home/octrow/dev/web-backend-new
git clone -b dev https://github.com/CybernetKZ/web-backend-new.git /home/octrow/dev/web-backend-new
cd /home/octrow/dev/web-backend-new
tar xzf /tmp/wbn-env-backup.tgz            # разложит 22 .env по своим директориям
git status -s | head   # ожидание: только ?? .env.capture и ?? extra_scripts/ -
                       # эти пути не покрыты .gitignore WBN (не дефект кита)
```

Установить кит с нуля - **интерактивно, отвечая Enter на дефолты** (это и есть тест
установщика; `SDD_KIT_ASSUME_YES` не используем):

```bash
/home/octrow/cybernet/sdd-kit/install.sh --repo-only
```

Что смотреть по ходу: вопросы понятны? дефолты разумные? не просит ли лишнего?
В конце - список ручных шагов (там должен быть пункт про `make sdd-index`).

**Замечание про ruff**: конфиг ruff у WBN живёт в `backend/pyproject.toml`
(`[tool.ruff]`, в git) - инсталлер обязан сказать "ruff config (repo's own - left
alone)" и не класть свой `ruff.toml`.

---

## M1. Хуки (главный блок - только реальная сессия)

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
| M2.1 | Закоммитить правку `.md`-файла | `make sdd-check` **пропущен** ("no spec-related changes staged") |
| M2.2 | Закоммитить правку в `openspec/` или `AGENTS.md` | `sdd-check` реально отрабатывает |
| M2.3 | Попытаться закоммитить строку `AKIA0000000000000000` в тестовом файле | блок по секретам |
| M2.4 | Закоммитить `.py` с кривым форматированием | ruff автофиксит и ре-стейджит |
| M2.5 | Попробовать коммит в `dev` напрямую | warn (не блок); в `main` - блок |

## M3. Скилл целиком по триггеру

| # | Что сделать | Ожидаемое |
|---|---|---|
| M3.1 | В новой сессии: "сделай WEB-2318" (текст тикета под рукой) | скилл `feature-flow` подхватывается сам |
| M3.2 | Пройти шаг 1 | `intake.md` создан, затем planner сворачивает его в proposal.md и **удаляет** (так по SKILL §1 - его отсутствие в конце не дефект); store опрошен правильными командами (C3) |
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
| M5.5 | `openspec store list` -> `openspec list --specs --store cybernet-specs` -> `openspec show external-webapi-authorization --type spec --store cybernet-specs` | store доступен из свежего клона, 8 спек |

---

## Порядок

**M0** -> M1 (хуки) -> M2 (pre-commit) -> M3 (скилл) -> M4 -> M5.

Между блоками я чиню найденное и раскатываю. Перезапуск сессии нужен только после
моих правок `.claude/settings.json` - предупрежу отдельно.

## Что я делаю в фоне

Держу журнал актуальным, перепроверяю результаты по файлам (не по пересказу),
чиню кит, раскатываю `--refresh` по 6 боевым репо + полигон.

---

# Промпт для нового чата (скопировать целиком)

> Ниже - стартовое сообщение для отдельной сессии, где идёт этот прогон.
> Всё, что до этой черты, - контекст, который та сессия прочитает сама.

```text
Мы проводим ручное тестирование sdd-kit + cybernet-specs на свежем клоне web-backend-new.
Я выполняю шаги руками в интерактивной сессии Claude Code, ты - мониторишь, находишь
дефекты кита, чинишь их и раскатываешь.

## Контекст (прочитай в начале)

Обязательно: /home/octrow/cybernet/sdd-kit/docs/DRYRUN_MANUAL_PLAN.md (план прогона,
блоки M0-M5) и /home/octrow/cybernet/sdd-kit/docs/DRYRUN_WEB2318.md (журнал уже найденной
фрикции: E1-E4, C1-C10, G1-G4, P1-P6).
По необходимости: README.md, WORKFLOW.md, docs/ADR/README.md (ADR-0015 advisory-first,
ADR-0016 test-author, ADR-0017 метаданные спек, ADR-0018 правка стор-контракта),
templates/skills/feature-flow/SKILL.md.

## Что уже сделано

Кит прошёл две итерации упрощения и три волны фиксов; все 8 контрактов в сторе
cybernet-specs сверены с кодом. Полигон ~/dev/web-backend-new пересоздаётся с нуля
по блоку M0 плана (клон ветки dev + распаковка /tmp/wbn-env-backup.tgz с 22 файлами
.env + интерактивный install.sh --repo-only).

## Жёсткие правила

1. Изменения только в /home/octrow/cybernet/sdd-kit и /home/octrow/cybernet/cybernet-specs.
   Сервисные репо (включая полигон ~/dev/web-backend-new и донор
   ~/cybernet/web-backend-new) - read-only: там я работаю руками, ты только смотришь.
2. Донор ~/cybernet/web-backend-new не трогать вообще - из него берутся .env.
3. Enforcement сознательно advisory (ADR-0015) - не предлагай включать branch protection.
4. Находки по коду WBN (безопасность, моки) запаркованы - тикеты не заводим.
5. YouTrack/MCP-вопросы пропускаем (C1/C7 отложены).

## Твой цикл на каждый блок

Я пишу "M1.2 done" (вывод вставляю, только если он неожиданный). Ты:
1. Проверяешь сам, не по пересказу: git status/diff в полигоне, содержимое созданных
   артефактов (openspec/changes/<id>/intake.md, proposal.md, design.md,
   .claude/last-session-state.md), openspec validate, make sdd-doctor.
2. Если поведение расходится с тем, что обещает кит, - это дефект кита, даже когда
   "всё сработало": инструкция, которую нельзя выполнить буквально, тоже дефект
   (так нашли G2 - graphify query со свободным вопросом даёт шум, и P1 - субагент
   не может вызвать слэш-команду).
3. Заносишь находку в docs/DRYRUN_WEB2318.md (новая секция на блок, таблица
   # | Проблема | Приоритет | Статус).
4. Чинишь в ките - сам или субагентом (opus для сложного). Каждую команду, которую
   вписываешь в промпт/скилл/Makefile, сначала выполни и убедись, что она существует
   и работает.
5. Коммит в кит + раскатка: install.sh --refresh по 6 боевым репо
   (~/cybernet/{web-backend-new,voice-agent-constructor-backend,
   voice-agent-postcall-analitics-backend,cybernet3.0,conversation_flow,web-frontend-new})
   и по полигону.
6. Пишешь "дальше" + предупреждаешь, если нужен перезапуск моей сессии (только при
   правках .claude/settings.json).

## Порядок

M0 (чистый полигон) -> M1 хуки (spec-guard, block-no-verify, pre-compact - их можно
проверить только в моей сессии) -> M2 pre-commit на живых коммитах -> M3 скилл целиком
по триггеру ("сделай WEB-2318") -> M4 слэш-команды и graphify -> M5 make-цели и store.

Тестовый тикет - WEB-2318 (server-to-server эндпоинт для браузерной WebRTC-сессии).
Цель - не выполнить тикет, а сломать кит и починить. Intake уже показал, что три
несущих утверждения тикета не соответствуют коду (WebRTC-механизма нет, ключи
валидирует gateway+SSO, путь конфликтует с топологией префиксов) - если скилл
отработает верно, он найдёт это снова сам.

Начни с короткого подтверждения, что прочитал план и журнал, и жди "M0 done".
```
