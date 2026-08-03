# План миграции conversation_flow на sdd-kit + OpenSpec

Дата: 2026-08-03. Статус: **черновик, ждёт грилл** (grill-with-docs).
Источники: `~/cybernet/docs/sdd-kit-vs-conversation_flow.md`, `~/cybernet/docs/sdd-kit-vs-code-conventions.md`, глубокий аудит conversation_flow от 2026-08-03 (LIVING SPEC 9470 строк / v1.81.0, 83 ТЗ в `docs/patches/`, 41 405 строк тестов).
Решение пользователя: conversation_flow входит в scope sdd-kit; **спец-код под conversation_flow разрешён внутри sdd-kit** (профиль + payload + конвертеры).

---

## 0. TL;DR

Домашняя SDD-система conversation_flow структурно почти 1:1 с OpenSpec — мигрируем **конвергенцией, а не заменой**:

| Домашнее | OpenSpec / sdd-kit | Способ |
|---|---|---|
| `docs/patches/patchNN-*.md` (ТЗ) | `openspec/changes/<id>/` (proposal + delta + tasks) | новые ТЗ (№85+) сразу в новом формате; старые 83 — **не конвертируем**, остаются замороженным архивом |
| `docs/DOCUMENTATION.md` (LIVING SPEC) | `openspec/specs/<capability>/spec.md` (~20 capabilities) | майним по секциям волнами (spec-miner), секция за секцией усыхает до обзор+ссылка |
| §17 changelog | порядок `openspec/changes/archive/` | §17 замораживается на последнем «старом» ТЗ, дальше — история архива |
| `/patch` → `/patch-review` → `/patch-implement` | feature-flow + planner/plan-griller/test-author | **адаптированные скиллы в payload профиля** — сохраняем всё ценное из трилогии (recon-before-text, «код важнее спеки», STOP-гейты, 11 инвариантов платформы) |
| `tests/test_patchNN.py` | тесты со `# spec:` трейсерами по Scenario | старые не трогаем; якоря `enforced:` берём из готовой карты §14 + tests/README.md |
| `pretooluse_guard.py`, lint_brand/migrations/imports, `make test` | — | **не трогаем вообще** — у kit нет эквивалента, это сильнее `sdd-test` |
| `docs/integration-guide.md` + `cybernetrag_openapi.json` | `cybernet-specs` store | два новых контракта в store (по ADR-0018) |

Плюс: чиним 4 бага sdd-kit, найденных на этом репо, и коммитим установку (сейчас весь kit-дроп untracked = невидим для CI и команды).

---

## 1. Принципы

1. **Конвергенция, не замена.** Патч-система живая (28 из 40 последних коммитов — ТЗ), самосогласованная и в HEAD. Ломать работающий процесс ради формата — потеря. Меняем контейнер артефактов, сохраняем дисциплину.
2. **Append-only уважается.** 83 старых ТЗ не переписываются (собственное правило репо: «патчи не переписываются задним числом»). Конвертер делает только *stub-ссылки* в архив, если решим (§5, фаза 3).
3. **Ничего из "do-not-break" списка не деградирует:** `pretooluse_guard.py` (flow.gen.ts / brand / append-only миграции / demo-flow), `make test` (строже `sdd-test`), правило «код важнее спеки — STOP», замеры latency p50/p90, i18n×6 локалей, «не пушить без явной просьбы» (совпадает с MAIN RULE пользователя).
4. **Спец-код живёт в sdd-kit**, а не россыпью в репо: профиль `conversation_flow.env` + payload `profiles/conversation_flow/` + конвертеры. `--refresh` должен уметь обновлять адаптированные скиллы.
5. **Advisory-first сохраняется** (ADR-0015): гейты включаем поэтапно, сначала сигналы.

## 2. Целевая картина (после всех фаз)

- `openspec/specs/` — ~20 capabilities (разбивка из аудита): `flow-schema`, `flow-execution`, `voice-pipeline`, `telephony`, `call-control`, `recording`, `tts`, `asr`, `observers`, `mcp`, `cost-analytics`, `editor-ui`, `copilot`, `persistence-versioning`, `webhooks`, `monitoring`, `tenancy-auth`, `rag`, `timezones`, `public-api-v1`. Метаданные по ADR-0017 (`id:`/`enforced:`), якоря из §14 + карты тестов.
- `openspec/changes/` — новые ТЗ как changes с id `tz-NNN-<slug>` (сквозная нумерация продолжается: следующий №85 → `tz-085-...`).
- `docs/DOCUMENTATION.md` — остаётся, но меняет роль: архитектурный обзор (§1–2), карта проекта (§14), глоссарий (§16), операционка (§15) + на каждый вымытый § — 3–5 строк обзора и ссылка на capability-спеку. §17 заморожен. Целевой размер ≤ ~2500 строк.
- `docs/patches/` — заморожен, README дополнен «архив закрыт на ТЗ №84, дальше `openspec/changes/`».
- `cybernet-specs` — +2 контракта: `cf-dialer-integration-api` (из integration-guide.md), `cf-rag-contract` (из cybernetrag_openapi.json + §11.9). conversation_flow получает `references:` на store.
- `.spec-guard-paths` — включён обратно (14 префиксов из аудита), living-spec-фрагмент pre-commit **выключен** после фазы 4 (DoD переезжает на spec-дельты; до этого — оставляем как warn).
- `AGENTS.md` — канонический ≤500 строк (ADR-0002), `CLAUDE.md` → симлинк; инфра-блок USA v4 (260 строк) переезжает в `docs/DEPLOY_USA.md`.
- Весь kit-дроп + openspec закоммичены; `sdd-ci.yml` реально гоняется на PR.

## 3. Спец-код в sdd-kit (новое и правки)

### 3.1 Багфиксы kit (независимо от миграции — bite каждый профиль)

| # | Баг | Файл | Фикс |
|---|---|---|---|
| B1 | `wc -l` по `.spec-guard-paths` считает комментарии → ложное «guard enabled (2 paths)» | `templates/sdd-doctor.sh:~100` | strip `#`-строк перед подсчётом (как в `spec-guard.cjs:33`) |
| B2 | living-spec-фрагмент pre-commit не стрипает `#`-строки | `templates/living-spec-check.sh` | тот же strip |
| B3 | `SDD_REVIEW_BASE ?= dev`, а у CF default branch `main` → `sdd-review` диффает несуществующий ref | `templates/Makefile.sdd` | новая переменная профиля `PROFILE_REVIEW_BASE`, install.sh подставляет; fallback — автоопределение `origin/HEAD` |
| B4 | `install.sh:337` пропускает `openspec init`, если dirs существуют, даже пустые (0 файлов) → «вечно пустой openspec» | `templates/../install.sh` | считать директорию отсутствующей, если в ней 0 файлов |

### 3.2 Профиль `profiles/conversation_flow.env` (обновить)

```
PROFILE_SPEC_GUARD_PATHS="engine/ api/ livekit_agent/ storage/ webhooks/ recording/ ttscache/ analytics/ reports/ rag/ monitoring/ copilot/ editor/src/ migrations/versions/"   # раскомментировать (фаза 5)
PROFILE_LIVING_SPEC=1        # оставить до фазы 4, потом убрать
PROFILE_REVIEW_BASE=main     # новое (B3)
PROFILE_ENV_FILES=".env"
```

### 3.3 Payload `profiles/conversation_flow/` (новое)

- `AGENTS.md` — готовый канонический (карта модулей из §14, команды, инварианты, порядок чтения), по образцу payload'ов WBN/VA.
- `openspec/config.yaml` — с `references: [cybernet-specs]` и context-блоком.
- `.claude/skills/tz/SKILL.md` — **наследник `/patch`**: тот же recon-before-text, §0-позиция, «проверить перед реализацией», 11 инвариантов платформы, но артефакт = `openspec/changes/tz-NNN-<slug>/` (proposal.md с §0 и блокквотом зависимостей, spec-дельты `## ADDED/MODIFIED Requirements` + Scenario, tasks.md = критерии приёмки). Русский язык сохраняем.
- `.claude/skills/tz-implement/SKILL.md` — **наследник `/patch-implement`**: фаза 0 reconcile + «код важнее спеки» STOP, фаза 1 план+STOP-гейт, логичные коммиты «ТЗ №NN §M», `make test` после каждого, spec-дельта в тех же коммитах, замеры latency, финальный отчёт, **не пушить**. Отличия: вместо §8.x/§17 обновляются spec-дельты change; архивирование по ADR-0011/0012.
- `/patch-review` **не портируем как скилл** — его роль закрывают `plan-griller` (формат/консистентность, `## Grill` в proposal.md) + facts-vs-code блок, который добавляем в промпт грилла для этого профиля (или отдельный `tz-review` тонкой прослойкой — решить на грилле).
- `.claude/agents/repo-auditor.md` — **поднять в общие шаблоны kit** (`templates/agents/`): аддитивен, эквивалента нет, полезен всем профилям. Вопрос грилла.

### 3.4 Конвертеры (`sdd-kit/tools/cf/`, запускаются вручную, не гейты)

- `mine-section.md` — промпт-инструкция для spec-miner-прогона по одному § DOCUMENTATION.md → `openspec/specs/<capability>/spec.md` (Requirement/Scenario **пишутся заново** — в LIVING SPEC 0 MUST и нет Given/When/Then, механическая конвертация невозможна; факт из аудита). Вход: § + карта тестов + §14-аннотации → `enforced:` якоря.
- `patch2stub.py` (опционально, фаза 3) — генерирует в `openspec/changes/archive/tz-0NN-*/proposal.md` стабы-ссылки на `docs/patches/patchNN-*.md`, не трогая оригиналы. Нужен только если хотим единый архив; вопрос грилла.
- `anchors-from-tests.py` — из `tests/README.md` + имён `test_patchNN.py` + 195 путей в DOCUMENTATION.md собирает черновой список `enforced:` якорей на capability (сырьё для майнинга).

## 4. Фазы

### Фаза 0 — kit-багфиксы и гигиена (sdd-kit, ~полдня)
B1–B4 из §3.1; вычистить `templates/__pycache__/`, `templates/.ruff_cache/` + .gitignore. Прогнать self-CI (bootstrap-smoke).

### Фаза 1 — фундамент в conversation_flow (~полдня)
1. `rm -r openspec/` (пустые dirs) → `openspec init` → `config.yaml` из payload (store `references:` появится в фазе 2).
2. Закоммитить весь kit-дроп: `Makefile.sdd` + include, hooks, agents, скиллы kit, скрипты, `feature_flags.py`, `.spec-guard-paths` (пока пустой, с комментом «включается фазой 5»), `sdd-ci.yml`, `autoreview.yml`, `.claude/settings.json`, `.mcp.json`. Отдельно решить судьбу грязного `patch49-components.md` (+129/−61 — нарушение собственного append-only; **вопрос грилла**).
3. `AGENTS.md`/`CLAUDE.md`: USA v4 → `docs/DEPLOY_USA.md`; собрать канонический AGENTS.md (payload); `CLAUDE.md` → симлинк. Проверить `make sdd-check` — теперь не вакуумно.

### Фаза 2 — кросс-репо контракты в store (~1 день)
По процессу store (ADR-0018): change в cybernet-specs → PR → review владельцев.
- `cf-dialer-integration-api` — из `docs/integration-guide.md` (829 строк, EN, /v1 + webhook HMAC). Store-формат: проза + якоря `file.py:line` (ADR-0017), Provenance + отметка «response shapes authoritative here, requests — OpenAPI».
- `cf-rag-contract` — из `cybernetrag_openapi.json` + §11.9 (входящий контракт с CybernetRAG).
- Обновить `SOURCES.md` (закрывает пункт «have conversation_flow publish its /v1 call API + webhook payloads») и README-таблицу; в CF — `references:` в config.yaml.

### Фаза 3 — cutover процесса (~1 день + пилот)
1. Установить payload-скиллы `tz`/`tz-implement` (профиль, `--refresh`-ом).
2. `docs/patches/README.md`: «архив закрыт на №84; новые ТЗ — `openspec/changes/tz-NNN-*`»; старую трилогию скиллов пометить deprecated (удалить после пилота).
3. **Пилот: следующее реальное ТЗ №85 прогоняется полным новым циклом** (tz → plan-griller → test-author → tz-implement → review → archive). Friction-лог в `sdd-kit/docs/DRYRUN_CF.md` (по образцу DRYRUN_WEB2318). Критерий выхода: цикл прошёл без ручных обходов, `make test` зелёный, spec-дельта провалидирована.
4. Опционально `patch2stub.py` для единого архива.

### Фаза 4 — майнинг LIVING SPEC (волнами, ~2–4 недели фоном)
Приоритет по нормативности и риску дрейфа (из аудита):
- Волна 1: `flow-schema` (§3/5/6), `flow-execution` (§4) — ядро, самое нормативное.
- Волна 2: `public-api-v1` (§13.3e, сверка со store-контрактом), `webhooks` (§11.4), `persistence-versioning` (§11.1–11.2).
- Волна 3: голосовой слой §8 → `voice-pipeline`, `telephony`, `call-control`, `recording`, `tts`, `asr`, `observers`, `mcp` (2324 строки, режем по подсекциям).
- Волна 4: остальное (`editor-ui`, `copilot`, `cost-analytics`, `monitoring`, `tenancy-auth`, `rag`, `timezones`).

Каждая волна: spec-miner по `tools/cf/mine-section.md` → верификация против кода (протокол STORE_VERIFICATION) → `id:`/`enforced:` → соответствующий § DOCUMENTATION.md усыхает до обзор+ссылка (в том же PR). §17 не трогаем. После волны — `spec-lint` чистый.

### Фаза 5 — включение enforcement (~час, после волны 2)
Раскомментировать `PROFILE_SPEC_GUARD_PATHS` (сначала префиксы вымытых capabilities, полный список после волны 3); living-spec-фрагмент оставить warn до конца фазы 4, затем убрать `PROFILE_LIVING_SPEC`; TODO в Makefile.sdd про `SPEC_LINT_STRICT=1` — включить для CF, когда все волны пройдены.

## 5. Язык

Предложение (вопрос грилла): **репо-локальные спеки и proposal.md — по-русски** (команда, LIVING SPEC, коммиты — русские; ADR-0017 язык не фиксирует), заголовки `### Requirement:` / `#### Scenario:` / WHEN/THEN — английские ключевые слова (нужны валидатору), тело — русское. **Store-контракты — только английский** (правило cybernet-specs).

## 6. Что берём из code-conventions в sdd-kit

Из сравнения `sdd-kit-vs-code-conventions.md` — граница «kit = коммитимые файлы, plugin = сессия» остаётся. Конкретно в kit:

| # | Что | Действие | Обоснование |
|---|---|---|---|
| C1 | **Zero-click подключение плагина** | `install.sh` дописывает в `.claude/settings.json` репо `extraKnownMarketplaces` + `enabledPlugins: code-conventions@cybernet` (спросив y/N) | закрывает шаг 4 PORT-плана; CF-разработчик получает clean-code/gof/project-structure/KB-инъекцию без ручной установки |
| C2 | **Дедупликация ревьюеров** | как только C1 сделан — `install.sh` перестаёт копировать агентов, которые дублируются плагином (`database-reviewer`); `backend-reviewer`/`planner`/`plan-griller`/`test-author` остаются kit-only | убирает «двойные ревьюеры в одной сессии» (gap №2 сравнения) |
| C3 | **Drift-check** | лёгкий CI-джоб в sdd-kit: diff kit-овских `feature-flow`/`database-reviewer` против копий в code-conventions, WARN при расхождении | gap №1 сравнения (плагин от 2026-07-31 не знает ADR-0017/0018) |
| C4 | **rtk-конфликт** | решить: `setup-dev.sh` перестаёт ставить rtk через curl, если обнаружен `rtk-plugin` из marketplace (проверка + skip) | PORT §5.3, висит с 2026-07-30 |
| C5 | gherkin-spec | **не берём** | второй спец-диалект; у kit уже есть Scenario в OpenSpec-дельтах. Плагину — пометить «для не-SDD репо» (не наша сторона) |
| C6 | clean-code / gof / project-structure / KB-инъекция | **не берём в kit** | сессионный слой, закрывается C1 |

Прим.: back-port prompt-injection-guard'ов в 4 агента плагина (gap №5) — работа на стороне code-conventions, в этот план не входит.

## 7. Риски

| Риск | Митигция |
|---|---|
| Майнинг §8 (2324 стр.) забуксует, останутся «две правды» надолго | волны с приоритетом; правило «вымытый § сразу усыхает» — двух полных копий не существует ни дня; living-spec-warn держит DoD до конца |
| Команда/агенты продолжат писать в docs/patches по привычке | deprecated-пометка в трилогии скиллов + README + CLAUDE.md обновлён в фазе 3; spec-guard (фаза 5) физически требует активный change |
| Рерайт в Requirement/Scenario внесёт смысловой дрейф от кода | верификация каждой волны против кода (протокол STORE_VERIFICATION), `enforced:` якоря из карты тестов, spec-lint freshness |
| `--refresh` затрёт локальные правки payload-скиллов | payload-файлы — repo-owned после установки (как AGENTS.md); в manifest не включать |
| Пилот №85 покажет, что новый цикл медленнее патчей | friction-лог + right-to-rollback: трилогия остаётся deprecated-но-рабочей до конца пилота |

## 8. Вопросы для грилла

1. Судьба `/patch-review`: тонкий `tz-review` скилл или facts-vs-code блок внутрь plan-griller-промпта профиля?
2. `patch2stub.py`: нужен ли единый архив, или `docs/patches/` просто остаётся историей рядом?
3. Язык репо-спек: русский с англ. ключевыми словами (предложение §5) — ок?
4. `repo-auditor` — поднимать в общие шаблоны kit для всех профилей?
5. Грязный `patch49-components.md` (+129/−61): закоммитить как есть с новым номером-коррекцией (по собственному правилу репо) или откатить?
6. Нумерация: продолжаем сквозную `tz-085…` или переходим на YouTrack-id (у CF тикеты не в YouTrack-флоу WEB-*)?
7. Целевой размер DOCUMENTATION.md после миграции (~2500 строк с §17 или §17 тоже выносим в архив-файл)?
8. C2 (перестать копировать `database-reviewer`): не рано ли, пока плагин не стал обязательным для всей команды?
9. Кто владелец store-PR'ов фазы 2 со стороны потребителей (WBN/VA ревьюеры)?
10. Пилот №85: ждём реальное ТЗ или берём что-то из DEFECTS_BACKLOG (65 находок) как синтетический прогон?
