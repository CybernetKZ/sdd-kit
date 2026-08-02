# Пилот spec-miner в WBN — итоги (2026-08-02)

Фаза D [PLAN_QUALITY.md](PLAN_QUALITY.md). 4 параллельных spec-miner-агента по горячим доменам web-backend-new.

## Результат

| Спека | Req | Scenarios | Invariants | Валидация |
|---|---|---|---|---|
| `openspec/specs/call-campaign/spec.md` | 22 | ~68 | 9 | ✓ strict, FRESH |
| `openspec/specs/auth-access/spec.md` | 22 | 79 | 9 | ✓ strict, FRESH |
| `openspec/specs/call-in/spec.md` | 20 | 60 | 8 | ✓ strict, FRESH |
| `openspec/specs/call-stats-reporting/spec.md` | 25 | 62 | 11 | ✓ strict, FRESH |
| **Итого** | **89** | **~269** | **37** | 4/4 |

Все спеки: `id`/`enforced`-якоря (все резолвятся), `Last verified: (commit 36f29f5e-совместимый SHA)`,
uncertainty-заметки вместо выдуманных требований, ссылки `test:`/`verified_by:` на существующие тесты.
Файлы **не закоммичены** — на ревью владельцу.

## D.3: проверка «Scenario → тест»

test-author по Scenario «окно 22:00→06:00 → два слота» (`derive_standard_daily_slots`):
- **Маппинг чистый**: тест написан без чтения кода за пределами enforced-файла;
  файл `backend/tests/test_spec_call_campaign_daily_slots.py` (оставлен на ревью).
- **RED/GREEN не получен**: тест-харнесс WBN не позволяет изолированный unit-прогон —
  `backend/tests/conftest.py` на импорте коннектится к Redis, autouse-фикстура
  делает drop/create БД + полную цепочку Alembic для ЛЮБОГО теста; в контейнере
  прогон висел 7+ минут без вывода.

## Решение D.4

1. **Качество spec-miner подтверждено — масштабировать можно** (остальные capability WBN:
   dashboard/operations, external web_api key-auth, external_call_campaign_service;
   затем VA-репо). Формат и дисциплина (uncertainty вместо фантазий, doc-vs-code drift)
   выдержаны всеми четырьмя агентами.
2. **Перед масштабированием test-author в WBN — нужен изолированный unit-вход** в тест-харнесс
   (отдельная директория tests/unit без тяжёлого conftest, или guard на module-level
   redis_connect). Без этого RED/GREEN-верификация блокируется инфраструктурой.
   Это же чинит вечно-красный advisory `make test` (30 collection errors).
3. Доки WBN расходятся с кодом в зафиксированных местах — Redis-контракт («нормативный»)
   и lifecycle-док требуют синхронизации (список ниже).

## Находки для тикетов (по убыванию серьёзности)

**Безопасность:**
1. `POST/PUT/DELETE /api/v1/firm`, `GET /firm/{uuid}` — нет tenancy-проверки: любой
   аутентифицированный пользователь может удалить ЛЮБУЮ фирму (каскад: удаление её
   пользователей + отключение агентов VA).
2. `POST /internal/v1/call-in/` — `Depends(verify_api_key)` закомментирован; регистрация
   входящих защищена только сетью.
3. `Depends(authenticated)` на v1-роутах ничего не гейтит (возвращает bool, не raise);
   реальная защита — только middleware.

**Корректность:**
4. `GET /report/summary` — захардкоженный мок (TODO WEB-1818), выставлен как живой API.
5. Redis-лок генерации отчётов никогда не берётся (`lock_key=None` в `generate_report.kiq()`).
6. `call_reach_rate`/`total_successful_calls` исключают показываемое 30-дневное окно —
   сумма дневного ряда ≠ total по построению.
7. `get_user_by_uuid` → 500 вместо 404 (деref до guard).
8. `scripts_usage` без фильтра call_direction (включает входящие); граничные звонки
   двоятся между отчётами (closed vs half-open окна).
9. Inbound-звонок на OUTBOUND-кампании молча исчезает из всей inbound-статистики.
10. `call_campaign_settings` TTL: два писателя в коде расходятся (30d create-путь vs 7d dispatch-путь).

**Мёртвый код / доки:**
11. `PermissionChecker.verify_access` + вся ROLE_HIERARCHY — ноль вызовов.
12. `CALL_CAMPAIGN_LIFECYCLE_LOGIC.md`: история «same-day extension» (+2 дня) устарела —
    хелпер и константа удалены (WEB-1917 Variant A).
13. Redis-контракт: TTL `call_in_redis:*` — доки 1h, код 7d; `CALL_RELATION_KEY` пишет
    post-call-processor, не call_in_service.

**Скоуп 2026-08-02**: работаем только с sdd-kit + cybernet-specs; находки по WBN (см. список выше) запаркованы — тикеты не заводятся, ошибки в других репо игнорируются до отдельного решения.
