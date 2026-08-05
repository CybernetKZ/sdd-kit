# Аудит 2026-08-05: корень + инсталлеры (агент 1/5, opus)

Зона: install.sh, uninstall.sh, README.md, WORKFLOW.md, QA-SDD-PROCESS.md,
BRIEF-CONCEPT.md, LICENSE, .gitignore, .github/workflows/ci.yml,
.claude/settings.local.json. Контекст: сверка после ADR-0026.

## Сводная таблица

| Файл | Вердикт | Что не так | Рекомендация |
|---|---|---|---|
| `install.sh` (1126 стр.) | **ISSUE** | Фантомный маркер `sdd-check` (стр. 782) — в `templates/pre-commit-hook.sh` такой строки НЕТ → ложный WARN при каждом повторном install. `repo_section()` = 392 строки. Нумерация секций дырявая: `5a`, `6b` (нет 6/6a), `8b` (нет 8a). `--help` = `sed -n '2,34p'`, а хедер разросся до 40 строк → справка обрезана. kit_manifest ✅ все 32 источника существуют | Заменить grep на `scripts/sdd/check.sh`; вынести шаги 1–2 (youtrack) и 4 (openspec seed) в функции; перенумеровать; заменить magic-range в `--help` на маркер |
| `uninstall.sh` (264) | **ISSUE** | Списки агентов/скиллов/скриптов (стр. 115–158) и пустых каталогов (254–258) — **хардкод-дубль `kit_manifest`** в 3 местах. Тот же фантомный `sdd-check` (204). `rm -f .spec-guard-paths && say "removed"` (183) врёт при отсутствии файла и нарушает заявленное правило «удаляем только байт-идентичное». `$OPENSPEC` в `unregister_store` (43) объявлен позже определения — работает только по порядку вызовов | Подключить `kit_manifest` из install.sh вместо трёх списков; починить `sdd-check`; обернуть `.spec-guard-paths`/`expected-env` в проверку существования |
| `README.md` (392) | **ISSUE** | Стр. 53–55: «settings.json is compared, never written… WARN and merge by hand» — **устарело**, `merge_settings_hooks()` пишет аддитивно. Стр. 111–112: у store «strict-validate **CI** gate» — теперь pre-commit (ADR-0026 §5). Стр. 141–142: «LIVING SPEC pre-commit fragment» — выпилен. Стр. 79 vs 208: пин «в 3 местах» vs «в четырёх» (реально 5 помеченных + 2 непомеченных в агентах). Стр. 332–337, 357–361: «enforcement lives in hooks + **CI gates**», «даже CI-половина advisory» — CI нет вовсе. Layout не упоминает `.github/workflows/` | Прогнать раздел за разделом под ADR-0026; записать точное число пинов; удалить абзацы про advisory-CI |
| `WORKFLOW.md` (321) | **ISSUE** | Стр. 192: `spec-miner` в таблице «где живут части» — в `templates/agents/` его НЕТ (README:143 прямо говорит «kit does not ship a spec-miner»). Стр. 221: `repo-audit` «exists» — переименован в `repo-auditor` / audit-секцию sdd-doctor. Остальное (scripts/sdd, no-CI, флаги) — сверено с ADR-0026 ✅ | Пометить spec-miner как machine-level (`~/.claude/agents/`), не kit-installed; заменить `repo-audit` на актуальные имена |
| `QA-SDD-PROCESS.md` (219) | **ISSUE** | Стр. 117–123: трейсер `# openspec: <change> / Requirement: / Scenario:` — канон в `test-author.md:35`, `feature-flow` §3 и README:187 другой: `# spec: <requirement-id> / <scenario>`. А этот файл объявлен каноном фазы 3 (WORKFLOW:187) | Привести формат к `# spec: <req-id> / <scenario>` |
| `BRIEF-CONCEPT.md` (76) | **OK** | «Битые» ссылки (`templates/living-spec-check.sh`, `docs/patches`) — намеренная история, шапка это фиксирует | Оставить как есть |
| `LICENSE` (18) | ISSUE (мелочь) | `Copyright (c) 2026 owner` — незаполненный плейсхолдер в юридическом файле | Подставить юрлицо |
| `.gitignore` (5) | ISSUE (мелочь) | Нет `.claude/settings.local.json` — сейчас скрыт только личным `~/.config/git/ignore`; у другого разработчика попадёт в коммит. `templates/.ruff_cache/` валяется мусором внутри дерева шаблонов | Добавить строку; удалить каталог |
| `.github/workflows/ci.yml` (96) | **ISSUE** | Существует при доктрине «CI без исключений» (ADR-0026 §5). По содержанию легитимен (self-test кита, не устанавливается в репо), но **нигде не задокументирован** → читается как нарушение ADR. Плюс `templates/*.yml` в YAML-шаге больше не матчит ничего. Не закоммичен | Одна строка в README Layout + строка в WORKFLOW Status («CI кита ≠ CI в целевом репо»); закоммитить; убрать мёртвый glob |
| `.claude/settings.local.json` (5) | ISSUE (мелочь) | `enabledMcpjsonServers: ["searxng"]`, но `.mcp.json` в репо нет → запись ни на что не влияет | Удалить файл или добавить в `.gitignore` |

## Топ-5 находок

1. **Фантомный маркер `sdd-check` — install.sh:782, uninstall.sh:204.** `grep -c 'sdd-check' templates/pre-commit-hook.sh` = 0 (в шаблоне только `scripts/sdd/check.sh`). Следствия: повторный install печатает ложное WARN при полностью корректном хуке; uninstall не распознаёт хук, сшитый вручную. CI это не ловит. Регресс переименования ADR-0026 §3.
2. **README:53–55 противоречит install.sh:344–443.** README утверждает «is compared, never written», фактически `merge_settings_hooks()` пишет файл и на install, и на `--refresh`.
3. **uninstall.sh — тройной хардкод-дубль `kit_manifest`.** Любой новый шаблон устанавливается, но не удаляется.
4. **Пласт устаревшего ADR-0026-текста в README** (store CI gate, LIVING SPEC fragment, advisory-CI, счётчик пинов) + WORKFLOW (spec-miner, repo-audit). Пины реально: 5 помеченных `# openspec-pin` + 2 непомеченных `1.7.0` в `planner.md:26`, `plan-griller.md:43`.
5. **QA-SDD-PROCESS.md:120 — расхождение формата трейсера** с каноном `# spec: <req-id> / <scenario>`.

## Прочее (низкий приоритет)

- Политика пина непоследовательна: install.sh запрещает глобальный `openspec`, а `uninstall.sh:106` и `sdd-doctor.sh:248` предпочитают его.
- `assemble_pre_commit()` после ADR-0026 §4 — просто `cp`+`chmod`; абстракция от снесённого сплайса. `refresh_settings_hooks()` — 3-строчный шим.
- Локальные переменные без `local` в `repo_section`: `AGENTS_LINES`, `CLAUDE_LINES`, `BEHIND_COUNT`, `CHANGE_CANDIDATES`, `cname`, `tzid`.
- Мёртвых функций/переменных в install.sh нет — все 19 функций вызываются.
