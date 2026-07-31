# Consolidated defect backlog

Date: 2026-07-29. Findings recorded during WEB-2305 spec mining and review
pipeline testing; NOT fixed - ticket material.

## Counts summary

| Scope | Total | CRITICAL | HIGH | MEDIUM |
|---|---|---|---|---|
| WBN | 5 | 1 | 3 | 1 |
| VA | 15 | 2 | 3 | 10 |
| Frontend | 11 | 0 | 4 | 7 |
| cybernet3.0 (call-session-initialization) | 21 | 1 | 5 | 15 |
| PCA | 2 | 0 | 1 | 1 |
| Cross-service (WBN <-> VA RPC) | 11 | 0 | 4 | 7 |
| **Total** | **65** | **4** | **20** | **41** |

Note: some frontend defects are cross-cutting between WBN and VA payload
contracts; they are listed once in the Frontend table with both source refs
where an overlap exists (see dedup note under that table).

---

## WBN (web-backend-new)

| ID | Severity | Title | Source |
|---|---|---|---|
| WEB-2256-review(C1) | CRITICAL | Lease-loss race in shutdown can permanently drop post-commit webhook/archive-publish side effects | reviews/WEB-2256-review.md |
| WEB-2256-review(C2) | CRITICAL | Graceful shutdown closes shared Redis/RabbitMQ/DB clients while tasks may still be running past cancel_timeout | reviews/WEB-2256-review.md |
| WEB-2256-review(H1) | HIGH | Task drain budget (12s) far shorter than message budget (300s) strands in-flight calls >=10 min on every deploy | reviews/WEB-2256-review.md |
| WEB-2256-review(H2) | HIGH | Consumers start before shutdown manager registers them; SIGTERM during startup leaves consumers mid-message with no clean close | reviews/WEB-2256-review.md |
| NEXT_STEPS(wbn-ci) | HIGH | WBN CI does not run tests at all (pytest step missing from pipeline) | NEXT_STEPS.md:135 |

---

## VA (voice-agent-constructor-backend)

| ID | Severity | Title | Source |
|---|---|---|---|
| va-frontend-api(a) | CRITICAL | VA never verifies the gateway's HMAC trust-header signature and 13 of 18 routers require no identity at all, including provider endpoints exposing api_key | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(b) | CRITICAL | Provider api_key credentials are returned to the browser in plaintext across >=6 read models (LLM/TTS/ASR/PCA settings) | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(c) | HIGH | TtsIntegrationProviderRead leaks url/api_key/icon unredacted while sibling LLM/ASR integration reads suppress them | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(h) | HIGH | List `size` query parameter has no upper bound on any VA endpoint, breaching frontend-api-v1 pagination contract | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(t) | HIGH | Malformed tool parameters silently swallowed (JSON.parse in try/catch) instead of failing validation; magic-string PCA sentiment coupling with no shared constant | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(f) | MEDIUM | Untagged unions (tools_settings.setting, ToolFunctionParameters.properties) are duck-typed on arrival, silently re-defaulting to a different retrieval config on probe failure | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(e) | MEDIUM | Untyped holes on both sides for tool-parameter and dynamic-variable shapes (Record<string, unknown> / Any / dict) - nothing validates or drift-detects them | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(i) | MEDIUM | Closed enumerations (barge_in, tts_method, transfer_method, etc.) arrive as bare strings on both sides with no type-boundary rejection | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(k) | MEDIUM | Read/write asymmetry unmodelled for LLM/TTS/ASR/PCA settings; read models get hand-rebuilt into duplicated update shapes that will drift | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(l) | MEDIUM | Frontend TAgent type diverges from VA's AgentRead (missing fields, wrong nullability) - a freshly created agent violates the frontend's own type at runtime | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(m) | MEDIUM | Frontend invents four PCA template fields (enabled, is_system, default_description, reset_to_default) that don't exist in VA's model | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(n) | MEDIUM | Dead commented-out CRUD block in tool.py; deprecated /tts-type still has a table; deprecated GET /tts/model still has a live frontend caller | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(o) | MEDIUM | /agent-template and /template-topic are implemented and unused on VA while the frontend serves both domains from in-memory mocks across 17 call sites | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(v) | MEDIUM | Frontend sends knowledge-base `add_file_uuids` key that VA does not accept/parse - silently adds nothing | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| va-frontend-api(w) | MEDIUM | Knowledge-base `status` is a closed 2-value union on the frontend vs a nullable enum in VA - a failed-indexing state matches neither frontend value | cybernet-specs/openspec/specs/va-frontend-api/spec.md |

---

## Frontend (web-frontend-new / gateway contract)

Dedup note: `frontend-api-v1(a)` (no codegen, ~130 hand-written client
methods/types) is the same root cause cited by `va-frontend-api(l)`, `(g)`,
`(d)` and others; those are kept under VA/Frontend individually but not
re-listed as separate frontend-side rows to avoid duplication.

| ID | Severity | Title | Source |
|---|---|---|---|
| frontend-api-v1(e) | HIGH | logout is never called on the client; server-side Redis session stays live for full TTL after user "logs out", so a stolen token survives logout | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(d) | HIGH | DELETE /web/auth/user/bulk-delete has no matching backend route; call binds "bulk-delete" as a path parameter and fails | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(l) | HIGH | GET /auth/me is typed as a list on WBN while frontend reads it as a single user object - one side is wrong | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| va-frontend-api(g)/(p) | HIGH | One client object (agentAPI) mixes two backends' agent lists (VA uuid-keyed vs WBN agent_uuid-keyed) with no way to tell which service answers; dual-identity fallback exists in one mapper (selectAgentByFirmDTO) and not its twin | cybernet-specs/openspec/specs/va-frontend-api/spec.md |
| frontend-api-v1(a) | MEDIUM | No codegen on the largest owned contract: ~130 hand-written client methods/types against two backends that both publish OpenAPI; a renamed field surfaces as undefined in production | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(b) | MEDIUM | Three error body shapes coexist (HTTPException detail, gateway error_code, RFC 9457 problem+json); frontend partially matches human-readable strings against a hardcoded dictionary | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(c) | MEDIUM | No refresh-token flow on either service; 24h fixed session silently logs the user out mid-work with unsaved form state lost | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(f) | MEDIUM | WebSocket path /lk/ws may not match the Vite proxy rule for /ws, which targets a different port (8000 vs 8015) - unconfirmed at runtime | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(g) | MEDIUM | Production reverse-proxy rewrite rules exist in no inspected repository; only the dev Vite config is version-controlled, and it hardcodes a production target IP | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| frontend-api-v1(i) | MEDIUM | Tenant routing (ChatPlatform) is a frontend hostname match against a hardcoded list of 8+ tenant hostnames; unmatched hostname fails silently | cybernet-specs/openspec/specs/frontend-api-v1/spec.md |
| va-frontend-api(d) | MEDIUM | Frontend main-prompt type declares misspelled `variablses` where VA emits `variables` - any reading path gets undefined | cybernet-specs/openspec/specs/va-frontend-api/spec.md |

---

## cybernet3.0 (call-session-initialization: initializer + VAD + controller)

| ID | Severity | Title | Source |
|---|---|---|---|
| call-session-init(17) | CRITICAL | Duplicate `new_conversations` message for a live call uses JSON.SET on the root path, silently destroying its phrases/messages/states/errors | cybernet3.0/openspec/specs/call-session-initialization/spec.md:777 |
| call-session-init(1) | HIGH | Owner/reader mismatch on phrase-id path: initializer seeds `last_phrase_id` while writers update `latest_values.phrase_id`; controller reads the latter and gets nothing between conversation creation and first phrase | cybernet3.0/openspec/specs/call-session-initialization/spec.md:760 |
| call-session-init(2) | HIGH | vad lock (`lock:vad:{conversation_id}`) is never cleared by controller cleanup, relying solely on a 10s TTL with no refresh - calls longer than 10s run unlocked | cybernet3.0/openspec/specs/call-session-initialization/spec.md:761 |
| call-session-init(3) | HIGH | VAD state vocabulary mismatch: VAD publishes `starting`/`no_audio`, neither recognised by the controller's VAD state set; `starting` also double-published on two different keys | cybernet3.0/openspec/specs/call-session-initialization/spec.md:762 |
| call-session-init(4) | HIGH | Discovery mismatch: controller derives work from `engine:active_conversations`, VAD from its own queue with no shared reconciliation - a lost queue message yields a controller worker with no VAD worker | cybernet3.0/openspec/specs/call-session-initialization/spec.md:763 |
| call-session-init(13) | HIGH | ThreadedWorkerRegistry shares one `_lock_identifier` UUID across all workers in a process; any worker's release can delete another worker's `lock:vad` entry for the same conversation | cybernet3.0/openspec/specs/call-session-initialization/spec.md:772 |
| call-session-init(16) | HIGH | phrase_id computed as `int(round(time.time(), 2) * 100)` (10ms granularity) with no collision guard; two phrases in the same window collide on the same `$.phrases` member | cybernet3.0/openspec/specs/call-session-initialization/spec.md:776 |
| call-session-init(5) | MEDIUM | `$.states.vad` sub-document is seeded but never written at runtime (writer exists, never called) - stays `{"state": ""}` for the whole call | cybernet3.0/openspec/specs/call-session-initialization/spec.md:764 |
| call-session-init(6) | MEDIUM | Documented `Controller:{deploy_suffix}` event queue / throttle does not exist in the runtime; call site commented out, method never defined; dead configuration | cybernet3.0/openspec/specs/call-session-initialization/spec.md:765 |
| call-session-init(7) | MEDIUM | VadStateMachine class attributes shared across workers cause `must_transition` to evaluate true for `min_buffer_gathered` from ~1s after process start onward, spamming re-publish instead of publishing on change | cybernet3.0/openspec/specs/call-session-initialization/spec.md:766 |
| call-session-init(8) | MEDIUM | `speech_threshold_on`/`threshold_on` read from the same params key with different code defaults (0.5 vs 0.6); no distinct override possible | cybernet3.0/openspec/specs/call-session-initialization/spec.md:767 |
| call-session-init(9) | MEDIUM | Sample call record (main_record_data_model.json) diverges from the shape both services actually read (agent.properties nesting, timezone_name); sample may be stale or live producer reads an undocumented shape | cybernet3.0/openspec/specs/call-session-initialization/spec.md:768 |
| call-session-init(10) | MEDIUM | Unbound `conversation_id` in initializer's RedisError handler on BLPOP failure raises NameError, swallowed by a bare except, hiding the original Redis error | cybernet3.0/openspec/specs/call-session-initialization/spec.md:769 |
| call-session-init(11) | MEDIUM | `release_lock_sync` called before a None-check on `client` in threaded_worker.py finally block; masks the original create_client() error with AttributeError | cybernet3.0/openspec/specs/call-session-initialization/spec.md:770 |
| call-session-init(12) | MEDIUM | `ThreadedWorkerRegistry.has_capacity()` off-by-one permits MAX_WORKER_THREADS + 1 concurrent worker threads (same class of bug as the controller registry) | cybernet3.0/openspec/specs/call-session-initialization/spec.md:771 |
| call-session-init(14) | MEDIUM | `ThreadedWorkerManager._sync_workers` stop branch appears unreachable given how entries are removed; `ThreadWorker.stop()` has no effect on a running audio loop | cybernet3.0/openspec/specs/call-session-initialization/spec.md:773 |
| call-session-init(15) | MEDIUM | `_requeue_active_conversation` uses LPUSH against a LPOP listener, causing LIFO retry order and rapid re-pop/re-push churn under full capacity | cybernet3.0/openspec/specs/call-session-initialization/spec.md:774 |
| call-session-init(18) | MEDIUM | Manager's start/stop reconciliation calls `_fetch_active_conversations` twice per tick under the same lock with no documented ordering guarantee between the two snapshots | cybernet3.0/openspec/specs/call-session-initialization/spec.md:775 |
| call-session-init(19) | MEDIUM | Initializer's begin_dynamic phrase leaves `asr.finished` false by default while controller's phrase arbitration treats false as "ASR still working", pausing TTS/LLM - unclear if first-turn exclusion is intended | cybernet3.0/openspec/specs/call-session-initialization/spec.md:778 |
| call-session-init(20) | MEDIUM | Dead async `create_phrase_metadata` twin omits fields (`finished`, `from_vad_to_asr_duration`, `history_edit`) present in the sync version the runtime actually uses | cybernet3.0/openspec/specs/call-session-initialization/spec.md:779 |
| call-session-init(21) | MEDIUM | `metadata_ttl_time`/`MAX_CONCURRENT_CONVERSATIONS` are non-overridable module literals; VAD config path mismatch (`config.MAX_WORKER_THREADS` vs `config.VAD.MAX_WORKER_THREADS`) works only by incidental default instantiation order | cybernet3.0/openspec/specs/call-session-initialization/spec.md:780 |

---

## PCA (voice-agent-postcall-analitics-backend)

| ID | Severity | Title | Source |
|---|---|---|---|
| NEXT_STEPS(pca-code96) | HIGH | Confirmed bug: success code 96 is not conditionally skipped as intended (test_success_code_96_is_not_skipped fails) - vs voicemail_codes handling | NEXT_STEPS.md:159 (also AGENTS.md Known issues per NEXT_STEPS notes) |
| NEXT_STEPS(pca-await-sync) | MEDIUM | Suspected bug: an `await` on a sync method on the publish path (post-call-report-generation) | NEXT_STEPS.md:159 |

---

## Cross-service (WBN <-> VA RPC, wbn-va-rpc)

| ID | Severity | Title | Source |
|---|---|---|---|
| wbn-va-rpc(c) | HIGH | VA -> WBN queue (agent_wb_rpc_queue) is non-durable (FastStream defaults, durable=False) - every in-flight write is lost on a broker restart with no broker-side recovery | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(b) | HIGH | `description` sent by VA on UPSERT_POST_CALL_ANALYSIS_SEGMENT is declared but never forwarded by WBN to the service layer - silent data-loss path that looks supported from VA | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(d) | HIGH | DISABLE_AGENT is fire-and-forget after WBN's local commit with no retry; a VA outage leaves the agent enabled in VA and deleted in WBN with nothing logged as a failed call | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(i) | HIGH | VA's dead-letter exchange/routing-key on agent_reconciliation_rpc_queue is unreachable: the handler catches every exception and always replies, so no message is ever rejected into that route | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(a) | MEDIUM | Latent break: WBN types `since_datetime` as nullable but VA's strict parser requires a non-empty aware ISO string for the windowed reconciliation action; a future None-passing call site would fail every hourly sweep | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(h) | MEDIUM | TOUCH_AGENT_WB.user_uuid is nullable on VA's outbound type but required (UUID) on WBN's payload model - a None would fail validation and burn 3 retries plus dead-letter | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(e) | MEDIUM | No versioning mechanism at all on the RPC contract - no version field, headers, versioned names or negotiation | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(f) | MEDIUM | Stale comment in WBN's action enum claims the two PCA segment actions are a no-op "until catalog cache lands" - both are fully implemented; misleading to future readers | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(g) | MEDIUM | BATCH_GET_AGENT_WBS is dead: WBN implements the handler, both sides declare the enum member, but VA has no call site and nothing exercises it | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(j) | MEDIUM | TLS/vhost handling diverges: VA disables hostname/cert verification in dev mode; WBN's RPC client broker lacks the security object its main broker uses, relying on amqps:// scheme alone; RABBITMQ_VHOST is declared but WBN hardcodes URI path to "/" | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |
| wbn-va-rpc(k) | MEDIUM | Response extras (`count`) returned by VA on all three read responses are ignored by WBN - not part of the contract, must not be relied on for pagination or truncation detection | cybernet-specs/openspec/specs/wbn-va-rpc/spec.md |

---

## Source-doc defects (resolved against code 2026-07-29 - fix the DOCS, not code)

All three contradictions verified against code; the specs in cybernet-specs now
state the code truth. Remaining work is doc fixes by the doc owners:

| ID | Severity | Title | Source |
|---|---|---|---|
| docs(1) | MEDIUM | EXTERNAL_CALL_CAMPAIGN_API.md advertises header `X-API-Key`; the gateway reads only `x-cybernet-api-key` (headers.py:27-29) - the doc conflated the external key with the unrelated internal static-key mechanism | external-webapi-authorization spec, Provenance |
| docs(2) | MEDIUM | EXTERNAL_CALL_CAMPAIGN_API.md still lists `PUT /call-campaign/{uuid}/call-records`; only `/phone-number` exists in code (call_campaign.py:218,426) | external-call-campaign-api spec, Provenance |
| docs(3) | MEDIUM | Source doc claims a new API key auto-deactivates the old one; code refuses with 409 and never auto-supersedes (web_api_service.py:137-148) - an integrator building rotation on the doc would break | external-webapi-authorization spec, Provenance |
| docs(4) | LOW | WEB-2061 restriction note carries a lifting date (2026-06-09) already in the past - stale note, or the restriction was lifted long ago | NEXT_STEPS.md |

## Additions 2026-07-29 (post-call-processing re-mining vs main efbfec54)

| ID | Severity | Title | Source |
|---|---|---|---|
| wbn-pcp(remine-1) | HIGH | Three AMD flags (llm_amd/vad_amd/amd_detection) are OR-ed with no producer contract from the engine; a false-positive llm_amd silently demotes an answered code-16 call to VOICEMAIL_REACHED and suppresses its post-call analytics | web-backend-new/openspec/specs/post-call-processing/spec.md |
| wbn-pcp(remine-2) | MEDIUM | Dead code after WEB-2256: _get_dynamic_call_timeout(), _check_redis_stuck_calls() and settings USE_DYNAMIC_STUCK_TIMEOUT / STUCK_TIMEOUT_RETRY_CYCLES / MIN_CALL_DURATION_FOR_STUCK are inert (only tests reference them) - ZSET deadlines replaced them | web-backend-new/openspec/specs/post-call-processing/spec.md |

## Additions 2026-07-29 (goal-achievement mining, WBN @ efbfec54)

| ID | Severity | Title | Source |
|---|---|---|---|
| wbn-goal(2) | HIGH | Stale late `False` verdict demotes a promoted attempt: _persist_late_goal_verdict always writes False and re-applies GOAL_NOT_ACHIEVED even over a COMPLETED/True attempt | web-backend-new/openspec/specs/goal-achievement/spec.md |
| wbn-goal(3) | HIGH | retry_lock leak on mid-flow dispatch failure: taken in preconditions, never released on failure after that point - re-initiation blocked for 1200s (TTL bound to unrelated MAX_CALL_DURATION_SECONDS) while the deadline member is already dropped; attempt stranded CALL_IN_PROGRESS | web-backend-new/openspec/specs/goal-achievement/spec.md |
| wbn-goal(4) | MEDIUM | Deadline poller's `finally` ZREM discards a deadline whose finalization failed transiently (pinned by a test as intended, product-questionable) | web-backend-new/openspec/specs/goal-achievement/spec.md |
| wbn-goal(5) | MEDIUM | Poller writes the forced False verdict without any lock; only a goal_achieved-is-not-None re-read narrows the race with a committing judge report | web-backend-new/openspec/specs/goal-achievement/spec.md |
| wbn-goal(6) | MEDIUM | find_rule_by_condition never checks an `enabled` flag despite docstrings/logs saying "enabled rule" - presence == enabled | web-backend-new/openspec/specs/goal-achievement/spec.md |
| wbn-goal(8) | MEDIUM | get_due_goal_deadline_members() is unbounded (no BATCH_SIZE, unlike every other sweep) | web-backend-new/openspec/specs/goal-achievement/spec.md |
| va-tmpl(1) | MEDIUM | delete_template idempotency (repeat delete -> 404) contradicts sibling delete_agent (repeat delete -> success) - inconsistent contract between domains | voice-agent-constructor-backend/openspec/specs/agent-template/spec.md |
| va-tmpl(2) | MEDIUM | System templates (is_system=True) allow the same PUT mutations as regular ones with no identity-field lock, unlike PCA system templates | voice-agent-constructor-backend/openspec/specs/agent-template/spec.md |

- **uninstall.sh + SDD_KIT_ASSUME_YES=1**: без вопросов отвечает «да» на «Unregister central store» и снимает регистрацию реального store на машине (найдено при smoke-тесте фазы 6, поведение существовало и раньше). Нужен guard: unregister только при явном `--force` или интерактивном yes.
