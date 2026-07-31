нам нужно провести сравнение С и БЕЗ sdd-kit на нашем реальном репозитории и реальной задаче.

изначально мы должны 
1. проверить все глобальные (claude code, etc):
- skills
- plugins
- rules
- CLAUDE.md / AGENTS.md / etc
- другие tools влияющие на процессы работы с LLM (на примере claude code)

2. с разрешения пользователя отключить / убрать их все -> проверить
3. git clone https://github.com/CybernetKZ/web-backend-new в nude-claude И sdd-kit-claude
4. запустить /home/octrow/cybernet/sdd-kit для sdd-kit-claude/web-backend-new
5. в каждом из репозиториев nude-WBN (nude-claude/web-backend-new) и sdd-WBN (sdd-kit-claude/web-backend-new) запускаем терминал с claude code
6. найти в youtack назначенные на меня таски со статусами backlog/read_to_go (use mcp youtack)
7. уточнить какую из задач взять в работу (к примеру WEB-2334)
8. выполнить шаги docs/INIT.md:1-33
9. сравнить результаты и метрики

## метрики
Не считайте руками - Claude Code умеет отдавать почти весь L2/L3 через OpenTelemetry. Включается переменными окружения:
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_METRIC_EXPORT_INTERVAL=10000
export OTEL_RESOURCE_ATTRIBUTES="arm=sdd,task=WEB-2334,run=1"   # ключевое: тегируйте арму!

Последняя строка - самое важное для вашего кейса: OTEL_RESOURCE_ATTRIBUTES навешивается на каждую метрику и событие, так что арму/задачу/номер прогона можно потом просто отфильтровать в бэкенде. Ограничения формата строгие: только key=value через запятую, без пробелов внутри значений.

Что откуда берётся:

Что нужно	Источник
Токены по типам	метрика claude_code.token.usage, атрибут type = input / output / cacheRead / cacheCreation
Деньги	claude_code.cost.usage (USD); на событии api_request есть cost_usd и cost_usd_micros
Токены/латентность на запрос	событие claude_code.api_request: input_tokens, output_tokens, cache_read_tokens, cache_creation_tokens, duration_ms
Число человеческих turn'ов	события claude_code.user_prompt (есть prompt_length)
Отклонённые правки	claude_code.code_edit_tool.decision, атрибут decision = accept/reject, плюс source
Tool call'ы, их длительность и объём вывода	claude_code.tool_result: tool_name, duration_ms, success, tool_input_size_bytes, tool_result_size_bytes
Давление на контекст	claude_code.compaction: trigger (auto/manual), pre_tokens, post_tokens
Строки кода	claude_code.lines_of_code.count, атрибут type = added/removed
Активное время (без idle)	claude_code.active_time.total, атрибут type = user / cli
Ошибки и retry	claude_code.api_error, claude_code.api_retries_exhausted (total_attempts)
Реально ли сработал sdd-kit	claude_code.skill_activated: skill.name, invocation_trigger (user-slash / claude-proactive), skill.source

Последняя строка - отдельно подчёркиваю. Типичный провал такого рода инструментов: скилл установлен, но ни разу не активируется сам (именно на этом развалился Ponytail в независимом тесте JetBrains). Через skill_activated вы это увидите сразу, а не будете сравнивать арму B с ней же самой.
Если нужна максимальная гранулярность - есть beta-трейсинг (CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1 + OTEL_TRACES_EXPORTER), который даёт дерево спанов interaction -> llm_request -> tool с ttft_ms и токенами на каждый запрос.
Для верификации: после запуска проверьте, что в бэкенд пришла метрика claude_code.session.count; если нет - claude --debug покажет ошибки экспорта. Учтите, что цифры стоимости - приблизительные (для точного биллинга - консоль).
Транскрипты сессий лежат в ~/.claude/projects/*/*.jsonl и их можно парсить как fallback, но формат внутренний и меняется между версиями - не строить на нём основной пайплайн.

0. какая модель
1. Task success - Прошёл acceptance criteria из тикета: да/нет + градация (0/0.5/1)
2. Human interventions - Сколько раз человек вмешался и перенаправил. Лучший единичный прокси реальной пользы
3. Rejected edits - Сколько правок вы отклонили (снимается автоматически)
4. Time-to-mergeable - До состояния PR, который вы бы реально влили
5. Review rounds - Число циклов ревью до approve
6. token input (uncached) / модель  / модель 
7. token output / модель 
8. token cacheCreation / модель 
9. token cacheRead / модель 
10. Cache hit rate = cacheRead / (input + cacheRead) / модель 
11. Число turn'ов агента  / модель 
12. число tool call'ов / модель 
13. Разбивка tool call'ов: Read / Grep / Glob / Edit / Bash / модель 
14. Отношение "прочитано файлов : изменено файлов"
15. Число компактификаций и pre/post токены
16. Пиковое заполнение окна
17. Число тупиковых ветвей (агент пошёл не туда и откатился)
18. Ошибки API / retries - иначе спишете чужую latency на арму
19. Wall-clock - самая шумная метрика, зависит от загрузки API и времени суток. Держите как справочную, не как основную
20. Собирается / линт чистый / типы чистые / тесты зелёные - бинарные гейты, считаются до всякой субъективщины
21. Размер диффа: +/− строк, число файлов. Меньше ≠ лучше в вакууме - только в паре с task success
22. Scope creep: файлы, тронутые вне ожидаемого blast radius (список ожидаемых файлов зафиксируйте до прогонов)
23. Новые зависимости, новые абстракции/слои
24. Галлюцинации API: число ошибок компиляции/импорта на несуществующие символы
25. Дельта покрытия тестами по изменённым строкам
26. Дельта цикломатической сложности, дублирование
27. Соответствие конвенциям репо (частично ловится линтером, остальное - в рубрику)
28. Рубрика написана до просмотра результатов (корректность, читаемость, конвенции, качество тестов, "влил бы я это" - 1-5)
29. Слепое ревью: снять маркеры арм, перемешать диффы, ревьюер не знает, что где
30. Медиана + разброс (min/max или IQR) по трём прогонам, не среднее по одному