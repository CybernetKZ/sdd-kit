# Runbook: Web-2316 (Web SDK для голосовых звонков на сторонних сайтах) через sdd-kit + cybernet-specs

Задача выполняется **независимо несколькими инструментами** для сравнения. Этот файл - прогон
через sdd-kit: команды, шаги, замерные метрики. Формат по образцу
[DRYRUN_WEB2318.md](archive/DRYRUN_WEB2318.md).

Тикет: `Web-2316` - Web SDK для запуска голосовых звонков с AI-агентом на сторонних сайтах.

## Решения по прогону (приняты 2026-08-03)

| Вопрос | Решение |
|---|---|
| Ветка | от `test-sdd-kit` (в неё уже влит `main`) |
| Прежняя работа | **чистый прогон**: ветку `feature/patch92-web-sdk-voice-calls` НЕ читать до финала |
| Store | **контракт в `cybernet-specs` планируем сразу** (ADR-0018) |
| Номер ТЗ | `tz-101` + `Web-2316` (двойная нумерация, ADR-0019 §7) |

### Дисциплина "чистой комнаты"

На `origin/feature/patch92-web-sdk-voice-calls` лежит готовое ТЗ и рабочий Web SDK
(11 коммитов, код-ревью, багфиксы, `CFLOW_CORS_ORIGINS`). Для честности замера **не читать
ни ТЗ, ни код** до завершения прогона. Практически: не делать `git checkout`/`git show` по этой
ветке и не грепать по ней. Ограничение техническое, не моральное - прочитанное нельзя "забыть".

Отдельно учесть: **номер №92 в репозитории занят дважды** - `patch92-web-sdk-voice-calls`
на фиче-ветке и `patch92-tenant-isolation-repositories` на `main`. Обе ветки отросли от общего
merge-base с максимумом 91 и независимо взяли 92. Это не наша забота в этом прогоне, но при
слиянии её придётся решать; и это причина, по которой в расчёте номера ниже участвует `main`.

## Исходная точка (проверено 2026-08-03)

```bash
cd /home/octrow/cybernet/conversation_flow
git fetch origin
git rev-list --count origin/test-sdd-kit..origin/main   # 0  - main влит в нашу ветку
git rev-list --count origin/main..origin/test-sdd-kit   # 40 - наша ветка впереди
```

Номера (все четыре источника, потому что ни один в одиночку не верен):

```bash
ls docs/patches | grep -o 'patch[0-9]*' | sed 's/patch//' | sort -n | tail -1            # 99
ls openspec/changes openspec/changes/archive | grep -o 'tz-[0-9]*' | sed 's/tz-0*//' | sort -n | tail -1  # 100
grep -o 'ТЗ №[0-9]*' docs/DOCUMENTATION.md | grep -o '[0-9]*' | sort -n | tail -1        # 95
git ls-tree -r --name-only origin/main -- docs/patches | grep -o 'patch[0-9]*' | sed 's/patch//' | sort -n | tail -1  # 99
```

Максимум 100 (`tz-100` - RG1) ⇒ **следующий свободный №101**.

Базовое состояние гейтов - записать ДО начала, иначе не отличить свой результат от фона:

```bash
make sdd-check                                   # OK (spec-lint advisory)
python3 .claude/scripts/spec-lint.py             # FRESH=5 STALE=15, 0 metadata violations
npx -y @fission-ai/openspec@1.7.0 validate --all --strict   # 29 passed / 0 failed
make sdd-doctor                                  # 1 warning (spec-guard off by design), 0 failures
PY=/opt/anaconda3/bin/python3.12 make test       # зафиксировать: зелёный или нет
```

**`STALE=15` - фон, не ваша поломка.** Это следствие мержа `main`: код ушёл вперёд маркеров
`Last verified`. Ре-верификация 15 спек - отдельная работа (см. "Долги", ниже), в замер
Web-2316 не входит. Если хотите чистое поле - сначала закройте долги, но тогда сравнение с
другими инструментами сместится на время этой уборки.

## Шаг 0. Ветка

```bash
cd /home/octrow/cybernet/conversation_flow
git checkout test-sdd-kit && git pull --ff-only
git checkout -b feature/web-2316-web-sdk
bash ../sdd-kit/tools/cf/main-drift.sh    # ожидаемо: дрейфа нет (main влит)
```

## Шаг 1. `/tz` - требование как OpenSpec change

Вызвать скилл (человеком, по имени - скиллы трилогии намеренно без
`disable-model-invocation`):

```
/tz Web-2316: Web SDK для запуска голосовых звонков с AI-агентом на сторонних сайтах
```

Скилл сам посчитает номер по четырём источникам (должен дать 101 - сверьте) и создаст:

```
openspec/changes/tz-101-web-sdk-voice-calls/
├── proposal.md   шапка-цитата, ## Закрываемые дефекты / ## Контекст, ## Why,
│                 ## What Changes (§1..§N), ## Проверить перед реализацией,
│                 ## Вне scope, ## Что затрагивается в каноне, ## Grill, ## Тир
├── specs/<capability>/spec.md   дельта: ## ADDED / ## MODIFIED Requirements
└── tasks.md      критерии приёмки как `- [ ]`
```

**Тир - `deep`** (новая внешняя поверхность + безопасность). Обосновать в `## Тир`.

Какие capability затрагиваются (владельцы уже существуют, новую заводить только если гриль
скажет): `public-api-v1` (web-звонки, `POST /v1/calls/web` уже там), `telephony`
(лимиты транка), `tenancy-auth` (ключи, origin), `voice-pipeline` (рантайм сессии).

**Три зарегистрированных дефекта бьют прямо в задачу** - внести в `## Проверить перед
реализацией`, полные формулировки в [DEFECTS_CF.md](DEFECTS_CF.md):

- **T1 (HIGH, финансовый)** - `_check_limits` зовётся ровно из одного места
  (`api/telephony.py:483`), `transfer_dial` его не зовёт. С публичным вебовым входом обход
  anti-toll-fraud перестаёт быть внутренним риском.
- **D7** - обещанный 404 на неизвестный `agent_id` в `POST /v1/calls/phone` не наступает
  (там 403); у `/v1/calls/web` контракт другой. SDK на чужих сайтах сделает расхождение
  видимым наружу.
- **TA9 (MEDIUM, периметр)** - `/metrics` полностью неаутентифицирован (регистрируется вне
  `/api/*` и `/v1/*`, middleware его не видит).

Плюс `tz-087` (правка `rate_limit_per_minute` ключа без ротации секрета) - рабочий инструмент
для ключей сторонних сайтов.

## Шаг 2. `/tz-review` - механический аудит

```
/tz-review openspec/changes/tz-101-web-sdk-voice-calls
```

**Запускать другим агентом, не автором** - ревьюер обязан опровергать. Проверяет: формат,
сверку утверждений с фактами кода грепом, якоря `enforced:` на существование **символа**
(дефект M1), непротиворечивость канону и истории, корректность номера, brand-clean.
Документ не правит, вердикт в чат. Реализация не начинается без вердикта.

## Шаг 3. `plan-griller` - допрос плана

Субагент `plan-griller` (`.claude/agents/plan-griller.md`), пишет `## Grill` в proposal с
шапкой провенанса. **Не дубль шага 2** (ADR-0020): ревью - механическая сверка документа,
гриль - интерактивный допрос решений.

Вопросы, которые обязаны быть заданы для этой задачи:

1. Что уезжает в браузер - долгоживущий API-ключ или эфемерный токен? Кто его минтит и на
   какой срок?
2. Чем ограничен origin: allowlist на сервере, `CFLOW_CORS_ORIGINS`, проверка `Referer`?
   Что происходит при отсутствии совпадения - 403 или тихий отказ?
3. Кто минтит комнату LiveKit - сервер или сам SDK? (второе - прямой вектор злоупотребления)
4. Лимиты: чем ограничен веб-вход по числу одновременных и по минуте, и как это соотносится
   с T1?
5. Что видно в браузерной консоли и в сетевых запросах - не утекает ли имя агента, флоу,
   organization_id?
6. Деградация: RAG недоступен, TTS-провайдер упал, LiveKit не отвечает - что видит
   пользователь на чужом сайте?

## Шаг 4. `test-author` - RED-тесты до кода

Субагент `test-author` (ADR-0016) пишет падающие тесты по Scenario дельты. Файл -
`tests/test_patch101.py` (конвенция репозитория: `patchNN` ↔ номер ТЗ, карта в
[tests/README.md](../../conversation_flow/tests/README.md)).

```bash
PY=/opt/anaconda3/bin/python3.12 python3 -m pytest tests/test_patch101.py -q   # ожидаем RED
```

## Шаг 5. `/tz-implement` - реализация

```
/tz-implement openspec/changes/tz-101-web-sdk-voice-calls
```

Фаза 0 остановится, если нет вердикта ревью или пуста `## Grill`. Реализацию делегирует
субагенту `executor` (строго по `tasks.md`, стоп при отклонении, без коммитов).

Принцип "код важнее спеки": расхождение ⇒ СТОП и доклад, а не подгонка кода под текст.

Перед **каждым** коммитом:

```bash
nvm use 20
PY=/opt/anaconda3/bin/python3.12 make test        # lint_brand + lint_migrations + lint_imports + ruff + pytest
npm --prefix editor run build                     # включает tsc --noEmit
npm --prefix editor run lint && npm --prefix editor run format:check
```

Если менялась `engine/schema.py`:

```bash
python scripts/gen_ts_types.py      # или: npm --prefix editor run sync-schema
```

Ловушки этой машины: `python3` в PATH может быть 3.7 - всегда `PY=/opt/anaconda3/bin/python3.12`;
Node - через `nvm use 20`; дефолтный vLLM-endpoint недоступен без VPN.

В **тех же коммитах** (DoD, ADR-0019): спек-дельта в `openspec/specs/` (канон) **и** § в
`docs/DOCUMENTATION.md` + запись в §17 + версия `1.NN.0`.

## Шаг 6. Ревью кода

```bash
make sdd-review        # база сравнения: SDD_REVIEW_BASE (по умолчанию из origin/HEAD)
```

Субагенты: `backend-reviewer` (Python/FastAPI), `database-reviewer` (если появились миграции).
Отдельно прогнать `security`-взгляд на периметр: ключ в браузере, CORS, origin, лимиты.

## Шаг 7. Контракт в store `cybernet-specs`

Решение принято: контракт планируем сразу. По ADR-0018 текст стор-контракта правится
**отдельным change/PR** в `cybernet-specs`, а в `tasks.md` репо-change'а обязательна
задача-связка; **архивация репо-change'а ждёт стор-PR**.

```bash
cd /home/octrow/cybernet/cybernet-specs
# образцы: openspec/changes/add-cf-dialer-integration-api/, add-cf-rag-contract/
npx -y @fission-ai/openspec@1.7.0 new change add-cf-web-sdk-contract
npx -y @fission-ai/openspec@1.7.0 validate --all --strict
```

Что описывает контракт: публичная поверхность для сторонних сайтов - инициализация SDK,
минтинг токена/комнаты, события, ошибки и коды, требования к origin, лимиты, версионирование
и обратная совместимость. PR и ревью владельцем - за Даниилом.

## Шаг 8. Архивация

После реализации, зелёных гейтов и стор-PR:

```
/openspec-archive-change tz-101-web-sdk-voice-calls
```

```bash
npx -y @fission-ai/openspec@1.7.0 validate --all --strict
python3 .claude/scripts/spec-lint.py     # спеки, которые вы трогали, должны стать FRESH
make sdd-check
```

## Замерные метрики

Снимать в двух точках: **до шага 0** (baseline) и **после шага 8**. Всё, что ниже,
считается командами - без экспертных оценок.

### Процесс

| Метрика | Как снять |
|---|---|
| Время по шагам | вручную: старт/финиш каждого шага 1-8 (wall-clock) |
| Число коммитов | `git rev-list --count test-sdd-kit..HEAD` |
| Размер диффа | `git diff --stat test-sdd-kit...HEAD \| tail -1` |
| Диффы по областям | `git diff --numstat test-sdd-kit...HEAD \| awk '{print $3}' \| cut -d/ -f1 \| sort \| uniq -c \| sort -rn` |
| Сколько раз сработал СТОП-гейт | считать вручную по докладам `/tz-implement` |
| Вопросов на гриле | `grep -c '^[0-9]\.' openspec/changes/tz-101-*/proposal.md` в секции `## Grill` |
| Правок плана после гриля | из шапки провенанса `## Grill` (`plan changes:`) |

### Спеки и требования

| Метрика | Как снять |
|---|---|
| Добавлено Requirements | `grep -c '^### Requirement:' openspec/changes/tz-101-*/specs/*/spec.md` |
| Добавлено Invariants | `grep -c '^### Invariant:' openspec/changes/tz-101-*/specs/*/spec.md` |
| Затронуто capability | `ls openspec/changes/tz-101-*/specs/` |
| Задач в `tasks.md` / выполнено | `grep -c '^- \[' .../tasks.md` и `grep -c '^- \[x\]' .../tasks.md` |
| Спеки стали FRESH | diff вывода `spec-lint` до и после (только те, что трогали) |

### Тесты и гейты

| Метрика | Как снять |
|---|---|
| Новых тестов | `grep -c 'def test_' tests/test_patch101.py` |
| RED->GREEN подтверждён | зафиксировать вывод pytest до реализации (RED) и после (GREEN) |
| Покрытие новых Requirements тестами | по каждому id: есть ссылка на тест в Scenario или "нет теста" |
| Прогонов `make test` | считать; фиксировать каждое падение и причину |
| `openspec validate --all --strict` | было 29/0 -> должно стать 30/0 (+1 активный change), после архивации снова 29/0 |
| `spec-lint` metadata violations | должно остаться 0 на всех прогонах |
| Дельта проверена spec-lint | в выводе есть строка `N change delta(s) checked, 0 with findings` |
| `make sdd-doctor` | было 1 warning / 0 failures - новых warning быть не должно |

### Качество результата

| Метрика | Как снять |
|---|---|
| Найдено дефектов кода по ходу | записывать в [DEFECTS_CF.md](DEFECTS_CF.md), считать по severity |
| Из них подтверждены прогоном | сколько воспроизведено тестом/исполнением, а не только чтением |
| Ложных срабатываний | сколько заявленных дефектов отозвано после проверки (ср. историю R1) |
| Расхождений код ↔ документация | сколько раз сработало "код важнее спеки" |
| Замечаний `/tz-review` | по категориям: формат / факты кода / якоря / номер / brand |
| Замечаний ревьюеров кода | `backend-reviewer` + `database-reviewer`, по severity |
| Правок после ревью | `git rev-list --count <до-ревью>..HEAD` |

### Сравнение с другими инструментами

Для честного сопоставления записать одинаково для всех прогонов: **вводная** (только текст
тикета), **исходная ветка**, **результат по гейтам**, **время**, **объём диффа**, **число
найденных дефектов**, **покрытие тестами**. После завершения - открыть
`feature/patch92-web-sdk-voice-calls` и сравнить с ней как с четвёртым, "ручным" прогоном:
что нашли мы и не нашли там, и наоборот.

## Долги репозитория (в замер не входят, но искажают фон)

Возникли из мержа `main` в `test-sdd-kit`, закрывать отдельно:

1. **15 спек STALE** - ре-верифицировать против нового кода, обновить `Last verified`
   (протокол: [tools/cf/verify-section.md](../tools/cf/verify-section.md)).
2. **`tz-092` и `tz-093` реализованы на `main`** - архивировать как выполненные и проверить,
   что TA1-TA5 и V1a/V1b/TA3 действительно закрыты кодом, а не только заявлены.
3. **RG1 (CRITICAL)** ждёт реализации по `tz-100`.
4. `AGENTS.md` / `CLAUDE.md` на `main` - два расходящихся файла (WARN в `sdd-check`);
   в нашей ветке канон + симлинк, разойдётся снова при обратном мерже.
