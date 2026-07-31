# Spec-Driven Development Tools

example:

```
1. link github/other main site if not on githuib
2. stars on github if exist
3. commits on github if exist
4. forks on github if exist
5. last update github if exist
6. License (proprietary move down to own section)
7. Git Worktrees:
8. Orchestration Scope:
9. Best For:
10. Maturity:
11. Spec Type:
12. description
```

## Core SDD Tools

https://github.com/Fission-AI/OpenSpec
62.7k stars
695 commits
4.3k forks
last update 3 days ago
License: MIT
Git Worktrees: No
Orchestration Scope: None (agent-agnostic)
Best For: Brownfield changes
Maturity: Production (v1.3.1)
Spec Type: Semi-living (delta markers)
AI coding assistants are powerful but unpredictable when requirements live only in chat history. OpenSpec adds a
lightweight spec layer so you agree on what to build before any code is written.
Agree before you build - human and AI align on specs before code gets written
Stay organized - each change gets its own folder with proposal, specs, design, and tasks
Work fluidly - update any artifact anytime, no rigid phase gates
Use your tools - works with 30+ AI assistants via slash commands

https://github.com/github/spec-kit
124k stars
1574 commits
11.1k forks
last update 3 days ago
License: MIT
Git Worktrees: No
Orchestration Scope: None (agent-agnostic)
Best For: Greenfield projects / Cross-agent standardization
Maturity: Production (v0.8.18)
Spec Type: Static (markdown)
An open source toolkit for building high-quality software with any AI coding agent - a ready-to-use spec-driven
process (or bring your own), endlessly extensible, community-driven, and built for your whole organization.

https://github.com/bmad-code-org/bmad-method
51.2k stars
1983 commits
5.9k forks
last update 4 days ago
License: Open Source
Git Worktrees: No
Orchestration Scope: 21+ role-based agents
Best For: Enterprise workflows / Framework-heavy enterprise planning
Maturity: Stable (v6.8.0)
Spec Type: Static (docs-as-code)
Build More Architect Dreams - An AI-driven agile development module for the BMad Method Module Ecosystem, the best and
most comprehensive Agile AI Driven Development framework that has true scale-adaptive intelligence that adjusts from bug
fixes to enterprise systems.

https://github.com/Priivacy-ai/spec-kitty
1.4k stars
7465 commits
131 forks
last update 2 hours ago
License: MIT
Git Worktrees: Yes
Orchestration Scope: ?
Best For: Parallel development
Maturity: Active Dev (v3.2.5)
Spec Type: ?
A comprehensive research and comparison of spec-driven development (SDD) tools for AI-assisted coding, including
analysis of git worktree support, architectural approaches, and practical recommendations.

## Core Additions

https://github.com/obra/superpowers
286k stars
679 commits
23.4k forks
last update 3 days ago
License: MIT
Git Worktrees: Yes
Orchestration Scope: ?
Best For: Disciplined autonomous dev
Maturity: Active Dev (v5.1.0)
Spec Type: ?
MIT skills framework + methodology; brainstorm -> plan -> subagent TDD
Superpowers is a complete software development methodology for your coding agents, built on top of a set of composable
skills and some initial instructions that make sure your agent uses them.

## Additional SDD Tools

https://github.com/gotalab/cc-sdd
3.6k starts
429 commits
last update 3 mouths ago
License: MIT
Git Worktrees: ? (no)
Orchestration Scope: ?
Best For: ?
Maturity: ?
Spec Type: ?
One command installs an agentic SDLC workflow as Agent Skills: discovery, requirements, design, tasks, and autonomous
implementation with per-task independent review. Works across 8 AI coding agents, with the same 17-skill set on each.
Kiro-inspired. Similar spec-driven, agentic SDLC style as Kiro IDE. Existing Kiro specs remain compatible and portable.

## Need to sort this:

GSD - Meta-prompting SDD system with wave-based context management (63.8K stars)
Ralph Loop - Stateless iterative execution pattern by Geoffrey Huntley
Zencoder/Zenflow - Commercial SDD control plane; free Zenflow desktop app
Kilo Code - Open-source agentic platform with Memory Bank ($8M seed, 1.5M users)
Conductor - macOS parallel agent runner using git worktrees
PromptX - AI agent context platform via MCP (gap entry)
MUSUBI - Maximally-rigorous SDD framework, marginal (~57 stars, stalled)
MoAI-ADK - Go CLI wrapping Claude Code in a SPEC-First Plan->Run->Sync lifecycle with TDD gates (~1.1K stars)
Frame - Electron "Agentic Development Environment" orchestrating parallel agents in isolated worktrees
GRACE - Contract-first Graph-RAG methodology as installable agent skills (XML artifacts, drift detection)
GAAI - Governed autonomous delivery: Discovery -> git-tracked backlog -> Delivery daemon (source-available, ELv2)
Smart Ralph - Claude Code/Codex plugin layering spec phases on the Ralph autonomous loop

---

# License: Proprietary (OUT of ranknig)

## Core SDD Tools License: Proprietary

https://github.com/kirodotdev/Kiro
4.1k stars
70 commits
289 forks
last update last month
License: Proprietary (paid tiers + free tier)
Git Worktrees: no
Orchestration Scope: Single agent + hooks
Best For: IDE experience / AWS-native greenfield projects
Maturity: GA (v0.12.x)
Spec Type: Static (EARS notation)

https://tessl.io/
License: Proprietary
Git Worktrees: no
Best For: Spec-as-source
Maturity: Active Dev (public)

https://www.augmentcode.com/#meet-cosmos
Best For: IDE experience / AWS-native greenfield projects
Maturity: GA (v0.12.x)
Spec Type: Living (auto-updating)
Orchestration Scope: Organization-wide (Experts)
License: Proprietary

## Core Additions License: Proprietary

https://traycer.ai/
License: Proprietary
Git Worktrees: no
Best For: Plan-first orchestration
Maturity: Active Dev

https://cursor.com/dashboard
License: Proprietary (paid tiers + free tier)
Git Worktrees: ?
Orchestration Scope: Single agent
Best For: Developers already in Cursor
Maturity: Production
Spec Type: Pseudo-specs (rules)
Cursor + .cursor/rules

# Sources

1. https://github.com/cameronsjo/spec-compare/blob/main/README.md
   94 stars
   last update 3 days ago
   Research comparing 6 spec-driven development tools (Spec-Kit, Spec Kitty, BMad, OpenSpec, Kiro, Tessl) with git
   worktree analysis and decision frameworks
   visual: https://cameronsjo.github.io/spec-
2. compare/
2. https://freedium-mirror.cfd/https://medium.com/@wasowski.jarek/comparing-15-spec-driven-development-frameworks-sdd-c052df529274
3. https://freedium-mirror.cfd/https://medium.com/@wasowski.jarek/sdd-designing-a-spec-that-survives-code-generation-spec-first-spec-driven-development-b61fdc234493
4. https://redreamality.com/blog/-sddbmad-vs-spec-kit-vs-openspec-vs-promptx/
5. https://www.augmentcode.com/learn/gsd-stars-spec-driven-dev-claude-code
6. https://kiro.dev/
7. https://tessl.io/blog/tessl-launches-spec-driven-framework-and-registry/
8. https://docs.tessl.io/use/spec-driven-development-with-tessl
9. https://www.augmentcode.com/tools/best-spec-driven-development-tools
10. https://cameronsjo.github.io/spec-compare/
11. https://ranthebuilder.cloud/blog/i-tested-three-spec-driven-ai-tools-here-s-my-honest-take/
12. https://www.reddit.com/r/ClaudeAI/comments/1tnt93b/any_review_about_spec_driven_development/
13. https://www.infoq.com/articles/enterprise-spec-driven-development/
14. https://www.reddit.com/r/ClaudeCode/comments/1t9xpeg/does_the_spec_driven_development_actually_works/
15. https://www.marktechpost.com/2026/05/08/9-best-ai-tools-for-spec-driven-development-in-2026-kiro-bmad-gsd-and-more-compare/

 