# Глоссарий

Термины, которые в наших документах означали разное. Здесь - единственное значение.
Одна мысль на строку. Дата: 2026-07-30 (grill-сессия по WORKFLOW.md).

## Процесс

- **RAISE** - наш внутренний intake-процесс (форма заявки + RICE + доска Voicebot+LLM, VB-A-92...96). Не useraise.dev и не научные RAISE. См. ADR-0009.
- **intake** - шаг 1 feature-flow: допрос тикета разработчиком/агентом. Подача и валидация заявки - это RAISE, не intake.
- **тир задачи** - light / standard / deep. Меняет глубину подготовки (гриль, исследование), не гейты. См. ADR-0010.
- **гриль** - допрос плана до имплементации. След: секция "Grill" в proposal.md change'а. Это практика, не устанавливаемый инструмент.
- **handoff** - перевод тикета в `ready_to_test` + комментарий тестировщику до 1 абзаца. Не путать с CURRENT_HANDOFF.md (передача сессии агента).
- **TBD** - у нас это trunk-based development (ADR-0006). "Будет определено позже" пишем словами, не аббревиатурой.
- **тестовый режим** - файлы созданы, но не закоммичены в git. Это не staging.

## Спеки

- **спека (capability spec)** - файл в `openspec/specs/<capability>/spec.md`. Описывает поведение prod.
- **change (дельта)** - активная папка `openspec/changes/<id>/`: proposal + спек-дельты + tasks. Архивируется в спеку, когда флаг включён в prod (ADR-0011).
- **store** - наш центральный репозиторий cybernet-specs (только 4 внешних границы). OpenSpec-фича `store` - механизм; SmartAndPoint ProjectStore - чужой отклонённый инструмент (ADR-0008).
- **LIVING SPEC** - формат conversation_flow. Исключение: без spec-guard, только warn-проверка.
- **enforced: якоря** - ссылки на код в спеке; spec-lint сверяет их свежесть с git diff.

## Гейты и проверки

- **гейт** - блокирующая проверка. Warn-only проверки (spec-lint до SPEC_LINT_STRICT, sdd-audit) гейтами не называем.
- **make sdd-check** - локальная блокирующая проверка: AGENTS.md ≤500 строк + openspec validate + spec-lint. Бежит в pre-commit.
- **sdd-gate** - тот же sdd-check как required check в CI на PR.
- **make test** - единая точка входа CI по ADR-0003: линтеры + sdd-check + pytest + контрактные тесты. Ещё не реализован ни в одном репо.
- **autoreview** - PR-ревью в CI: reviewdog/ruff (всегда) + AI-ревью (advisory, скипается без токена). AI-ревью НЕ блокирует мерж; блокирует только sdd-gate/make test.
- **spec-guard** - PreToolUse-хук: код в guarded-путях не правится без активного change. Обхода нет ни для urgent, ни для light-тира.

## Ревью и приоритеты

- **ревью** - уточняем какое: ревью-агенты локально (`make sdd-review`), autoreview в CI, человеческое ревью PR.
- **CRITICAL/HIGH/MEDIUM/LOW** - severity находок ревью.
- **low/medium/high/critical** - приоритет баг-репорта RAISE. Другая шкала, не смешивать.
- **urgent** - категория RAISE: блокирует запуск клиента или риск потери клиента. Не "горит у стейкхолдера".

## Флаги

- **feature-флаг** - запись в `feature_flags.py` с owner/ticket/expires (ADR-0007). Конвенция сред: вкл в dev/stage, выкл в prod; включение в prod - осознанное действие после QA (ADR-0011).
- **просроченный флаг** - `expires` в прошлом: 7 дней WARN, потом FAIL (`make sdd-flags`).
