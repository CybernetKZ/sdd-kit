https://github.com/alibaba/open-code-review
14.6k stars
988 forks
401 commits
last update 4 hour ago
Open-source & free — Battle-tested at Alibaba's scale. Hybrid architecture code review tool: deterministic pipelines + LLM Agent, precise line-level comments, built-in fine-tuned ruleset (NPE, thread-safety, XSS, SQL injection), OpenAI & Anthropic compatible.


---

https://github.com/reviewdog/reviewdog
9.5k stars
492 forks
5544 commits
last update 4 days ago
reviewdog provides a way to post review comments to code hosting services, such as GitHub, automatically by integrating
with any linter tools with ease. It uses an output of lint tools and posts them as a comment if findings are in the diff
of patches to review.

reviewdog also supports running in the local environment to filter the output of lint tools by diff.



---

https://github.com/the-pr-agent/pr-agent
12.3k stars
1.6k forks
5070 commits
last update yesterday
This repository contains the open-source PR Agent Project. It is not the Qodo free tier.

PR-Agent is an open-source, AI-powered code review agent and a community-maintained legacy project of Qodo. It is
distinct from Qodo’s primary AI code review offering, which provides a feature-rich, context-aware experience. Qodo now
offers a free tier that integrates seamlessly with GitHub, GitLab, Bitbucket, and Azure DevOps for high-quality
automated reviews.



---

https://www.apodex.ai/chat/dc49bbdf-2858-4dc6-a034-a81a138e0784
There isn’t a single universally “best” free GitHub auto‑reviewer, but there are a few strong options that are genuinely
usable for free. Which one is “best” depends on whether you want AI feedback, static analysis, or code‑health insights.

### If you want **AI code review** (comments on logic, tests, style)

**1. Qodo Merge / PR-Agent (open‑source core)**

- **What it is:** An AI PR reviewer originally released as **PR-Agent**, now also available via Qodo’s hosted service.
- **Free options:**
    - **Open‑source PR-Agent core is free to self‑host** on your own infrastructure for GitHub PR reviews.[1]
    - Qodo also has a **Developer/free tier** aimed at individuals, providing automated reviews with a credit/PR
      allowance (e.g., 75 PRs + monthly LLM credits in recent descriptions).[1]
- **Why it’s good:**
    - Designed specifically for PR workflows: summaries, change reasoning, suggestions.
    - Self‑hosting gives you full control and no per‑seat cost (you only pay LLM/API costs if you use a paid model).
- **When it’s “best”:**
    - You’re comfortable with a bit of setup and maybe self‑hosting.
    - You want a powerful AI reviewer that you can customize and run in your own CI.

---

**2. CodeRabbit (for open source / public repos)**

- **What it is:** A hosted AI PR reviewer that integrates with GitHub/GitLab.
- **Free plan highlights:**
    - **\$0 plan**: no credit card required.[2]
    - PR summarization for each pull request.[2]
    - **Unlimited public and private repositories** on the free plan.[2]
    - Reviews available in IDE/CLI as well.[2]
    - Also includes a **14‑day Pro Plus trial** with more advanced features.[2]
- **Why it’s good:**
    - Very easy to install from GitHub Marketplace and start using.
    - Good default behavior, minimal configuration.
- **When it’s “best”:**
    - You want a **hosted solution** with minimal setup.
    - You work heavily with **public/open‑source repos** (they get particularly good support).

---

### If you want **rule‑based/static analysis auto‑reviews**

**3. reviewdog**

- **What it is:** An open‑source tool that turns any linter’s output into GitHub PR comments/checks.[3]
- **Free tier:**
    - Completely **free and open source** (MIT license).[3]
- **What it does:**
    - Integrates with GitHub (often via Actions) and posts automated review comments based on linters for any
      language.[3]
- **Why it’s good:**
    - Battle‑tested and widely used.
    - You can plug in any static analysis or style tool you already use.
- **When it’s “best”:**
    - You’re primarily interested in **linting, type errors, formatting, and simple bug patterns**.
    - You don’t need “LLM intelligence” and prefer deterministic checks.

---

### If you want **code‑health / architecture feedback** on each PR

**4. Repowise PR Bot (for public repos)**

- **What it is:** A codebase‑intelligence tool with a PR bot focused on hotspots, coupling, dead code, etc.
- **Free tier:**
    - **Free forever for public/OSS repos** – no LLM tokens, no PR cap.[4]
- **What it does:**
    - Indexes your repo and comments on PRs with code‑health insights: hotspots, hidden coupling, dead code,
      ownership/bus factor, architectural decisions.[4]
- **Why it’s good:**
    - Complements other reviewers: instead of style/bugs, it looks at **long‑term maintainability and risk**.
- **When it’s “best”:**
    - You care about **architectural quality and hotspots**, not only correctness.
    - You’re working on **public repos** (its free plan is optimized for that).

---

### Simple Recommendation by Scenario

| Scenario                                                | Best free auto‑reviewer to start with      |
|---------------------------------------------------------|--------------------------------------------|
| You want **AI PR reviews** with control & self‑hosting  | **PR-Agent (Qodo Merge open‑source core)** |
| You want a **hosted AI reviewer** with easy setup       | **CodeRabbit free plan**                   |
| You mainly want **linting/static checks** as comments   | **reviewdog**                              |
| You want **code health & architecture feedback** on PRs | **Repowise PR Bot (public repos)**         |

---

### Minimal Setup Path (practical answer)

If you just want something that “works” with minimal friction:

1. **For a public GitHub repo using AI review:**
    - Install **CodeRabbit** from GitHub Marketplace and enable it on your repo.
    - Let it auto‑comment on PRs and tweak its settings if/when needed.

2. **For strong static checks in any language:**
    - Add a GitHub Action that runs your favorite linter(s) and pipes results through **reviewdog**.
    - You get inline PR comments for every issue the linters find.

3. **If you’re willing to invest a bit more setup for maximum power and control:**
    - Self‑host **PR-Agent** (Qodo’s open‑source core) and add it as a GitHub Action or App.
    - Optionally combine it with reviewdog for both AI and static analysis in each PR.

Any of these choices will give you a high‑quality **free GitHub auto‑reviewer**; which is “best” depends mainly on
whether you favor **AI suggestions**, **static analysis**, or **code‑health insights**.

---

### References

[1] Qodo Plans & Pricing. <https://www.qodo.ai/pricing/>  
[2] CodeRabbit Pricing | AI Code Review Plans. <https://www.coderabbit.ai/pricing>  
[3] reviewdog – A code review dog who… <https://github.com/reviewdog/reviewdog>  
[4] repowise pricing: free open source, Pro \$15, Teams \$60. <https://www.repowise.dev/pricing>
---

# Вердикт для нашего стека (2026-07-27, слой «ревью и гейты»)

Контекст: репозитории приватные, хостинг GitHub, выбранный стек — ревьюеры-агенты
(python/fastapi/database) на границе PR + обязательный `make test` в CI (ADR-0003).
Авто-ревьюер здесь — не замена гейту, а способ доставить замечания строчными
комментариями прямо в PR.

| Инструмент | Вердикт | Почему |
|---|---|---|
| **reviewdog** | **взять** | MIT, бесплатный, детерминированный: превращает вывод ruff/mypy/pylint в строчные комментарии PR. Дополняет `make test`: тот валит сборку, reviewdog показывает, где именно. Дёшево, ставится одним GitHub Action |
| **ECC-ревьюеры через headless Claude** (`claude -p` в CI) | **взять** | наши промпты и наши правила уже есть локально (`~/.claude/agents/*-reviewer.md`); не завязываемся на чужую платформу |
| PR-Agent (open-source core, self-hosted) | запасной вариант | готовая обвязка «LLM-ревью → комментарии в PR», совместим с Anthropic API; но дублирует ECC-ревьюеров и добавляет платформу, которую надо хостить |
| open-code-review (Alibaba) | посмотреть позже | 14.6k звёзд, гибрид «детерминированные проверки + LLM»; встроенные правила заточены под Java (NPE, thread-safety) — ценность для Python не проверена |
| CodeRabbit | нет | хостинг у третьей стороны: код приватных репо уходит наружу — вопрос политики; бесплатный план — в основном summary |
| Repowise PR Bot | нет | бесплатен только для публичных репо, наши — приватные |

Итог: слой ревью в CI = **reviewdog (механика: ruff/mypy/pylint) + ECC-ревьюеры
через `claude -p` (логика/архитектура)**. Оба шага добавляются в sdd-ci.yml после
пилота на WBN. Отражено в NEXT_STEPS.md.
