# Review: commit 3cc56e7c [bugfix/WEB-2256] PCP shutdown & processing refactor

Reviewed 2026-07-28 by sdd-kit reviewer agents (code-reviewer/opus, python-reviewer/sonnet,
database-reviewer/sonnet) on fresh clone /home/octrow/dev/web-backend-new.
Verdict: **WARNING** - merge only after fixing C1, C2, H1.

Design itself is sound: single shielded shutdown task, phased drain, owner-token
lease with Lua renew/release, PEL-preserving ACK discipline. Findings are about
phase budgets, registration order, and the lease-loss edge, not the state machine.

## CRITICAL

**C1. Lease-loss race can permanently drop post-commit side effects.**
`service/call_processor.py:659-676`: `asyncio.wait(FIRST_COMPLETED)` over
{processing_task, renewal_task}. If both complete on the same tick (renewal fails
right as the DB commit lands), the code takes the renewal-loss branch and discards
`deferred_side_effects` - customer webhook and archive publish are never scheduled.
CallEvent is already terminal, so redelivery is a silent no-op: the webhook is lost
forever, not delayed. Fix: check processing_task first; if it finished, use its result.
Related: `_renew_processing_lease` raises on the FIRST transient Redis error
(`cache_redis.py:542-547` conflates "lease lost" and "Redis raised") - one eval
timeout discards up to 300s of work. Tolerate ≥1 failed renewal within the
120s/30s budget and distinguish the two cases.

**C2. Cleanup closes shared clients under still-running tasks.**
`core/graceful_shutdown.py:258-266`: if tasks survive cancel_timeout (2s), the code
only logs and proceeds to close Redis/RabbitMQ/archive broker/DB pool. A task stuck
in a 300s message timeout or a non-cancellable DB commit then hits closed connections
mid-await. Realistic under load given SHUTDOWN_TIMEOUT=25s vs per-message 300s.

## HIGH

**H1. Drain budget 12s vs message budget 300s -> every deploy strands in-flight calls ≥10 min.**
TASK_DRAIN_TIMEOUT_SECONDS=12 while a telephony message may park 180s in the judge
wait. SIGTERM during a judge wait -> task cancelled pre-commit -> message sits in PEL;
recovery needs TELEPHONY_PENDING_MIN_IDLE_MS=600000, and prod runs replicaCount:1
maxSurge:0 (kz-prod-port.yaml) so no peer reclaims it. Either drain > judge wait,
or stop entering the judge wait once `_is_shutting_down` is set.

**H2. Consumers start before the shutdown manager knows about them.**
`main.py:125-137` starts consumers; registration happens only at :141-175.
SIGTERM during startup -> `_shutdown_sequence` sees no tasks/callbacks, finishes in
~0s, process exits with consumers mid-message and no connection ever closed.
`start_application_services` has no try/except either. Register handlers/callbacks
before creating tasks.

**H3. Poison judge messages retried forever (no DLQ).**
`judge_consumer.py`: rowcount==0 now returns RETRY (previously ACK+log). An
un-fillable message (CallEvent hard-deleted) is XAUTOCLAIM-reclaimed every 5 min
indefinitely, occupying 1 of 5 judge slots. Needs an attempt cap or dead-letter path.

**H4. Telephony capacity double-counts chained same-call messages.**
`telephony_consumer.py:466-511`: `_inflight_message_count` incremented at schedule
time even when the task is queued behind `previous_task` for the same call_event_uuid.
Bursty redelivery of one call starves unrelated calls though real concurrency is low.
Regression from replacing the Semaphore with manual bookkeeping; no test covers it.

**H5. `await asyncio.sleep(0)` as post-commit side-effect "synchronization".**
`call_processor.py:668-673`: gives no completion guarantee for real network side
effects; tests in test_hoist_side_effects_after_commit.py pass only because mocks
have no await points (mock-echo). Remove it or assert eventual completion via the
drained task set.

## MEDIUM (short list)

- M1. Manual `db.close()` inside a still-open `async with` (`call_processor.py:728/829/950`) - works today, fragile to SQLAlchemy changes; restructure into two sequential blocks.
- M2. `execute_cleanup` documents ordered execution but dispatches concurrently (`graceful_shutdown.py:269-277`) - callbacks are independent today; trap for the next one.
- M3. Readiness-exposure sleep runs AFTER connections close (`graceful_shutdown.py:336-342`) - burns grace-period budget, gives kubelet nothing.
- M4. Slow-path judge idempotency is read-then-write TOCTOU; `fill_call_event_empty_judge_fields` UPDATE has no emptiness predicate (`repo/db_write_call.py:207-212`).
- M5. `check_stuck_calls` is the only maintenance step without its own try/except (`main.py:332`) - one Redis blip skips the whole cycle.
- M6. Dead rolling-upgrade branch in `telephony_maintenance.py:65-92` mutates-while-iterating if ever revived - snapshot with `list(...)` or delete.
- M7. `_cleanup_periodic_task` abandons the sweep after 2s, then cleanup closes its deps (`main.py:196-207`) - bounded, but guaranteed shutdown noise.
- M8. Group message timeout doesn't break the group loop (`telephony_consumer.py:620-626`) - timed-out IN_PROGRESS followed by COMPLETED for the same call defeats ordering.
- M9. Lease TTL 120s is only 4x renew interval 30s - narrow dual-processing window under loop stalls; widen margin or fence at the DB layer.
- M10. Inline EVAL instead of EVALSHA for renew/release (`cache_redis.py:588-642`) - avoidable overhead at scale.
- M11. `getattr` re-creation of `_post_commit_tasks` (`call_processor.py:140-166`) exists only to support `__new__`-constructed test objects.

## Static tools (verified)

Real: F401 `core.enum.Message` unused (`call_processor.py:18`).
Dropped as noise: CPY001, radon C/D + PLR0912/PLR0911 on orchestration functions
(linear dispatch, splitting won't reduce coupling).

## Verified as good

- Owner-token CAS lock fixes the prior "any consumer can release" bug.
- judge_report_cache through retry_on_deadlock prevents re-waiting on deadlock retry (WEB-2220 class).
- Hoist-side-effects test pins release-after-side-effect ordering correctly.
- Most new tests assert real behavior, not mock-echo (exception: H5).
