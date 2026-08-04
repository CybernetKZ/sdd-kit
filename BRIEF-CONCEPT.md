# BRIEF-CONCEPT — исходная концепция (intake-заметка)

> Сверено 2026-08-04, текст ниже не правился (история). Реализация и
> отклонения: store/граф/без-CI — ADR-0023; краткость текстов — ADR-0024;
> одна команда установки (граф + статические тулзы + ruff), план-ревью как
> pre-pass гриллера, дедупликация агентов — ADR-0025. Решено иначе: Gherkin →
> `#### Scenario:` в спек-дельте; выбор моделей в рантайме → пин во
> frontmatter (ADR-0010/0013, override — исключение, ADR-0025 §6);
> конвертация docs/patches → ручные протоколы tools/cf (фаза 3 выполнена).

наши репозитории (в порядке приоритета):
1. conversation_flow (обязательно)
2. web-backend-new (пропустить, вероятно depricated)
3. voice-agent-constructor-backend (пропустить, вероятно depricated)
4. voice-agent-postcall-analitics-backend (пропустить, вероятно depricated)
5. web-frontend-new (пропустить, вероятно depricated)
6. cybernet3.0 (пропустить, вероятно depricated)

всякие CI/CD в sdd-kit вероятно сейчас не нужно т.к. усложняют и так сложные процессы (можно обсудить)

## пример workflow new feature standart для нового репозитория conversation_flow:

### установка sdd-kit в репозиторий
```
bash /home/octrow/cybernet/sdd-kit/install.sh /home/octrow/cybernet/conversation_flow
```
установка включает:
- установка/проверка: uv, ruff, radon, complexipy, vulture, semgrep (for check/review)
- установка graphify, mcp context7, mcp youtrack, rtk, etc
- установка "npx -y @fission-ai/openspec@1.7.0"
- проверка наличия папки graphify-out и запуск сбора данных если их нет с согласия пользователя
- заполненную openspec папку в репозиторий
- обновление openspec на основе conversation_flow/docs/patches (branch main) с помощью sdd-kit/tools/cf/main-drift.sh, mine-section.md, patch2change.md, sync-main.md, verify-section.md
- добавление как подпапку `git clone https://github.com/CybernetKZ/cybernet-specs` (openspec store)
- установка/проверка правил для python: ruff.toml
- установка .git/hooks/pre-commit
- установка/проверка необходиых вещей для openspec
- установка/проверка skills
- установка/проверка agents
- установка/проверка tools
- копирование/проверка AGENTS.md (+simlink CLAUDE.md) для репозитория, если нет то создание на основе шаблона с согласия пользователя
...

### вызов agent (агент МОЖЕТ выбирать модели/effort, запускать субагенты, вызывать skills) для НАШЕГО 100% совместимого с openspec workflow feature standart
- opus: обзор задачи/таска (возможно grill), читаем либо через mcp youtrack, либо из файла/чата
- opus: составление плана выполнения задачи:
  - opus/sonnet: поиск и анализ связанной документации (graphify, mcp context7)
  - opus/sonnet: поиск и анализ связанного кода (graphify, etc)
  - opus/sonnet: поиск и анализ связанного openspec (openspec, graphify, etc)
  - выполнение openspec логики
  ...
- opus: grill плана выполнения задачи (вопросы пользователю на русском с рекомендациями), обновления плана в итоге
  - opus/sonnet: поиск и анализ связанного (graphify, mcp context7)
- opus: review плана свежей независимой сессией
- opus: если нет документации / критериев для тестов написать их в Gherkin
  - sonnet: на основе документации, если ещё нет, написать тесты для таска, свежей независимой сессией, они должны проваливаться т.к. код ещё не имплементирован
- opus: оркестратор sonnet имплементирующих план выполнения задачи
  - sonnet: имплементация части плана выполнения задачи
  ...
- sonnet: запуск тестов после имплементации, поиск и устранения ошибок
- opus: ревью имплементации плана задачи свежей независимой сессией
- opus/sonnet: логика openspec
- sonnet: открытие PR в нашем стиле и обновление статуса задачи в youtrack

## НЕ нужно усложенеия
- абсолютный минимум guards/etc -> по сути наш набор .git/hooks/pre-commit вероятно более чем достаточный, но можно уточнить и разбить наши ШТУКИ на мелкие и понятные скрипты 
- сейчас избегаем трогать CI/Cd
- может быть нам не нужен Makefile если у нас есть установка скриптом?
- избегать дублирующихся skills/agent/tools/etc
- убрать пока всё связанное с feature_flags
- зачем sdd-kit/templates/living-spec-check.sh ?
- минимум всяких флагов, и скперочевидные имена для них  