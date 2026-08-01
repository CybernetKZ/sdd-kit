# Team workflow: from signal to merged PR

End-to-end flow (feature or bug) with every tool's plug-in point.
The first diagram is the flow itself; the second maps tools to phases.
Cross-cutting tools (active in every phase) are listed after the diagrams.

This document describes the TARGET process. What is already running vs
still planned is tracked in the **Status** section at the end; planned
pieces are marked *(planned)* in the text.

Grounding: RAISE intake = ADR-0009; task tiers & models = ADR-0010;
epic/flags/handoff seam = ADR-0011; grill/QA/epic clarifications =
ADR-0012; branch & PR gates = ADR-0006; enforcement = ADR-0003, deliberately
advisory today = ADR-0015; testing = `QA-SDD-PROCESS.md` + ADR-0016 (tests are
written from the spec delta BEFORE implementation, and never by whoever writes
the implementation: today the `test-author` agent writes them and a human QA
validates; human QA owning the step is the target).
The per-task orchestration lives in the `feature-flow`
skill (features) and `incident-flow` skill (bugs/incidents) - this diagram
is those skills drawn as one picture.

```mermaid
flowchart TD
    %% ============ RAISE INTAKE (above the dev process, ADR-0009) ============
    subgraph RAISE["0 · RAISE intake (company process)"]
        FEAT["Feature request<br/>(business / Rashid)"]
        FORM["Request form + RICE score<br/>(requester, validated by process owner)"]
        BOARD["Voicebot + LLM board:<br/>monthly review / urgent ad-hoc path"]
        BUG["Bug signal<br/>(Telegram: 'something broke')"]
        BUGREP["Bug report ticket (immediately,<br/>no RICE): env, Dialogue ID, steps,<br/>actual/expected, priority"]
        YT["YouTrack ticket WEB-XXXX<br/>accepted into a sprint"]
        FEAT --> FORM --> BOARD --> YT
        BUG --> BUGREP --> YT
    end

    %% ============ INTAKE + TIER ============
    subgraph INTAKE["1 · Check / inspect + tier (feature-flow 1, 1b · incident-flow 1, 2)"]
        READ["Interrogate the ticket:<br/>cross-check claims against code & specs;<br/>missing RICE form = warn, not block"]
        INC["Bug only: collect evidence<br/>(CybernetKZ/incident_collect,<br/>needs its .env configured) -> root-cause doc"]
        CLASS{"Root cause?"}
        STOPDOC(["Client misuse / infra: the root-cause<br/>doc IS the deliverable. Ticket comment +<br/>status via youtrack-mcp; the ticket author /<br/>process owner closes it, not the dev<br/>(interim decision, ADR-0012)"])
        Q{"Serious business fork?"}
        ASK["Ask author (ticket comment);<br/>meanwhile build a PROTOTYPE on the<br/>recommended answer - marked as such,<br/>with a request to verify it"]
        NOTE["Non-blocking gaps: note assumptions,<br/>ask + proceed on recommended answers"]
        TIER["Pick tier: light / standard / deep<br/>(heuristic table below; dev may override;<br/>tier + why -> into the change)"]
        READ --> Q
        Q -- "yes" --> ASK --> READ
        Q -- "no" --> NOTE --> TIER
    end
    YT --> READ
    BUGREP -.-> INC --> CLASS
    CLASS -- "misuse / infra" --> STOPDOC
    CLASS -- "code bug" --> READ

    %% ============ PLAN ============
    subgraph PLANNING["2 · Plan (OpenSpec change) (feature-flow 2 · incident-flow 3)"]
        RESEARCH["deep tier only: research architecture<br/>options, compare, write ADR"]
        PLAN["planner agent (opus): /opsx:propose -<br/>proposal + spec deltas + tasks<br/>(ticket id, tier + why inside)"]
        GRILL["standard/deep: plan-griller agent (opus)<br/>grills the plan, the dev answers (ADR-0012) -<br/>edge cases, rollback, migrations, cross-service;<br/>unanswered -> question to the ticket author.<br/>Q&A recorded as '## Grill' section in proposal.md"]
        POK{"Plan holds?"}
        RESEARCH --> PLAN
        PLAN -- "standard/deep" --> GRILL --> POK
        POK -- "no: fix plan, not code later" --> PLAN
    end
    TIER -- "deep" --> RESEARCH
    TIER -- "standard" --> PLAN
    TIER -- "light: minimal change<br/>(why + what + regression test)" --> PLAN

    %% ============ QA: TESTS BEFORE CODE ============
    subgraph QAF["3 · Tests from the spec delta, BEFORE code (QA-SDD-PROCESS.md, ADR-0016)"]
        QAVAL["Validate the spec delta:<br/>every Requirement has a measurable<br/>Scenario (WHEN/THEN), edge cases covered,<br/>no conflict with existing contracts"]
        QOK{"Spec delta<br/>testable?"}
        QATESTS["test-author agent writes tests from<br/>Scenarios - one test (or explicit skip)<br/>per Scenario, tracer '# spec: requirement /<br/>scenario'. The implementer never writes them;<br/>human QA ownership = target (ADR-0016)"]
        ADV["Adversarial check: independent agent<br/>tries to refute each test<br/>(green-stub detection)"]
        RED["Tests RED before implementation"]
        QAVAL --> QOK
        QOK -- "yes" --> QATESTS --> ADV --> RED
    end
    POK -- "yes" --> QAVAL
    QOK -- "no: spec delta back<br/>to its author" --> PLAN
    PLAN -- "light: minimal spec delta,<br/>same QA validation" --> QAVAL

    %% ============ IMPLEMENT ============
    subgraph IMPL["4 · Implement (feature-flow 4, 4b · incident-flow 4)"]
        CODE["Branch feature/WEB-XXXX off dev.<br/>Code + spec deltas move together.<br/>The tests already exist - dev runs them<br/>locally while implementing.<br/>Epic: several small PRs; a feature flag only<br/>if it must ship dark (optional, ADR-0015)"]
        RUN1["Run the tests"]
        T1{"Green?"}
        FIX["Fix implementation<br/>(never the tests - not the implementer's)"]
        CODE --> RUN1 --> T1
        T1 -- "no: code wrong" --> FIX --> RUN1
        T1 -- "no: test contradicts its Scenario -<br/>dispute it: back to the test step with the<br/>argument, dev never edits it (ADR-0012)" --> QATESTS
    end
    RED --> CODE

    %% ============ VERIFY ============
    subgraph VERIFY["5 · Verify & review (feature-flow 5, 6 · incident-flow 5)"]
        MANUAL["Manual testing: walk the QA Scenarios<br/>on local/stage; incident: re-run the<br/>incident scenario, record before/after"]
        SDDCHECK["make sdd-check green<br/>(AGENTS.md + openspec validate + spec-lint)"]
        REVIEW["Review: reviewer agents on the diff<br/>(backend-reviewer + database-reviewer,<br/>ECC-derived, ours now)"]
        SCOPE{"Findings in scope<br/>of the ticket?"}
        APPLY["Implement suggestions"]
        TODO["Add TODO/NOTE with ticket id<br/>(no silent scope creep)"]
        RUN2["Run tests"]
        T2{"Green?"}
        MANUAL --> SDDCHECK --> REVIEW --> SCOPE
        SCOPE -- "yes" --> APPLY --> RUN2 --> T2
        SCOPE -- "no" --> TODO --> PR
        T2 -- "no" --> APPLY
    end
    T1 -- "yes" --> MANUAL

    %% ============ SHIP ============
    subgraph SHIP["6 · Ship & handoff (feature-flow 7, 8 · incident-flow 5, 6)"]
        PR["Open PR to dev<br/>[feature/WEB-XXXX] title, test plan in body.<br/>Signals: branch age (2d warn / 5d red),<br/>PR size (xl-ok label needs 'Why XL')"]
        CI["All CI checks are ADVISORY today (ADR-0015):<br/>no branch protection, no required check.<br/>sdd-gate (-> make test (planned)), tbd-gates,<br/>autoreview; traceability + QA quality gates (planned)"]
        CIOK{"Gates green?"}
        MERGE["Merge to dev"]
        HANDOFF["Ticket -> status: ready_to_test<br/>+ comment for QA ≤ 1 paragraph:<br/>what & how to check, flag name + FLAG_NAME=1 if any"]
        QA["QA verifies on stage; if there IS a flag,<br/>it is enabled with FLAG_NAME=1 per the handoff<br/>comment, then the flag owner enables it in prod<br/>(same owner deletes it at expires, ADR-0013);<br/>change archived"]
        PR --> CI --> CIOK
        CIOK -- "no" --> APPLY
        CIOK -- "yes" --> MERGE --> HANDOFF --> QA
    end
    T2 -- "yes" --> PR

    classDef terminal fill:#fdf2e0,stroke:#c93
    class STOPDOC terminal
```

## Tool plug-ins (which tool serves which phase)

```mermaid
flowchart LR
    subgraph PHASES["Flow phases"]
        P1["1 · Intake"]
        P2["2 · Plan"]
        P3["3 · QA tests"]
        P4["4 · Implement"]
        P5["5 · Verify & review"]
        P6["6 · Ship & handoff"]
    end
    YTMCP(["youtrack-mcp<br/>get_issue / comment / move ticket"]) -.-> P1
    YTMCP -.-> P6
    STORE(["openspec store<br/>cybernet-specs: cross-service contracts"]) -.-> P1
    STORE -.-> P2
    GRAPH(["Graphify<br/>repo knowledge graph for inspection"]) -.-> P1
    OS(["OpenSpec<br/>specs + delta-changes, spec-guard hook"]) -.-> P2
    OS -.-> P4
    OS -.-> P5
    GWD(["grill-with-docs<br/>team practice: agent interrogates the plan"]) -.-> P2
    C7(["context7 MCP<br/>library / API docs"]) -.-> P2
    C7 -.-> P4
    ASTG(["ast-grep<br/>bulk mechanical refactors"]) -.-> P4
    CDA(["chrome-devtools-axi<br/>frontend debug/test loop"]) -.-> P4
    CDA -.-> P5
    FLAGS(["feature_flags.py + make sdd-flags<br/>name -> expires registry (ADR-0007);<br/>on demand, not every change (ADR-0015)"]) -.-> P4
    FLAGS -.-> P6
    AGENTS(["reviewer agents + static report<br/>(ruff, radon, complexipy, vulture, semgrep)"]) -.-> P5
    AGENTS -.-> P6
    GHA(["gh-axi<br/>PR / CI ops from the agent"]) -.-> P6

    classDef tool fill:#e8f4e8,stroke:#4a8,stroke-dasharray: 4 3
    class YTMCP,STORE,GRAPH,C7,OS,GWD,ASTG,CDA,GHA,AGENTS,FLAGS tool
```

## Task tiers (ADR-0010)

Tiers scale preparation depth only - **gates never change**: spec always
exists (minimal for light), tests before code, sdd-check, review, CI.
No spec-guard bypass on any tier. Tasks genuinely differ: a small clear
edit ships via light right away; a risky or cross-service one earns the
full spec grilling - the tier decides depth, never whether gates apply.

| Tier | Adds / skips |
|---|---|
| light | minimal spec delta (why + what); no plan grill; the test is still written first by `test-author` - for bugs, the regression test reproducing the incident |
| standard | the full feature-flow above, test flow per QA-SDD-PROCESS.md |
| deep | + architecture research phase (options compared, ADR written) + mandatory plan grill |

Picking the tier - the default comes from this heuristic (dev may
override; the chosen tier + why goes into the change):

| Task looks like | Default tier |
|---|---|
| typo / config value / isolated bug with no cross-service impact | light |
| a regular feature inside one service | standard |
| cross-service change, data migration, new architecture, unknown territory | deep |

Model binding is pinned in agent frontmatter, not in people's memory:
plan and grill run as the `planner` / `plan-griller` subagents
(`.claude/agents/`, `model: opus` - installed by bootstrap, ADR-0013);
tests run as `test-author` (`model: sonnet`, ADR-0016); implementation ->
session model; reviewer agents -> their `model` frontmatter; mechanical
steps -> haiku.

## Epics (ADR-0011, ADR-0012, ADR-0013)

The unit of work is fixed: **1 YouTrack task = 1 PR**. An epic is split
into YouTrack tasks at intake (declared in the tracker, not invented in
tasks.md) - the epic's breakdown and progress live in YouTrack. One OpenSpec
change spans the whole epic (ADR-0011); each task's PR moves its slice of
code and runs the tests that already exist. A feature flag over the epic is
**optional** (ADR-0015) - take one when the half-built state must not be
reachable in prod, not because it is an epic. Exception to 1:1: follow-up
fix PRs for an already-accepted feature may ride the original task.

Suspect an undeclared epic whenever the plan predicts crossing the ADR-0006
signals - >1500 changed lines or >2 days of work for a single PR - and
confirm the split with the ticket author before starting.

Tests for an epic (ADR-0013): written ONCE for the whole change (all
Scenarios, before the first PR); Scenarios not yet implemented stay as
explicit skips (or, with a flag, run behind it while OFF). Intermediate
merges do NOT ping QA - the single `ready_to_test` handoff happens when the
whole change is done on stage.

## Who writes the tests (ADR-0016, ADR-0012)

Today the **`test-author` agent** writes them, in its own context, from the
spec delta - never the person who will write the implementation. Human QA
owning phase 3 is the TARGET state, not the current one. The adversarial
check (a separate agent, never `test-author` on itself) stays mandatory, and
the PR notes that tests were agent-generated without human QA validation -
human QA catches up before the change reaches prod (with a flag: before the
flag is enabled).

For flagless changes (typical light tier) the catch-up point is the
release: **`ready_to_test` holds the release** (ADR-0013) - before
deploying dev to prod, the release checklist verifies in YouTrack that no
shipped ticket is still in `ready_to_test` without a human QA verdict.
This is a process rule (like RAISE), not a CI gate.

## Disputed tests (ADR-0012)

A red test means one of three things, each with its own exit:

1. The implementation is wrong -> fix the implementation (the normal loop).
2. The test contradicts its Scenario -> the dev disputes it: the test goes
   back to phase 3 with the argument "contradicts Scenario X". The arbiter is
   the Scenario text. The dev never edits the test.
3. The Scenario itself is ambiguous -> the spec delta goes back to its
   author (the existing "spec delta back to its author" path).

## Where the named pieces live

| Piece | Place in the flow |
|---|---|
| `feature-flow` skill | IS phases 1-6 for features (its steps 1->8 are marked on the phase titles) - the orchestrator the agent follows |
| `incident-flow` skill | IS phases 1-6 for bugs (steps 1->6 marked on the phase titles); owns the misuse/infra terminal exit; defaults to light tier |
| `QA-SDD-PROCESS.md` | IS phase 3 and the test-related CI gates (planned): validate the spec delta, write tests before implementation, traceability, adversarial check. Who executes the writing step: the `test-author` agent today, human QA as the target (ADR-0016) |
| `AGENTS.md` (+`CLAUDE.md` symlink) | ambient context read by the agent in every phase; existence/size gated by sdd-check |
| `planner` / `plan-griller` agents | phase 2 on opus (`model` frontmatter, ADR-0013): planner writes the change, plan-griller interrogates it |
| `test-author` agent | phase 3 on sonnet (ADR-0016): one failing test per Scenario from the spec delta, tracer `# spec: ...`, RED confirmed; writes test files only, never implementation |
| `spec-miner` agent | repo onboarding only (seed specs one capability at a time), NOT in the per-task loop; OpenSpec has no built-in equivalent |
| reviewer agents | `backend-reviewer` + `database-reviewer` - ECC-derived (commit ec92b528), consolidated from four agents into two; they replace the old `review-pr.md` prompt, locally (`make sdd-review`) and in CI autoreview |

## No magic: prompts vs hooks (what actually enforces)

"Skills", "rules" and "plugins" are marketing names for prompts - instruction
texts injected into the model's context, on every request or at key points.
The model can ignore them: a prompt is advice, never a guarantee. Hooks
(pre-commit, PreToolUse/PreCompact) are ordinary deterministic code bound to
events - e.g. blocking a code edit that has no active openspec change, or
ruff autofix on staged Python before every commit - and cannot be ignored.

Consequences:

- **Enforcement lives only in deterministic code** (hooks + CI gates).
  Prompt-layer pieces (feature-flow, reviewer agents) are advisory - useful,
  but a standard cannot rest on them.
- **And today even the CI half is advisory by choice** (ADR-0015): branch
  protection is off and no check is required, so the only thing that actually
  blocks anyone is local - spec-guard, the `--no-verify` blocker and the
  pre-commit hook. Server-side gates are signals in a log. Turning them into
  real gates is one deliberate decision (required check + branch protection),
  deferred on purpose.
- **Verifiability is mandatory.** Every skill/tool must have a way to confirm
  it actually ran: a measured artifact, a log line, a gate that fails without
  it. Unverifiable pieces get removed - 95% of ~285 installed skills were
  never used once (`docs/archive/OUR_PATTERNS.md`), and `repo-audit` exists to keep it
  that way.

## Prototype instead of waiting

A serious business fork blocks the decision, not the hands: while the ticket
author answers, build a prototype on the recommended answer - explicitly
marked as a prototype, with a request to verify it. The answer either
confirms the direction or the prototype is cheaply discarded; both beat
idling. This never bypasses gates: the prototype lives behind the same
OpenSpec change, and merging still requires the full flow.

## Cross-cutting tools (active in every phase)

Installed per developer machine by `install.sh --machine-only` (core stack, default-yes):

| Tool | What it does |
|---|---|
| **rtk** | compresses shell output in every Bash call (global hook) |
| **ponytail** | minimal working solutions; less code, fewer tokens (plugin) |
| **ast-grep** | structural codemods for bulk mechanical refactors |
| **spec-guard + pre-commit hooks** | block code edits without an active OpenSpec change (not in conversation_flow - LIVING SPEC exception); ruff, hygiene, `make sdd-check` on commit |

Opt-in (y/N): **gh-axi**, **chrome-devtools-axi**, **serena** (earlier trial
left `.serena/` litter; the sdd-doctor audit section flags it). **caveman** is not installed -
it exists only as a benchmark arm inside the ponytail repo; ponytail covers it.

## Status: what runs today vs what is planned

Last verified: 2026-08-01. Update this table when a planned piece goes live.

| Component | Status |
|---|---|
| bootstrap assets: `make sdd-check`, spec-guard, pre-commit hooks, `sdd-ci.yml` (incl. tbd-gates), autoreview, spec-lint, sdd-doctor (incl. audit section) | shipped by sdd-kit - live in a repo once bootstrapped |
| **enforcement model** | **advisory by design** (ADR-0015): branch protection OFF, no required check - sdd-gate / tbd-gates / autoreview are signals, not blocks. Only the local hooks (spec-guard, `--no-verify` blocker, pre-commit) block anything today. Activation of the ADR-0003 model is deferred, not cancelled |
| `feature-flow` / `incident-flow` skills | shipped (`templates/skills/`) |
| `planner` / `plan-griller` agents (model binding for plan/grill) | shipped (`templates/agents/`, ADR-0013) |
| `test-author` agent (tests before code) | shipped (`templates/agents/`, ADR-0016) |
| **feature flags** | **dormant / on demand** (ADR-0015): the registry + `make sdd-flags` ship and work, but no process step requires a flag. Open question: who sets `FLAG_X=1` on stage/prod and where |
| central store (cybernet-specs) | live - consumer is the **agent** reading cross-service specs at intake/planning, not a machine gate (ADR-0015) |
| RAISE intake (form, RICE, board) | company process being introduced (ADR-0009) |
| `make test` single CI entry point (ADR-0003) | **planned** - not yet implemented in any repo |
| human QA owning phase 3 (writes tests before code) | **target state** (ADR-0016) - today `test-author` writes, human QA validates |
| traceability gate (Scenario ⇄ test) in CI | **planned** - no implementation yet |
| QA quality gate in CI | **planned** |
| frontend profile (frontend-reviewer, TS flags variant) | **backlog, low priority** (ADR-0015 p.5) - web-frontend-new gets the standard backend-oriented install |
