# Запуск фазы 0-1 исследования SDD на Claude Fable 5

Назначение файла: перенести задачу выбора SDD-стека в сессию на модели Fable 5 с
субагентами. Постановка задачи - `TASK_SDD_SELECTION.md` (этот файл её не дублирует,
а даёт вход для модели, промпт и ссылки).

Дата: 2026-07-27. Автор решения о модели: Daniil.

## 1. Распределение моделей по работам

Fable 5 подтверждена как доступная. Субагентам можно назначать модель **индивидуально**
(параметр `model` в вызове Agent: `fable` / `opus` / `sonnet` / `haiku`, либо
`model:` во frontmatter агента в `~/.claude/agents/`), плюс отдельно `effort`. Значит
дорогая модель нужна только там, где решается качество, а механику отдаём Sonnet.

| Работа | Модель | Effort | Почему |
|---|---|---|---|
| Оркестратор сессии, синтез матрицы, ADR | **Fable 5** | high, `xhigh` на итоговый синтез | держит весь собранный контекст, сильнейшая на длинном горизонте |
| Глубокое чтение сложных кандидатов (BMAD 21 роль, superpowers, GSD) | **Fable 5** | high | там много механики промптов, поверхностное чтение даст маркетинг вместо фактов |
| Карточки остальных кандидатов (OpenSpec, spec-kit, cc-sdd), разбор merge-истории по репозиторию | **Opus 5** | high | вдвое дешевле за токен, для одного ограниченного трека этого достаточно |
| Механика: подсчёты, grep, инвентаризация 357 док-файлов, токен-статистика по 1014 транскриптам, список неиспользованных скиллов/MCP | **Sonnet 5** | low/medium | извлечение фактов без суждений; на этом Fable-качество не даёт ничего |
| Правки кода, hooks, мелкие итерации после выбора | Opus 5 | high | преимущества Fable на этом профиле не проявляются |

Haiku 4.5 в этой задаче не использовать: контекст 200K против 1M у остальных, а
читать придётся большие файлы.

## 2. Настройки сессии

- Модель: `claude-fable-5` (в Claude Code - `/model`).
- Effort: `high` по умолчанию; `xhigh` только на синтез матрицы и ADR. `low`/`medium`
  у этой модели работают заметно лучше, чем у предыдущих - на рутинных проходах не
  завышать.
- Thinking: **не настраивать**. У Fable 5 он всегда включён; явное
  `thinking: {type: "disabled"}` или `budget_tokens` возвращают 400.
- Субагенты: делегировать **асинхронно** и часто. Долгоживущий субагент, который
  держит свой контекст между подзадачами, обгоняет схему "породил -> заблокировался ->
  прочитал отчёт". Один субагент на репозиторий и один на источник данных фазы 0;
  модель каждому - по таблице §1.
- Ожидать ходы длиной в минуты (15 минут на сложном запросе - норма). Не прерывать
  по таймауту, проверять асинхронно.
- Ограничение аккаунта: Fable 5 требует 30-дневного хранения данных, при zero data
  retention все запросы возвращают 400. Если у организации ZDR - модель недоступна,
  и это не проблема запроса.

## 3. Промпт для старта сессии

Промпт и инструкции агентам - **на английском**, вопросы пользователю и итоговые
документы - на русском. Причина не в "английский умнее": доказательств этому нет, и
я их не нашёл. Причина практическая - поведенческие снипеты из официального
руководства по Fable 5 (§5) написаны по-английски и проверены в этой формулировке;
смешивать проверенный английский текст с переводом означает вносить дрейф
формулировок в самое чувствительное место промпта.

Сформулирован как цель + ограничения, без пошагового плана: у Fable 5 излишне
директивные промпты, написанные под предыдущие модели, **снижают** качество вывода.
Не "улучшать" его добавлением шагов.

```
Choose an SDD (spec-driven development) stack for CybernetAI R&D and justify the
choice with data.

Read TASK_SDD_SELECTION.md first - it is the source of truth for scope,
weighted criteria, and the five open decisions.

Deliverables:
1. OUR_PATTERNS.md - how our teams actually work, with numbers.
   Sources: dev merge history across web-backend-new, voice-agent-constructor-backend,
   voice-agent-postcall-analitics-backend, cybernet3.0; ~/.claude/projects (183 projects,
   1014 .jsonl, 2 GB) for where tokens go and which skills/MCP servers were never used
   once; web-backend-new/docs and shared_docs for what our specs and plans look like
   today. Tools for session history: rtk discover, /insights.
2. SDD_EVALUATION.md - one card per candidate plus a weighted matrix showing
   coverage of the four bottlenecks in §3 of the task. Candidates are cloned as sources
   under refactor_v4/ - read their prompt templates and actual mechanics, not just the
   README. GSD and ECC are already installed system-wide; evaluate them on equal footing.
3. ADRs for the five open decisions in §8, each with a status and a rationale.

Constraints:
- Brownfield + multi-repo is a filter, not a scored dimension: failing it drops a
  candidate from the shortlist regardless of total score.
- Enforceability (CI gates, hooks) carries a weight of 25 out of 100. This team
  systematically does not follow conventions, so a standard with no automatic
  enforcement does not count as viable.
- A hands-on pilot and runtime measurements are out of scope. This is a desk review
  backed by sources.
- Every claim in the matrix cites a file, a commit, or a documentation line. Mark
  anything unverified as "(not verified)" rather than stating it as fact.

Delegate independent tracks to subagents and keep working while they run. Assign models
per subagent: Fable for deep reads of BMAD, superpowers, and GSD; Opus for the remaining
candidate cards and per-repo merge-history analysis; Sonnet at low effort for mechanical
extraction (counts, greps, file inventories, token statistics).

Write the deliverable documents in Russian. Ask me any clarifying questions in Russian,
with context and a recommendation for each.
```

## 4. Ссылки

Кандидаты (склонированы в `refactor_v4/`, читать локально; ссылки - для метаданных):

- OpenSpec - https://github.com/Fission-AI/OpenSpec - `refactor_v4/openspec`
- spec-kit - https://github.com/github/spec-kit - `refactor_v4/spec-kit`
- BMAD-METHOD - https://github.com/bmad-code-org/bmad-method - `refactor_v4/BMAD-METHOD`
- cc-sdd - https://github.com/gotalab/cc-sdd - `refactor_v4/cc-sdd`
- superpowers - https://github.com/obra/superpowers - `refactor_v4/superpowers`
- GSD - `refactor_v4/gsd-core` (плюс установленные скиллы `gsd:*`)
- spec-compare (обзор-источник) - https://github.com/cameronsjo/spec-compare -
  визуализация https://cameronsjo.github.io/spec-compare/ - `refactor_v4/spec-compare`

Эталон процесса внутри компании: `conversation_flow/docs/DOCUMENTATION.md` -
7504 строки LIVING SPEC, нумерация "ТЗ №N", changelog и тесты со ссылкой на номер,
`make test` = lint_brand + lint_migrations + ruff + pytest.

Прочие источники со сравнениями SDD-инструментов: `Spec-Driven-Development-Tools.md`,
раздел Sources (15 ссылок).

Продуктовый gap-анализ (UI, не бэкенд): `WEB-2303-Hubtalk-comparison.md`,
тикет https://support.cyber-net.ai/issue/Web-2303/Hubtalk-ai-platform-comparison

## 5. Поведенческие поправки под Fable 5

Добавлять в промпт **только когда симптом проявился**, не заранее: избыточные
инструкции у этой модели снижают качество. Формулировки - дословно из официального
руководства, на английском; не переводить (см. §3).

| Симптом | Что добавить |
|---|---|
| Раздутый итоговый текст, структура ради структуры | `Lead with the outcome. Your first sentence after finishing should answer "what happened" or "what did you find". Supporting detail and reasoning come after. Being readable and being concise are different things, and readability matters more.` |
| Непрошенные действия рядом с задачей (начал внедрять вместо оценки) | `When the user is describing a problem, asking a question, or thinking out loud rather than requesting a change, the deliverable is your assessment. Report your findings and stop. Don't apply a fix until they ask for one.` |
| Фабрикация статуса на длинных прогонах | `Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for; if something is not yet verified, say so explicitly.` |
| Ранняя остановка: последний абзац - план или вопрос вместо работы | `You are operating autonomously. The user is not watching in real time. Before ending your turn, check your last paragraph. If it is a plan, an analysis, a question, or a promise about work you have not done, do that work now with tool calls.` |
| Тревога по контексту ("предлагаю начать новую сессию") | `You have ample context remaining. Do not stop, summarize, or suggest a new session on account of context limits - continue the work.` |
| Лишние абстракции и "уборка" в правках кода (фаза внедрения) | `Don't add features, refactor, or introduce abstractions beyond what the task requires. Only validate at system boundaries (user input, external APIs).` |
