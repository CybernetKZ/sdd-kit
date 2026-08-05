# Архив

Сырьё и завершённые разовые анализы этапа WEB-2305. Актуальные документы - в корне и в `docs/`.

- `autoreviewer.md` - разбор инструментов авто-ревью PR.
- `autoreview.yml` - CI-воркфлоу авто-ревью PR (логика: репо-агенты через headless `claude -p`).
- `Spec-Driven-Development-Tools.md` - сравнение SDD-инструментов (черновой обзор).
- `recommendations.md` - рекомендации по skills/MCP.
- `FABLE5_SESSION.md` - заметки сессии по Fable 5.
- `LOGIC_VERIFICATION.md` - разбор логической верификации, первая блокирующая находка.
- `benchmark-m1-m2/` - завершённые прогоны бенчмарка m1/m2 (протоколы, отчёты, харнесс-скрипты).
- `benchmark-sdd-kit.md` - план качественного сравнения ДО/ПОСЛЕ sdd-kit+tools.
- `research-useraise-methodology.md` - разбор методологии useraise.dev (не внедряем).
- `research-codegraph-vs-graphify-habr.md` - статья с Habr: CodeGraph vs Graphify (сравнение графовых инструментов для агентов).
- `INIT.md` - исходная методичка/постановка задачи по SDD-стеку.
- `original_description_WEB-2305.md` - исходное описание тикета WEB-2305.
- `TASK_SDD_SELECTION.md` - постановка задачи выбора SDD-архитектуры.
- `OUR_PATTERNS.md` - фаза 0: как команды реально работают, с числами.
- `SDD_EVALUATION.md` - карточки кандидатов, взвешенная матрица, shortlist.
- `WEB-2303-Hubtalk-comparison.md` - продуктовый gap-анализ HubTalk (UI/админка).
- `NEXT_STEPS.md` - дальнейшие шаги внедрения SDD-стека (WEB-2305, ADR-0001...0005).
- `ONBOARDING.md` - методичка SDD-стека CybernetAI для команды.
- `PROPOSAL_langfuse.md` - предложение по LLM-observability (Langfuse) для разбора инцидентов.
- `pre-commit-recommendations.md` - разбор конфигурации pre-commit (пример хука).
- `REPORT_TBD_PROJECTSTORE.md` - отчёт по Trunk-Based Development + feature flags и ProjectStore.
- `SDD_KIT_LAYERS.md` - послойная карта sdd-kit и план упрощения.
- `PLAN_UPDATE.md` - план обновления sdd-kit, итерация 1 (упрощение).
- `PLAN_QUALITY.md` - план качества sdd-kit, итерация 2.
- `PLAN_TEXTS.md` - ревизия текстов кита (skills/agents/prompts/tools).
- `PLAN_WIRING.md` - внедрение ADR-0023 (store фикс-путём, граф в git, CI выпилен, CF-конвергенция).
- `PLAN_CF_MIGRATION.md` - план миграции conversation_flow на sdd-kit + OpenSpec.
- `HANDOFF_CF_PHASE3.md` - handoff миграции conversation_flow, фаза 3.
- `SPEC_MINER_PILOT.md` - итоги пилота spec-miner в web-backend-new.
- `STORE_VERIFICATION.md` - сверка store-контрактов cybernet-specs с кодом.
- `DRYRUN_MANUAL_PLAN.md` - план ручного прогона sdd-kit с нуля для поиска дефектов кита.
- `DRYRUN_SUMMARY.md` - итоги ручного прогона sdd-kit M0-M5.
- `DRYRUN_WEB2318.md` - журнал фрикции ручного прогона sdd-kit на WEB-2318.
- `sdd-ci.yml` - архивный server-CI воркфлоу (retired по ADR-0023/ADR-0026, install.sh не копирует).
- `WEB-2256-review.md` - ревью коммита 3cc56e7c (WEB-2256, PCP shutdown & processing refactor).
- `PRESENTATION_PLAN.md` - план презентации перехода разработки на Spec-Driven Development.
