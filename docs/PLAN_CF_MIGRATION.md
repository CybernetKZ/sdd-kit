# План миграции conversation_flow на sdd-kit + OpenSpec

Дата: 2026-08-03. Статус: **прошёл грилл** (grill-with-docs, решения зафиксированы в [ADR-0019](ADR/ADR-0019-cf-onboarding.md)).
Источники: `~/cybernet/docs/sdd-kit-vs-conversation_flow.md`, `~/cybernet/docs/sdd-kit-vs-code-conventions.md`, глубокий аудит conversation_flow от 2026-08-03 (LIVING SPEC 9470 строк / v1.81.0, 83 ТЗ в `docs/patches/`, 41 405 строк тестов).
conversation_flow входит в scope sdd-kit (частично отменяет ADR-0015); спец-код под conversation_flow разрешён внутри sdd-kit.

---

## 0. TL;DR (после грилла)

**Полная конвертация всего `conversation_flow/docs/` в OpenSpec до первого нового ТЗ.** Внутренние спеки — канон в самом репо, 2 кросс-репо контракта — в cybernet-specs, полный слепок — в `sdd-kit/profiles/conversation_flow/` (копируется при install, только для этого репо). DOCUMENTATION.md не замораживается — ведётся параллельно: агент генерирует его обновление из spec-дельты, канон — openspec.

| Домашнее | OpenSpec / sdd-kit | Способ |
|---|---|---|
| `docs/DOCUMENTATION.md` (LIVING SPEC) | `openspec/specs/<capability>/spec.md` (~20 capabilities) | полный рерайт sonnet-агентами + полная верификация против кода |
| `docs/patches/patchNN-*.md` (83 ТЗ) | `openspec/changes/archive/tz-0NN-*/` | полная конвертация (sonnet); оригиналы остаются, в change — ссылка на оригинал |
| `docs/integration-guide.md`, `cybernetrag_openapi.json` | `cybernet-specs` store | 2 контракта по ADR-0018 |
| `/patch` → `/patch-review` → `/patch-implement` | скиллы `tz`/`tz-implement` в payload профиля | наследники с сохранением recon-before-text, «код важнее спеки», STOP-гейтов, 11 инвариантов; судьба review-шага — отдельный грилл |
| §17 changelog | продолжается (агент обновляет из дельты) + порядок `changes/archive/` | |
| `tests/test_patchNN.py` | тесты со `# spec:` трейсерами по Scenario | старые не трогаем; `enforced:` якоря из §14 + tests/README.md |
| `pretooluse_guard.py`, lint_brand/migrations/imports, `make test` | — | **не трогаем** — сильнее `sdd-test`, эквивалента в ките нет |

## 1. Решения грилла (2026-08-03, ADR-0019)

1. **Конвертация — полная**, весь `docs/` (не только нормативные разделы), LLM-часть на sonnet.
2. **Размещение — два уровня ADR-0001**: внутреннее в CF (канон), контракты в store. Слепок в профиле кита = seed при install (repo-owned после, в `--refresh`-manifest не входит).
3. **Верификация — полная по протоколу store**: каждая capability сверяется с кодом отдельным агентом, расхождения — в список дефектов.
4. **Порядок: сначала вся конвертация, потом пилот.** До завершения конвертации новые ТЗ идут по старому патч-процессу. Пилот — реальное следующее ТЗ (не синтетика из бэклога).
5. **DOCUMENTATION.md — параллельно, навсегда**: канон openspec; в `tz-implement` фаза 3 агент переносит изменение из spec-дельты в § документа + §17 + версия `1.NN.0`, в тех же коммитах. Living-spec-warn в pre-commit остаётся постоянно (`PROFILE_LIVING_SPEC=1` не снимается).
6. **Язык**: спеки/proposal в репо — русские, ключевые слова Requirement/Scenario/WHEN/THEN — английские; store — только английский.
7. **Нумерация — двойная**: id change = сквозной `tz-NNN` (следующий №85); YouTrack-id — в proposal.md.
8. **patch49** (грязные +129/−61): закоммитить как есть — формат легаси и замораживается; **коммитит Даниил** (агенты не коммитят).
9. **repo-auditor** → `templates/agents/` кита + kit_manifest (для всех профилей).
10. **Отдельный грилл (следующий)**: дедупликация `/patch-review` ↔ `plan-griller` ↔ opsx-команды openspec ↔ `feature-flow`, со сверкой текстов; там же — когда install.sh перестаёт копировать `database-reviewer` (дубль с плагином code-conventions, C2 из §6).

## 2. Спец-код в sdd-kit

### 2.1 Багфиксы kit (фаза 0, независимо от миграции)

| # | Баг | Файл | Фикс |
|---|---|---|---|
| B1 | `wc -l` по `.spec-guard-paths` считает комментарии → ложное «guard enabled» | `templates/sdd-doctor.sh:~100` | strip `#`-строк (как `spec-guard.cjs:33`) |
| B2 | living-spec-фрагмент pre-commit не стрипает `#`-строки | `templates/living-spec-check.sh` | тот же strip |
| B3 | `SDD_REVIEW_BASE ?= dev`, у CF default branch `main` | `templates/Makefile.sdd` | автоопределение `origin/HEAD` в самом Makefile, fallback `dev` (без профильной переменной — Makefile.sdd байт-сравнивается при `--refresh`, подстановка сломала бы сравнение) |
| B4 | `install.sh:337` пропускает `openspec init` при существующих, но пустых dirs | `install.sh` | директория с 0 файлов = отсутствующая |

### 2.2 Профиль `profiles/conversation_flow.env`

```
PROFILE_SPEC_GUARD_PATHS="engine/ api/ livekit_agent/ storage/ webhooks/ recording/ ttscache/ analytics/ reports/ rag/ monitoring/ copilot/ editor/src/ migrations/versions/"   # включается фазой 5
PROFILE_LIVING_SPEC=1        # постоянно (решение 5)
PROFILE_REVIEW_BASE=main     # новое (B3)
PROFILE_ENV_FILES=".env"
```

### 2.3 Payload `profiles/conversation_flow/`

- **Полный слепок сконвертированных спек** `openspec/specs/**` + архив `openspec/changes/archive/tz-0NN-*/` (результат фазы 3) — seed при install, только для этого репо.
- `openspec/config.yaml` — с `references: [cybernet-specs]` и context-блоком.
- `AGENTS.md` — канонический ≤500 строк (карта модулей, команды, инварианты).
- `.claude/skills/tz/SKILL.md` — наследник `/patch`: recon-before-text, §0-позиция, «проверить перед реализацией», 11 инвариантов платформы; артефакт = `openspec/changes/tz-NNN-<slug>/` (proposal.md, spec-дельты `## ADDED/MODIFIED Requirements` + Scenario, tasks.md = критерии приёмки). Русский.
- `.claude/skills/tz-implement/SKILL.md` — наследник `/patch-implement`: фаза 0 reconcile + «код важнее спеки» STOP; фаза 1 план + STOP-гейт; логичные коммиты «ТЗ №NN §M», `make test` после каждого; **фаза 3: правится openspec-спека (канон), затем агент генерирует из дельты обновление § DOCUMENTATION.md + §17 + версия — в тех же коммитах**; замеры latency; не пушить.
- `.claude/skills/tz-review/SKILL.md` — тонкий наследник `/patch-review` (ADR-0020): механический аудит change-документа — формат, facts-vs-code грепом, brand-lint, номер, вердикт `готово к реализации`/`требует правок`; документ не правит; бежит **перед** plan-griller. НЕ дубль гриллера (тот — допрос с записью `## Grill`).
- `.claude/agents/repo-auditor.md` — переезжает в `templates/agents/` (решение 9), в payload не нужен.

### 2.4 Конвертеры (`sdd-kit/tools/cf/`, ручной запуск, не гейты)

- `mine-section.md` — промпт для sonnet-агента: § DOCUMENTATION.md → `openspec/specs/<capability>/spec.md` (рерайт в Requirement/Scenario — в исходнике 0 MUST; вход: § + карта тестов + §14-аннотации → `enforced:` якоря).
- `verify-section.md` — промпт верификации capability против кода (протокол STORE_VERIFICATION): каждое Requirement подтверждено чтением кода, расхождения — в `DEFECTS_CF.md`.
- `patch2change.md` — промпт конвертации patchNN → `changes/archive/tz-0NN-*/` (proposal.md из ТЗ + ссылка на оригинал, tasks.md из критериев приёмки). Механика, sonnet.
- `anchors-from-tests.py` — из `tests/README.md` + `test_patchNN.py` + 195 путей в DOCUMENTATION.md собирает черновые `enforced:` якоря по capability.

## 3. Разбивка на capabilities (~20)

`flow-schema` (§3/5/6), `flow-execution` (§4), `voice-pipeline` (§8.1–8.4, 8.15), `telephony` (§8.5, 8.9–8.10, 11.3a), `call-control` (§8.6, 8.8, 8.13, 8.22), `recording` (§8.7, 11.5), `tts` (§8.11–8.12, 8.14), `asr` (§8.20), `observers` (§8.16–8.18), `mcp` (§8.19), `cost-analytics` (§8.21, 11.10), `editor-ui` (§9, 11.2.2), `copilot` (§10), `persistence-versioning` (§11.1–11.2), `webhooks` (§11.4), `monitoring` (§11.6), `tenancy-auth` (§11.7–11.8), `rag` (§11.9), `timezones` (§11.11), `public-api-v1` (§13.3e + integration-guide, сверка со store-контрактом).

## 4. Фазы

### Фаза 0 — kit-багфиксы и гигиена (~полдня) — **ВЫПОЛНЕНА 2026-08-03, не закоммичена**
B1–B4 ✅; `repo-auditor` → `templates/agents/` + kit_manifest ✅; кэши вычищены ✅; сверх плана — P0-2 (planner получил Write/Edit), P0-3 (plan-griller переписан в one-shot, 48 строк), P0-1-пин (`$OPENSPEC` больше не падает на глобальный непиненный бинарь — всегда `npx -y @fission-ai/openspec@1.7.0`). Локальные проверки зелёные (bash -n, node --check, py_compile); закоммитить + прогнать self-CI (bootstrap-smoke) — Даниил.

### Фаза 1 — фундамент в conversation_flow (~полдня) — **ВЫПОЛНЕНА 2026-08-03, не закоммичена**
1. ✅ patch49: diff проверен — все 21 «изменение» это перенос строк (IDE-переформат), семантика не тронута; коммитить как есть безопасно.
2. ✅ `openspec init` на пиненном 1.7.0 (config.yaml создан; store `references:` — в фазе 2). По ADR-0020 п.8: `commands/opsx/` удалены, 6 openspec-скиллов проштампованы `disable-model-invocation: true`.
3. ✅ Kit-дроп готов к коммиту (коммитит Даниил); по P0-7 из CF удалены мёртвые `feature-flow`/`incident-flow` (оговорка: `--refresh` их вернёт, пока не сделано профильное гейтирование манифеста — P0-4); копии planner/plan-griller в CF синхронизированы с починенными шаблонами фазы 0.
4. ✅ AGENTS.md канонический 246 строк (всё содержимое старых файлов сохранено), `CLAUDE.md` → симлинк, USA v4 → `docs/DEPLOY_USA.md` (311 строк, дословно). `make sdd-check` зелёный и не вакуумный (config.yaml существует; specs/ наполнится в фазе 3).
Сверх плана: `planner.md`/`feature-flow` кита перенацелены с удалённого `commands/opsx/propose.md` на `skills/openspec-propose/SKILL.md`.

### Фаза 2 — кросс-репо контракты в store (~1 день) — **ВЫПОЛНЕНА 2026-08-03, не закоммичена**
По ADR-0018: два change в cybernet-specs готовы, `validate --all --strict` = 10 passed / 0 failed. PR + ревью владельцев + apply (перенос в specs/, обновление SOURCES.md/README) — Даниил/владельцы.
- ✅ `add-cf-dialer-integration-api` — 26 Requirements / 81 Scenarios, якоря сверены с кодом; **12 расхождений записано** (топ: webhook `call.status` = `ended|active` против REST `queued|ringing|ongoing|ended|failed` — одно имя поля, два словаря; «must be HTTPS» из гайда не энфорсится — `allow_http` no-op; 5 недокументированных полей объекта звонка).
- ✅ `add-cf-rag-contract` — 13 Requirements / 30 Scenarios; **13 расхождений записано** (топ: лимиты SearchRequest не энфорсятся → 422 без ретрая и RAG молча выключен; деградация ловит только RagError, ValidationError парсинга роняет тёрн; литеральный адрес в §11.9; расхождение имён S3-бакета).
- ✅ В CF — `references: cybernet-specs` в config.yaml (формат как у WBN), `sdd-check` зелёный. Обновление SOURCES.md/README-таблицы — задачи в tasks.md обоих changes (на apply-этапе, с пересчётом итогов из-за параллельности).

### Фаза 3 — полная конвертация (главная фаза, ~2–3 недели, sonnet-агенты волнами)
Для каждой capability: `mine-section` → `verify-section` (полная сверка с кодом) → `id:`/`enforced:` метаданные (ADR-0017) → `openspec validate --strict` + `spec-lint` чистый. Расхождения — в `DEFECTS_CF.md` (тикет-материал, поведение не «чинится» молча).
Порядок волн (по нормативности): 1) `flow-schema`, `flow-execution`; 2) `public-api-v1`, `webhooks`, `persistence-versioning`; 3) голосовой слой (§8 → 8 capabilities); 4) остальное.
Параллельно: `patch2change` по всем 83 патчам → `changes/archive/`.

**Прогресс (2026-08-03): все 20 capabilities смайнены; верифицировано 15 из 20.** Детали и остаток — [HANDOFF_CF_PHASE3.md](HANDOFF_CF_PHASE3.md).


- ✅ Волна 1: `flow-schema` 34 Req/37 Sc (верификация: 28 CONFIRMED, 0 MISMATCH кода, 5 пробелов полноты закрыты fixup'ом), `flow-execution` 23 Req/37 Sc (верификация opus: 3 MISMATCH кода + 2 завышения спеки + 8 пропусков — всё исправлено fixup'ом, дефекты E1–E5 в DEFECTS_CF.md). Оба гейта (`validate --all --strict`, spec-lint strict) зелёные. Конвейер: майнер(sonnet) → верификатор(скептик) → fixup(sonnet) — работает, верификатор обязателен: оба майнера заявляли «расхождений нет».
- ✅ Архив: все 83 патча + 4 безномерных → 87 `openspec/changes/archive/tz-*` (proposal.md + tasks.md, оригиналы не тронуты). Аномалии в отчётах партий (у ТЗ №45/46 тестов нет вовсе).
- 🔄 Волна 2 запущена: майнеры `public-api-v1` (со сверкой против store-контракта), `webhooks`, `persistence-versioning`.
По завершении: слепок `openspec/**` копируется в `profiles/conversation_flow/` (решение 2); в DOCUMENTATION.md шапку — строка «канон поведения — openspec/specs/, документ ведётся параллельно (ADR-0019)»; `docs/patches/README.md` — «архив закрыт на №84, новые ТЗ — openspec/changes/».

**Промежуточная реализация слепка (проверена агентом-верификатором 2026-08-03, до payload-копии по решению 2 выше): git-ref-сид.**
`profiles/conversation_flow.env` → `PROFILE_OPENSPEC_SEED_REF=test-sdd-kit`; `install.sh` (~строки 172, 334–349) при пустом/отсутствующем `openspec/` (B4: 0 файлов = отсутствует) резолвит `origin/$REF`, затем `$REF`, и при первом найденном делает `git checkout <ref> -- openspec` вместо `openspec init`. Мотив — DRY: не держать в ките второй экземпляр 195 файлов/412 Requirements, которые меняются на каждом ТЗ и гарантированно разойдутся со слепком при дублировании.
Проверено прогоном в песочнице (не в рабочем репо): полный клон + чекаут `main` восстанавливает все 195 файлов из `origin/test-sdd-kit` корректно. Но условие работоспособности — **ветка `test-sdd-kit` должна физически существовать и быть достижимой из клона, в котором запускается install.sh**. Два реалистичных сценария этому противоречат и оба проверены в песочнице:
- shallow single-branch clone (`git clone --depth 1 --branch main`, как делает `actions/checkout@v4` по умолчанию) не тянет `test-sdd-kit` вообще — сид не находится;
- если фиче-ветку смержат и удалят (обычный конец жизни ветки) — `origin/test-sdd-kit` пропадает из fetch-рефов при следующем `git fetch --prune`.
В обоих случаях падение не громкое: код печатает `WARN: openspec seed ref ... falling back to init` в stderr и **продолжает работу**, вызывая `openspec init --tools claude` — репозиторий получает пустой валидный skeleton вместо 412 Requirements, установка завершается успешно (exit 0), а `openspec validate --all --strict` на пустом `openspec/` тривиально проходит. Риск не в самом коде (он написан аккуратно и предупреждает), а в том, что этот механизм противоречит явному тексту решения 2 ADR-0019 («install копирует его [слепок] только при отсутствии в репо» — про копию из кита, не про `git checkout` из ветки целевого репо) и в том, что предупреждение легко потерять в логе однократного install-прогона. См. открытый вопрос Даниилу в [HANDOFF_CF_PHASE3.md](HANDOFF_CF_PHASE3.md#открытые-вопросы-даниилу).

### Фаза 4 — cutover процесса и пилот
1. Установить payload-скиллы `tz`/`tz-implement`; старую трилогию пометить deprecated (удаление — после пилота и грилла по дедупликации).
2. **Пилот — реальное следующее ТЗ №85** полным циклом: tz → plan-griller → test-author → tz-implement (включая агент-генерацию обновления DOCUMENTATION.md) → review → archive. Friction-лог в `sdd-kit/docs/DRYRUN_CF.md`. Критерий выхода: цикл без ручных обходов, `make test` зелёный, спека и DOCUMENTATION.md обновлены синхронно.

### Фаза 5 — enforcement (~час, после пилота)
Включить `PROFILE_SPEC_GUARD_PATHS` (14 префиксов); `SPEC_LINT_STRICT=1` для CF после стабилизации спек. Living-spec-warn остаётся (решение 5).

## 5. Что берём из code-conventions в sdd-kit

| # | Что | Действие | Статус |
|---|---|---|---|
| C1 | Zero-click подключение плагина | `install.sh` дописывает `extraKnownMarketplaces` + `enabledPlugins: code-conventions@cybernet` (y/N) | в работу (закрывает шаг 4 PORT-плана) |
| C2 | Дедупликация ревьюеров (`database-reviewer`) | сначала слияние (канон — кит, у плагинной копии забрать Write/Edit); кит перестаёт копировать только когда плагин станет обязательным | решено (ADR-0020) |
| C3 | Drift-check | CI-джоб в sdd-kit: diff с копиями плагина `feature-flow`/`database-reviewer` + 5 общих блоков по маркерам заголовков, WARN; внутри кита — equality-проверка 70 общих строк ревьюеров в `--refresh` | решено (ADR-0020), в работу |
| C4 | rtk-конфликт | `setup-dev.sh` пропускает curl-установку rtk при обнаруженном `rtk-plugin` | в работу |
| C5 | gherkin-spec | не берём (второй спец-диалект) | закрыто |
| C6 | clean-code / gof / project-structure / KB | не берём (сессионный слой, закрывается C1) | закрыто |

## 6. Риски

| Риск | Митигция |
|---|---|
| Конвертация 9470 строк + 83 патча забуксует, новый процесс не стартует | волны с фиксированным порядком; пилот не блокируется хвостовыми волнами 3–4 (ядро+API достаточно для большинства ТЗ) — но по решению 4 cutover только после ПОЛНОЙ конвертации, так что дедлайн фазы 3 — управляемый риск №1 |
| Рерайт внесёт смысловой дрейф от кода | полная верификация каждой capability (решение 3), `enforced:` якоря из карты тестов, spec-lint freshness |
| Параллельное ведение двух текстов разъедется | канон назначен (openspec), обновление DOCUMENTATION.md генерирует агент из дельты в тех же коммитах, living-spec-warn ловит забытое |
| Команда продолжит писать в docs/patches | README + deprecated-пометка + spec-guard (фаза 5) требует активный change |
| `--refresh` затрёт слепок/скиллы payload | payload — repo-owned, в manifest не входит |
| Пилот покажет, что цикл медленнее патчей | friction-лог + трилогия deprecated-но-рабочая до конца пилота |

## 7. Открытые вопросы (вне этого плана)

1. ~~Грилл №2 — дедупликация команд~~ — **проведён 2026-08-03, решения в [ADR-0020](ADR/ADR-0020-dedup-commands-reviewers.md)** (tz-review добавлен в payload §2.3; C2/C3 закрыты в §5; фиксы planner/plan-griller/openspec-1.7.0 — по списку PROMPT_AUDIT_SDD_KIT.md P0).
2. Владельцы-ревьюеры store-PR фазы 2 со стороны WBN/VA.
3. Дефекты из `DEFECTS_CF.md` (появятся в фазе 3) — триаж в тикеты.
4. Работы на стороне code-conventions (решены здесь, делаются там): пересинк database-reviewer и feature-flow с кита, бэкпорт hardening-преамбулы + вердикт-формата в python/fastapi-reviewer, HIGH=Warning в python-reviewer (ADR-0020 п. 1, 3, 5, 7).
