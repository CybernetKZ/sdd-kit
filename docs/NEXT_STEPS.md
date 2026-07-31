# Дальнейшие шаги: внедрение SDD-стека

Дата: 2026-07-27. Контекст: WEB-2305, решения - в ADR-0001...0005.
Заготовка для репозиториев готова: `../` (проверена на тестовом репозитории).

## Что такое sdd-kit

Один скрипт: `sdd-kit/bootstrap.sh /путь/к/репозиторию`.

Обновление 2026-07-27: комплект переведён на английский (всё, что попадает в
репозитории) и сделан переносимым для машин всей команды:

- проверяет зависимости (git, node, uv) и подсказывает команды установки;
- youtrack-mcp ищет по путям (`$YOUTRACK_MCP_DIR` -> `~/dev/youtrack-mcp` ->
  `~/cybernet/youtrack-mcp`), при отсутствии - спрашивает разрешение и клонирует
  `github.com/tonyzorin/youtrack-mcp`;
- если нет токена YouTrack - даёт ссылку
  (https://cybernet.youtrack.cloud/users/me?tab=account-security), принимает ввод
  скрыто и сохраняет в `.env` сервера (chmod 600); токен никогда не пишется в репозиторий;
- `.mcp.json` генерируется с реальным путём на конкретной машине, без хардкода;
- без терминала (CI) вопросы пропускаются с инструкциями; `SDD_KIT_ASSUME_YES=1`
  авто-подтверждает клонирование, но никогда - ввод токена.

Обновление 2026-07-28:

- скрипт проверяет CLI openspec: если не установлен - предлагает
  `npm install -g @fission-ai/openspec@latest`, при отказе работает через npx;
- скрипт ставит git-хук `pre-commit` (в `.git/hooks`, в git не попадает):
  перед каждым коммитом гоняет `make sdd-check`, при провале коммит блокируется;
  если в репо уже был свой pre-commit (в WBN и VA - ruff format) - скрипт
  предупреждает, sdd-check туда вписан вручную в начало.

Он докладывает в репозиторий (существующие файлы не трогает):

1. `AGENTS.md` - из шаблона; если был `CLAUDE.md` - переименует его и оставит симлинк.
2. `openspec/` - инициализация OpenSpec для Claude Code.
3. `Makefile.sdd` с целью `make sdd-check` (AGENTS.md есть и ≤500 строк + `openspec validate --all --strict`).
4. `.github/workflows/sdd-ci.yml` - гейт на каждый pull request.
5. `.claude/hooks/` - два перехватчика: запрет `git commit --no-verify` и spec-guard
   (нельзя править код без активного изменения в `openspec/changes/`; включается
   файлом `.spec-guard-paths`, без него молчит).
6. `.mcp.json` - общие MCP проекта: context7 и youtrack (токен - через переменную окружения).

Для нового репозитория порядок тот же: `git init` -> `bootstrap.sh` -> заполнить TODO в AGENTS.md.

## Порядок внедрения по репозиториям

### Шаг 0. Общие предпосылки (один раз)

- [x] Тестовая версия store-репозитория создана 2026-07-28: `~/cybernet/cybernet-specs`
      (git init без коммитов - Daniil смотрит и решает). Внутри: README (английский) +
      3 контракта в формате OpenSpec, `openspec validate --all --strict`: 3 passed.
      Спеки: telephony-in-redis-stream (дрейф починен: код 96 - условный, не статичный
      success; код 16 - задокументировано текущее поведение, WEB-2298 ещё НЕ смержен;
      путь модели исправлен на `schema/schema.py:321`), post-call-processor-llm-redis,
      engine-redis-contract (срез из майнинга cybernet3.0).
- [x] Тестовый store опубликован 2026-07-28: https://github.com/octrow/cybernet-specs
      (private, аккаунт octrow). Доведён по официальному гайду stores: identity
      с remote, archive/, каталог 5 репозиториев в `context:` (обход issue #1436).
      Теперь 5 спек (`validate --all --strict`: 5 passed): + external-call-campaign-api
      (9 треб.) и external-webapi-authorization (7 треб., переведён с русского).
      Разбор всех 24 доков wbn-project-logic - в `SOURCES.md` store:
      2 импортировано, 15 - внутренняя логика WBN (для майнинга в repo-спеки),
      3 устарели. OVERALL LOGIC не импортирован: его границы - между сервисами
      ВНУТРИ репо WBN, а не между репозиториями (ADR-0001 такие не берёт).
- [x] Контракт WBN↔VA (RabbitMQ RPC) добыт из кода обоих репо 2026-07-28:
      спека `wbn-va-rpc` в store (22 требования / 61 сценарий, validate: 6 passed,
      запушено). 11 межсторонних расхождений задокументированы как беклог дефектов,
      включая: очередь VA->WBN не durable (записи гибнут при рестарте брокера);
      идемпотентность держится на подстроках error_message ("already exists" /
      "not found") - теперь это явное нормативное требование; `DISABLE_AGENT` -
      fire-and-forget после локального коммита WBN; на стороне WBN ноль тестов
      на весь RPC-путь; версионирования нет вообще.
- [x] Скоуп store зафиксирован (решение Daniil 2026-07-28): только ВНЕШНИЕ границы
      WBN+VA - 1) frontend api/v1 (главная незакрытая дыра), 2) внешний WebAPI
      (закрыт), 3) redis-движок cybernet3.0 (закрыт), 4) прочие внешние сервисы.
      Внутреннее устройство репозиториев - в их собственных openspec/specs.
- [x] Контракт api/v1 фронтенда добыт 2026-07-29: спека `frontend-api-v1` в store
      (724 строки, 13 требований / 31 сценарий, validate: 7 passed, НЕ закоммичено -
      коммитит Daniil). Формат: конвенции как норматив (роутинг через gateway,
      auth с trust-заголовками, envelope, ошибки, пагинация, websockets)
      + сверочная таблица эндпоинтов + 13 дефектов (a-m). Скоуп store закрыт
      целиком: все 4 внешние границы покрыты. Главные находки:
      (a) ~130 клиентских методов и все типы рукописные, кодгена нет - переименование
      поля на бэке всплывает как undefined в проде (оба бэка публикуют OpenAPI!);
      (b) три формата ошибок сосуществуют, фронт частично матчит человекочитаемые
      строки по словарю; (c) refresh-флоу нет - через 24ч тихий разлогин посреди
      формы; (d) DELETE /web/auth/user/bulk-delete не имеет роута на бэке -
      свяжется как uuid и упадёт; (e) logout не зовётся - Redis-сессия живёт
      после "выхода", украденный токен переживает logout; (f) /lk/ws может
      не совпадать с proxy-правилом /ws (порт 8000 vs 8015) - проверить трейсом.
      Следующая дыра (записана в SOURCES.md): payload-контракт VA (/va/api/v1
      покрыт только топологией, ~34 метода агент-билдера - за VA).
- [x] Payload-контракт VA добыт 2026-07-29: спека `va-frontend-api` в store
      (1096 строк, 18 требований / 44 сценария, validate: 8 passed, НЕ закоммичено).
      Кросс-сверка: 79 эндпоинтов VA (18 роутеров) против фронтовых вызовов /vac.
      25 дефектов (a-y), главные: (a) кандидат-CRITICAL - VA НЕ проверяет
      HMAC-подпись gateway (доверяет x-user-context как есть) и 13 из 18 роутеров
      вообще без auth-зависимости, включая провайдеров с api_key; (b) api_key
      провайдеров отдаётся браузеру открытым текстом в ≥6 местах - на тех самых
      неавторизованных роутах; (o) /agent-template и /template-topic реализованы
      на VA, а фронт держит оба домена на in-memory моках (17 точек) - работа
      сделана с двух сторон, не соединена ни с одной; (l) TAgent ≠ AgentRead
      (6 ключей отсутствуют, providers non-null там, где VA даёт null - свежий
      агент ломает собственный тип фронта); (f) untagged union tools_settings
      duck-типится с подменой retrieval-конфига. Целостность файла проверена
      (усечение при правке поймано и восстановлено писателем; validate зелёный).
      Открытая дыра store: контракт node-графа conversation_flow (за CF).
- [x] node-граф conversation_flow проверен 2026-07-29 - НЕ идёт в store:
      это внутренний артефакт CF (типы Flow/Node/Edge в engine/schema.py
      создаются редактором, исполняются engine.py, передаются в livekit_agent
      как Python-объект - границу сервиса не пересекают). Другие сервисы видят
      только opaque YAML + хеш flow_fingerprint. Схема уже в LIVING SPEC CF §3.
      Спеку не создавали (дубль внутренней схемы). Ложная дыра снята.
      Реальный остаток за CF: опубликовать /v1 call API + вебхуки (если нужно).
      На внешней оси store ПОЛНЫЙ - 8 спек, все 4 границы закрыты.
- [ ] Найдены противоречия в источниках (зафиксированы в Provenance спек):
      путь `/call-records` vs `/phone-number` (взята inline-поправка);
      ротация ключей 409-vs-supersede (описан только общий инвариант);
      ограничения WEB-2061 с датой снятия 2026-06-09 - уже прошла.
- [x] Заголовок `X-API-Key` vs `x-cybernet-api-key` - РАЗРЕШЕНО кодом 2026-07-29:
      gateway читает только `x-cybernet-api-key` (headers.py:27-29); `X-API-Key`
      в коде - только тесты ВНУТРЕННЕГО механизма ключей, старый док смешал два
      механизма. Provenance спеки обновлён; правка дока - его владельцу.
- [x] Стиль метаданных store выровнен 2026-07-29: из wbn-va-rpc сняты 22 id +
      22 enforced комментария (единственная спека с ними; Provenance держит
      полные файловые якоря - потерь нет). Validate: 8 passed.
- [x] WBN post-call-processing перемайнена против main с WEB-2298 (см. таблицу
      спек ниже) - предупреждение "спека снята без WEB-2298" снято.
      Замечание miner'а: ЛОКАЛЬНЫЙ main в ~/cybernet/web-backend-new устарел
      (632b8726, 2026-07-20) - git fetch не помешает.
- [ ] Боевой store: завести репозиторий в организации (вопрос 1 ниже) или
      перенести тестовый; добавить контракты api/v1.
- [ ] Решить судьбу `web-backend-new/docs/`: сейчас это личный репозиторий вне git проекта,
      гейты его не видят (первая блокирующая находка в `../archive/LOGIC_VERIFICATION.md`).
      Контрактные части -> store; результат извлечения спек -> `openspec/specs/` в WBN;
      `shared_docs/` удалить.

### Шаг 1. Пилот - web-backend-new (самый нагруженный: 48% всех токенов, 40% PR - фиксы)

- [x] `sdd-kit/bootstrap.sh ~/cybernet/web-backend-new` - выполнено 2026-07-27 в тестовом
      режиме: файлы созданы, `make sdd-check: OK`, в git НЕ добавлено (решение Daniil).
      Единственное изменение отслеживаемого файла - 2 строки include в Makefile.
- [ ] Перед боевой раскаткой: убрать `CLAUDE.md` и `AGENTS.md` из `.gitignore` WBN
      (строки 147-148) - сейчас сам репозиторий запрещает коммитить контекст-файлы,
      это блокирует ADR-0002. Плюс локальные исключения `.git/info/exclude`
      (`/.claude/`, `CLAUDE.md`) прячут хуки и настройки от git на этой машине.
- [x] Заполнить AGENTS.md - выполнено 2026-07-27: 290 строк, на английском
      (9 сервисов, команды, карта модулей, ссылки на спеки и контракты).
- [x] Подключить store через `references:` - выполнено 2026-07-28 во всех 4 репо:
      store зарегистрирован (`openspec store register`, id `cybernet-specs`),
      `openspec doctor` - ok, чтение чужих спек из WBN проверено.
- [ ] Довести CI: сейчас в WBN тесты не запускаются вообще (вторая блокирующая находка);
      добавить в sdd-ci.yml шаг с pytest (docker compose), расширить с backend на post-call-processor.
- [x] Авто-ревью в PR - файлы установлены 2026-07-28 во все 4 репо (тестовый режим,
      в git не добавлено). Что поставлено: `.github/workflows/autoreview.yml`
      (reviewdog: ruff -> строчные комментарии в PR; AI-ревью: `claude -p` читает дифф
      и правила из `.claude/agents/`, пишет один комментарий, только CRITICAL/HIGH)
      + 4 ревьюера в `.claude/agents/` (python, fastapi, database, code).
      Разбор инструментов - `archive/autoreviewer.md`. PR-Agent - запасной вариант.
- [ ] Для запуска авто-ревью: закоммитить workflow + один раз выполнить
      `claude setup-token` на залогиненной машине и положить токен в секрет
      GitHub `CLAUDE_CODE_OAUTH_TOKEN`. Работаем по подписке Claude Code (OAuth),
      API-ключ Anthropic НЕ используется. Без секрета AI-шаг тихо пропускается,
      reviewdog работает и без него.
- [ ] Включить branch protection на dev + сделать sdd-gate обязательным check.
- [x] Первичное наполнение спек - выполнено 2026-07-27, spec-miner по всем 4 репо
      (см. таблицу "Состояние спек" ниже), все проходят `openspec validate --all --strict`.
- [x] spec-guard включён: `.spec-guard-paths` созданы во всех 4 репо, блокировка проверена.

### Состояние спек (2026-07-27, всё в тестовом режиме - в git не добавлено)

| Репо | Capability | Объём | Замечание |
|---|---|---|---|
| WBN | post-call-processing | 30 треб. / 7 инв. | перемайнено 2026-07-29 против origin/main efbfec54 (WEB-2298 и WEB-2256 внутри): код 16 + AMD-флаг -> VOICEMAIL_REACHED (retry-eligible), fail-closed ACK, owner-token lease, ZSET-дедлайны; spec-lint FRESH strict; miner нашёл мёртвый код (динамический stuck-timeout вытеснен ZSET) и новую неопределённость (три AMD-ключа OR-ятся без контракта производителя - ложный llm_amd тихо глушит аналитику) |
| VA | agent-configuration | 29 / 83 / 7 | следующая цель - agent-template (дёшево, есть тесты) |
| PCA | post-call-report-generation | 17 / 52 / 9 | найдено 2 подозрения на баги (код 96 vs voicemail_codes; await sync-метода на пути публикации) |
| cybernet3.0 | call-orchestration | 20 / 56 / 6 | точный redis-контракт -> сырьё для store; в репо НЕТ тестов вообще, все якоря MISSING |
| cybernet3.0 | call-session-initialization | 11 / 24 / 3 | initializer-часть после сплита 2026-07-29 (было 784-строчное объединение с vad); redis-поверхность движка закрыта целиком; находки владелец↔читатель - в client-audio-segmentation |
| cybernet3.0 | client-audio-segmentation | 18 / 51 / 4 | vad-часть после сплита 2026-07-29; 15 uncertainty-заметок (vad-лок не продлевается/не чистится, LIFO-ретраи, гонка состояний); нарезка по строкам без переписывания текста, суммы 29/75/7 сохранены, spec-lint FRESH strict |
| WBN | goal-achievement | 21 / 63 / 6 | добыто 2026-07-29 (opus) против efbfec54; goal-правила, дедлайны (ZADD NX 600s), общий retry_lock, поздние вердикты; 8 находок в беклоге, включая HIGH: поздний False затирает промоушен, утечка лока на 1200с при падении диспатча; попутно исправлен дрейф в post-call-processing (judge-wait 5s/30s -> 180s/180s по коду) |
| VA | agent-template | 20 / ~50 / 4 | добыто 2026-07-29 (sonnet); шаблоны+топики+снапшот AgentTemplateConfigV1; большинство сценариев с test-якорями; spec-lint FRESH strict |
| store | frontend-api-v1 | 13 / 31 | добыто 2026-07-29 из кода WBN+фронтенда; конвенции + сверка эндпоинтов + 13 дефектов |
| store | va-frontend-api | 18 / 44 | добыто 2026-07-29; payload-контракт агент-билдера, 25 дефектов; в store теперь 8 спек, validate: 8 passed |

Следующие цели майнинга: cybernet3.0 initializer+vad (закрывают ключи, которые controller
читает, но не владеет); VA agent-template; WBN goal_achieved_service.

### Шаг 2. voice-agent-constructor-backend (35% его тикетов - общие с WBN)

- [x] bootstrap.sh - выполнено 2026-07-27 в тестовом режиме (openspec, хуки,
      .mcp.json, Makefile.sdd; `make sdd-check: OK`).
- [x] Заполнить AGENTS.md - выполнено 2026-07-28: 275 строк, английский, все команды
      сверены с Makefile. Внутри честно записано: `make test` гоняет только 2 файла
      и возвращает 0 даже при падении.
- [x] Подключить store через `references:` - сделано (проверено 2026-07-29,
      references wired во всех 5 репо, включая conversation_flow).
- [ ] Контрактные тесты оси WBN↔VA - первый настоящий груз контрактного слоя.

### Шаг 3. Остальные

- [x] voice-agent-postcall-analitics-backend: bootstrap.sh выполнен 2026-07-27
      (тестовый режим, `make sdd-check: OK`).
- [x] PCA: AGENTS.md заполнен 2026-07-28: 195 строк, английский; в Known issues -
      подтверждённый баг кода 96 (тест `test_success_code_96_is_not_skipped` падает).
- [ ] PCA: навести порядок с тикетами в коммитах (сейчас 2.4% PR с номером тикета).
- [x] cybernet3.0: bootstrap.sh выполнен 2026-07-27 (Makefile создан скриптом,
      существующий AGENTS.md сохранён; `make sdd-check: OK`).
- [x] cybernet3.0: AGENTS.md переписан 2026-07-28 (303 строки, английский; старый
      57-строчный содержал 3 ложных утверждения про сборку - исправлены).
- [ ] cybernet3.0: главное - branch protection (1780 коммитов мимо PR)
      и хоть какие-то тесты (сейчас их ноль). Redis-контракт уже в store
      (engine-redis-contract).
- [x] conversation_flow: bootstrap выполнен 2026-07-29 (тестовый режим, git-индекс
      чист - staged-переименование снято, в рабочем дереве: CLAUDE.md->симлинк,
      AGENTS.md новый, Makefile +2 строки). LIVING SPEC сохранён как основной
      процесс: **spec-guard в этом репо не ставится** (новый шаблон
      settings-living-spec.json + PROFILE_LIVING_SPEC=1 в профиле) - иначе он
      блокировал бы все правки 9 модулей, требуя openspec change, которых у CF
      для внутренней работы нет by design. Вместо него - проверка в pre-commit:
      "код из .spec-guard-paths staged без docs/DOCUMENTATION.md -> предупреждение"
      (идея lint_spec из этого пункта; шаблон living-spec-check.sh, ставится
      bootstrap'ом, проверено на живом хуке и на свежей песочнице).
      AGENTS.md переписан на канон (251 строка, английский, команды сверены:
      lint-brand/lint-migrations/lint-ruff через дефис; все "не трогать руками"
      сохранены; найдено устаревшее "943 теста" в DOCUMENTATION.md §14 - реально
      ~60 файлов / >1300 функций, записано в quirks). openspec/ в CF - только
      для контрактов store; sdd-check OK, аудит чистый.
      Осталось из старого пункта: публикация контракта node-графа в store (за CF).

### Шаг 4. Пилот процесса на живой задаче

- [ ] Миграция WEB-2303 идёт первой задачей по новому процессу.
- [ ] На ней же решаем судьбу GSD как слоя фаз (замер цены 6-12 проходов на фазу).
- [ ] После закрытия WEB-2305 - завести backend-gap-тикет (ADR-0005).

## MCP: что настроено и что осталось

| Где | Состояние |
|---|---|
| Глобально у Daniil | вычищено по ADR-0004: остались context7, headroom, youtrack |
| Пер-репозиторий `.mcp.json` | кладёт bootstrap.sh: context7 + youtrack; токен youtrack - через `YOUTRACK_TOKEN` в окружении, НЕ в файле |
| У остальных разработчиков | раздать методичку: `INIT.md` требует ≤500 строк CLAUDE.md и минимум MCP; проверить, что ни у кого не тянутся мёртвые серверы |
| graphify | не MCP-гейт, а навигация; `graphify watch` на WBN уже работает - оставить |

## Реализовано 2026-07-28 (по итогам исследований ниже)

- [x] spec-lint (`.claude/scripts/spec-lint.py`, идеи 1-2 из ECC #2283, переписан на
      Python): проверка свежести спек (`Last verified` против `git diff` по файлам
      из `enforced:`) + валидатор метаданных (уникальность id, наличие enforced,
      сценарии не в инвариантах). Встроен в `make sdd-check`. По умолчанию только
      предупреждает; `SPEC_LINT_STRICT=1` - блокирует. Раскатан во все 4 репо,
      результат: все 4 спеки FRESH; найдены и починены 4 дубля id (1 в VA, 3 в PCA).
- [x] Секция "Spec Compliance (OpenSpec)" добавлена во все 4 ревьюера (идея 3):
      ревьюер сверяет дифф с `enforced:`-якорями; нарушение спеки или изменение
      поведения без активного изменения в `openspec/changes/` = HIGH.
- [x] Гигиенические проверки в git-хук pre-commit (по вердикту из
      `pre-commit-recommendations.md`; фреймворк pre-commit.com решили не брать):
      маркеры незакрытого мержа, файлы >5 МБ, забытый `breakpoint()`/`pdb.set_trace()`,
      секреты по паттернам токенов, новые сабмодули, битые JSON/TOML/YAML,
      плюс ruff (автофикс + формат staged-файлов) и защита веток
      (main/master/prod/stage - блок, dev - предупреждение; обход `SDD_ALLOW_PROTECTED=1`).
      Шаблон - `sdd-kit/templates/pre-commit-hook.sh`; раскатано во все 4 репо
      и проверено на свежем клоне в ~/dev/web-backend-new - все блокировки живые.
- [x] Авто-ревизия мусора - `make sdd-audit` (`.claude/scripts/repo-audit.sh`,
      ставится bootstrap'ом и запускается в его конце): лишние MCP-серверы,
      конфиги чужих агент-инструментов (.cursor/.serena/...), посторонние skills
      и агенты. Только докладывает; `SDD_AUDIT_STRICT=1` - блокирует.
      Результат по репо: .mcp.json чист везде (context7+youtrack);
      WBN - 17 предупреждений (15 посторонних skills, .cursor, .serena);
      VA - .cursor и .serena; PCA - .serena; cybernet3.0 - чисто.
      Удалять или нет - решает Daniil (файлы могут быть личными/отслеживаемыми).

- [x] Методичка для команды: `ONBOARDING.md` (русский; установка,
      ежедневный цикл, шпаргалка команд, ruff, авторизация по подписке).
      Ссылка для команды: https://claude.ai/claude-code/onboard/LhGSXknq0pnB
- [x] `ruff.toml` в kit: ставится только если у репо нет своего конфига ruff
      (у WBN есть - пропускается; VA/PCA/cybernet3.0 получили). Явный `select`
      вместо extend-select: дефолты ruff 0.15+ раздулись до 400+ правил,
      на brownfield это шум и нестабильность между версиями.

- [x] Инструменты из старого ревью-промпта (radon, complexipy, vulture) встроены
      в контур ревью: секция "Tool-assisted checks" в python/code-ревьюерах
      (запуск через uvx только по изменённым .py, вывод - наводки для проверки,
      не готовые находки) + отчёт инструментов генерируется в CI и передаётся
      AI-ревью; в code-reviewer добавлен строгий порядок приоритетов
      (баги -> дубли -> сложность -> мёртвый код -> стиль -> читаемость).
      pylint не взят - дублирует ruff.

## Исследование 2026-07-28 (ECC #2283 и OpenSpec workspace)

ECC issue #2283 (расширение spec-miner: 5 агентов + CI) - НЕ смержено, PR конфликтует,
CI-скрипты на Node с багами и заточены под JavaScript. Целиком не брать.
Выцепить 3 идеи (портировать на Python, а не копировать):
1. Проверка свежести спек: `Last verified (commit)` против `git diff` по файлам из
   `enforced:` - ловит ровно наш случай "WBN-спека снята без WEB-2298". В sdd-check,
   сначала в режиме предупреждения.
2. Валидатор слоя метаданных spec-miner (`id` уникален, `enforced` есть,
   у инвариантов нет сценариев) - `openspec validate` этот слой не видит.
3. ~60 строк "Spec Compliance" в наших ревьюеров (`.claude/agents/`) -
   нарушение спеки = HIGH; пути переписать на канонический `openspec/changes/`.
Пропустить: spec-to-test и spec-fuzzer (JS-only), spec-delta-writer (пишет в
неканонический `openspec/deltas/`, наши гейты его не видят), spec-guardian (рано).

OpenSpec "workspace" - мёртвая ветка: модель удалена в 1.5.0 и заменена на stores.
Наш store + `references:` - действующая модель. Подробности - дополнение в ADR-0001.
Практические выводы: пин ровно 1.6.0; каталог 4 репозиториев положить в `context:`
конфига store (мигрирует в `repos:` из issue #1436, если тот примут); следить за
PR #1286 (`--serves` - кросс-репо статус для оси WBN↔VA); можно откомментировать
issue #1436 нашими цифрами (8,3% кросс-репо тикетов, WBN↔VA = 35% тикетов VA).

## Исследование 2026-07-28 (intent-driven-template и portfolio-reuse-kit)

Сравнили sdd-kit с двумя внешними наборами. Целиком не брать ни один.

**intent-driven-template** (intent-driven-dev, 93 звезды) - шаблон под OpenCode,
не под Claude Code. Весь контроль - прозой в SKILL.md: ни хуков, ни CI, ни Makefile.
Наш kit сильнее по принуждению (гейты на уровне tool-call и CI). Но у них есть
дисциплины, которых у нас нет - стоит забрать три:
1. **Неизменяемые ADR + `Supersedes:`** - прошлый ADR не правится, пишется новый
   со ссылкой; spec-lint может проверять висячие ссылки. Дёшево, ложится на наш ADR/.
2. **Контракт proposal↔spec**: proposal перечисляет capabilities 1:1 к папкам
   `specs/<capability>/` - проверяется grep'ом в sdd-check.
3. **`*.council.md` рядом с AI-артефактом** (автор -> оппонент -> сверка, журнал
   принятых/отклонённых замечаний) - можно добавить к нашему авторевью как
   артефакт-след, а не только комментарий в PR.
Пропустить: adversarial-агенты OpenCode (у нас свои ревьюеры), glossary-файлы (рано).

**portfolio-reuse-kit** (Brilhante29, 0 звёзд, персональный, PowerShell-центричный) -
мета-система для портфолио из 33 реп, не устанавливаемый kit. CI тоньше нашего,
хуков нет. Забрать одну идею:
4. **`CURRENT_HANDOFF.md`** - файл преемственности длинной агентной сессии:
   состояние, доказательства, отклонённые альтернативы, следующие шаги; с явным
   запретом на неподтверждённые заявления "готово". У нас эту роль играет
   NEXT_STEPS.md - формализовать шаблон, когда пойдём в боевую раскатку.
Пропустить: decision-brain YAML-матрицы, benchmark-схемы, журнал efficiency-событий
(оверкилл для 4 реп), дубль скиллов под .codex/ (нам не нужен Codex).

Итог: sdd-kit по всем пяти критериям TASK_SDD_SELECTION §4 не хуже обоих;
брать точечно идеи 1-3 (в kit) и 4 (шаблон при раскатке), не архитектуру.

## Ревью-пайплайн проверен на живом коммите (2026-07-28)

sdd-kit переустановлен на свежий клон `~/dev/web-backend-new` (SDD_KIT_ASSUME_YES=1,
всё встало, sdd-check OK, аудит нашёл только .cursor). Затем три ревьюера kit'а
(code/opus + python/sonnet + database/sonnet) прогнаны по коммиту 3cc56e7c
(WEB-2256, PCP shutdown refactor, 31 файл): 2 CRITICAL, 5 HIGH, 11 MEDIUM,
ложные наводки статических инструментов отфильтрованы. Полный отчёт:
`reviews/WEB-2256-review.md`. Вердикт: WARNING - мержить после
фиксов C1 (гонка lease -> потеря вебхука навсегда), C2 (cleanup закрывает
соединения под живыми задачами), H1 (drain 12с против бюджета сообщения 300с).

## Профили репозиториев в sdd-kit (2026-07-29)

sdd-kit теперь узнаёт наши 7 репозиториев по имени каталога
(`sdd-kit/profiles/<имя>.env`) и сразу настраивает их правильно:
- сеет `.spec-guard-paths` с реальными путями продакшен-кода
  (tests/docs/migrations/values не охраняются);
- подключает store: клонирует cybernet-specs (с разрешения), регистрирует,
  дописывает `references:` в `openspec/config.yaml`. Проверено: `validate`
  в CI без зарегистрированного store НЕ падает, `doctor` подсказывает фикс;
- web-frontend-new: PROFILE_SKIP_PY=1 (ruff не ставится, свой eslint-стек);
- conversation_flow: охраняются 9 модулей, editor/flows/migrations свободны,
  их `make test` не трогаем;
- cybernet-specs: PROFILE_IS_STORE=1 - минимальная установка (локальная
  регистрация + store-ci.yml со strict-валидацией), больше ничего.
Протестировано на ~/dev/web-backend-new (профиль подхватился, 35 путей,
references добавлен) и на cybernet-specs (store-ci.yml создан).
Незнакомые репо идут по общему пути с TODO. Переопределение:
SDD_STORE_ID / SDD_STORE_DIR / SDD_STORE_GIT.

Из no-mistakes (kunchenguid, 7k звёзд) решили НЕ брать демон/git-прокси;
кандидаты в промпты ревьюеров (ещё не внесены): "не докладывай о стиле -
это дело ruff", поле действия auto-fix/ask-user/no-op, клауза про
долговременный фикс против осознанного сдерживания.

## Сверка с INIT.md (2026-07-29): sdd-doctor и добивка пробелов

Прошлись по INIT.md пункт за пунктом. Было покрыто: методичка ≤500 строк,
youtrack-mcp/context7, AGENTS.md-канон, авторевью с tools + правилами репо
(AGENTS.md в промпте - проверено), hooks, Graphify/ponytail/Headroom/grill
(персональные, в методичке), модели//effort, sdd-audit против раздувания.
Добавлено сегодня:
- **`make sdd-doctor`** (`.claude/scripts/sdd-doctor.sh`) - проверка окружения:
  git/node/python3≥3.10/uv/ruff/openspec, claude CLI, gh CLI + auth,
  store зарегистрирован, токен youtrack, хуки/pre-commit на месте.
  Запускается в конце bootstrap. Advisory, exit 1 только на FAIL.
- **chrome-devtools MCP для фронтенда**: профиль web-frontend-new
  (PROFILE_FRONTEND=1) кладёт его в .mcp.json; whitelist аудита дополнен.
- Методичка: поиск в интернете (встроенный WebSearch достаточен, SearXNG -
  опция), "повторил промпт трижды - оформи skill", sdd-doctor в шпаргалку.
Осознанно не делаем: pylint (дубль ruff), переходники на codex/cursor
(AGENTS.md уже agent-agnostic, спрос появится - добавим).

## setup-dev.sh и feature-flow (2026-07-29)

По просьбе Daniil kit теперь покрывает и личные инструменты, и наш процесс:
- **`sdd-kit/setup-dev.sh`** - машинная установка рекомендованного, каждый
  пункт с вопросом y/N, установленное распознаёт: ponytail (плагин
  DietrichGebert/ponytail), rtk (curl + rtk init -g), gh-axi и
  chrome-devtools-axi (npx skills add ... -g), Graphify (uv tool install
  graphifyy + graphify install --platform claude), Headroom (uv tool install
  headroom-ai + claude mcp add). caveman отдельно не существует - это
  бенчмарк-стенд внутри репо ponytail; Playwright закрыт chrome-devtools-axi.
- **`.claude/skills/feature-flow/SKILL.md`** (ставит bootstrap) - процесс
  Daniil из INIT.md:19-32 как skill: допрос тикета против кода и спек ДО кода
  (вопросы Дине/Ольге комментарием), план как OpenSpec change, ветка
  feature/WEB-*, тест-док, pytest+newman, ручной прогон, ревью (в скоупе -
  чинить, вне - TODO с номером тикета), PR. Whitelist repo-audit дополнен.
Синхронизировано по 5 установкам. Методичка обновлена (ссылка та же).

## Проверка 14 инструментов из INIT.md:45-94 (2026-07-29)

Три субагента (контекст / параллельные агенты / LLM-фреймворки+observability).

**ADOPT (3):**
- **semgrep** - [x] внесён 2026-07-29: autoreview.yml (p/security-audit +
  p/secrets на изменённых файлах, severity ≥WARNING) + строка в python/code
  ревьюерах + промпт "подтверждённая security-находка = минимум HIGH".
  Смоук-тест uvx semgrep прошёл. Синхронизировано по 5 установкам.
- **ast-grep** - [x] внесён 2026-07-29 в setup-dev.sh (uv tool install
  ast-grep-cli, с вопросом). Кодмоды по AST, не гейт.
- **Langfuse** -> кандидат в ПРОДУКТ (не в kit): self-host (MIT-ядро,
  Postgres+ClickHouse+Redis+S3), трейс по call/session id вместо ручного
  collect_incident.py, плюс prompt-management (промпты сейчас в коде/БД).
  Пилот на офлайн-сервисе, НЕ на realtime-движке.
  Это решение уровня команды/продукта - вынести отдельным предложением.
  [x] Предложение написано 2026-07-29: `PROPOSAL_langfuse.md`
  (проблема->что даёт->почему Langfuse, а не Phoenix/Helicone->честная ops-цена:
  ClickHouse+S3 новые для нас->план пилота на офлайн-сервисе с go/no-go).
  Кандидаты пилота уточнены по коду: judge/аналитика в backend/ (openai уже в
  зависимостях) или asterisk-json-creator-llm; realtime cybernet3.0/llm - в
  последнюю очередь. Решает команда/Рашид.

**SKIP (10):** langchain и llama_index (ретрофит рабочего direct-API кода -
переписывание ради абстракций), graphrag (нет корпуса документов), helix-db
(новая БД для маленькой команды; pgvector в Postgres закрывает вектор),
container-use (докер-оверхед ради изоляции, которой нет как проблемы),
Understand-Anything (дубль Graphify + признаки накрутки звёзд: орг с 1 репо,
76k звёзд за 4 месяца), serena (уже пробовали - .serena/ лежит мусором,
аудит его ловит), repomix и code2prompt (монолитный дамп репо против нашей
философии; на крайний случай - разовый npx repomix), helicone (прокси в
пути запроса - риск для realtime-голоса).

**LATER (2):** worktrunk (если появится ручное жонглирование worktree вне
Claude Code), phoenix (запасной вариант observability, если Langfuse тяжёл).

## Беклог дефектов, incident-flow, дисциплина ревью (2026-07-29)

- [x] **`DEFECTS_BACKLOG.md`** - все находки майнинга и ревью в одном
  файле: 65 дефектов (4 CRITICAL / 20 HIGH / 41 MEDIUM), таблицы по репо
  (WBN 5, VA 15, frontend 11, c3.0 21, PCA 2, кросс-сервис WBN↔VA 11),
  каждая строка - готовый заголовок тикета + ссылка на источник.
  Мы их НЕ чиним (скоуп WEB-2305) - материал для тикетов, заводит Daniil.
- [x] **Skill `incident-flow`** в kit (BUGFIX-процесс из INIT.md:35-43):
  собрать данные collect_incident.py -> док о причинах (баг/клиент/инфра -
  не угадывать до данных) -> план как OpenSpec change -> фикс с регрессионным
  тестом (падает до, проходит после) -> проверка против инцидента.
  Ставится bootstrap'ом, whitelist аудита дополнен.
- [x] **"Review discipline" во всех 4 ревьюерах** (3 идеи из no-mistakes):
  не докладывать о стиле/линте (это дело ruff), каждая находка с полем
  действия auto-fix/ask-user/no-op (по умолчанию ask-user), запрет выводить
  системный дефект из формы кода без конкретной падающей последовательности.
Синхронизировано по 5 установкам; методичка дополнена (incident-flow).

## CI для самого sdd-kit (2026-07-29)

- [x] `.github/workflows/ci.yml` в репо kit: lint-джоб (shellcheck по всем
  скриптам - 2 реальных замечания найдены и исправлены; bash -n; node --check
  хуков; py_compile spec-lint; YAML/JSON шаблонов; bash -n профилей) +
  smoke-джоб (bootstrap пустого репо без TTY -> make sdd-check + sdd-audit +
  проверка pre-commit -> повторный bootstrap и diff md5 всех файлов =
  идемпотентность). Все проверки прогнаны локально: LINT_OK, IDEMPOTENT,
  sdd-check OK. НЕ закоммичено - коммитит Daniil.
- [x] LICENSE создан 2026-07-29 (проприетарная, copyright owner, с сохранением
      MIT-уведомления для адаптированных из ECC ревьюеров/spec-miner).

## Запуск стека на свежем клоне (2026-07-29)

- [x] Методичка: секция "Свежий клон бэкенда: запуск стека" - скопировать 8
  реальных `.env` из рабочего клона (в git их нет; `.env.example` без секретов)
  + `docker compose up --build -d` для WBN И VA (WBN ходит в VA).
- [x] sdd-doctor проверяет наличие 8 `.env` (профиль WBN отдаёт список в
  `.claude/expected-env`; doctor читает только факт наличия, не значения).
  Проверено: 8 WARN на клоне без .env, "all present" на настроенном.
  Раскатан по 5 репо; в свежий ~/dev/web-backend-new список засеян.
  Механизм общий - любой профиль может задать PROFILE_ENV_FILES.

## Реорганизация документов (2026-07-31)

Разложили корень `refactor_v4/` и `sdd-kit/benchmark/` по папкам - стало трудно
искать актуальное среди черновиков.

В корне появились `archive/`, `docs/`, `presentations/`.
В `archive/` ушли разовые анализы и черновые сравнения: `autoreviewer.md`,
`Spec-Driven-Development-Tools.md`, `recommendations.md`, `FABLE5_SESSION.md`,
`LOGIC_VERIFICATION.md`, `HubTalk_AI_Platform_Comparison_RU.docx`.
В `docs/` - рабочие документы: `GLOSSARY.md`, этот файл (`NEXT_STEPS.md`),
`DEFECTS_BACKLOG.md`, `PROPOSAL_langfuse.md`, `pre-commit-recommendations.md`.
В `presentations/` - `PRESENTATION_PLAN.md` и `SDD_presentation.pptx`.

В `sdd-kit/benchmark/` появилась `archive-m1-m2/` - туда ушли завершённые
прогоны m1/m2 (протоколы, отчёты, ручные прогоны, харнесс-скрипты) и
планирование самого бенчмарка. Актуальные `PLAN-tools.md`, `recommendations.md`
и `adr/` остались на месте.

Все ссылки между документами поправлены на новые пути.

## Открытые вопросы (решает Daniil)

1. Где живёт store-репозиторий (GitHub-организация? имя?) - нужно для шага 0.
2. Кто пилотирует WBN (шаг 1) - один человек-владелец процесса на 1-2 недели.
3. `.spec-guard-paths` уже создан во всех 4 репо (тестовый режим). Решить,
   что коммитим при боевой раскатке: все сразу или сначала только WBN
   (рекомендация: WBN - сразу, остальные - после пилота).
