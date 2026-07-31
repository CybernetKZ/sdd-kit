рекомендации специалистов:
W17
- **Restructure skills as folders**: move any single-file skill prompts to directories containing `prompt.md`, scripts, references, and templates — enables progressive disclosure and keeps context window lean
- **Add a Gotchas section to each skill**: maintain a running log of Claude's past mistakes inside the skill folder so the same errors don't recur across sessions
- **Avoid over-specifying steps in prompts**: provide context and constraints, then let Claude determine execution — over-prescribing steps reduces adaptability
- **Lazy-load supplementary files**: keep reference docs and templates in the skill folder but don't include them by default; pull them into context only when the task needs them
- **Install Playwright CLI for browser automation**: use it instead of the built-in Claude+Chrome tool in Claude Code — more reliable and token-efficient; supports click, scroll, JS execution, screenshots
- **Enable Computer Use MCP in Claude Code**: `/mcp` → scroll to Computer Use — unlocks full desktop and native app automation including iPhone simulator testing and autonomous agentic workflows
- **Add Huashu Design skill**: clone from GitHub and load into Claude Code to get Claude Design-level outputs (web apps, mobile prototypes, slide decks, motion design) without hitting Claude Design weekly usage limits
- **Add Impeccable skill**: 23 commands for polishing individual UI components inside Claude Code
- **Consider UIUX Pro Max skill**: domain-aware design guidance for Claude Code, a stronger replacement for generic frontend design prompts
- **Adopt an agentic OS pattern**: pair Claude Code with Obsidian for persistent memory and organize work into portable skill packs — skills remain compatible with Codex if you want to switch models
- **Watch for Opus 4.7 long-context regression**: avoid 500K–1M token contexts with Opus 4.7 until fixed; Opus 4.6 is more stable at that range
- **Track OpenClaw and Claude Code co-work integration**: emerging agentic coding environments worth evaluating for multi-agent workflows
W18
### Immediate / high-priority
- **Evaluate RooFlow** — open-source multi-agent layer for Claude Code that auto-routes subtasks to cheaper vs. more capable models; claimed 50% token savings and 2.5x session extension. High priority if you run complex multi-step coding tasks.
- **Check Anthropic's Managed Agents API** — new feature from Anthropic; review their docs for configuration options that may affect how you set up or orchestrate agents.
- **Audit and expand Claude Code hooks** — PreToolUse, PostToolUse, UserPromptSubmit, and Stop hooks are your primary lever for observability, destructive-action prevention, auto-formatting, and completion alerts. Your ECC hooks profile is "minimal" — review coverage gaps now that these are clearly load-bearing in production agent setups.
- **Harden Claude Code secrets handling** — audit all skills and MCP servers cloned from GitHub for prompt injection; strip JSONL transcript files of secrets and env vars. Deploy **Invisible** secrets manager (app.invisible.com) so API keys never reach Claude's context window.
- **Adopt Claude Code agent teams** — define reusable role-based agents (security, frontend, backend, CI/CD) under `~/.claude/agents/` with shared task lists and inter-agent messaging. This maps directly onto your existing ECC agents folder and Opus 4.6 sub-agents.
- **Add `mcp.json` to project repos** — commit a `mcp.json` alongside `CLAUDE.md` so all team members share the same MCP tool configuration automatically (per @nocode.joshua / Claude Code creator tip).
- **Use `/memory` command in Claude Code** — inspect and manually edit what Claude has stored about your project; use `/compact` proactively before context overflow rather than after.

### Skills to install into Claude Code
- **Impeccable 3.0** — 23 frontend design commands + live browser editing mode (reference: impeccable.style)
- **Caveman skill** — enforces concise Claude responses; saves ~5% tokens and reduces verbosity across all sessions
- **Stop Slop skill** — strips AI writing giveaways (em dashes, filler phrases) from output
- **Context Engineering skill** — reduces tokens per response to avoid hitting usage limits
- **UI/UX Promax skill** — built-in database of 50+ UI styles and 99 UX guidelines
- **Remotion skill** — lets Claude drive the Remotion video editor from a text prompt (also works via `nategold.ai` CLI workflow)
- **Marketing Skills by Corey Haynes** — 23 marketing agents (SEO, copywriting, email sequences) in one install
- **Excalidraw skill** — generates editable Excalidraw diagrams from prompts
- **n8n MCP server** — official MCP for Claude Code/Codex to build n8n automations with TypeScript validation; worth adding if you use n8n
- **Banana skill** — uses Google AI Studio API for image generation/room redesign via `/banana` slash command; lightweight example of wrapping an external image API as a Claude Code skill

### CLAUDE.md / context engineering
- **CLAUDE.md as agent brain** — store timing rules, API endpoints, scoring logic, and workflow instructions directly in `CLAUDE.md` to give Claude persistent context across sessions (validated by @adamstewartmarketing Arcads pipeline)
- **Brain voice markdown file** — inject writing-style examples via a `CLAUDE.md`-style file to lock tone for any content generation workflow
- **Claude Code skills built on Karpathy's 4 principles**: think before coding, simplicity first, surgical changes only, goal-driven execution — encode these in your skill scaffolding prompts
- **`/status line`** — run this in Claude Code to keep context window % visible; act before hitting 80%+ to avoid degraded output quality
- **Plan-before-code discipline** — per the Claude Code creator: always ask Claude to Q&A the codebase first, then produce a plan, then implement; reduces wasted context from wrong-direction code

### Memory and persistence
- **Claude Memory API** (Anthropic Agent SDK) — persistent, file-based memory stores shared across multiple agents; evaluate for replacing ad-hoc CLAUDE.md state
- **Claude Routines** (Claude Desktop) — schedule recurring Claude Code sessions in the cloud with Gmail/Google Calendar connectors
- **Pinecone + Obsidian 3-tier memory OS** — (1) fixed strategic memory, (2) full conversation recall via Pinecone vector store, (3) strategic awareness dashboard; useful if you want cross-session RAG without the Memory API
- Enable **Claude memory** in Settings → Capabilities and configure **custom response style** by feeding Claude samples of your own writing

### MCP servers and connectors
- **Blender, Adobe Suite, Autodesk Fusion MCP connectors** — now available from Anthropic; check if relevant to your workflows
- **Zapier** — use as a Claude integration bridge for tools not yet covered by native MCP servers (8,000+ tool connections)
- **Apify MCP** — single API key gives agents access to scrape TikTok, LinkedIn, X posts with full transcripts and metadata
- **Meta Ads MCP/CLI connector** — campaign management and metrics from Claude Code
- **Higgsfield MCP** — multimodal tool hub (GPT images, Cling, Nano Banana) for media automation workflows
- **Picsart CLI MCP** — access image/video/audio models from Claude Code
- **Claude Connectors** (Gmail, Google Drive, Notion) — connect via Claude Desktop settings for direct tool access from chat
- **Figma MCP** (via Claude Cowork design plugin) — design skill + Figma connector bundled; worth evaluating if you do UI work

### Agent design
- **Three-component agent structure** (per Anthropic engineer): every agent needs exactly (1) an environment, (2) a connected tool, and (3) a system prompt — nothing more to start
- **Automate vs. autonomy decision tree** — before building an agent, decide explicitly whether each step needs human approval; encode the decision in the system prompt rather than hardcoding behavior

### Rate-limit management
- Use **Claude Haiku or Sonnet** (not Opus) for routine/repetitive tasks to preserve rate-limit credits
- Use **Claude Projects** as knowledge-base folders so context persists across chats without re-uploading files
- Start new chats frequently and summarize context rather than letting single sessions grow unbounded

### Tools worth evaluating
- **DeepSeek V4 Flash** — open-weight model at ~10% of frontier model cost; benchmark near Claude Opus on coding tasks; worth testing for high-volume agentic subtasks
- **Graphify** — knowledge graph layer for Obsidian/RAG; multimodal (PDFs, screenshots, Whisper audio); claims 71.5x fewer tokens per query vs raw file reads
- **Browser Harness** — self-improving Playwright agent that updates its own skill file after each run
- **Design Extract** — headless browser scraper that generates full design systems from any target website
- **Claude Video** — ffmpeg-based frame extraction + Whisper audio to give Claude Code video comprehension
- **Codeburn** — token/cost analytics dashboard across 16 AI coding tools with optimization suggestions
- **Hermes Agent** — auto-generates reusable skills from repeated prompts and runs background reflection on conversation logs; evaluate for Claude Code skill generation workflows
- **Open Design** — open-source Claude Artifacts alternative (GUI); connects to Claude Code via local CLI, draws from your Max subscription rather than API credits
- **Wushi Design** — terminal-based Claude Artifacts clone; faster and more flexible than Open Design
- **OpenClaw** — open-source Claude/OpenAI UI now supporting multi-agent orchestration and Slack thread integration; also supports local models (Google Gemma) for provider independence
- **Anthropic Claude Design** — new first-party feature: text prompt → interactive prototype/design system in one conversation; check current availability on your plan
- **Claude Cowork** — 15 free plugins bundling pre-built Skills + MCP connectors (marketing, productivity with memory, design with Figma); custom plugin creation now available

### Prompt modifiers to add to your toolkit
- **`LANDMINE`** — append to any plan prompt to surface hidden risks before execution
- **`V10`** — append to get 10 response variants and pick the best
- **`/caveman`** prefix — cuts output verbosity ~75%, useful for routine code generation
- **Meta-prompt after good output** — ask Claude to act as an expert prompt engineer and explain how you could have requested that result directly; builds prompt precision faster than trial and error (per @the.rachelwoods)

### Watch
- **"Cyrus" daemon** (Anthropic, unreleased) — persistent 24/7 Claude Code session manager with scheduled workers and push notifications; watch for official release as it may replace manual Routines setup

W19
### Claude Code CLI
- **Claude Code Auto mode (`Shift+Tab`)**: reduces permission interruptions without fully bypassing safety — enable for autonomous runs.
- **`claude project purge`** (run `--dry-run` first): clears stale session data, transcripts, and trust state between major feature phases.
- **`claude mcp add <name>`**: install MCP servers scoped to local/project/global; use **mcpmarket.com** to discover servers (Figma, Blender, GitHub, Playwright, Context7, Supabase, Higgsfield, Browserbase, Notion, Gmail+Calendar, Slack).
- **Custom context handoff + `/clear`**: replace Claude Code's autocompact with a manual handoff-document pattern to prevent recency-bias context pollution.
- **`/schedule`**: built-in CLI command for natural-language scheduled agentic workflows running on Anthropic servers; configure MCP connectors via the Claude AI web app settings (local configs don't apply to cloud-scheduled runs).
- **`/ultra` (ultra-review)**: multi-agent PR review for complex pull requests.
- **`/insights`**: audit your Claude Code usage patterns.
- **`/loop`**: repeating cron-style prompts within a session.
- **Watch KV cache sizing**: monitor KV cache usage/size when running long Claude Code agent sessions to avoid unexpected slowdowns or cost spikes.

### Skills and prompts
- **Claude Skills (`skill.md`)**: create custom skill files to define persona, tone, and automated workflows — load them as context modules for repeatable Claude behaviors.
- **Anthropic's 33-page Claude Skills guide**: official blueprint for creating reusable skills/instructions that Claude applies automatically — read before authoring skills.
- **Skill Creator plugin** (`/plugin` → Skill Creator): Anthropic's official plugin uses multi-agent eval loops to iteratively improve skill descriptions automatically.
- **Modular nested skills**: one skill per tool (e.g., GWS CLI for Google Calendar), composed into higher-level workflow skills.
- **Communication-style context pattern**: combine chat history + personality notes as Claude context to mimic a specific person's communication style.
- **Prompt patterns** (from @sabrina_ramonov): append "ask me clarifying questions until you're 95% confident"; use "be my sparring partner, identify my blind spots"; use "reflect on this conversation and turn repeatable tasks into skills I can reuse later".
- **"Boil the ocean" prompt** (Gary Tan): explicit instruction pushing Claude toward full task completion without pushback on scope — useful for autonomous/long-running runs where you want persistence over incremental check-ins.
- **General Instructions** (system prompt personalization): Settings → General Instructions → Personalize with your bio.
- **Design mode**: left sidebar → Design, for slide decks, websites, prototypes.
- **Claude Code design skill**: free GitHub prompt with 20 universal design rules for consistent UI/slide output.
- **Designer skills** (installable): Front End Design, UI/UX Pro Max (50+ UI styles, 99 UX guidelines), Canvas Design (outputs PNG/PDF).
- **Claude agent templates for financial services**: pre-built plugins for pitch decks, wealth management, month-end close — check Settings → Plugins if your workflow overlaps.
- **Anti-AI-tells skill file**: add a compressed version of Wikipedia's "Signs of AI Writing" list to your Claude system prompt/skill file; run post-draft checks to suppress m-dashes, "delve", negative parallelism, and other common LLM writing patterns.
- **Comparative prompting**: ask Claude to compare two options rather than validate one — reduces sycophancy in responses.
- **Auto skill builder**: capture corrections/patterns from your Claude session history and auto-generate a new skill file from them — good weekend project for keeping skills current with how you actually work.

### Memory and context
- **CLAUDE.md memory folder pattern**: daily memory files in a dedicated folder, referenced by CLAUDE.md — keeps persistent context across sessions.
- **Obsidian as memory layer**: Karpathy's raw/wiki/output vault structure as a lightweight alternative to vector RAG; add a `CLAUDE.md` in the vault to define memory structure and agent behavior.
- **Graphify**: point at your entire workspace so Claude Code builds a knowledge graph before important tasks.
- **Context-pruning pattern**: summarize prior turns into a compact state object (goals, decisions) every N turns for long-running agents; Claude Code does this automatically in the background.
- **gbrain** (Gary Tan/YC, open-source): self-writing knowledge graph that outperforms vector-only RAG by 31 points — worth evaluating as a memory/recall layer.
- **`v1/dreams` API**: Anthropic endpoint for automated agent memory consolidation and deduplication — integrate into long-running agent workflows to keep memory stores clean.
- **Open Brain** (open-source): model-agnostic personal memory layer; worth evaluating as a Claude memory alternative for cross-model setups.

### MCP and integrations
- **Zapier MCP** (`mcp.zapier.com`): safe MCP server layer between agents and business apps (Gmail, Slack, Notion, HubSpot); scope permissions per tool to reduce prompt injection risk.
- **GWS CLI** (Google Workspace): install in a Claude Code workspace for access to Google Calendar, Gmail, and Drive.
- **Playwright CLI**: gives Claude Code a persistent browser for automation and UI-task workflows.
- **Higgsfield MCP**: connect via CLI to generate images and videos programmatically inside Claude Code or any CLI-connected agent.
- **Browserbase MCP**: autonomous web browsing inside Claude Code.
- **GitHub MCP**: repo management (issues, PRs, code search) from Claude.
- **Notion MCP**: read/write access to Notion workspaces.
- **Gmail + Google Calendar MCP**: inbox and calendar management from Claude.
- **Slack MCP**: read channels and draft replies from Claude.
- **Google Stitch → MCP → Claude Code**: design UI in Stitch, export via MCP server, feed into Claude Code for production frontend generation.
- **Hyperspace pods**: CLI tool that meshes multiple laptops/machines into a distributed AI supercomputer exposing an OpenAI-compatible API — pluggable into Claude Code or Cursor as an alternative model backend.

### Agentic workflow patterns
- **Codebase tour before coding** (Eric Sluntz, Anthropic): spend 15–20 min giving Claude a codebase tour in a *separate* conversation, build the plan together, then execute — treat Claude as executor not reviewer.
- **Point Claude at leaf nodes**: features with no dependents; keep humans on core architecture.
- **Design for verifiable I/O**: human-readable inputs and outputs so you can trust agent output without reading every line.
- **GSD framework + agent self-awareness**: add a planning step where the agent identifies which MCP servers it needs, then generates custom skills scoped to each autonomous loop before starting.
- **Domain → task → skill → automation pipeline**: codify repeated prompts into reusable skills, then wire skills into automated workflows.
- **Octogen**: open-source orchestrator for running multiple parallel Claude Code agents on one project with shared context and a single dashboard — useful for splitting large tasks by concern (DB, API, frontend).
- **Proactive agent pipelines**: build email triage and calendar management agents now using predictable workflows; avoid deploying vibe-coded AI-generated code to production without review.
- **Hallucination mitigations**: enable web search in Claude, use extended thinking on paid plans, ground answers in your own documents via RAG (NotebookLM), and explicitly prompt Claude to self-check citations after responding.
- **Weekend AI build projects** (@qbuilder): screenshot-to-code (vision model → React), AI daily digest (scraping + summarization + cron), content repurposer (prompt chaining across platforms), AI inbox triage (Gmail API + AI drafting agent) — small, scoped projects to extend your Claude setup incrementally.

### Multi-model and cost strategy
- **Run Claude Code + Codex in parallel**: route tasks to each based on strengths; Codex handles more usage at lower token cost.
- **Claude Router**: proxy tool letting Claude Code use alternative models (e.g., Deepseek V4) — 7–40x cheaper than native Anthropic API for bulk automations.
- **Run Claude Code with Gemma 4 via Ollama**: eliminates token costs on repetitive agent tasks entirely.
- **LM Studio / Ollama**: free local model runners worth setting up now as Claude Code pricing on the $20/mo plan may change.
- **Kimi K2.6** (Moonshot AI): open-source model with strong coding benchmarks, 300 parallel agents, 4000-step workflows, API 7x cheaper than Claude Opus — evaluate as a cost alternative for agent-heavy tasks.
- **Omnara** (`omnara.com`): voice + cloud-persistent sessions for Claude Code/Codex — keeps coding agents running with laptop closed.
- **OpenCode CLI**: model-agnostic Claude Code alternative for local-model or multi-model agentic workflows.
- **Model tier for autonomous agents**: Claude Opus extracts ~$2.68 more per sale and pays ~$2.45 less per purchase than Haiku in negotiation tasks — use Opus for agentic workflows where transaction outcomes matter.
- **Google's free coding tool suite** (Antigravity, Opal, Stitch, Jules): worth trying alongside Claude Code — Jules in particular for GitHub-connected autonomous bug/feature work, as a free complement to paid agent usage.

### Learning resources
- **Anthropic Academy** (free): courses on Claude Code, Claude.ai workflows, and MCP with completion certificates.
- **Claude Certified Architect certification**: first 5,000 registrations free.
- **Anthropic AI Fluency for Students** course: free introductory course.
- **Arena** (`lmarena.ai`): free multi-model playground with Claude, Gemini, Grok, ChatGPT in one place — useful for quick model comparisons without separate subscriptions.

### Notable open-source repos
- **MattPocock/skills**: Claude Code skills directory from a production engineer.
- **Ruvnet/Ruflo**: Claude Code agent orchestration with multi-agent swarms, self-learning, and RAG.
- **Virattt/Dexter**: autonomous deep research agent (reads SEC filings, news, earnings calls → structured report).
- **1jehuang/JCode**: lightweight Rust-based coding agent harness for Claude Code.

W20
**Claude Code core workflow**
- **Install the Graphite plugin for Claude Code** — builds a persistent knowledge graph from your PDFs, markdown, and code; invoke via `/graph`; cuts token usage ~70x by replacing grep-style context with thematic graph links. Visualize the graph by opening its data folder as an Obsidian vault.
- **Add the Claude Council skill** (by Ole Lemon) — spins up 5 sub-agents attacking a decision from different angles, then synthesizes into one verdict; directly counters sycophantic single-pass answers for high-stakes choices.
- **Use `/goal` command** for long-running agentic tasks with explicit success conditions — pair with plan mode first, then let Claude run autonomously turn-after-turn (API migrations, doc implementation, issue backlog clearing).
- **Use `claude agents`** to open Agent View dashboard for managing multiple concurrent sessions from one terminal UI.
- **Configure a custom statusline** (`statusLine` key in `settings.json`) with a shell script to surface model/token usage, git branch, and working directory at a glance.
- **Use `/resume`** to recover and continue crashed or past Claude Code sessions instead of rebuilding context from scratch.
- **Build a personal slash-command palette** — drop markdown files into the slash-commands folder for repeatable personal workflows.
- **Skip agent frameworks for simple agent loops** — a bare LLM call + tool runner + while loop is enough; fewer deps, full control, easier to debug.
- **Always review agentic Claude Code actions** before deployment; never run Claude Code unsupervised against production databases.
- **Install Ruffle** — open-source multi-agent framework for Claude Code that runs 60+ coordinated agents with shared memory and automatic cheap-vs-powerful model routing; worth evaluating for complex research or testing pipelines.
- **Try PAI, OpenSpace, and GSD** — three complementary Claude Code GitHub repos: PAI adds a custom status line/personal AI infrastructure layer, OpenSpace gives Claude Code access to local or API-based sub-agents (e.g. offloading to local Qwen models), and GSD provides a plan-then-execute workflow for low-babysitting autonomous task completion.
- **Watch Google Jules** as an alternative/complement to Claude Code and Cursor for goal-based async coding tasks that run continuously without per-prompt supervision.
- **Try Open Design (GUI) or HuaWu Design (terminal skill)** as free, local, open-source alternatives to Cloud Design that can attach to any coding agent, including Claude Code.
- **Consider Hyperspace Pods** to mesh multiple machines' VRAM into a shared local model cluster exposing an OpenAI-compatible endpoint pluggable into Cursor or Claude Code — useful for running larger local models without per-token API cost.
- **Consider local hardware for heavy usage** — high-RAM Apple Silicon (e.g. M4 Mac Studio, 500GB RAM) paired with OpenRouter as an API gateway can help sidestep cloud usage limits when running large local models alongside Claude Code/Codex.

**Context engineering and memory**
- **Use the `.claude` root folder** as a cross-project skills/memory layer — persistent markdown files, hooks, and context injection share insights across sessions.
- **Treat `CLAUDE.md` and Claude Skills files as living documents** — update them after each session based on AI feedback to iteratively improve future sessions.
- **Add a `claude.md`** to the root of any large vault or repo documenting folder structure, navigation patterns, and format conventions so Claude Code writes files natively without token waste.
- **Ask Claude Code directly** to suggest project-specific slash commands, hooks, and skills to improve your workflow — it can introspect its own environment.
- **Use Stagewright** to gate available MCP/CLI tools per workflow phase (plan → read-only, implement → edit-only, validate → Playwright-only) to reduce context noise and improve output quality.
- **gbrain skill pattern** — store agent capabilities as self-contained markdown skill files; use "skillify" to extract a workflow you ran manually into a reusable skill.
- **Drop a Refero Style design.md** into your repo or as a Claude skill so coding agents pull exact design tokens instead of generic defaults.
- **Claude session memory (4-file system)**: maintain `memory.md` (project index), `agents.md` (behavior rules), a daily log, and per-project context files in a `projects/` folder — Claude reads them at session start for persistent state across sessions.
- **Agent Memory MCP server** (51 tools, ~5K stars) — auto-captures decisions, files touched, and blockers in Claude Code/Cursor each session; eliminates cold-start context re-entry. Consider layering it under a manually curated 4-file system: auto-capture for solo work, manual curation for client/sensitive work.
- **Claude Code hooks**: configure `PreToolUse`, `PostToolUse`, and `Stop` hooks in `.claude/settings.json` as shell commands for auto-commit, auto-format on edit, and destructive-action confirmation guards.
- **Git worktrees for agent parallelism**: use `--worktree` isolation when spawning Claude Code subagents so each agent operates on its own branch/directory, eliminating edit conflicts.
- **Try Hermes** (open-source agent by Nous Research) for a self-hosted agent that writes and refines its own markdown "skills" files, integrates with Telegram/Discord/Slack/Signal, and spawns subagents for larger tasks — an alternative pattern to Claude Code-centric setups for teams wanting a model-agnostic agent core.

**MCP servers worth installing**
- **Build custom MCP servers** with `mcp` Python package + `FastMCP` — deployable and connectable to Claude in ~9 lines.
- **Apideck MCP server** — single MCP connection to 200+ SaaS platforms (accounting, CRM, file storage, task management); worth evaluating for any agent needing multi-service integrations.
- **Facebook Ads MCP** — add via Settings > Connectors > Add Custom Connector to pull ad analytics and manage campaigns directly from Claude; pair with **Higgsfield MCP** to generate and auto-upload ad creatives.
- **Higgsfield MCP** — install via Claude connectors to access GPT Image 2 and CogVideoX 2.0 for image/video generation inside Claude; useful for UGC ad creation from a single prompt.
- **Agentic CRM via MCP** — pipe Slack/Gmail into Claude Code to build a centralized contacts + interaction history database for meeting prep and action-item automation.
- **Blotato MCP** — social media post syndication and analytics inside your agent; pairs well with Claude Code content pipelines.
- **Canva connector** — add via Settings > Browse Connectors for in-chat brand-kit-aware design generation and carousels.

**Headless and automation patterns**
- **Headless Claude Code via cron** — `claude -p` with bash scripts to schedule tasks on a timer; pass system prompts and MCP server configs via project directory. **Pricing alert**: headless use on MAX plan now draws from a $200/mo API-rate pool separate from the flat subscription (~$1/3 min burn rate) — audit your headless usage and consider **Codex CLI** as a cost-comparable fallback.
- **Cortex OS / 24/7 daemon pattern** — run Claude Code and Codex agents as persistent daemons with shared kanban boards and cron-injected prompts for async multi-agent collaboration.
- **Cron-based agent workflows** — schedule agents to scan Anthropic changelog + Hacker News daily, run weekly log reviews, and consolidate memory files automatically.
- **Agent evaluation framework** — define input/output test cases, run a benchmarking runner, print regression reports on each deploy; wire into CI/CD.
- **Postgres job queue** for multi-tenant AI agent systems (jobs table + worker listener + optional recurring scheduler).
- **Multi-model aggregator in Cursor/VS Code** — open-source tool routes a single prompt to ChatGPT, Claude, and other models simultaneously via one config for free side-by-side comparison.
- **Claude + Gmail/Calendar automation prompts** — three reusable patterns: draft email replies in your tone and flag urgent ones, generate daily meeting-prep briefings from calendar + email, and produce a daily competitor/industry intelligence brief via web search.

**Prompt modifiers and system prompt hygiene**
- **`ultrathink` suffix** — activates Claude's extended thinking mode for deeper reasoning before responding.
- **`/confess` prefix** — makes Claude report its own confidence level and where it was guessing.
- **Audit existing system prompts**: remove "think step by step" (redundant on reasoning models that do chain-of-thought by default), "never hallucinate" (counterproductive — increases false confidence), and "world class expert" persona framing (no accuracy benefit per research).
- **Replace hallucination wishes with actionable rules**: "if uncertain, label it" and "if fact-dependent, cite the source" outperform wishful instructions.
- **Avoid open-ended length instructions**; specify format or length constraints rather than maximums like "be as detailed as possible".

**Connector safety**
- In Claude connectors, set read and write tools to **"needs approval"** rather than always-allow to prevent unintended data access.
- Disable **"Help improve Claude"** (and equivalent ChatGPT setting) in privacy settings before connecting work tools.
- Add **"stop and ask with options"** instructions to any Claude playbook step that touches sensitive or irreversible actions.

**Tooling and integrations**
- **Install the Codex plugin for Claude Code** to run `/codex adversarial review` and cross-check Claude Code's output with GPT-5.5; also install **Caveman repo** for token-saving concise output and **NotebookLM-Pi repo** to connect NotebookLM as a CLI tool.
- **Browser Harness** — open-source, LLM-native Playwright alternative that auto-generates and self-improves browser skills per site; works with Claude Code and Codex.
- **Obsidian as Claude Code frontend** — embed an integrated terminal for a dashboard combining file access, custom metrics, and skill launchers; structure vault with a Carpathian layout (raw → wiki → outputs) plus per-folder index files.
- **Remotion MCP** in Claude Desktop (`/remotion video`) for programmatic video editing.
- **Migrate ChatGPT memories to Claude** via `claude.com/import-memory`; alternatively export `conversations.json` from ChatGPT and prompt Claude to ingest it.
- **Anthropic's finance agent templates** (free GitHub repo) — valuation review, model builder, statement auditor; installable to Claude.ai or Claude Code with 8 MCP connectors for live financial data.
- **Grab Anthropic's free certifications** (13 courses) at `anthropic.skilljar.com` — paste a course URL into Claude to extract and auto-install relevant skills before they become paid.
- **Invest in agent orchestration and knowledge graph setup** rather than chasing the latest model — orchestration architecture compounds more than model upgrades.
- **Claude for small business native integrations** — Anthropic now ships toggle-ready connectors for QuickBooks, HubSpot, PayPal, and Canva; no custom integration needed for basic SaaS wiring.
- **Claude Skills as Level 1 AI ops entry point** — build skills/playbooks before attempting agentic or multi-agent workflows; progress to tool-connected agents with memory, then multi-agent orchestration.
- **Always read and understand Claude's output** before accepting it — vibe-coding without comprehension produces code you can't debug or refactor; treat Claude as a pair programmer, not an oracle.

W21
- **Add `guardrails.md`** — create this file and reference it from `CLAUDE.md` to cap unwanted agent behavior; grow it incrementally as issues surface
- **Add pre-tool-use hooks** — in `.claude/settings.json`, ban specific tool calls deterministically (e.g., destructive bash commands via the permissions denylist)
- **Add a `design.md` skill** — drop Google's public UI template into your Claude Code project for consistent UI output; add "UI skills" to upgrade generated website quality to production-ready animated 3D output
- **Enable Claude Code plan mode** — toggle it with Shift+Tab before executing complex tasks to get research + questions + plan first, saving tokens and improving output structure
- **Scope-limit all agentic tasks explicitly** — add confirmation steps before destructive operations; MIT/Stanford/Harvard research shows agents complete tasks literally while causing collateral damage
- **Use Claude Projects** for organizing persistent context and building reusable assistants (e.g., email assistant)
- **Match model tier to task** — use Claude Sonnet 4.6 for routine coding tasks; reserve Opus for complex reasoning only; implement a 3-tier router (Haiku → Sonnet → Opus) in applications to cut API costs; Claude Code agentic workflows are rate-limited under flat plans — heavy use requires paying per-token via the Anthropic API
- **Connect Expo MCP** when doing mobile development with Claude Code
- **Connect RevenueCat MCP + App Store Connect MCP** for autonomous payment/metadata management in mobile apps
- **Explore Claude Desktop Routines tab** for scheduling recurring agentic workflows against a local knowledge base folder
- **Adopt the slash command stack** — `/ultraplan` → `/goal` → `/agents` → `/ultrareview` for long-running multi-agent loops; `/goal` keeps Claude Code looping until done, `/agents` runs sessions in the background
- **Structure agentic workflows explicitly** — trigger → agent harness (Claude Agents SDK or Codex SDK) → skill folder (natural language procedure file) → tools → transcript audit loop; audit transcripts to iteratively refine skill prompts
- **Use `.claude/agents/` directory** to configure Opus orchestrator + Sonnet sub-agents running in parallel, with hooks to visualize what each sub-agent is doing
- **Treat RAG, memory, and agents as context management** — all reduce to loading relevant text into the model at the right time; no magic required
- **Use Claude + AWS CDK skill** to convert system design diagrams into infrastructure-as-code (snapshot diagram → Claude generates CDK with IAM, Lambda, DynamoDB)
- **Install built-in Skills via `/plugin`** in Claude Code (e.g., `frontend-design`) for structured, repeatable workflows
- **Build an Obsidian + Claude Code command center** with a custom plugin for token burn metrics and integrated terminal; extend it with Google Suite integration and domain-specific skill packs as an "agentic OS"
- **Know the Claude product line** — Claude Chat, Claude Cowork (computer use + browser extension), Claude Code (coding agent), Claude Design are separate products for separate use cases
- **If running LLM-as-judge pipelines**: shuffle answer order, instruct judge to ignore response length, use ensemble voting across models, and build eval golden datasets from real production failures (clustered by K-means, not synthetic)
- **Maintain a Claude Code session handoff file** — 3 sections (goal, decisions, resume point) to pass context between sessions without re-explaining; use an HTML implementation notes file (not Markdown) as Claude's working memory/decision audit trail per Trent Kwan's pattern
- **Use `claude --json` flag** (Claude Code v2.1.145+) to pipe structured session output to jq, Postgres, or Discord webhooks for querying agent history
- **Install Claude for Legal** from its GitHub repo for ready-made legal agents (contract reviewer, cease-and-desist writer, policy compliance scanner) usable inside Claude Code
- **Know the 7 Claude Code agent architectures** — basic tool agents, MCP server agents, sequential, parallel, router, human-in-the-loop, and orchestrator/sub-agent; pick the pattern before building
- **Install 11Labs Speech Engine** — one-command install adds voice generation/cloning to Claude Code or Codex agents
- **Evaluate Qwen 3.7 Max** (1M token context, cheaper than GPT) for long-context RAG or agent worker roles where Claude is too expensive
- **Try Hyperspace Pods** if your team has spare laptop VRAM — CLI pools it into a single OpenAI-compatible API endpoint you can paste into Claude Code or Cursor as a drop-in replacement for paid cloud models
- **Evaluate Grok Build** as an alternative to Claude Code for very large codebases — 10M token context, 8 parallel agents, headless/scriptable mode, ACP support
- **Distinguish agent types when designing workflows** — personal assistants, coding/knowledge-work agents (Claude Code, Codex), and deterministic background automation each require different model tiers and architectures
- **Keep an expert (not just any human) reviewing agent runs** to refine prompts and playbook success criteria over time; version playbooks/SOPs as files the agent reads each run to keep docs current
- **Use Anthropic's free AI Fluency course on Skilljar** to build a structured mental model of Claude: delegation, prompting, discernment, and ethics; shift from automation mode (step-by-step prompting) to agency mode (give a goal, let Claude plan and execute) for higher-quality outputs
- **Monitor Anthropic's model cards and safety publications** — documented cases of Claude exhibiting blackmail behavior in test environments traced to training data; build verification structures (source citations, grounding) into agentic workflows rather than relying on system prompt instructions
- **Vet "Claude Flow" (Ruflow) before adopting** — GitHub multi-agent framework claiming 60 parallel agents, automatic model routing, and 75% Claude API cost cuts; verify the growth/star claims independently before trusting it in production workflows
- **Set up GitHub as a shared source of truth across claude.ai, Claude Code, and Claude Cowork** — use a scheduled task for recurring analytics review, a custom "save" command to auto-file and commit generated content (scripts, captions, posts), and a keyword-triggered script to auto-load context/rules per mode
- **Use Claude Code/Codex's `/remote` command or claude.ai/code for phone-based coding**; pair with a Tailscale + Termius SSH setup for a full remote workflow when away from your desk
- **Try the free-llm-api GitHub repo** for high-volume free LLM token access as a stopgap when hitting Claude API/rate limits
- **Explore Daniel Miessler's PAI (Personal AI)** as a scaffolding layer for persistent memory and skills on top of Claude Code or OpenCode
- **Set up OpenCode + Qwen as a fallback coding stack** for continuity when Claude Code is rate-limited or unavailable
- **Add prompt-injection defenses to any MCP/agentic tool setup** — pre-screen inputs with a lightweight classifier, validate outputs before delivery, embed canary tokens in system prompts to detect leakage, and sandbox tool permissions to reduce blast radius; consider managed guardrail services (Azure AI Foundry, Amazon Bedrock) if building this in-house isn't worth the effort

W22
- **Switch to Claude Opus 4.8** in Claude Code (model selector at bottom) — 2.5x faster and 3x cheaper than Opus 4.7, 4x fewer missed code flaws, 84% on browser agent benchmark; leverage effort control to tune cost vs. depth per task
- **Enable dynamic workflows** in Claude Code (`/config` → dynamic workflows), then type `workflow` to generate a `workflow.js` subagent orchestration script stored in `.claude/`; one task can now orchestrate tens–hundreds of subagents for large codebase migrations
- **Try the `/goal` slash command pattern** (task + measurable end state + constraints) in Claude Code/Codex/Hermes to reduce prompt-babysitting and let agents loop autonomously toward a defined end state; test on a small task first due to loop token cost
- **Explore the `/ultra code` setting** for automatic effort scaling on complex tasks, and save recurring agent workflows (e.g., security audits) as custom slash commands, shareable at project or user level
- **Use `/loop` command** for long-running agent sessions (up to 4-hour heartbeat timer) instead of external daemons
- **CLAUDE.md 4-rule set** (Karpathy/Forrest Cheng pattern): add plan-before-coding, simplicity-first, surgical-changes, goal-driven-execution rules to your repo's CLAUDE.md — reported to cut agent mistake rate from 41% to 3%
- **Invest in "harness engineering"**: maintain clear architecture docs/maps, add guardrails (tool permissions, approval points), and strengthen feedback loops (tests, logs, traces) so agents can self-verify changes — the harness matters more than the underlying model
- **Install the Skill Creator skill** to generate, test, and benchmark other skills from within Claude Code
- **Install Caveman skill** (open-source) to reduce Claude Code verbosity and improve answer quality
- **Add anti-sycophancy instruction** to Claude system prompts; optionally add an LLM-as-judge agent for objective evaluation
- **CLAUDE.md / agents.md pattern**: inject identity, user context, and guardrail docs at agent boot via imports in the main context file
- **Graphify**: pre-indexes a codebase into a knowledge graph, reducing session token usage ~70x — worth evaluating for large repos (confirmed by multiple creators)
- **Use one change per prompt** in Claude Code to avoid regressions during iterative development
- **Persistent working memory doc**: maintain a capped markdown file (~500 tokens) for cross-session context management; tell Claude to update it after each session
- **Build focused MCP servers**: write tool descriptions for the model (what triggers the call), not for humans; give each agent only the MCP tools for its specific subtask
- **Top 4 MCP servers to install**: Chrome DevTools MCP (browser driving + console), Filesystem MCP (read/write/search local files), GitHub MCP (Anthropic official — PRs, code search, 40+ actions), Playwright MCP (Microsoft — browser automation for agent test flows)
- **Claude Code `/schedule`**: create persistent cron-driven agent workflows with MCP connectors via Settings → Connectors in the Claude AI web app
- **Skill folder pattern (3-file)**: README + system prompt + JSON schema is enough to wire a Claude agent to external systems (voice, DB, APIs) with minimal config
- **4-file agent template**: adopt `client.md` (context), `playbook.md` (workflows), `roles.md` (guardrails), `journal.md` (agent learning log) as a base install pattern for Claude agents
- **Portable SKILL.md system**: write vendor-agnostic skill docs with operating model + setup checklist — works across Claude, Codex, and Gemini; add a "catch-up" meta-skill that schedules which skills to run daily/weekly/monthly
- **`about-me.md` + `anti-style.md`** in Claude projects: two files that replace dozens of repeated prompts — concrete pattern to adopt
- **Install 1,000+ pre-made Claude Skills** library via terminal into Claude desktop or any AI code editor; covers automation, UI, testing, SEO
- **Claude desktop connectors**: link Google, Notion, Slack so Claude can reference live docs and messages mid-task
- **Claude Projects vs Skills**: use Projects for one-off context sharing; use Skills/Playbooks for repeatable tasks; chain playbooks together and run inside a Project
- **AskUserQuestion tool**: add to Claude prompts so Claude extracts requirements before building; provide specs as HTML (not markdown) and drop screenshots for bugs; use auto mode to reduce token loops
- **Explore GitHub repos**: awesome-claude-code, Superpowers, awesome-claude-skills, Everything Claude Code for community skills and optimizations
- **MCP tunnels + self-hosted sandboxes**: run Claude agents inside your own VPC — unblocks HIPAA/SOC2 compliance requirements
- **Supabase MCP/CLI**: prompt agent to self-identify which MCPs would let it act more autonomously (self-awareness prompt technique)
- **Claude legal skills**: enable free contract reviewer / compliance checker via Claude.ai → Customize → Plugins → "legal"
- **Go High Level MCP server**: connect Claude Code to your CRM via private integration token + location ID for pipeline/contact/inbox control
- **Run Bumblebee** (open-source, Perplexity) to audit your dev machine packages, VS Code extensions, and AI tool configs for known compromises
- **Avoid Copilot integrations**: multiple sources confirm the harness/wrapper is the weak link regardless of underlying model quality — invest in Claude slash workflows instead
- **Vercel Open Agents repo**: use as a reference architecture for building your own agent harness (prompt → DB → workflow → sandbox → streaming UI)
- **Prompt technique**: ask Claude to ask you clarifying questions before responding — improves output quality on complex tasks
- **Consider local inference hardware** (Nvidia DGX Spark or OEM equivalents like Asus GX10 Ascent) for privacy-sensitive or offline agent workloads; check Spark Arena leaderboard and Qwen models for current best performers on Spark-class hardware
- **No new actionable items this week** from @parthknowsai (industry commentary only, no tools/workflows) — nothing to add to setup.


W23
**Claude Code configuration**
- Split your global `CLAUDE.md` into per-project files under 200 lines; add dedicated `SKILL.md` files per tool/workflow
- Enable forked subagents in `settings.json`; use `/fork` for multi-perspective tasks (PR review, architecture decisions)
- Set `context: fork` + `model: claude-opus-4-8` in skill YAML front matter to spawn heavier subagents only when needed, saving tokens on lighter work
- Use `$arguments` variable in skill files so slash commands accept runtime params (e.g. `/docx myfile.md`)
- Add `/schedule` cron-style commands for overnight autonomous workflows (PR review, repo scraping)
- Use `/compact` to reduce token usage mid-session; add `/premortem` and `SteelMan`/`redteam` modifiers for design/architecture critique
- Add a PostToolUse hook in `settings.json` to auto-run your code formatter after every Claude edit (Boris Cherny's pattern — prevents PR formatting failures)
- Adopt the `/orchestrate → /plan → /spec → /implement → /review-loop` slash command pipeline for large features; deploy subagents per spec and per PR review in parallel
- Build a "phased plan" skill that forces Claude Code to break feature work into small, independently testable phases, paired with a "phase implementation" skill that halts after each phase for manual review before continuing — avoids huge unreviewable PRs
- Default to deterministic step-by-step workflows for predictable tasks; only reach for an LLM-driven agent loop (tool access + max iteration cap) when next steps genuinely can't be predicted upfront

**Prompting & caching**
- Place stable content first in system prompts, dynamic content last — maximizes KV cache hit rate (~10x input token cost reduction on repeated calls)
- Use parallel tool calls for independent agent actions to cut latency at no cost
- Put top RAG chunks at prompt start or end to mitigate "lost in the middle" degradation
- Apply the CIIC framework (Context, Instructions, Inputs, Constraints) to all Claude/ChatGPT prompts for more consistent outputs
- Use the LLM Council prompt pattern: structure a single prompt to spawn 5 adversarial advisor personas (contrarian, first-principles, expansionist, outsider, executor) + a chairman synthesis step for high-stakes decisions
- Verify LLM context by prompting it to recall domain-specific facts (product names, pricing, acronyms) before building agent workflows

**Model selection**
- Default to **Claude Sonnet 4.6** for daily coding tasks where speed and cost matter; escalate to **Opus 4.8** only for architecture review or complex reasoning subagents
- **Claude Opus 4.8** — same price as 4.7, better reasoning with adjustable thinking budget (high/medium/low); use thinking-budget control to manage token costs on Opus tasks
- Claude Sonnet 4.6 demonstrated strongest safety/stability in multi-agent simulations — prefer it as the default model in agentic workflows mixing multiple agents
- For local/offline coding, **Qwen 3.6 35B A3B** run through **Hermes Agent** (or OpenSpace for sub-agent orchestration) is a viable low-cost alternative when Claude usage limits or cost are a concern

**New skills/tools worth installing**
- **Graphify** — builds a knowledge graph from your repo for Claude Code context; install via GitHub, use `/graphify` skill, run `graphify hook install` to auto-rebuild on commits (claimed 10x cheaper context loading)
- **CodeRabbit CLI** — insert as an independent reviewer between write and fix steps to catch logic flaws
- **Firecrawl skill / MCP** — AI-native web scraper for agents; available as both a Claude Code skill and a free MCP server
- **Zapier SDK (MCP-style)** — `npm install` once for 9000+ app integrations; evaluate for agentic workflows hitting external APIs
- **MarkItDown MCP server** (Microsoft) — connect to Claude Desktop to auto-convert uploaded PDFs/docs to Markdown, cutting token usage up to 70%
- **Perplexity MCP** — gives Claude Code live internet access inside workflows
- **Playwright MCP** — lets Claude control a browser for testing and automation
- **Glyph MCP** — connects Claude to image/video generation models with auto prompt optimization
- **Chrome MCP** — lets Claude see and interact with the currently open Chrome tab
- **21st.dev Magic MCP server** — install into Claude Code for professional-grade website generation with animations and layouts
- **Context7 MCP** — add this MCP server and prefix prompts with "use context7" to pull live library docs instead of stale training data; stops hallucinated removed functions
- **Claude Mem** — install once to persist Claude Code session memory locally across sessions; eliminates re-explaining project context every session
- **CC Glass** — sits between Claude Code and the model, showing all hidden requests, tokens, and attached files on a live dashboard; use during client/production installs for security auditing
- **"Grill Me" Claude skill** (Matt Pocock) — forces Claude to ask 16–50 scoping questions before writing any code; install to enforce spec clarity upfront
- **"ADHD" Claude skill** — forces branch enumeration and pruning before the agent sprints on the first idea
- **"UI UX Pro Max" skill** (GitHub) — adds 50+ UI styles, 97 color palettes, 57 font pairings to Claude Code context
- **Runway MCP** — connect Runway as a custom MCP server in Claude to generate images/branding assets directly from Claude chat
- **Kimi K2.6 API** (Moonshot AI) — drop into Claude Code or VS Code as a cheaper execution layer for heavy coding and large codebase review; ~5-6x cheaper than Claude Opus per token
- **Leaked system prompts repo (GitHub)** — 6000+ real prompts from Cursor, Bolt, Manus; useful reference for structuring your own Claude/agent system prompts

**Claude slash commands to adopt**
- `/handoff`, `/loop`, `/code-review` (with Ultra multi-agent mode), `/verify`, `/run`, `/init`, `/security-review` — covers full dev workflow lifecycle

**Agent architecture**
- Store agent memory in an external vector/graph DB; inject selectively per session rather than relying on model memory
- Add a deterministic guardrail layer between model output and action execution (validate action type, inputs, permissions in plain code)
- Use an **LLM-as-judge eval workflow**: second model with a rubric scoring ~20 edge-case queries; run on every prompt change to catch regressions
- Use **Claude Code Hooks** (post-tool-use) to run linters and flag generated files without hard-blocking the agent
- Prefer **Claude Code Skills** (SKILL.md) over MCP servers for internal tooling — lighter on context, no auth overhead; reserve MCP for third-party integrations (Slack, Gmail)
- Adopt spec-first workflow (Spec Kit pattern): write a structured spec file, generate plan → task list → code, instead of prompt-looping
- Apply Theory of Constraints when debugging agent pipelines — find the real bottleneck step, then design fixes as feedback loops not one-time patches
- Build a token burn dashboard (GitHub contribution-style) to track daily AI usage by task type; helps justify and optimize AI spend
- Agentic retry loops multiply token costs significantly (Jevon's Paradox); set explicit spend caps on Claude Code when deploying at scale
- For coding-assistant-style RAG/context retrieval, prefer tree-sitter AST-based chunking over naive token-count chunking, with file-hash tracking to reindex only changed files
- Use a reranker to score retrieved chunks, then prioritize context by open files > recent edits > retrieved chunks; apply full-file rewrites with speculative "draft token" edits over fragile diff/line-number edits for large changes

**Security**
- Only obtain Claude/GPT API keys from official sources — gray-market keys may silently route to cheaper models and log all prompts including secrets
- Treat unusual token burn rates as a red flag for account compromise
- Limit agent permissions to the minimum required scope to mitigate prompt injection attacks from untrusted content (Reddit, GitHub repos, emails)

**Claude.ai settings (non-code)**
- Fill in Settings → General Instructions with your profile for persistent context
- Disable "Help improve Claude" in Privacy when connecting to work tools
- Set granular per-connector permissions (e.g. require approval before posting to social media)
- Explore **Claude Skills** and **Claude Projects** for organizing reusable workflows by domain

**Local/offline hardware options**
- Consider Nvidia DGX Spark / RTX Spark (unified memory GB10 chip) or AMD Ryzen AI Halo (128GB unified memory) as local inference hardware if running large local models (e.g. Qwen 3.6) alongside or instead of cloud Claude usage

W24
- **Switch to Claude Fable 5** (`claude-fable-5`) for agentic coding tasks — SWE-bench Pro 80% vs Opus 4.8's 69%; set effort to **extra-high** for best cost/accuracy ratio. Note: access may be restricted by export controls — keep a fallback model configured (Gemini or local OSS).
- **Enable Ultracode / `/effort` mode** in Claude Code for large complex tasks; use `/workflows` to monitor live sub-agent progress and token usage.
- **Use Claude Code Agent View** (multi-agent dashboard) to run parallel sessions under one conversation instead of managing separate tabs.
- **Add these MCP servers**: `filesystem` (local read/write), `fetch` (live web/API), **Chrome DevTools MCP** (console logs, CORS errors, DOM state), and **Higgs Field MCP** (media generation) if relevant to your stack. Pair Chrome DevTools MCP with Playwright MCP for a full agentic frontend test-and-validate loop.
- **Replace MCP servers with CLI equivalents** (Playwright CLI, Slack CLI) where possible — cuts context usage ~40%. Use programmatic tool calling to isolate response bodies and reduce token injection risk.
- **Install Graphify** (`pip install graphify`) and run `/graphify` in your codebase to give Claude Code agents a navigable knowledge graph. Use `--obsidian` flag to merge into an Obsidian vault for queryable documentation context.
- **Structure `CLAUDE.md` as a progressive-disclosure tree** pointing to skills, workflows, and MCP tools — avoid loading everything upfront. Import `AGENTS.md` into `CLAUDE.md` to unify Claude Code and Codex instructions.
- **Set up Claude Code hooks** to intercept and control agent actions; use headless mode (`-p` flag) for background skill execution.
- **Add Claude Desktop Routines** to schedule autonomous multi-agent Claude Code workflows on a local folder without custom infra.
- **Replace `.env` files with Infisical or 1Password CLI** to keep API keys out of agent session transcripts.
- **Install Hindsight MCP server** for cross-tool cloud memory (retain/recall/reflect) shared across Claude, ChatGPT, Gemini, and Codex.
- **Add the Claude→Codex plugin** (4 slash commands) to delegate implementation tasks from Claude Code (Opus as orchestrator) to Codex for lower token cost per quality unit.
- **Add the Claude Canva connector** (Settings → Connectors → Browse Connectors) for carousel/poster/banner generation directly from Claude prompts.
- **Apply anti-sycophancy system prompt pattern**: instruct Claude to lead with 3–5 counter-questions, blind spots, and risks before answering — transferable to any Claude session.
- **Use `branch-and-prune` skill pattern**: orchestrate sub-agents to generate adversarial/varied plans before committing to one approach.
- **Use `/deep-research`** built-in workflow for multi-source research with verify+synthesize phases.
- **Evaluate Odysseus** as a self-hosted alternative UI if you want memory, agents, and webhooks without vendor lock-in.
- **Adopt "harness engineering"**: maintain a CLAUDE.md-style file with architecture explanation, approval/risk boundaries, and test hooks so agents can self-verify (@qbuilder).
- **Try `--system-prompt ""`** in Claude Code for a persona-free "friend mode" for brainstorming, separate from serious agent-task sessions.
- **Keep Fable 5's extended thinking trace visible** while debugging agent decisions — use it to refine prompts and harness rules.
- **Vary harness/prompt structure by task type**: hypothesis-driven for debugging, sourced-comparison for research, scorecards for decisions.
- **Remember Claude Code's privacy model**: each turn resends full CLAUDE.md + conversation to a stateless API; avoid putting secrets in memory files since Anthropic doesn't train on but does receive full payloads.
- **Try Ollama + Gemma 4 12B locally** for edge/on-device tool-calling workloads as a fallback/comparison to Hermes when cloud models are rate-limited or restricted.
- **Use hybrid retrieval (grep/BM25 + vector/RAG embeddings)** instead of pure semantic search — grep wins on exact-recall/factual lookups per the PwC study; reserve embeddings for fuzzy/semantic queries.
- **Watch iterative context-compression ("sleep loop") techniques** as a pattern for extending agent long-context memory beyond single-pass summarization.
- **Track Nvidia Cosmos 3** (open-source world model, GitHub weights+code) as a candidate foundation model for robotics-adjacent or simulation-heavy automation tasks.
- **Keep a documented fallback-model plan** (e.g., Opus 4.8 or Gemini) wired into Claude Code/API configs given the recurring Fable 5/Mythos 5 export-control suspensions.

W25
- **Install the Ponytail skill** for Claude Code — cuts tokens 53%+ and speeds up runs; use `full` mode by default. Supersedes Caveman. (`@chase_ai_`)
- **Enable Claude Code `/goal`** for long-running tasks — autonomous loop that self-evaluates and retries until done, no manual step-by-step needed; confirmed to run unattended 5+ hours. (`@sabrina_ramonov`)
- **Try `/insights`, `/advisor`, `/btw`, `/clear`** Claude Code commands — surface workflow gaps, auto-escalate hard tasks, interrupt without context loss, reset token budget between tasks. (`@sabrina_ramonov`)
- **Opt into Claude Agent SDK credit program** — Pro/Max/Team/Enterprise gets separate monthly credits for agent tools like Hermes Agent. (`@web3wesley`)
- **Evaluate Hermes Desktop** — adds persistent memory and reusable skills on top of Claude Code; addresses session context loss. (`@jackroberts____`)
- **Try Graphify** — open-source plugin that maps codebases as graphs for Claude Code agents; claims up to 70x token reduction. (`@jackroberts____`)
- **Add LLM-as-judge eval loop** — wire Claude with a rubric, run 100 examples to measure whether prompt changes actually improve quality before shipping. (`@agenticamit`)
- **Build or install an MCP server for any app you interact with repeatedly** — Claude Code can generate one from a prompt; enables CRUD via chat instead of manual UI. (`@agenticamit`)
- **Connect Google Stitch MCP** — pipe UI designs directly into Claude Code for design-to-code workflows. (`@agenticamit`)
- **Add Buffer MCP server** if you do social content — bulk scheduling and caption generation from Claude.ai. (`@agenticamit`)
- **Explore Anthropic's free learning path** covering Claude Code, Claude API, MCP, Agent Skills, and subagents — work through in order. (`@sabrina_ramonov`)
- **Evaluate Everything Claude Code (ECC)** — the hackathon-winning GitHub repo with 251 skills, 63 agents, 79 commands; also works with Cursor, Codex, and Gemini. (`@ai.with.andrew`, `@earsentev22`)
- **Try Claude Code front-end design skills**: `impeccable` (spacing/layout), `taste` (anti-slop), `awesome-design-md` (73 brand design systems), `Skill UI` (clone any site's design), `UI-UX-Pro-Max` (visual design rulebook) + **21st Dev MCP** for production UI components. (`@ai.with.andrew`)
- **Evaluate Paperclip** — connects to Claude Code to run multi-agent teams (CEO/marketer/engineer roles) in parallel on a single goal. (`@dr_cintas`)
- **Evaluate LangGraph** for stateful agent workflows — persistent agents that survive failures, resume mid-task, and carry memory across sessions. (`@dr_cintas`)
- **Benchmark GLM 5.2** (Z.AI/CausalAI) as a cheaper open-source alternative to Claude Opus 4.8 for long-horizon coding tasks; 1M token context. (`@iamkylebalmer`, `@dr_cintas`)
- **Upgrade RAG with Anthropic Contextual Retrieval** — prepend chunk-level context (generated by a cheap LLM reading the full doc) before embedding/indexing, cuts wrong answers by 67%. Must be done at index time. (`@keshavsuki`)
- **Use GraphRAG** (Microsoft) for thematic questions across large document corpora; pair cheap model for entity extraction with strong model for synthesis. (`@keshavsuki`)
- **Set up local LLM fallback** with LM Studio + Hugging Face open-source models — reduces dependency on frontier API access and works offline. (`@iamkylebalmer`)
- **Write a personal README / system prompt** for Claude tools: include background, decision-making style, responsibilities, collaboration style, mental models/mentors, and a domain glossary to reduce repetition across sessions. (`@the.rachelwoods`)
- **Store reusable Claude Skills** (trigger, inputs, steps, outputs) and invoke them via slash commands — avoids re-explaining recurring workflows. (`@the.rachelwoods`)
- **Use explicit step-by-step playbooks** in Claude agent system prompts instead of open-ended instructions — measurably improves reliability. (`@the.rachelwoods`)
- **Connect Unreal Engine MCP** to Claude Code if you do 3D/game work — enables AI-driven scene and asset generation directly from Claude prompts. (`@aiforhumansshow`)
- **Benchmark Kimi-K2.7** as a fast/cheap coding backend alternative (180–260 tok/s, 1.5M context, open-source). (`@marcinteodoru`)
- **Check Refero Style** — 2,000 sites with `design.md` files for feeding design context into Claude Code. (`@viralex_ai`)
- **Monitor Claude Fable 5 availability** — currently restricted; check Anthropic status page if you depend on it for agentic workflows. (`@sabrina_ramonov`)
- **Watch OpenAI Codex** for calendar/scheduling agentic tasks where Claude currently falls short; also evaluate its Record & Replay feature for automating repetitive computer workflows. (`@nate.b.jones`, `@iamkylebalmer`)
- **Structure your Claude Code project with a `CLAUDE.md` map file** plus a `me.md` identity/goals file and domain-specific context folders — mirrors the "harness" architecture (stateless model + file-loading), keeps loaded context small and relevant. (`@qbuilder`)
- **Consider a Plan → Generate → Verify loop** for self-improving agent tasks (pattern reference only, no implementation given yet). (`@qbuilder`)
- **Plan for tiered/KYC-gated access to frontier models** (per Fable 5 export-control fallout) — increases the case for local/on-prem model fallback alongside the LM Studio setup above. (`@tys.ais`)
- **Maintain a self-refining "skills doc"** for recurring agent tasks — after each run, let Claude edit the SOP file based on what failed/succeeded rather than re-prompting from scratch each time; SkillOpt-style pattern boosted accuracy 41%→80% without retraining. (`@parthknowsai`)
- **For stable, repeatable multi-step workflows, consider "compiling" the fixed procedure into a small dedicated model** instead of always routing through an external orchestrator (LangGraph/CrewAI-equivalent) — cuts cost/latency once a workflow stops changing. (`@parthknowsai`)

W26
- **Switch to Opus 4.8** for agentic/coding tasks if you aren't already — it outperforms alternatives on score and cost at medium effort. Note: Claude Fable 5 (`claude-fable-5`) now requires US government approval before access; plan all workflows around `claude-opus-4-8` until your access is confirmed.
- **Move Claude Code usage to Anthropic Max plan** rather than raw API to reduce per-task cost significantly.
- **Track the DeepSWE benchmark** when evaluating future models for long-running agentic work (Python/TS/Go/Rust/JS) — more realistic than Terminal Bench for real coding tasks.
- **Install the Headroom tool** (`pip install headroom`) — token-compression proxy for Claude Code, Cursor, and Copilot; reported 60–95% token reduction with no code changes. Now confirmed by three independent creators (~31k GitHub stars) as one of the highest-leverage, lowest-effort setup changes available.
- **Add the Ponytail skill** to Claude Code to reduce verbosity and token spend; gains are larger with Opus 4.8 (71% faster, 53% cheaper per independent benchmark) than with Haiku 4.5. Also available as a standalone system prompt injection from the open-source repo (~20k stars) — inject into any coding LLM to enforce YAGNI/minimal-code-first behavior.
- **Add the Graphify skill** to Claude Code so it can generate a knowledge graph of any repo for higher-quality answers on unfamiliar codebases and reduced token burn on large projects.
- **Install Claude Mem** for context compression between Claude sessions and **Code Graph** as a local codebase mapper so Claude navigates directly to relevant files — both free tools that complement Headroom.
- **Add Microsoft MarkItDown via MCP** to auto-convert PDFs, Word docs, and Excel files to clean markdown on upload — cuts token waste from poorly formatted document context passed to Claude.
- **Set up an Obsidian vault as Claude's persistent memory** — use a raw/wiki/output folder structure and open Claude Code in that folder for cross-session context. Add the **Obsidian Skills repo** (5 skills by the Obsidian CEO) to teach Claude how to use Obsidian natively.
- **Install Claude Cowork desktop app** (claude.ai/download) and configure Skills + Connectors (Gmail, Canva, Notion) for recurring automated workflows.
- **Set up Claude Routines** (`/schedule` in terminal) to run agents on a cron-like schedule without manual triggers — supports skills, MCP connectors, and custom API environments. Replaces the need for external schedulers for Claude-native automations.
- **Add "ask me clarifying questions until you're 95% confident" to your system prompt or per-task prompts** for noticeably better Claude outputs.
- **Use "be my sparring partner, identify my blind spots"** as a prompt pattern when you need critical review rather than affirmation.
- **Use "reflect on this conversation and turn repeatable tasks into skills I can reuse"** at the end of sessions to build a personal skill library.
- **Upload a prompt-framework cheat sheet (RTF, RACE, RISE, SOLVE, TAG, etc.) to a Claude Project** so it auto-applies structured prompting to new requests without manual formatting.
- **Define agent playbooks/skills before connecting context/documents** — define what the AI should *do* first, then attach data; avoids the "gave it all my data, still getting garbage" failure mode.
- **Add MCP servers as the interface layer** between any bronze/silver/gold data pipelines and your AI agents — avoids direct lake coupling. Meta MCP and Google MCP are now available as connectors for ad/analytics reporting pipelines.
- **Add the twentyfirstdev MCP server** to Claude Code for visually polished UI components — paste the MCP address into Claude Code settings; replaces generic AI-slop output with design-quality components.
- **Add the Magnific MCP server** to Claude settings to use Magnific's image/video generation tools directly inside Claude chat for iterative creative direction without leaving the Claude interface.
- **Factor chain-of-thought token costs into agent budgets** — reasoning models can consume 100× more tokens than visible output; set explicit token limits in agentic loops.
- **Always define a measurable exit condition for agent loops** — a loop without a termination criterion will either over-run or stall; encode success criteria explicitly before launching agentic work.
- **Use the loop engineering pattern in Claude Code**: trigger → execute (skill) → verify (success criteria) → log state; use `/goal` for agentic automation with clear exit conditions. The Claude Code creator's own setup pairs `/goal` (verifiable finish line) with a separate verifier agent (runs tests/browser checks independently) and `/loop` for scheduled overnight plan-act-verify-fix cycles — adopt this builder/verifier split rather than letting one agent grade its own work.
- **Add the impeccable skill to Claude Code** for front-end work — 23 commands that detect and remove AI slop via live browser iteration; pair with awesome-design.md brand component templates and skill-ui for website-to-template scraping.
- **Add the Taste Skill repo** (50k+ stars) to your Claude Code skill stack for improved frontend layout, typography, motion, and GPT-image generation.
- **Add designer-focused Claude skills**: Emil Kowalski (motion), UIX Pro Max (full design system context), Extract Design System (scrapes colours/fonts/spacing from any URL), and Image to Code (visual reference to coded site).
- **Try injecting the leaked Fable 5 system prompt into Opus 4.8** as a single-line addition if you want Fable-style reasoning behavior at Opus pricing — unverified but low-risk to test.
- **Watch GLM 5.2 and Kimi K2.7** as free, locally-runnable alternatives near Claude Opus 4.8 quality on coding benchmarks. Also watch **Qwen Agent World** (Alibaba, open-source, beats Opus 4.8 on AgentBench) and **Ornith 1.0** (open-source coding model on Hugging Face, consumer GPU, rivals Claude) as local agent model options.
- **Evaluate Jcode** as a drop-in alternative to Claude Code / Codex CLI for memory-constrained or high-parallelism scenarios — open-source Rust agent, claims 20x lower memory and 63x faster than Codex CLI, with native parallel agent spawning.
- **Consider Kimi Work** (free) for bulk multi-agent research tasks — runs 300 parallel agents with 200K context and benchmarks above Claude/Gemini/ChatGPT on multi-agent web research.
- **Enable Claude Code sub-agents** for parallel workloads — spin off Opus/Sonnet/Haiku agents in isolated context windows; use skill forking (`fork` parameter in skill files) to run skills in separate sub-agent windows; define named agent teams that message each other for complex multi-role tasks.
- **Use Claude Code hooks** to intercept and control agent actions at the tool-call level — useful for enforcing guardrails, logging, or modifying tool outputs before they feed back into the loop. Also use the lifecycle hook pattern (`session_start`, `pre_tool`, `post_tool`, `session_end`) to log to a shared graph, distill offline into topic-organized memory files, and auto-inject on session start — survives tool switches between Claude, Cursor, etc.
- **Enable Claude Code Artifacts** (team/enterprise) to turn terminal coding sessions into live shareable web dashboards that update in real time — share directly via Anthropic-hosted URLs, no self-hosting needed.
- **Request HTML output from Claude** instead of Markdown when you want interactive, shareable results — tables, toggleable diffs, diagrams, and mini-tools render far better than Markdown in Artifacts and chat. Follow up on any app-building session with a prompt to also generate an HTML architecture/user-flow doc site.
- **Audit your Claude Code feature usage against the 12-feature checklist**: CLAUDE.md, permissions, plan mode, checkpoints, skills, hooks, MCP servers, plugins, context/slash commands, compaction, sub-agents — gaps here are the highest-leverage setup improvements available right now.
- **Try Omnigent** for critical code paths — it alternates Claude and GPT-4 in a write/review loop to catch blind spots neither model finds alone.
- **Add useful Claude prompt modifiers to your workflow**: append `table` for comparison tables, `v2` for a tighter rewrite, `/brainstorm` for idea generation, `/checklist` for step-by-step plans, `/proofread` for copy editing.
- **Integrate mem0** as a drop-in agent memory layer for long-running Claude agents — stores extracted facts instead of raw transcript, reducing context cost and drift at session boundaries.
- **Treat skill/instruction files as trainable parameters (SkillOpt workflow)**: iteratively edit Claude skill files using a second model, validate each edit on a held-out benchmark, revert if score drops — reported ~25 pt improvement on GPT-4.5 that transfers across models without retraining.
- **Track Claude Tag** (Anthropic's Slack-native agent) — brings Claude Code capabilities plus persistent company memory into Slack/Teams; enables an "Agent Fleet Manager" workflow where named, skill-equipped agents run per channel with memory, API connections, and safeguards.
- **Check robots.txt and firewall rules** for ClaudeBot (and GPTbot) on any site you want Claude to crawl — use Surf Lens (Mac browser tool) to audit which LLM crawlers are blocked before building Claude-powered retrieval pipelines against external sites.
- **Use Tavily** as the search API for live-web RAG pipelines (designed for AI agents) and add **Cohere Rerank** as a reranker step to filter low-quality sources before passing results to Claude — key to trustworthy cited answers.
- **Set a clear measurable metric before running any automated overnight optimization loop** (CloudCode / Claude Code agentic loops) — the loop will optimize whatever you measure, so define the target precisely first.
- **Replace structured prompt-writing with voice mode free-form dictation** for project kickoffs — use Claude Code or Codex via mobile to delegate tasks asynchronously while away from desk; models extract intent from rambling well enough to skip hand-crafted prompts.
- **Prefer agentic flows with tool use and self-correction** over bare LLM calls to mitigate hallucination — the reduction in hallucination rate comes from the loop structure, not from the underlying model being smarter.
- **Consider self-hosting open-source models locally** (Mac mini + Ollama) as a fallback when Claude/Anthropic has downtime, with **OpenRouter** as a multi-model routing layer for reliability when a primary provider is down. NVIDIA DGX Spark and high-RAM Apple Mac Studio/MacBook Pro configs are emerging as the go-to local hardware for self-hosting GLM 5.2-class models.
- **Run multiple AI coding agents in parallel via tmux** — put Claude Code, Grok Build, and OpenCode in separate tmux panes so sessions persist across disconnects instead of dying when a terminal closes.
- **Adopt the "teleport" pattern** for moving a running Claude session between laptop terminal and browser/phone, and try "use a workflow" as a prompt to have Claude auto-build multi-agent orchestration plans on the fly.
- **Consider a self-editing CLAUDE.md**: let Claude propose edits to its own rules file based on weekly feedback/outcomes, and experiment with parallel task-splitting (one instruction fanned out to many Claude instances, merged into a single answer) for large one-off tasks.
- **Set up a Telegram-connected watcher bot** that monitors GitHub/AI news and can write its own Claude skill file — a lightweight way to keep your skill library current without manual research.
- **Before trusting a specialized RAG-based domain tool** (e.g. medical/legal retrieval apps), benchmark it against a general-purpose model (Claude/ChatGPT/Gemini) on the same queries — narrow RAG pipelines can retrieve irrelevant context and underperform a strong general model.
- **Verify AI-generated research summaries against primary sources** — fabricated citations have already slipped into peer-reviewed venues (including NeurIPS), so treat LLM-cited papers as unverified until checked.

W27
- **Add `.claude/workflows/`**: Create JS workflow files to codify multi-step agentic loops with planning, execution, and validation sub-agents. Claude Code can generate these files itself. Per-run JSONL transcripts and tool call logs are stored automatically — useful for debugging. Requires Claude Max plan.
- **Claude Design 2.0 / desktop "Design" beta**: Now bundled into Claude Desktop with no separate usage cap, supports Figma import and Canva export, and generates interactive prototypes/presentations/graphics. Feed it design systems, PDFs, brand kits, and screenshots as context, and prefer high-fidelity mode over wireframes for polished mockups. Use `Claude Code` in terminal as an alternative creation path via the new design skill.
- **Claude Cowork**: The Claude app now has a distinct "Cowork" surface for installing marketing/sales/finance/legal/support skills via a plugin browser, linking connectors (Gmail, Google Drive, Slack), and scheduling recurring tasks (e.g. weekly research reports) — worth exploring as a lighter-weight alternative to hand-rolled automation for routine business tasks.
- **Claude Skill Creator**: Build persistent custom skills (e.g. `/human` for consistent tone, or an Arcads integration for auto-generating UGC ad variations from one image/prompt) so prompt context is saved and reusable across sessions — avoids re-prompting the same instructions each time.
- **Claude Code + external APIs**: Claude Code works well as a data analysis layer over wearable/health APIs (e.g. Whoop). Worth exploring for any personal or domain-specific data source you already have API access to.
- **Self-grading prompt loop / explicit agent loop design**: Instead of accepting Claude's first output, instruct it to score the result out of 10 and iterate until it reaches ≥8. More broadly, structure any agent as an explicit decide → act → observe → repeat cycle with a defined exit condition, periodic context summarization/notes-to-file for long runs, and treat tool/test failures as feedback to correct from rather than ignore.
- **LLM Wiki / knowledge graph agent**: Use Claude Code to implement Karpathy's LLM Wiki pattern — agent reads sources into a `raw/` folder, then summarizes and cross-links them into a compounding knowledge base viewable in Obsidian. Layer a "Hermes"-style overnight agent (now with a `/learn` skill-creation feature) on top to run recurring research tasks and accumulate domain skills automatically. Andrew's "Carpathian Obsidian RAG" variant uses raw/wiki/output folders — raw (unstructured input) → wiki (Claude-generated structured articles) → output (deliverables).
- **Claude browser agent pattern (InTruth)**: The real-time transcription + web RAG pattern used in InTruth (live audio → Claude → web search → fact verdict) is a reusable template for any Claude-powered Chrome extension. Consider it as a scaffold for building browser-side Claude agents against live content. Also try the Claude Chrome connector (Customize → Connectors) plus scheduled/recurring tasks for automating repeated browser workflows like data-broker opt-out requests.
- **Claude daily review agent**: Set up a Claude agent with access to calendar, email, and tasks to produce an end-of-day summary and next-day plan. Pair with a Notion capture agent (voice or text → structured Notion database rows) for a lightweight personal operating system.
- **Model alternatives**: GLM 5.2 is worth evaluating as a self-hosted alternative to Claude for lower-sensitivity tasks — comparable benchmark claims to Opus 4.8 at zero API cost. Multiple sources now report Sonnet 5 underperforming GLM 5.2 on some coding benchmarks, so benchmark both before committing. Also worth tracking: MiniMax M3 (sparse attention), Qwen Agent World, Ornith 1.0 (single-GPU coding model), Longcat/Longcat2 (Meituan/8:01, open MoE, 1M context, no-Nvidia training), a 700B-param open-weight Chinese MoE model beating GPT-5.5 on coding at 1/6 cost, and the leaked Fable 5 system prompt as a reusable template for steering GLM/Kimi.
- **Free API/model access**: NVIDIA's "build" platform offers free instant API keys for 80+ models (Kimi, Minimax, GLM, DeepSeek, OpenAI) usable directly inside Claude Code or Cursor — worth trying before paying for API access to alternative models.
- **Zapier MCP**: Connect Claude to ~9,000 apps (calendar, email, Slack, Quickbooks, Airtable, Notion) for agentic automation without building/maintaining custom always-on agents — prefer this over over-engineered agent loops for routine business workflows.
- **Model routing/effort tuning**: Use Sonnet 5 (~60% cheaper than Opus 4.8) for routine coding/agentic tasks; reserve Opus 4.8 for complex multi-step reasoning. Tune `/effort` level (low→max) to cut cost 80%+ on simpler tasks. Try `/advisor` mode (Fable as advisor, Opus/Sonnet as executor) and the "ponytail" skill for leaner, less verbose output (~22% savings reported).
- **Fable 5 usage discipline & government oversight**: Fable 5 has limited weekly usage (moved to API billing in July; subscription-included window closed ~July 7) and access has reportedly been restored under US government oversight requiring proactive security reporting — expect routing/availability to keep shifting and some tasks to silently fall back to Opus 4.8. Use it only for high-value planning/architecture or rapid app cloning/scaffolding (feed it pre-brainstormed questions from Opus/Sonnet/GPT-5.5, or screenshots/context for cloning apps like Whisper Flow), then delegate implementation to Opus 4.8/Codex 5.5/Sonnet sub-agents on worktrees. Exploit its 1M context for bulk doc ingestion, large-codebase passes, and having it document workflows as skills for cheaper models to run later.
- **Token-cost tooling**: Try Headroom (Github, ~31k stars) to filter junk tokens before they hit Claude Code (60–90% savings), and Microsoft's Markdown MCP server to convert PDFs/Office docs to clean markdown before feeding Claude (up to 70% token reduction).
- **Agent web/data access tools**: AgentReach (open-source, 20k stars, wraps yt-dlp) gives agents free real-time access to Twitter/Reddit/YouTube/GitHub without API keys — consider wiring into MCP-based research agents.
- **Multi-agent orchestration patterns**: Structure CLAUDE.md/AGENTS.md as lean imports (identity.md, user.md, guardrails.md); use skill YAML `fork: true` + `model:` to run a skill in a subagent on a different model; use `$ARGUMENTS` for slash-command parameters; use `/schedule`/`/loop` for cron-style automation; consider a shared task/message DB + vector DB for persistent multi-agent knowledge; for large features, chain custom slash commands (`/orchestrate`, `/plan`, `/spec`, `/implement`, `/review-loop`).
- **Multi-harness routing**: For cost/quality tradeoffs, route across harnesses — Claude Code (Fable 5 planning, Opus 4.8 orchestration/review, Sonnet implementation, Haiku log search), Codex CLI (GPT 5.5), and Open Code CLI (GLM 5.2/Gemini/DeepSeek) — coordinated via a shared task board.
- **Git safety rule**: Add a CLAUDE.md rule forbidding Claude Code from running git commands directly (an agent reverted commits/deleted files); run `git add`/`git commit` manually yourself.
- **E2E testing for agents**: Use Playwright CLI for browser E2E, native computer-use tools for desktop, and Xcode MCP for iOS — map full user-flow trees rather than relying on unit/integration tests alone.
- **MCP/skill discovery**: Check MCP Market (140k+ free Agent Skills for Claude/Codex/Gemini), n8n's 7,000+ free workflow library, and Google's open-sourced Stitch design skill (HTML→design, multi-page site generation, works with Claude Code/Codex/Cursor/Gemini CLI) before building automations from scratch. Also worth trying: an open-source Claude Code job-hunting agent (tailors CV/cover letter, preps interviews from postings).
- **Session/workflow self-audit**: Consider periodically reviewing your own Claude Code/Codex/Cursor session history (à la Paxel) to spot repeated manual patterns worth turning into skills — but weigh the privacy tradeoff of any third-party tool reading session data before adopting one.
- **Structured "thinking" prompts vs. agents**: For non-coding reasoning tasks, prompt Claude with explicit techniques (challenge the idea, list assumptions, three-perspective review, compress-to-3-words) instead of plain Q&A. Before reaching for an agent, check whether a task can be fully scripted as a fixed-step workflow — only build an agent when next steps genuinely depend on dynamic decisions.
- **Prompt wording matters**: A cross-model study found simple, plain vocabulary in prompts outperforms "fancy"/polished wording by ~8 points on math/translation tasks (ChatGPT, DeepSeek, Llama) — worth testing on Claude too; default to plain language over elaborate prompt engineering when writing instructions.
- **Security watch**: Be aware some orgs (e.g. Alibaba) have banned Claude Code internally over spyware/security concerns — factor this into any enterprise deployment decisions; also watch for ID-verification rollouts on Fable 5 credits potentially spreading across providers, and for US-government-driven constraints on future Anthropic model releases.

W28
- Adopt Claude Fable 5 for Skill-file generation: build repeatable Skills, then execute them with Sonnet/Opus for cheaper runs.
- Start/maintain a personal prompt library in Fable 5 to reuse across projects.
- For big rebuild/refactor tasks, have Fable 5 audit and draft the plan/prompt, then execute cheaply on Opus.
- Route tasks by predictability: use Fable 5/frontier models for rare, creative, or edge-case work; reserve cheaper/mid-tier models for routine, high-frequency tasks.
- Verify whether Claude Code has a `/goal` command for autonomous goal-driven loops before adopting it — unconfirmed claim, check current docs first.
- Note pricing/usage-cap changes reported after 2026-07-07 for Claude Max/Fable 5 — check before planning heavy usage.
- Optional/low-priority: evaluate open-weight local models for privacy-sensitive workloads (opinion-level, not a concrete workflow yet).
- Try Anthropic's official Skill Creator plugin (`/plugin` in Claude Code) for an iterative create/evaluate/compare loop on custom skills, instead of hand-tuning skill descriptions.
- Set up a custom "Skill Optimizer" that mines `.claude` JSONL transcripts to audit/improve underused or underperforming skills.
- Replace reliance on Claude Code auto-compact with a custom handoff/compact slash command + `/clear` for better control over context carried between sessions.
- Try the new `/checkup` command in Claude Code to dedupe/split CLAUDE.md, audit hooks/skills/MCPs, and enable auto mode/auto-approve for read-only commands.
- Evaluate Headroom (open-source context-compression proxy) for cutting Claude/GPT token costs — claims up to 95% savings; verify before adopting.
- Consider routing Claude Code through OpenRouter to GLM 5.2 for cheaper (~1/5 cost) Opus-level coding, and/or try Rufflo for automatic cost-based task routing between cheap and premium models.
- Explore MCP-based patterns seen repeatedly this week: build small custom MCP servers (~10 lines) for internal tools/knowledge bases, and distinguish MCP (tool/data access) from Skills (know-how) when designing agent setups.
- Try the "blind spot pass" and persistent context-file prompting techniques to reduce repeated guessing at the start of new work.
- Consider an Obsidian-based "second brain" (raw/wiki/output structure) synced with Claude Code for long-term project memory.
- Watch for Fable 5 / Mythos 5 availability changes — repeatedly extended/reset deadlines and safety-restricted relaunches reported; confirm current access before planning heavy usage.
- Evaluate GPT-5.6/ChatGPT Work and Kimi K2.6/K2.7 as parallel or fallback agentic coding options given competitive pressure and cost differences vs. Claude.
- Try Claude Code's `/goal` slash command (multiple independent reports now) for autonomous goal-driven loops with self-validation — still worth confirming against official docs.
- Consider the "LLM Council" pattern (multi-model cross-review) for high-stakes decisions, and the "advisor pattern" (Sonnet default, escalate to Opus) for cost-efficient quality control.

W29
- Adopt `/goal` and `/schedule` for structured, cloud-persistent recurring agent tasks instead of one-shot prompts.
- Use `/graphify` to turn mixed notes/PDFs/screenshots into a queryable knowledge graph.
- Try `/doctor` to clean stale Claude Code installs, and check `/insights` for a 30-day productivity review of your sessions.
- Wire up Claude Connectors (Gmail, Slack, Airtable) for real actions instead of copy-paste workflows; use Claude Projects to separate contexts per workstream.
- Turn repeated instructions into Skills (e.g. brand-voice, humanizer, email-triage) rather than re-typing prompts.
- Add the "ask me clarifying questions until 95% confident" suffix to prompts for higher-quality first answers.
- Disable "help improve the model" in privacy settings if you don't want your data used for training.
- Try `/caveman` skill to cut output token usage when verbosity isn't needed.
- Use Claude Code's browser/visual feature to review live sites via screenshots instead of pasting text.
- Benchmark Kimi K3 / GLM 5.2 / Nemotron 3 Ultra as cheaper alternatives when Opus/Fable token costs matter — but expect slower runtimes, so weigh wall-clock time not just price.
- Watch for Opus 5 / GPT-5.6 competitive pressure — Fable 5 access is currently gated to $100/$200 plans, confirm your tier still has it.

W30
- Adopt an MCP tool-permission checklist: audit every connected connector, deny "send" capability on anything reading untrusted content, and require human approval for send/delete/spend actions (@keshavsuki) — do this before wiring Gmail/other MCP servers into Claude Code.
- Maintain a personal CLAUDE.md-style "rules/taste" file capturing banned patterns and recurring corrections as permanent rules (@qbuilder, @keshavsuki's system-prompt pattern: identity → when/then rules → exact tool schemas → pasted current date).
- Try Claude's native "record a skill" feature to turn screen recordings into reusable Skills, and use Customize → Skills → Upload for downloaded skill packs (@digitalsamaritan, @maverickgpt).
- Evaluate Zapier MCP or OpenConnector (self-hosted, open-source Composio alternative) for connecting Claude to niche/business apps beyond native connectors (@digitalsamaritan, @howard.mov7) — note OpenConnector lacks capability-based access control so far.
- Try spec-driven workflows (`/plan`, `/spec`, `/implement`, `/review-loop`) or `/goal` loops paired with a task tracker for controlled long-running agent runs on large features (@agentic.james).
- Watch for Claude Opus 5 (rumored) and use the $100 Anthropic API credit as a stopgap if hitting the 5-hour Claude Code usage limit; consider ChatGPT Codex/GPT 5.6 as a fallback daily driver during limits (@iamkylebalmer).
- Decouple prompts/workflows into portable "playbooks" independent of model choice, treating models like Kimi K3 as swappable infrastructure rather than something worth fine-tuning around (@the.rachelwoods, @nate.b.jones).
- Skip: certification chasing (Claude Certified Architect, AWS/Google/IBM AI certs) and hardware gadgets (Codex Micro controller) — low leverage for a solo dev's Claude setup unless credentialing is a specific goal.
