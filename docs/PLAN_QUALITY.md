# План качества sdd-kit (итерация 2)

> Дата: 2026-08-02. Продолжение [PLAN_UPDATE.md](PLAN_UPDATE.md) (итерация 1: упрощение, выполнена).
> Логика: гейты упрощены и честно advisory (ADR-0015) — слабое место теперь **топливо для агентов**:
> поиск по кодовой базе на intake, реальные спеки для test-author/spec-guard, единый тестовый сигнал,
> и обновляемость самого кита. Решения приняты на опросе 2026-08-02.

Прогресс: `[ ]` → `[x]`. Фаза = проверка + отдельный коммит.

---

## Фаза A. `install.sh --refresh` (первым — дальше всё раскатывается им)

Проблема: `put()` never-overwrite → каждое обновление шаблонов требует ручной докатки
(в итерации 1 — 6 агентов на раскатку + 2 ручные докатки: `.cjs`, test-author).

- [x] A.1 Манифест kit-owned файлов в install.sh (простой список): `.claude/hooks/*.cjs`,
      `.claude/agents/{backend-reviewer,database-reviewer,planner,plan-griller,test-author}.md`,
      `.claude/skills/{feature-flow,incident-flow}/SKILL.md`,
      `.claude/scripts/{spec-lint.py,sdd-doctor.sh,review-prompt.md}`,
      `Makefile.sdd`, `.github/workflows/{sdd-ci,autoreview}.yml`, `.git/hooks/pre-commit`.
- [x] A.2 Режим `install.sh --refresh [--repo-only]`: перезаписывает ТОЛЬКО манифест
      (с diff-выводом «что изменилось»); repo-specific (`AGENTS.md`, `.spec-guard-paths`,
      `feature_flags.py`, `.claude/expected-env`, `ruff.toml`, `openspec/**`, `.mcp.json`) не трогает.
      `.claude/settings.json`: сравнить блок `hooks` с шаблоном — при расхождении warn + подсказка
      (не молча перезаписывать: там могут быть добавленные хуки, как pretooluse_guard.py в conversation_flow).
      pre-commit: при `PROFILE_LIVING_SPEC=1` пересобирать с living-spec-вставкой (как при установке).
- [x] A.3 uninstall.sh: guard на unregister store — только интерактивный yes или `--force`
      (unattended = skip + подсказка). Закрывает дефект из DEFECTS_BACKLOG.
- [x] A.4 CI кита: smoke-шаг «изменить шаблон → --refresh → файл обновился, AGENTS.md не тронут».
- [x] A.5 Доки: README×2 («обновление кита = git pull + install.sh --refresh»), ONBOARDING.

**Проверка**: smoke на временном репо — refresh обновляет манифест, не трогает repo-specific,
идемпотентен (второй прогон — ноль изменений); `bash -n` + shellcheck чисто.

---

## Фаза B. `make test` — единый advisory-сигнал (ruff нигде не сигналит, pytest в CI нет)

- [x] B.1 `Makefile.sdd`: цель `test` — `ruff check .` (если есть ruff-конфиг) + `pytest -q`
      (если есть tests/ или pytest-конфиг); graceful skip с внятным echo, если нечего гонять.
      НЕ включать в `sdd-check` (pre-commit останется быстрым).
- [x] B.2 `templates/sdd-ci.yml`: отдельный job `tests` (advisory, ADR-0015 — красный виден в PR,
      не блокирует): checkout → uv → `make test`. `continue-on-error: true` НЕ ставить —
      честный красный чек, просто он не required.
- [x] B.3 Убрать TODO «make test» из sdd-ci.yml и WORKFLOW Status (пункт закрывается).
- [x] B.4 Раскатка: `install.sh --refresh` по 6 репо (первое боевое применение фазы A).

**Проверка**: в WBN `make test` гоняет ruff+pytest; в web-frontend-new — graceful skip;
job `tests` появляется в PR-чеках.

---

## Фаза C. Graphify на intake (make sdd-index + инструкция)

Правило ADR-0004 остаётся: graphify — navigation/context only, никогда не гейт (INFERred-рёбра).

- [x] C.1 `Makefile.sdd`: цель `sdd-index` — `graphify` по коду + `openspec/` + `docs/`
      (точную команду взять из `~/.agents/skills/graphify/SKILL.md`; graceful skip
      с подсказкой `install.sh --machine-only`, если graphify не установлен).
      Запуск ручной — перед крупным intake; ноль фоновых процессов.
- [x] C.2 `templates/AGENTS.md`: секция «Поиск по кодовой базе»: порядок — граф (если индекс есть) →
      grep; как построить/обновить индекс (`make sdd-index`).
- [x] C.3 `templates/skills/feature-flow/SKILL.md` шаг 1 (intake): «сверку утверждений тикета
      начинай с запроса к графу (если индекс свежий), затем grep/чтение»; одна строка + ссылка.
      То же в incident-flow (поиск по симптому).
- [x] C.4 `sdd-doctor`: info-строка «graphify index: present/absent» (не warn — опциональный инструмент).
- [x] C.5 (refresh done; индекс WBN ждёт LLM-ключа или интерактивного /graphify) Раскатка `--refresh` + построить индекс в WBN (пилот, замерить пользу на живом intake).

**Проверка**: `make sdd-index` в WBN строит индекс; в репо без graphify — skip с подсказкой;
инструкция в AGENTS.md не раздувает файл за 500 строк.

---

## Фаза D. Spec backfill: spec-miner в WBN (пилот)

test-author («1 тест на Scenario») и spec-guard бесполезны при пустых `openspec/specs/`.
Спеки — топливо; извлекаем из brownfield-кода агентом spec-miner (`~/.claude/agents/spec-miner`).

- [ ] D.1 Выбрать 2–3 ключевые capability WBN для пилота (кандидаты — самые горячие по тикетам
      направления; согласовать список перед запуском).
- [ ] D.2 Прогнать spec-miner → `openspec/specs/<capability>/spec.md` (Requirements + Invariants,
      enforced-якоря, id). Валидация: `openspec validate --strict` + spec-lint METADATA чисто.
- [ ] D.3 Ручная проверка качества: каждый Requirement измерим? Scenario пригоден test-author'у?
      (тест: дать test-author один Scenario — получится ли осмысленный RED-тест).
- [ ] D.4 По итогам пилота — решение: катить на остальные capability WBN и другие бекенд-репо,
      или сначала докрутить spec-miner. Зафиксировать выводы (короткая заметка в docs/).
- [ ] D.5 `Last verified:` проставить — spec-lint FRESHNESS начинает работать по-настоящему.

**Проверка**: `make sdd-check` в WBN зелёный со спеками; test-author на пилотном Scenario
выдаёт валидный RED-тест; spec-guard в WBN получает реальный смысл.

---

## Порядок и зависимости

```
A (--refresh) ──→ B (make test) ──→ раскатка одной командой
      │
      └─────────→ C (graphify) ──→ D (spec backfill, использует индекс для spec-miner)
```

A — первым (механизм доставки). B и C — независимы, можно параллельно. D — после C
(spec-miner выигрывает от индекса) и это работа в WBN, не в ките.

## Вне плана (зафиксировано, не делаем сейчас)

- Frontend-профиль (frontend-reviewer, TS-флаги) — бэклог, низкий приоритет (D4 гриля).
- FLAG_X=1 deploy-механизм — до первого реального флага (ADR-0015).
- conversation_flow — вне скоупа (D5 гриля).
- Активация enforcement — по решению команды (ADR-0015, фаза 1 итерации 1).
