# что нужно для настройки и стандартизации работы R&D с claude code 
и опционально аналогами: codex, cursor, antigravity, aider, cline, opencode, continue, roo code, etc
- методичку (не слишком большую, до 500 строк) как рекомендуется работать с claude code
- имеет смысл сформировать общие вещи полезные для всех проектов CybernetAI (ex: youtrack-mcp, context7, CLAUDE.md, /skills ponytail, etc)
  - к примеру выбор самого лучшего mcp/hook/tool/etc для поиска в интернете
  - использование context7 (вся документация)
  - использование Graphify (repo-to-knowledge-graph skill)
  - использование skill ponytail or caveman (экономия токенов, повышения качества кода)
  - использование Chrome DevTools MCP + Playwright CLI for a frontend debug/test loop
  - использование Headroom (тестирование, экономия токенов -> проверить как взаимодействует с кэшированием claude)
[24.07.2026 15:36] Dan: - создание/настройка/использование системы авторевью с несколькими агентами, с использованием tools ruff, radon, complexipy, vulture, pylint, etc. ОБЯЗАТЕЛЬНО с проверкой против правил для этого репозитория
  - использование grill-with-docs (бывшее Grill Me) после написания полного плана и до имплементации
  - создание/настройка/использование Claude Code hooks (PreToolUse/PostToolUse/Stop) для автоформатирования, безопасности (запрет операций записи в git) и т.д.
  - Sonnet 5 для базовых задач, Opus 4.8/Fable 5 для сложных задач и планирования
  - корретный выбор уровня /effort
  - оптимальное количество mpc/skills/etc -> слишком большое количество забивает контекст и контрпродуктивно
  - создание skills на основе частых паттернов использования
- каждый репозиторий (модуль) должен иметь свои характерные для него правила CLAUDE.md до 500 строк

мы должны провести качественное сравнеие (benchmark) ДО и ПОСЛЕ sdd-kit+tools (@benchmark-sdd-kit.md)
с нашими репозиториями и реальными задачами.

к примеру имеет смысл использовать более быстпр

# пример моего текущего рабочего процесса (backend developer):
## FEATURE
- бизнес (обычно в лице Рашида) хочет что-то (feature), они не проверяют досконально, есть ли это или что то похожее, мешает ли это ли логике и/или архитектуре а просто говорят, иногда до конца не понимая что имеется в виду (пример: добавление системы SPIN обзвонов в WBN /home/octrow/cybernet/voice-agent-constructor-backend/docs/WEB-1836_SPIN_callback_plan.md)
- Ольга / Дина открывают и описывают таску на youtrack, это может быть и просто строка/загловок (ex: добавить SPIN обзвон) и более подробно расписанная задача (через LLM, с частыми ошибками в контрактах, логике и т.д)
- я с проверяю таск глазами + LLM с кодом и моей внутренней документацией и пишу комменатрии на найденнные проблемы -> запрос/вопросы к Дине/Ольге/Рашиду
- с учётом моих базовый рекомендаций я пишу план выполнения таска
- через LLM имплементирую план в код (в ветку с feature/WEB-****)
- c LLM пишу док что нужно проверить и протестировать  (ex: /home/octrow/cybernet/voice-agent-constructor-backend/postman-collections/daniil/docs/WEB-1836-Test-Cases.md)
- на основе плана LLM пишет e2e тесты (newman) + pytests
- провожу ручное тестирование
- провожу (LLM) ревью кода c /home/octrow/cybernet/voice-agent-constructor-backend/docs/wbn-prompts/review-pr.md
- имплементирую рекомендации если они в рамках задачи, иначе просто добавляю TODOs/NOTEs
- провожу тесты
- открываю pr

## BUGFIX
- в telegram группе (Новый ЛК, Voice Product, Run Engine v3 in K8S, VoiceBots + LLM, etc) кто-то (к примеру Рашид) пишет что вроде что-то где то сломалось ex: ```очень странно. При этом не было end_call со стороны агента.
@trauor посмотри пожалуйста, почему нас трансфер статус?  @Makhambet_Mamyrov``` ответственных могут отиетить но не обяхательно, это мрожет быть как баг в коде (реальная ошибка), так и рошибка клиента (создание 9000 call_campaign подряд в каждой по 1 звонку), так и проблемы devops, etc
- если я беру ошибку в работу (обычно по желанию/нагрузке, или если только я отмечен) я начинаю с анализа
- запускаю /home/octrow/cybernet/web-backend-new/extra_scripts/incident_collect/collect_incident.py с uuid звонка/call_campaign
- на основе данных с LLM формируем док о причинах инцидента
- пишем план фикса
- реализуем в коде с LLM план фикса
- пишем тесты и проверяем

# check tools (uncomleted list)


1. https://github.com/langchain-ai/langchain
143k stars
LangChain is a framework for building agents and LLM-powered applications. It helps you chain together interoperable components and third-party integrations to simplify AI application development - all while future-proofing decisions as the underlying technology evolves.
2. https://github.com/run-llama/llama_index
51.2k stars
LlamaIndex OSS (by LlamaIndex) is an open-source framework to build agentic applications. Parse is our enterprise platform for agentic OCR, parsing, extraction, indexing and more. You can use LlamaParse with this framework or on its own; see LlamaParse below for signup and product links.
3. https://github.com/Egonex-AI/Understand-Anything
76.6k stars
Understand Anything is a Claude Code Plugin that analyzes your project with a multi-agent pipeline, builds a knowledge graph of every file, function, class, and dependency, then gives you an interactive dashboard to explore it all visually. Stop reading code blind. Start seeing the big picture.
4. https://github.com/oraios/serena
27.1k stars
A powerful MCP toolkit for coding, providing semantic retrieval and editing capabilities - the IDE for your agent
5. https://github.com/microsoft/graphrag
35k stars
A modular graph-based Retrieval-Augmented Generation (RAG) system
The GraphRAG project is a data pipeline and transformation suite that is designed to extract meaningful, structured data from unstructured text using the power of LLMs.
6. https://github.com/HelixDB/helix-db
5.7k stars
HelixDB is an OLTP graph-vector database built in Rust on Object Storage.
HelixDB is a database that makes it easy to build all the components needed for AI applications in a single platform.
7. https://github.com/yamadashy/repomix
27.5k
Repomix is a powerful tool that packs your entire repository into a single, AI-friendly file. Perfect for when you need to feed your codebase to Large Language Models (LLMs) or other AI tools like Claude, ChatGPT, DeepSeek, Perplexity, Gemini, Gemma, Llama, Grok, and more.
8. https://github.com/ast-grep/ast-grep
15.3k
A CLI tool for code structural search, lint and rewriting. Written in Rust
9. https://github.com/mufeedvh/code2prompt
7.5k 
A CLI tool to convert your codebase into a single LLM prompt with source tree, prompt templating, and token counting.
10. https://github.com/max-sixty/worktrunk
6.2k
Worktrunk is a CLI for Git worktree management, designed for parallel AI agent workflows
11. https://github.com/dagger/container-use
3.9k
Development environments for coding agents. Enable multiple agents to work safely and independently with your preferred stack.
12. https://github.com/langfuse/langfuse
32.1k
Open source AI engineering platform: LLM evals, observability, metrics, prompt management, playground, datasets. Integrates with OpenTelemetry, LangChain, OpenAI SDK, LiteLLM, and more. YC W23
12. https://github.com/Arize-ai/phoenix
10.8k
Phoenix is an open-source AI observability platform designed for experimentation, evaluation, and troubleshooting.
13. https://github.com/Helicone/helicone
6k
Open source LLM observability platform. One line of code to monitor, evaluate, and experiment. YC W23
14. https://github.com/semgrep/semgrep
16k
Lightweight static analysis for many languages. Find bug variants with patterns that look like source code.