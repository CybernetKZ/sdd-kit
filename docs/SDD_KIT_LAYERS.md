# SDD-Kit: послойная карта и план упрощения

> Дата: 2026-07-31. Полный разбор того, что kit устанавливает, запускает и принуждает —
> послойно, с матрицей дублирования и ранжированным планом упрощения.
> Источник: аудит 5 параллельными агентами (bootstrap / hooks / gates+CI / prompts / flags+docs).

---

## Слой 0. Установка

### bootstrap.sh (361 строка, идемпотентный: never-overwrite через `put()`)

Последовательность в целевом репо:

1. **Профиль** — читает `profiles/<repo>.env`. Ветка `PROFILE_IS_STORE=1` (только cybernet-specs): регистрирует репо как store, кладёт `store-ci.yml` и **выходит**.
2. **Зависимости** — git, node/npx; openspec CLI (глобальный → предложение установить → fallback `npx -y @fission-ai/openspec@1.7.0`); uv для youtrack-mcp.
3. **youtrack-mcp** — ищет/клонирует `tonyzorin/youtrack-mcp`, интерактивно запрашивает токен → пишет в `<yt-dir>/.env` (chmod 600, в репо не попадает).
4. **Контекст агентов** — `CLAUDE.md` → `AGENTS.md` (git mv) + симлинк обратно; `openspec init --tools claude`; при `PROFILE_STORE=1` подключает центральный store (`references: cybernet-specs` в config.yaml).
5. **Файлы в целевой репо**:

| Куда | Что |
|---|---|
| `AGENTS.md` + `CLAUDE.md` (symlink) | контекст агентов |
| `Makefile.sdd` + `-include` в Makefile | цели sdd-check/flags/review/audit/doctor |
| `.github/workflows/` | `sdd-ci.yml`, `autoreview.yml` |
| `ruff.toml` | если нет своего и не `PROFILE_SKIP_PY` |
| `.claude/hooks/` | `block-no-verify.js`, `format-py.js`, `pre-compact.js`, `spec-guard.js` (не-LIVING-SPEC) |
| `.claude/settings.json` | `settings.json` или `settings-living-spec.json` |
| `.claude/scripts/` | `spec-lint.py`, `repo-audit.sh`, `sdd-doctor.sh` |
| `.claude/agents/` | 6 агентов (4 ревьюера + planner + plan-griller) |
| `.claude/skills/` | feature-flow, incident-flow |
| `.spec-guard-paths` | из `PROFILE_SPEC_GUARD_PATHS` |
| `.claude/expected-env` | из `PROFILE_ENV_FILES` (только WBN) |
| `.git/hooks/pre-commit` | `pre-commit-hook.sh` (+ LIVING-SPEC-вставка python-хередоком) |
| `.mcp.json` | context7 + youtrack |

6. **Финал** — advisory-прогон `repo-audit.sh` и `sdd-doctor.sh` (`|| true`), список ручных шагов.

**Что bootstrap НЕ ставит**: `feature_flags.py` (копируется вручную «when first needed») и `QA-SDD-PROCESS.md` (на который ссылаются агенты и скиллы — висячая ссылка в целевом репо).

### setup-dev.sh (machine-level, репо не трогает)

- CORE (default-yes): ponytail, rtk (`curl|sh` + глобальный hook), graphify, ast-grep.
  (headroom выпилен - ADR-0014.)
- OPTIONAL (opt-in): gh-axi, chrome-devtools-axi, serena.

### Матрица профилей (только реально различающееся)

| Переменная | conv_flow | cyb3.0 | cyb-specs | va-ctor | va-postcall | WBN | WFN |
|---|---|---|---|---|---|---|---|
| `PROFILE_IS_STORE` | — | — | **1** | — | — | — | — |
| `PROFILE_STORE` | 1 | 1 | — | 1 | 1 | 1 | 1 |
| `PROFILE_SKIP_PY` | — | — | — | — | — | — | **1** |
| `PROFILE_LIVING_SPEC` | **1** | — | — | — | — | — | — |
| `PROFILE_SPEC_GUARD_PATHS` | 9 путей | 8 | — | 7 | `app/` | 35 | `src/` |
| `PROFILE_ENV_FILES` | — | — | — | — | — | **8 путей** | — |

`PROFILE_STORE=1` — **константа во всех прикладных профилях** (фактически не переменная).

### Переусложнения слоя 0

| # | Где | Что | Действие |
|---|---|---|---|
| 0.1 | bootstrap.sh:176-188 | Мёртвый шаг 2b «profile payload»: копирует `profiles/<repo>/`, таких директорий нет ни одной | Удалить (−13 строк) |
| 0.2 | все 6 app-профилей | `PROFILE_STORE=1` — константа | Сделать дефолтом в bootstrap, убрать из профилей |
| 0.3 | bootstrap.sh:75,95 + Makefile.sdd:41 | Тройной пин `openspec@1.7.0` (`# openspec-pin`, ручная синхронизация) | Вынести git-check и `OPENSPEC=` до store-ветки → один источник в bootstrap |
| 0.4 | bootstrap.sh:307-318 | python3-хередок для вставки LIVING-SPEC в pre-commit; падает `ValueError`, если в кастомном хуке нет маркера `make sdd-check` | Конкатенация шаблонов при установке; guard `grep -q` |
| 0.5 | Makefile.sdd:8-11,46 | `sdd-flags` ищет `*feature_flags.py`, которого bootstrap не кладёт → гейт всегда зелёный в свежем репо | Решить: либо `put` в bootstrap, либо явно документировать opt-in |
| 0.6 | `templates/.ruff_cache/`, `.ruff_cache/` | Кэш-мусор в git | В .gitignore + удалить |
| 0.7 | setup-dev.sh:20-35 | Два варианта `ask`/`ask_core`; `ask_core` при no-TTY молча ставит софт через `curl\|sh` | Один `ask` с параметром default |

---

## Слой 1. Claude Code hooks + settings

### Хуки

| Хук | Событие | Поведение | Блокирует? |
|---|---|---|---|
| `block-no-verify.js` | PreToolUse Bash | Regex: `--no-verify`, `core.hooksPath=`, `commit -n` в git-командах | exit 2 = блок |
| `spec-guard.js` | PreToolUse Write\|Edit | Правка файла под префиксом из `.spec-guard-paths` без активной `openspec/changes/*` → блок. Opt-in: без файла — no-op | exit 2 = блок |
| `format-py.js` | PostToolUse Write\|Edit | `ruff format` на `*.py`, best-effort | никогда (exit 0) |
| `pre-compact.js` | PreCompact | «Пакет выживания» в `.claude/last-session-state.md`: ветка, коммит, активные changes, status, diff vs **захардкоженного `dev`** | никогда |
| `living-spec-check.sh` | фрагмент git pre-commit (LIVING SPEC) | Код из `.spec-guard-paths` staged, а `docs/DOCUMENTATION.md` — нет → WARN | нет |

### Settings: два файла ради одной строки

`settings-living-spec.json` = `settings.json` минус блок spec-guard. При этом spec-guard.js **и так самоотключается** без `.spec-guard-paths` — двойной механизм включения одной фичи.

### Переусложнения слоя 1

| # | Где | Что | Действие |
|---|---|---|---|
| 1.1 | `settings-living-spec.json` + bootstrap.sh:258-265 | Второй settings-файл + развилка; opt-in уже реализован самим spec-guard | **Удалить файл и развилку**, всегда ставить settings.json + spec-guard.js |
| 1.2 | `format-py.js` | Дублирует pre-commit-ruff (который сильнее: ещё и `check --fix`); node+ruff spawn на каждый Edit ради косметики | Удалить (или явно задокументировать как UX-дубликат) |
| 1.3 | spec-guard.js:25-32 | Walk-up поиск корня репо, хотя `CLAUDE_PROJECT_DIR` доступен (pre-compact.js так и делает) | Заменить 8 строк на 1 |
| 1.4 | pre-compact.js:41 | Хардкод ветки `dev` — в main-репо секция diff всегда `n/a` | fallback на `origin/HEAD` |
| 1.5 | block-no-verify.js | Не трогать — минимален, самодокументирован; ветки `-n`/`hooksPath` почти never-fire, но дёшевы | Оставить как есть |

---

## Слой 2. Локальные гейты (pre-commit + make sdd-check)

### pre-commit-hook.sh — каждый коммит

**Блокирует**: коммит в main/master/prod/stage (обход `SDD_ALLOW_PROTECTED=1`), новый submodule, конфликт-маркеры, файл >5MB, `breakpoint()`/`pdb`, секреты (regex-префиксы), невалидный JSON/TOML/YAML, падение `make sdd-check`.
**Warn**: коммит в dev, возраст ветки >2 дней (хардкод `origin/dev`), LIVING-SPEC-фрагмент.
**Автофикс**: ruff `check --fix` + `format` на staged `*.py` + re-stage.

### make sdd-check (Makefile.sdd:36-47) — из pre-commit И из CI

- AGENTS.md существует / ≤500 строк — **блок**; TODO — warn.
- `npx -y openspec@1.7.0 validate --all --strict` — **блок** (npx-резолв на каждый коммит без глобального openspec — медленно).
- `spec-lint.py` — **warn-only, stdout в /dev/null** — гейт-иллюзия: строка `|| exit 1` срабатывает только при краше python, а «all gates passed» печатается всегда.
- `sdd-flags` — **блок** при просроченном флаге (но реестра нет ни в одном репо → всегда OK).

### spec-lint.py

FRESHNESS (`Last verified:` vs изменения enforced-файлов) + METADATA (id/enforced у Requirements, уникальность, whitelist ключей). Exit ≠ 0 только в `--strict` / `SPEC_LINT_STRICT=1` — **нигде в ките не включён**.

### sdd-doctor.sh / repo-audit.sh — два advisory-скрипта об одном

- doctor: machine-тулы (fail при отсутствии git/node/python/uv/ruff) + repo-конфигурация (warn) + **«personal»-секция (rtk/graphify/ponytail — зона setup-dev, не репо)**.
- audit: `.mcp.json`, чужие конфиги, лишние skills/agents/plugins — всегда exit 0; `SDD_AUDIT_STRICT` не используется нигде.
- Оба проверяют `.mcp.json`, оба advisory. Кандидаты на слияние в один скрипт / один make-таргет.

---

## Слой 3. CI

### sdd-ci.yml (PR, required check — **но ещё не включён**: workflow не закоммичен в репо, branch protection выключен)

- job `sdd-check`: тот же `make sdd-check`. `make test` (линт+pytest) — TODO, не подключён → **ruff нигде не блокирует**.
- job `tbd-gates`: возраст ветки warn>2д / **fail>5д** (обход: лейбл `long-lived-ok` + «Why long-lived:» в PR); размер **fail>1500 строк** (обход: `xl-ok` + «Why XL:»). Лейбл без обоснования = fail. Единственное место, где TBD-дисциплина реально принуждается — сделано хорошо.

### store-ci.yml

`openspec validate --all --strict` — блок. Триггер `push: main` станет дублем PR-check после включения protection.

### autoreview.yml — целиком не блокирующий

- `reviewdog-ruff`: `ruff check` по **всему** репо, `-fail-level=none` — шум на brownfield, ничего не гарантирует, дублирует pre-commit-автофикс.
- `claude-review`: radon/complexipy/vulture/semgrep по изменённым .py **до** проверки секрета `CLAUDE_CODE_OAUTH_TOKEN` (без секрета — минуты CI впустую) → AI-ревью `claude -p`, промпт **дословно продублирован** в `Makefile.sdd` (`sdd-review`) — дрейф гарантирован.

### Матрица дублирования гейтов

✔ = блок, (w) = warn, ⊙ = проверка наличия/конфига. Жирным — 2+ места.

| Проверка | pre-commit | spec-guard | sdd-ci | store-ci | doctor | audit | autoreview |
|---|---|---|---|---|---|---|---|
| **openspec validate** | ✔ | | ✔ | ✔ | | | |
| **AGENTS.md есть/≤500/TODO** | ✔/✔/(w) | | ✔/✔/(w) | | ⊙(w) | | |
| **spec-lint** | (w) | | (w) | | | | |
| **sdd-flags expiry** | ✔ | | ✔ | | | | |
| **ruff** | autofix | | | | ⊙ | | (w) весь репо |
| **возраст ветки** | (w)>2д | | (w)>2д/✔>5д | | | | |
| размер PR >1500 | | | ✔ | | | | |
| **защищённые ветки** | ✔ (эхо) | | *(server protection — настоящий гейт, выключен)* | | | | |
| **секреты** | ✔ regex | | | | | | (w) semgrep |
| breakpoint/submodule/конфликты/>5MB/JSON | ✔ | | | | | | |
| код без активной change | | ✔ | | | ⊙(w) | | |
| **AI-ревью (один промпт ×2)** | | | | | | | (w) + `make sdd-review` |
| **.mcp.json** | | | | | ⊙(w) | ⊙(w) | |

Дублирование pre-commit↔CI через единый `make sdd-check` — **осознанное и правильное** (ADR-0003: CI — гейт, хуки — эхо). Проблемы — не в этом паттерне, а в: (а) spec-lint выглядит гейтом, но им не является; (б) advisory размазан на 2 скрипта + 2 канала ruff + 2 канала AI-ревью; (в) **главный гейт ADR-0003 фактически не включён** — сегодня блокирует только локальный pre-commit, обходимый `--no-verify`.

### Переусложнения слоёв 2–3

| # | Где | Что | Действие |
|---|---|---|---|
| 2.1 | Makefile.sdd:45,47 | Фиктивный `\|\| exit 1` у warn-only spec-lint + ложное «all gates passed» | Убрать `\|\| exit 1`; включить `--strict` в CI, когда specs дозреют |
| 2.2 | autoreview.yml:77-87 + Makefile.sdd:20-27 | Дословный дубль AI-промпта | Промпт в один файл; основной канал — `make sdd-review` |
| 2.3 | autoreview.yml:44-68 | Статические тулы гоняются до проверки секрета | Проверку секрета — первым шагом / `if:` на job |
| 2.4 | autoreview.yml:19-31 | reviewdog-ruff: не гейтит, шумит по всему репо | Удалить (линт-гейт должен жить в `make test` внутри sdd-ci) |
| 2.5 | doctor + audit | Два advisory-скрипта; `SDD_AUDIT_STRICT` мёртв; personal-секция не про репо | Слить в один; убрать мёртвый флаг; personal → setup-dev |
| 2.6 | pre-commit-hook.sh:20-27 | Возраст ветки: эхо CI с враньём для PR не-в-dev (хардкод `origin/dev`) | Удалить (сигнал придёт из CI) |
| 2.7 | pre-commit → sdd-check | npx-резолв openspec на каждый коммит | Гонять sdd-check только при staged-изменениях `openspec/**`, `AGENTS.md`, `feature_flags.py` |
| 2.8 | store-ci.yml:5-7 | `push: main` дублирует required PR-check | Убрать после включения protection |
| 2.9 | — | **Главный гейт не включён**: sdd-ci не закоммичен, branch protection выключен | Включить — важнее любых упрощений |

---

## Слой 4. Промпты: агенты и skills

### Агенты

| Агент | Строк | Модель | Роль |
|---|---|---|---|
| planner | 38 | opus | Пишет OpenSpec change (proposal/deltas/tasks на 1 PR) |
| plan-griller | 39 | opus | Допрашивает план до кода → `## Grill` в proposal.md |
| code-reviewer | **368** | sonnet | Общее ревью; «MUST BE USED for all changes» |
| python-reviewer | 142 | sonnet | Python-идиомы; «MUST BE USED for Python projects» |
| fastapi-reviewer | 98 | sonnet | async/DI/Pydantic |
| database-reviewer | 119 | sonnet | PostgreSQL; **единственный с Write/Edit** |

planner + plan-griller — образцовые (короткие, соответствуют ADR-0010/0012/0013). Проблемы — в ревьюерах.

### Сверка промптов: найденные несоответствия

1. **Висячие ссылки**: `QA-SDD-PROCESS.md` (planner, оба скилла) — bootstrap его не ставит; «see skill: python-patterns / postgres-patterns / database-migrations» — таких скиллов нет; `/opsx:propose` — внешний плагин, наличие не проверяется.
2. **Противоречивые вердикты**: code-reviewer блокирует только CRITICAL, python-reviewer — CRITICAL **и HIGH**. Один дифф — разный вердикт у двух «обязательных» ревьюеров.
3. **code-reviewer написан под JS/TS**: React/Next.js-секции, TS-примеры, JS-false-positives — в Python/FastAPI-ките; при этом его tool-checks гоняют ruff по `*.py`.
4. **~70% пересечение** мандатов code-reviewer и python-reviewer (SQL-инъекции, секреты, N+1, длина функций…).
5. database-reviewer: половина контента — Supabase/RLS/`auth.uid()`, нерелевантно для SQLAlchemy без Supabase; Write/Edit в tools у ревьюера.
6. Дословные дубли между 4 ревьюерами ≈90 строк: Untrusted input (×6), Spec Compliance (×4), Review discipline (×4), Tool-assisted checks (×2), формат вывода (×4).
7. Хардкод `origin/dev...HEAD` в tool-checks — ломается в main-репо.
8. feature-flow шаг 7 подаёт traceability/QA quality gate как действующие — ADR-0012 п.8 требует пометки «(planned)».
9. «Механические шаги — haiku» (ADR-0010) — фраза без механизма.

### Skills

- **feature-flow**: intake (YouTrack + кросс-чек против кода/спек) → тир light/standard/deep → planner (`/opsx:propose`) → plan-griller → QA пишет тесты ДО кода (RED) → имплементация ≤2-дневной веткой → флаги/expand-contract (шаг 4b, 30 строк = пересказ ADR-0007/0011) → ручной прогон → ревью 4 агентами → PR → handoff.
- **incident-flow** ≈ 60% копия feature-flow с фиксированным light-тиром + сбор улик/root-cause (misuse/infra = терминальный док).

### Переусложнения слоя 4

| # | Где | Что | Действие |
|---|---|---|---|
| 4.1 | 4 ревьюера | Пересечение мандатов + противоречие Block-критериев | **Схлопнуть 4 → 2**: `backend-reviewer` (python + fastapi + анти-шум блок из code-reviewer — его лучшая часть) + `database-reviewer` (вычистить Supabase, убрать Write/Edit) |
| 4.2 | все ревьюеры | ≈90 строк дословных дублей | Общие блоки → один канонический текст (вклейка при bootstrap или `_common-review.md`) |
| 4.3 | code-reviewer.md | React/Next.js/Node-секции, TS-примеры, «v1.8 AI Addendum» | Резать 368 → ~120 строк (уходит при 4.1) |
| 4.4 | оба скилла + planner | Висячие ссылки (QA-SDD-PROCESS.md, python-patterns, postgres-patterns) | Ставить файл через bootstrap или инлайнить правила |
| 4.5 | feature-flow | Шаги 5+6 слить; 4b сжать до 5 строк + ссылки на ADR; дубль описания Grill убрать (оставить в агенте); «(planned)» на несуществующие гейты | Сжать SKILL.md |
| 4.6 | incident-flow | 60% повтор feature-flow | Переписать как diff: «отличия — улики, root-cause, light» (~30 строк) |
| 4.7 | ревьюеры | Хардкод `origin/dev` | Параметризовать базовой веткой |

---

## Слой 5. Feature flags

### Как устроено сейчас (feature_flags.py, 112 строк, stdlib)

- `FlagMeta` (frozen dataclass): `owner`, `ticket`, `expires`, `spec` (кросс-репо контракт в store).
- `FLAGS: dict[str, FlagMeta]` — **пуст во всех репо** (bootstrap файл не ставит).
- `is_enabled(name)`: env `FLAG_<NAME>` ∈ {1,true,yes}; KeyError на опечатку; по умолчанию OFF везде.
- `check()`: нет expires → FAIL; просрочен ≤7 дней → WARN; >7 → FAIL; для `spec=` — regex-rglob по всем .md центрального store (store нет → WARN).
- Принуждение: `make sdd-flags` в sdd-check (pre-commit + CI); промпты (feature-flow §4b, plan-griller, planner).

### Вердикт по ценности

**Оставить (зарабатывает своё место):**
- `is_enabled()` + env — 4 строки, дёшево.
- **Гейт `expires`** — единственная настоящая ценность (dead-flag reaper; продление видно в diff).
- KeyError на опечатку.
- **Не выбрасывать флаги целиком**, пока действует FAIL>5 дней на возраст ветки: без флагов единственный клапан для эпиков — `long-lived-ok`, т.е. возврат больших батчей, против которых весь ADR-0006.

**Церемония (резать):**
- `spec=` + `_store_expires()` (строки 61-73): хрупкий regex-скан чужого репо под сценарий, который **не случился ни разу**; WARN-фолбэк делает гейт декоративным.
- `owner`/`ticket` — потребляются только print'ом в FAIL-сообщении; живут в git blame и OpenSpec change.
- Конвенция «ON в dev/stage, OFF в prod» (ADR-0011 §2) — **в коде отсутствует**; WORKFLOW/GLOSSARY/SKILL транслируют неимплементированное как факт.

**Минимальная версия (~25 строк):**
```python
FLAGS = {"widget_v2": "2026-09-01"}  # имя → expires
def is_enabled(name): ...            # как сейчас
def check(): ...                     # только expires + GRACE_DAYS
```
Кросс-репо: одинаковая дата руками в двух репо + строка в контракт-спеке; расхождение ловится на ревью change.

---

## Слой 6. Документация

### Противоречия

| # | Где | Что |
|---|---|---|
| 6.1 | ADR-0007 п.1, ADR/README:16 | Обещают «pydantic-settings» — код на plain `os.environ` (код лучше ADR; ADR не обновлён) |
| 6.2 | ADR-0011 §2 + WORKFLOW:83,117 + GLOSSARY:45 + SKILL:117,159 | «Флаг по умолчанию ON в dev/stage» — нигде не имплементировано |
| 6.3 | ADR-0006 п.2 vs README:31 | Пороги PR: «в profiles/*.env» vs «edit PR_XL_LINES in workflow» — два места истины |
| 6.4 | QA-SDD-PROCESS.md vs WORKFLOW Status | QA-SDD подаёт traceability/Schemathesis/quality-gate как действующие; WORKFLOW честно помечает planned. Плюс QA-SDD привязан к путям одного репо (WBN), лёжа в корне общего кита |
| 6.5 | lifecycle флага | Одно и то же в 8 местах (ADR-0007/0011/0013, WORKFLOW ×2, GLOSSARY, ONBOARDING, SKILL, docstring). Канон — docstring + ADR-0007, остальное — ссылки |
| 6.6 | 3 ADR о флагах (0007/0011/0013) | На систему из 112 строк с пустым реестром; при минимизации ADR-0013 §1 теряет предмет (owner-поля не будет) |

ProjectStore (ADR-0008) — чисто: ссылки уже ведут в `docs/archive/`.

---

## Сводный план упрощения (ранжирован: эффект / диффу)

### Сначала — включить то, что должно работать
1. **Включить главный гейт** (2.9): закоммитить sdd-ci.yml в репо, включить branch protection на dev. Без этого весь блокирующий слой — локальный pre-commit, обходимый `--no-verify`.

### Крупные упрощения
2. **Ревьюеры 4 → 2** (4.1–4.3): `backend-reviewer` + почищенный `database-reviewer`; −1 проход на PR, уходит противоречие вердиктов и ~250 строк промптов.
3. **feature_flags.py 112 → ~25 строк** (слой 5): dict имя→expires, `is_enabled`, `check` без store-скана. Гейт `sdd-flags` не трогать. Синхронизировать ADR-0007 (убрать pydantic), вычеркнуть конвенцию «ON в dev/stage» из ADR-0011/WORKFLOW/GLOSSARY/SKILL (или имплементировать одной строкой).
4. **Один settings.json** (1.1): удалить `settings-living-spec.json` и развилку — spec-guard и так opt-in через `.spec-guard-paths`.
5. **Слить doctor + audit** (2.5) в один advisory-скрипт; убрать `SDD_AUDIT_STRICT` и personal-секцию.

### Честность гейтов
6. **spec-lint**: убрать фиктивный `|| exit 1` и «all gates passed» (2.1); план — `--strict` в CI после стабилизации specs.
7. **AI-промпт в один файл** (2.2); удалить reviewdog-ruff (2.4); проверку секрета — первым шагом autoreview (2.3).
8. **Проставить «(planned)»** на traceability/QA quality gate в feature-flow (4.5, требование ADR-0012); статус-шапку в QA-SDD-PROCESS.md (6.4).

### Мелкая чистка
9. Удалить мёртвый шаг 2b bootstrap (0.1); `PROFILE_STORE` → дефолт (0.2); один источник openspec-пина (0.3); LIVING-SPEC-вставка без python3 (0.4); `.ruff_cache` в .gitignore (0.6).
10. Удалить `format-py.js` (1.2); spec-guard через `CLAUDE_PROJECT_DIR` (1.3); починить хардкоды `dev` (1.4, 4.7); возраст ветки из pre-commit убрать (2.6); sdd-check в pre-commit — только при изменении spec-файлов (2.7).
11. Починить висячие ссылки промптов (4.4); incident-flow как diff от feature-flow (4.6); решить судьбу установки feature_flags.py (0.5).
12. Дедуп документации lifecycle флагов до канона docstring + ADR-0007 (6.5); одно место истины для порогов PR (6.3).

### Что НЕ трогать
- `block-no-verify.js`, `planner.md`, `plan-griller.md` — образцы минимализма.
- Паттерн «один `make sdd-check`, два вызова (pre-commit + CI)» — осознанный и правильный.
- `tbd-gates` (возраст/размер PR с escape-hatch через лейбл+обоснование) — единственное настоящее принуждение TBD, сделано хорошо.
- `spec-guard.js` по сути (дёшево, opt-in, контур 2 ADR-0003) — только упростить поиск корня.
