https://support.cyber-net.ai/issue/Web-2305/Analiz-i-vybor-aktualnoj-SDDAI-arhitektury-dlya-proekta-v4

# Анализ и выбор актуальной SDD+AI архитектуры для проекта v4

Анализ и выбор актуальной SDD+AI архитектуры для проекта v4 в рамках миграции

Выбрать и стандартизировать процесс написания кода ИИ-агентами (SDD-стек) для команд
CybernetAI, чтобы кратно ускорить работу над проектом. Стандарт должен пережить
предстоящие рефакторинги: миграцию на HubTalk-архитектуру, отказ от Asterisk,
появление новых сервисов.

**ответ:** **рекомендуемый стек из слоёв**

- OpenSpec в каждом репозитории (WBN, VA, etc) (delta-спеки + `openspec validate --all --strict --json` в CI)
- контекст/карта:  **AGENTS.md/CLAUDE.md**, не длиннее 500 строк. GSD map-codebase. **ecc:spec-miner**.
- контракты (redis, api, etc) в общем отдельном репозитории (OpenSpec)
- обязательные hooks (ruff, pylint, etc) для commits
- обязательный `make test` при открытии PR (CI)
- автоматическое ревью агентами - python/fastapi/database-ревьюеры (ECC/superpowers/cc-sdd/etc),
- спецификации из кода добывает spec-miner.

**Были рассмотрены:**

1. OpenSpec v1.6.0 - единственный подходящий. и единственный,
   кто даёт CI-гейт одной строкой. слабости - нет ревью, нет contract-тестов,
   нет майнинга спек, stores в бете. всё это закрывается
   другими слоями стека.
2. GSD v1.28.0 (`gsd-core`)
3. ECC v2.0.0
4. spec-kit v0.14.3.dev0
5. BMAD-METHOD v6.10.0
6. cc-sdd 3.0.2
7. superpowers v6.2.0
8. Ralph Loop - техника автономного цикла, не SDD-слой; без файлов-результатов и гейтов
9. Zencoder/Zenflow - платно/проприетарная лицензия
10. Kilo Code - агентная IDE-платформа
11. Conductor - agent runner, macOS-only, не SDD
12. PromptX - контекст-платформа через MCP, не SDD-метод; возможный кандидат слоя 2 в будущем
13. MUSUBI - ~57 звёзд, коммитов нет с 2026-01 - заглох
14. MoAI-ADK - emerging, Claude-only, self-reported бенчмарки, 1.1k start
15. Frame - Electron GUI-среда, 318 stars
16. GRACE - соло-мейнтейнер, результаты в XML
17. GAAI - Elastic License 2.0 не open source
18. Smart Ralph - соло-мейнтейнер, ~2 коммита за 5 месяцев
19. spec-kitty
20. Kiro - платно/проприетарная лицензия
21. Tessl - платно/проприетарная лицензия
    22.Traycer - платно/проприетарная лицензия
23. Cursor + rules - платно/проприетарная лицензия

[SDD_EVALUATION.md](SDD_EVALUATION.md)
[TASK_SDD_SELECTION.md](TASK_SDD_SELECTION.md)
[LOGIC_VERIFICATION.md](archive/LOGIC_VERIFICATION.md)
[recommendations.md](archive/recommendations.md)
[INIT.md](INIT.md)
[Spec-Driven-Development-Tools.md](archive/Spec-Driven-Development-Tools.md)
[OUR_PATTERNS.md](OUR_PATTERNS.md)
