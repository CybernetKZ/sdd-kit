# The RAISE Methodology for AI-Assisted IT Development

**A research report**
Date: 30 July 2026

---

## 1. Executive summary

The three sources you supplied describe **three unrelated frameworks that happen to share the acronym RAISE**. Only one
of them is a software development methodology. Before anything else, that needs to be separated out, because conflating
them would produce a report about nothing.

The methodology you are asking about is **RAISE - Rules and AI for Intention-driven Software Engineering** (
useraise.dev). Its core claim is worth taking seriously: AI coding agents fail not from lack of intelligence but from
lack of context, so the fix is to compile human intent into a set of durable, versioned, agent-readable artifacts
*before* code generation begins. The manifesto calls itself "a compiler for intention."

Three findings matter most:

1. **The idea was directionally correct and early.** Published May 2025, RAISE anticipated - by roughly four months -
   the artifact-first pattern that GitHub Spec Kit, AWS Kiro, OpenSpec and others turned into the dominant practice of
   2026. Its "Values" artifact prefigures Spec Kit's *constitution* and Kiro's *steering files*.
2. **The project itself is inert.** It is a single-author experiment. The site has not been updated since May 2025; the
   repository carries 24 commits, zero stars, zero forks, and one example project - the manifesto website describing
   itself. There is no tooling, no empirical evaluation, and no community.
3. **The category moved on without it.** Spec-driven development (SDD) is now the mainstream expression of the same
   idea, with maintained toolchains, formal requirements notation (EARS), task-level traceability and drift detection.
   RAISE's concepts survive; RAISE as a product does not.

**Recommendation:** do not adopt RAISE-SE as a production methodology. Harvest its vocabulary and its two genuinely good
ideas (a Values artifact; documentation rot as a first-class engineering problem), and implement them inside a
maintained SDD toolchain.

---

## 2. Acronym disambiguation

| Acronym expansion                                          | Domain               | Origin                                                                            | Relevance to IT development with AI                                |
|------------------------------------------------------------|----------------------|-----------------------------------------------------------------------------------|--------------------------------------------------------------------|
| **Rules and AI for Intention-driven Software Engineering** | Software methodology | useraise.dev, John Sloan, May 2025                                                | **Direct - the subject of this report**                            |
| **Responsible use of AI in evidence SynthEsis**            | Research methods     | Joint position statement: Cochrane, Campbell, JBI, CEE, Nov 2025 (Flemyng et al.) | Indirect - supplies a transferable *AI disclosure* template (§6.1) |
| **Responsible AI Scoring and Evaluation**                  | ML evaluation        | arXiv:2510.18559, FAU Erlangen-Nürnberg, Oct 2025                                 | Indirect - governance layer if you *ship* ML models (§6.2)         |
| **Reasoning and Acting through Scratchpad and Examples**   | Agent architecture   | arXiv:2401.02777, Beike Inc., Jan 2024                                            | Indirect - a ReAct extension with dual short/long-term memory      |
| **Requirements Engineering for AI-powered SoftwarE**       | Academic workshop    | RAISE @ ICSE, 2nd edition 2026                                                    | Indirect - the research venue for these questions                  |

The ScribeLabWriter article you linked is about the *second* RAISE. It is a well-written guide to evidence-synthesis
compliance and a lead-generation piece for a writing service. It contains nothing about software engineering - but its
disclosure discipline is unexpectedly reusable, and §6.1 explains how.

---

## 3. RAISE-SE: what the methodology actually specifies

### 3.1 Positioning

RAISE describes itself as a **pre-development methodology**: it stops at the point where artifacts are complete and any
coding agent - Copilot, Claude Code, Cursor, or a successor - takes over. This is a deliberate scoping decision and also
its main structural limitation (§4.2).

Its framing slogan: *Rules provide structure. AI amplifies execution. Intention guides purpose.*

### 3.2 The seven core principles

1. Vision comes first, before code.
2. Human-first, always.
3. AI is a partner, not just a tool - the human retains creative ownership of direction, voice and priorities.
4. Stories are the atomic unit of progress.
5. Living artifacts guide development.
6. Clarity drives quality.
7. Intentional iteration.

### 3.3 The seven core artifacts

These are the "Rules" in the acronym - not constraints, but the documents that collectively govern what an agent may
build.

| Artifact                          | Function                                  | Governs                    |
|-----------------------------------|-------------------------------------------|----------------------------|
| **Vision Document**               | What we are building and why it matters   | *what gets built*          |
| **Values**                        | Principles for decisions and trade-offs   | *how decisions are made*   |
| **User Stories**                  | Features + acceptance criteria            | *what features matter*     |
| **Site Map**                      | Navigation and content structure          | *information architecture* |
| **Architecture Decision Records** | Rationale for technical choices           | *technical constraints*    |
| **Designs**                       | Visual and interaction blueprints         | *user experience*          |
| **Commit Messages**               | Conventional Commits, capturing the "why" | *change history*           |

In the reference repository these live in a `.raise/` directory, alongside a `.claude/` directory - an early instance of
the now-standard pattern of committing agent context into the repo itself.

### 3.4 Two-phase AI collaboration

**Phase 1 - Artifact creation.** AI helps articulate and refine the vision, generate and iterate design concepts, and
structure the documents.

**Phase 2 - Implementation and alignment.** Artifacts become input to any coding agent. Ongoing AI assistance is
expected to monitor alignment, suggest artifact updates as requirements evolve, and keep documentation synchronised with
implementation.

Implementation practice is deliberately conservative: **vertical slices** (each story a complete testable unit of
value), **focused execution** (one story at a time, finished before the next), continuous refinement of artifacts, and
incremental validation.

### 3.5 The documentation-rot argument

This is the most substantive section of the manifesto. The diagnosis: documentation decays through entropy, teams face a
permanent choice between shipping features and maintaining artifacts, and the gap between stated intent and actual
implementation widens. The proposed remedy is **AI as documentation guardian** - proactive drift detection, AI-proposed
documentation updates, human validation of those updates, and continuous re-alignment.

Note the modal verbs throughout: the manifesto says AI *should* detect drift and *envisions* this workflow. It is a
design intent, not a shipped capability.

---

## 4. Critical assessment

### 4.1 Genuine strengths

- **The Values artifact.** Most SDD frameworks eventually discovered they needed a document encoding non-negotiable
  principles rather than requirements. Spec Kit calls it a *constitution*; Kiro calls them *steering files*. RAISE named
  it in May 2025. Good instinct, correctly timed.
- **Tool-agnosticism by construction.** Plain documents, versioned in the repo, no runtime. This turned out to be
  exactly the property that made SDD portable across agents - and the reason Spec Kit's markdown-in-repo approach
  outcompeted proprietary alternatives.
- **Drift as a first-class problem.** In 2025 this was a minority concern; by 2026 drift detection is a primary axis on
  which commercial SDD tools compete.
- **Accessibility framing.** Explicitly aimed at people with a product vision and no coding background - the same
  audience Kiro and Spec Kit now court.
- **Conventional Commits as an artifact.** Cheap, mechanical, and it produces a traceable "why" chain almost for free.

### 4.2 Structural weaknesses

- **Web-shaped, not IT-shaped.** "Site Map" as one of seven core artifacts betrays the origin: a static website built by
  a self-described backend engineer who wanted a front end. There is no equivalent artifact for a data pipeline, a
  service API contract, an event schema, or a mobile release train. For general IT development the artifact set needs
  redesign, not adoption.
- **No decomposition or traceability layer.** RAISE goes Vision -> Values -> Stories and then hands off. It has no task
  graph, no requirement-to-task mapping, no test artifact. Kiro generates a requirements doc, a design doc *and* a
  sequenced task list with traceability back to requirements; Spec Kit runs
  `constitution -> specify -> plan -> tasks -> implement`. RAISE stops two steps early, which is where most agent failures
  actually occur.
- **No acceptance-criteria notation.** Stories are said to carry acceptance criteria, but in free prose. Kiro's use of
  EARS (Easy Approach to Requirements Syntax - from Alistair Mavin's team at Rolls-Royce, c. 2009) forces testable
  phrasing of the form *WHEN [trigger] THE SYSTEM SHALL [response]*. Prose criteria are exactly the ambiguity that
  agents exploit.
- **The central mechanism is unbuilt.** The documentation-guardian loop is the methodology's differentiator and it
  exists only as prose.
- **Licensing friction.** The repository reads "© 2025 RAISE Initiative. All rights reserved." A methodology soliciting
  adoption while reserving all rights sends a mixed signal; compare Spec Kit's MIT licence.
- **Self-referential validation only.** The single case study is the manifesto website itself - a JavaScript-free static
  site. That is a weak proof for a methodology claiming to govern AI-assisted software engineering generally.

### 4.3 Maturity signals

| Signal                   | Observation                        |
|--------------------------|------------------------------------|
| Last site update         | 23 May 2025                        |
| Blog posts               | 1 (plus "more coming soon")        |
| Repository commits       | 24                                 |
| Stars / forks / watchers | 0 / 0 / 0                          |
| Example projects         | 1 (self-referential)               |
| Maintainers              | 1, self-described as an experiment |
| Empirical evaluation     | None                               |

The manifesto is candid about this - the author writes that "we" is currently just "me" and invites people to explain
why the idea is bad. That honesty is to his credit and should be reflected in any assessment: this is a well-articulated
hypothesis, not a validated methodology.

---

## 5. RAISE in the 2026 landscape

The idea RAISE articulated became a category. It just was not RAISE that captured it.

**Spec-driven development** emerged in 2025 as a response to the failure mode of "vibe coding" - agents producing
plausible code that drifts from intent, hallucinates APIs, and decays as projects grow. The term is most often credited
to GitHub Spec Kit, open-sourced September 2025 and grounded in John Lam's work on making LLM-driven development more
deterministic. By 2026 essentially every major tool ships an SDD flavour.

### 5.1 The rigour spectrum

The most useful mental model - attributed to Birgitta Böckeler on Martin Fowler's site, and echoed by the 2026 arXiv
paper *From Code to Contract* - is a three-level spectrum:

- **Spec-first** - the spec provides initial clarity, then is discarded or allowed to drift; code becomes the source of
  truth again.
- **Spec-anchored** - the spec is maintained alongside code and consulted on change.
- **Spec-as-source** - the spec is the artifact; code is build output, as `.c` compiles to a binary.

RAISE's *intent* is spec-as-source ("living artifacts"). Its *mechanism* only supports spec-first, because nothing
enforces or verifies the maintenance loop.

### 5.2 Comparable frameworks

| Framework                 | Character                                                                             | Traction (2026)                                                |
|---------------------------|---------------------------------------------------------------------------------------|----------------------------------------------------------------|
| **GitHub Spec Kit**       | MIT-licensed Python CLI; markdown in-repo; 30+ agents                                 | v0.8.7 (May 2026); 93,000+ stars - category definer            |
| **AWS Kiro**              | Agentic IDE + CLI; EARS requirements; agent hooks; requirement-to-task traceability   | Named AWS's successor to Amazon Q Developer                    |
| **OpenSpec**              | Strict three-phase state machine (proposal -> apply -> archive)                         | ~52,100 stars (June 2026); most actively maintained OSS option |
| **BMAD-METHOD**           | Orchestrates 12+ specialised agents across the SDLC via file-based handoffs           | Established                                                    |
| **GSD ("Get Shit Done")** | Meta-prompting and context engineering for Claude Code / Gemini CLI                   | 61,000 stars in under five months                              |
| **AWS AI-DLC**            | Full lifecycle methodology; "Mob Elaboration" turns business intent into requirements | Vendor methodology                                             |
| **Tessl Spec Registry**   | 10,000+ library specs to suppress API hallucination                                   | Niche but distinctive                                          |
| **RAISE-SE**              | Manifesto + artifact list; no tooling                                                 | Dormant                                                        |

The honest critiques of Spec Kit apply to RAISE with more force: a "sea of markdown," a "reinvented waterfall," weak on
iteration and on legacy codebases. RAISE has the same exposure and none of the tooling that mitigates it.

### 5.3 Why this matters commercially

Adoption is not the constraint; confidence is. The Stack Overflow 2025 survey found 84% of developers using or planning
to use AI tools, but only 33% trusting their accuracy, with positive sentiment falling from over 70% in 2023-24 to 60%
in 2025. Artifact-first methodologies exist to close that trust gap. A methodology that cannot demonstrate the closing -
no validation data, no drift-detection implementation, no case studies beyond its own website - cannot address the
actual bottleneck.

---

## 6. What the other two RAISEs contribute

If your interest is IT development *of* AI-bearing systems rather than IT development *with* AI assistance, the other
frameworks are more useful than the acronym collision suggests.

### 6.1 Disclosure discipline (RAISE - evidence synthesis)

The evidence-synthesis RAISE requires that any AI or automation tool that **"makes or suggests judgments"** be fully
disclosed. The threshold word is *suggests*: a classifier that ranks candidates for human confirmation is in scope.
Compliant disclosure specifies:

1. **Tool name and version** - "AI-assisted screening" is insufficient; the exact tool, version and model configuration
   is required.
2. **The human-AI workflow** - did humans review everything, or only what the AI surfaced? At what confidence threshold
   was material auto-excluded without review?
3. **The stopping rule**, if one was used.
4. **Validation data** - sensitivity and specificity against a human gold standard drawn from the *whole* dataset, not
   only from items the AI already flagged.

And the governing principle: **accountability does not transfer to the tool.** The named humans own the output and any
correction that follows.

Translate that to software engineering and you have a better AI-usage disclosure standard than most engineering
organisations currently operate:

- Which agent, which model version, which prompt or spec revision produced this change?
- Which changes had human review, and which were auto-merged below what confidence threshold?
- What is the measured defect or regression rate of agent-authored changes against a human-reviewed baseline?
- Who is accountable when an agent-authored change causes an incident?

RAISE-SE gestures at accountability through "human ownership." The evidence-synthesis RAISE operationalises it. That gap
is instructive.

### 6.2 Responsibility scoring (RAISE - Responsible AI Scoring and Evaluation)

The FAU framework quantifies models across **explainability, fairness, robustness and sustainability**, using 21 metrics
normalised into four Dimension Scores and an aggregate Responsibility Score. Predictive performance is reported
separately, and models are compared at a controlled F1 threshold so architectural trade-offs are visible rather than
confounded.

The headline result is the useful one for engineering leadership. Across three high-stakes tabular datasets (German
Credit, ACSIncome, Diabetes 130-Hospitals), models reaching statistically similar F1 scores diverged sharply on
responsibility. On German Credit an MLP scored 0.8352 overall against a Feature Tokenizer Transformer's 0.6402; the
Transformer's sustainability scores were 0.2480, 0.4575 and 0.0071 across the three datasets, against roughly 0.98-0.99
for the MLP. The Tabular ResNet sat between the two.

The practical conclusion: **predictive accuracy is a weak and often misleading proxy for a model's operational and
ethical fitness**, and there is no dominant architecture - only trade-off profiles that fit a given context better or
worse. If your project ships an ML model into a regulated domain, this gives you a defensible, reproducible record of
*why* an architecture was chosen. That is a governance artifact RAISE-SE's artifact set has no slot for.

---

## 7. Practical guidance

### 7.1 If you were considering adopting RAISE-SE

Don't - not as-is. Instead:

1. **Pick a maintained SDD toolchain.** Spec Kit if portability and agent-agnosticism matter; Kiro if you want a gated
   requirements -> design -> tasks flow inside AWS; OpenSpec if you want a lightweight enforced state machine.
2. **Port RAISE's artifact set onto it.** Vision -> your spec's problem statement. Values -> constitution / steering
   files. Stories -> specs with acceptance criteria. ADRs -> keep as-is, they predate all of this and still work. Drop
   Site Map unless you are building a website; substitute the architecture artifact your domain actually needs.
3. **Upgrade the acceptance criteria.** Rewrite prose criteria in EARS form. This is the single highest-leverage change
   and costs nothing.
4. **Add what RAISE omits.** A task decomposition with traceability to requirements; a test artifact; a definition of
   done that includes human review.
5. **Implement the guardian loop rather than describing it.** CI checks that flag PRs touching code whose governing
   artifact has not changed; a scheduled agent job that reports drift between specs and implementation. This is
   buildable today and is where RAISE's best idea lives.
6. **Add a disclosure record**, modelled on §6.1 - agent, model version, spec revision, review status, per change.
7. **Add a responsibility profile** (§6.2) if you ship models into regulated decisions.

### 7.2 Adopt the vocabulary, not the brand

RAISE's terms - *compiler for intention*, *living artifacts*, *rules as governance*, *documentation guardian* - are good
communication tools for explaining to non-engineering stakeholders why the team is writing documents before generating
code. They are worth borrowing. Citing "the RAISE methodology" as an established practice in a proposal or tender,
however, would not survive scrutiny: an evaluator who checks the source finds a dormant single-author site with zero
repository engagement.

### 7.3 Risks to keep in view

- **Waterfall regression.** Heavy up-front artifacts under an agile label. Mitigate with vertical slices and short
  spec-to-running-code cycles.
- **Markdown sprawl.** Artifacts that nobody reads are worse than no artifacts, because they license false confidence.
- **Brownfield mismatch.** Every framework in §5.2 is strongest greenfield and weakest on legacy code. Most IT
  development is legacy.
- **Acronym collision.** In any written deliverable, expand RAISE on first use. Five active frameworks share the
  letters, and two of them are far better known in their fields than the software-engineering one.

---

## 8. Conclusion

RAISE-SE is a correct hypothesis published early by one person and then abandoned. Its diagnosis - that agents are
expensive guessers without explicit intent, and that documentation rot is the structural enemy of AI-assisted
development - has been vindicated by the entire spec-driven development wave that followed it. Its prescription is
incomplete in ways that matter: no decomposition, no testable criteria notation, no traceability, and no implementation
of the drift-detection loop that was supposed to be its distinguishing contribution.

For a team building software with AI in 2026, the useful move is to treat RAISE as a well-written position paper, adopt
a maintained toolchain for the mechanics, and borrow the disclosure rigour from the evidence-synthesis RAISE and the
responsibility scoring from the FAU RAISE to cover the governance ground that none of the software-engineering
frameworks address.

---

## Sources

**RAISE - Rules and AI for Intention-driven Software Engineering**

- RAISE Manifesto - https://useraise.dev/ (last updated 16 May 2025)
- RAISE Manifesto Website Project (case study) - https://useraise.dev/projects/manifesto-site/
- Blog: "Preparing for the Age of Autonomous Agents" - https://useraise.dev/blog/2025-05-23-autonomous-agents-raise/ (23
  May 2025)
- Repository - https://github.com/raisedevmanifesto/raisedevmanifesto.github.io (24 commits, 0 stars, retrieved 30 July
  2026)

**RAISE - Responsible AI Scoring and Evaluation**

- Nguyen, L.P.T. & Do, H.T., "RAISE: A Unified Framework for Responsible AI Scoring and Evaluation," arXiv:
  2510.18559v1 - https://arxiv.org/html/2510.18559v1
- Implementation - https://github.com/raise-framework/raise

**RAISE - Responsible use of AI in evidence SynthEsis**

- Flemyng et al., Campbell Systematic Reviews 2025;21:e70074 (joint Cochrane / Campbell / JBI / CEE position statement,
  Nov 2025)
- Dawn, H., "AI Tools in Systematic Reviews: The Complete RAISE Compliance Guide for 2026," ScribeLabWriter, 15 June
  2026 - https://www.scribelabwriter.com/blog/ai-tools-systematic-review-raise-framework

**Other RAISEs**

- Liu et al., "From LLM to Conversational Agent: A Memory Enhanced Architecture with Fine-Tuning of Large Language
  Models," arXiv:2401.02777 (RAISE = Reasoning and Acting through Scratchpad and Examples)
- RAISE 2026 - 2nd Workshop on Requirements Engineering for AI-powered SoftwarE, ICSE
  2026 - https://conf.researchr.org/home/icse-2026/raise-2026

**Comparative landscape**

- "Spec-Driven Development in 2026: Guide + Tool Comparison" - https://codemyspec.com/blog/spec-driven-development
- "Spec-Driven Development (SDD): The Definitive 2026 Guide," BCMS - https://thebcms.com/blog/spec-driven-development
- "9 Best AI Tools for Spec-Driven Development in 2026," MarkTechPost, 8 May 2026
- "6 Best Spec-Driven Development Tools for AI Coding in 2026," Augment Code, 18 June 2026
- "AI-Driven Development Life Cycle: Reimagining Software Engineering," AWS DevOps
  Blog - https://aws.amazon.com/blogs/devops/ai-driven-development-life-cycle/
- Thoughtworks, "Why AI is raising the stakes of the software engineering craft," April 2026

*Report compiled 30 July 2026. Traction figures for third-party tools are as reported by the cited secondary sources and
change quickly.*