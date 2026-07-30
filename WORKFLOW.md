# Team workflow: from signal to merged PR

End-to-end flow (feature or bug) with every tool's plug-in point.
Solid arrows = the flow; dotted arrows = a tool plugging into a phase.
Cross-cutting tools (active in every phase) are listed after the diagram.

```mermaid
flowchart TD
    %% ============ ENTRY ============
    subgraph ENTRY["0 · Signal"]
        BUG["Bug signal<br/>(Telegram: 'something broke')"]
        FEAT["Feature request<br/>(business / Rashid)"]
        YT["YouTrack ticket WEB-XXXX<br/>(Olga / Dina)"]
        BUG --> YT
        FEAT --> YT
    end

    %% ============ INTAKE ============
    subgraph INTAKE["1 · Check / inspect"]
        READ["Read ticket + comments,<br/>cross-check against code & specs"]
        INC["Bug only: collect evidence<br/>(collect_incident.py) → root-cause doc"]
        Q{"Blocking questions?"}
        ASK["Comment on ticket →<br/>ask Dina / Olga / Rashid"]
        READ --> Q
        Q -- "yes" --> ASK --> READ
        Q -- "no" --> PLAN
    end
    YT --> READ
    BUG -.-> INC --> READ

    %% ============ PLAN ============
    subgraph PLANNING["2 · Plan"]
        PLAN["OpenSpec change:<br/>/opsx:propose — proposal + spec deltas + tasks"]
        GRILL["Grill the plan:<br/>edge cases, rollback, migrations,<br/>cross-service impact"]
        POK{"Plan holds?"}
        PLAN --> GRILL --> POK
        POK -- "no: fix plan, not code later" --> PLAN
    end

    %% ============ TESTS FIRST ============
    subgraph TDD["3 · Tests first"]
        TCDOC["Test-cases doc<br/>(what to check & how)"]
        WTEST["Write tests<br/>(pytest + newman e2e)"]
        RED["Run tests → RED<br/>(must fail before implementation)"]
        TCDOC --> WTEST --> RED
    end
    POK -- "yes" --> TCDOC

    %% ============ IMPLEMENT ============
    subgraph IMPL["4 · Implement"]
        CODE["Implement on feature/WEB-XXXX<br/>(code + spec deltas together)"]
        RUN1["Run tests"]
        T1{"Green?"}
        FIX["Fix implementation<br/>(not the tests)"]
        CODE --> RUN1 --> T1
        T1 -- "no" --> FIX --> RUN1
    end
    RED --> CODE

    %% ============ VERIFY ============
    subgraph VERIFY["5 · Verify & review"]
        MANUAL["Manual testing<br/>(run the test-cases doc on local/stage)"]
        SDDCHECK["make sdd-check green<br/>(AGENTS.md + openspec validate + spec-lint)"]
        REVIEW["Review: reviewer agents on the diff<br/>(python/fastapi/database/code)"]
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
    subgraph SHIP["6 · Ship"]
        PR["Open PR to dev<br/>[feature/WEB-XXXX] title, test plan in body"]
        CI["CI gates: sdd-gate +<br/>autoreview (ruff/reviewdog + AI review)"]
        CIOK{"Gates green?"}
        MERGE["Merge to dev → prod pipeline"]
        HANDOFF["Move YouTrack ticket<br/>→ QA / teamlead"]
        PR --> CI --> CIOK
        CIOK -- "no" --> APPLY
        CIOK -- "yes" --> MERGE --> HANDOFF
    end
    T2 -- "yes" --> PR

    %% ============ TOOL PLUG-INS ============
    YTMCP(["youtrack-mcp<br/>get_issue / comment / move ticket"])
    STORE(["openspec store<br/>cybernet-specs: cross-service contracts"])
    GRAPH(["Graphify<br/>repo knowledge graph for inspection"])
    C7(["context7 MCP<br/>library / API docs"])
    OS(["OpenSpec<br/>specs + delta-changes, spec-guard hook"])
    GWD(["grill-with-docs<br/>interrogate plan before code"])
    ASTG(["ast-grep<br/>bulk mechanical refactors"])
    CDA(["chrome-devtools-axi<br/>frontend debug/test loop"])
    GHA(["gh-axi<br/>PR / CI ops from the agent"])
    AGENTS(["reviewer agents + static report<br/>(ruff, radon, complexipy, vulture, semgrep)"])

    YTMCP -.-> READ
    YTMCP -.-> ASK
    YTMCP -.-> HANDOFF
    STORE -.-> READ
    STORE -.-> PLAN
    GRAPH -.-> READ
    C7 -.-> PLAN
    C7 -.-> CODE
    OS -.-> PLAN
    OS -.-> CODE
    OS -.-> SDDCHECK
    GWD -.-> GRILL
    ASTG -.-> CODE
    CDA -.-> MANUAL
    CDA -.-> CODE
    GHA -.-> PR
    GHA -.-> CI
    AGENTS -.-> REVIEW
    AGENTS -.-> CI

    classDef tool fill:#e8f4e8,stroke:#4a8,stroke-dasharray: 4 3
    class YTMCP,STORE,GRAPH,C7,OS,GWD,ASTG,CDA,GHA,AGENTS tool
```

## Cross-cutting tools (active in every phase)

| Tool | Where it lives | What it does |
|---|---|---|
| **rtk** | global hook | compresses shell output in every Bash call |
| **ponytail** | plugin, always on | minimal working solutions; less code, fewer tokens |
| **Headroom** | MCP | context compression on long sessions (append-only — prompt cache survives) |
| **serena** | MCP | symbol-level code navigation instead of whole-file reads |
| **spec-guard + pre-commit hooks** | `.claude/hooks/`, `.git/hooks/` | block code edits without an active OpenSpec change; ruff, hygiene, `make sdd-check` on commit |

**caveman** is not installed — it exists only as a benchmark arm inside the
ponytail repo; ponytail covers it.
