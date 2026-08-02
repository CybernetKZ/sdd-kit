# Сверка store-контрактов cybernet-specs с кодом (2026-08-02)

3 opus-агента, правило «код побеждает», WBN @ 36d29f5e. Проверено 5 из 8 контрактов
(engine-redis-contract, telephony-in-redis-stream, post-call-processor-llm-redis,
external-webapi-authorization, external-call-campaign-api). Не проверялись:
frontend-api-v1, va-frontend-api (фронт — низкий приоритет), wbn-va-rpc (следующая волна).

**Все правки — в рабочем дереве cybernet-specs, НЕ закоммичены** (README store требует
sign-off Daniil). `openspec validate --all --strict` → 8/8 passed.

## Масштаб drift'а (спека говорила ≠ код делает)

**engine-redis-contract — 18 исправлений.** Ключевые: разговор регистрирует сам движок
(initializer через `BLPOP new_conversations` — очереди вообще не было в контракте);
метаданные создаёт движок, не вызывающий; post-call-processor удаляет ключи движка
(контракт это запрещал); `warm_transfer` — мёртвая ветка; у `{cid}_hangup` и `{cid}_amd`
нет писателя ни в одном репо; сервис `sender` объявлен, но не существует.

**telephony-in-redis-stream.** WEB-2298 уже в коде (спека утверждала «не смержено») —
код 16 + AMD-вердикт → CALL_ANSWERED_ANSWERING_MACHINE, шаг вставлен в aggregate-порядок;
XACK **fail-closed**, а не fail-open (ошибка остаётся в PEL — DLQ нет); stuck-timeout
1200s, не 600s, дедлайн не продлевается; двух Redis-инстансов по направлениям нет —
всё на engine-коннекте; incoming consumer groups — объявлены, но мертвы; XTRIM в WBN
отсутствует (обязанность продюсера — uncertainty).

**post-call-processor-llm-redis.** `CALL_RELATION_KEY` (`call_campaign:*:call:*:call_event:*`)
**не существует** — только в capture-скрипте; заменён на явное «такого ключа НЕТ»;
`processing:{ce}` — 120s owner-token lease (Lua, renew 30s), не 1200s SET NX EX;
`call_campaign_settings` TTL — **четыре писателя, три TTL** (7d/30d, uncertainty без
выбора победителя); IP-литералы заменены на env-конфиг; добавлены недокументированные
`zset:terminal_event_deadlines`, `zset:goal_deadline`.

**external-webapi-authorization + external-call-campaign-api — фактически переписаны.**
8 маршрутизированных эндпоинтов вместо 4; ошибки — RFC 9457 problem+json; схема `/details`
не совпадала почти полностью; `transfer_next_day` удалён из внешней схемы; error-коды
расширены с 5 до полного словаря; два словаря статусов (CallRecordStatus vs CallEventStatus).

## Запаркованные наблюдения безопасности (контрактная поверхность; скоуп-решение 2026-08-02: тикеты не заводим)

1. api-key-роуты (`create/list/delete`) — ноль backend-аутентификации; защита только
   в gateway `ext_endpoints_auth_rules.yml`. Кто дотянулся до backend `/external` —
   выпускает/отзывает ключи любой фирмы.
2. `knowledge-base`-роуты не аутентифицированы и не скоупированы; сейчас недостижимы
   (нет gateway-правила) — добавление правила молча раскроет кросс-фирменные данные.
3. Gateway-кэш ключей никогда не хитует (несовпадение префикса `sso:` при записи/чтении) —
   ревокация мгновенна «случайно»; выравнивание префиксов внесёт лаг ревокации.
4. 403 vs 404 в `/details` позволяет перебирать чужие campaign UUID.
5. `key_prefix` = первые 7 символов UUID фирмы — enumerable; секретность целиком
   на hashed-половине.

## Волна 2 (2026-08-03): wbn-va-rpc — закоммичено (store `5acdca2`)

Сверка обеих сторон: WBN @ `36d29f5e`, VA @ `5d235888`. Инвентарь из 14 actions
не изменился. Ключевые drift'ы:

- **TaskIQ enqueue-failure fallback покрывает 2 из 6 write-actions** — 4 agent-записи
  идут `.kiq()` в log-only try/except: без fallback и без dead-letter (finding l).
- **Асимметрия возвращаемого клиентом**: VA возвращает весь envelope, WBN — `response.data`
  (finding m, load-bearing).
- **(h) эскалирован latent → LIVE**: `TOUCH_AGENT_WB` с `user_uuid=null` достижим с живого
  пути (удаление knowledge base → cleanup агентов), WBN-схема требует UUID. Кандидат на тикет.
- `UPDATE_AGENT_WB` имеет 2 недокументированные ошибки, НЕ покрытые idempotency-правилом.
- `RABBITMQ_VHOST` не читает ни одна сторона; дефолты различаются.
- Cross-side mismatches (a)–(k): все перепроверены, ни один не выброшен;
  (d)/(j)/(k) уточнены; закрыта uncertainty #2 (ровно один WBN-консьюмер очереди).

## Статус store

- [x] Волна 1: 5 контрактов закоммичены (`c41df8f`), README подписан (working store, 2026-08-03).
- [x] Волна 2: wbn-va-rpc (`5acdca2`).
- [ ] Не сверены: `frontend-api-v1`, `va-frontend-api` (фронт — низкий приоритет).
- [ ] Синхронизировать исходные доки WBN (`POST_CALL_PROCESSOR_LLM_REDIS_CONTRACT.md` и др.) —
      drift-места помечены в спеках; правка доков — вне скоупа (WBN read-only).
