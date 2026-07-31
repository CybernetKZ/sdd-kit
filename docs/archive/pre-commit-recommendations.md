# example:

```
exclude: |
  (?x)^(
      .*\{\{.*\}\}.*|     # Exclude any files with cookiecutter variables
      docs/site/.*|       # Exclude mkdocs compiled files
      \.history/.*|       # Exclude history files
      .*cache.*/.*|       # Exclude cache directories
      .*venv.*/.*|        # Exclude virtual environment directories
  )$
fail_fast: true
default_language_version:
  python: python3.12
default_install_hook_types:
  - pre-commit
  - commit-msg
repos:
  # Generic cleanup and config-file checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        name: "git - Block large file commits"
        args: ['--maxkb=5000']
      - id: check-executables-have-shebangs
        name: "filesystem/exec - Verify shebang presence"
      - id: check-shebang-scripts-are-executable
        name: "filesystem/exec - Verify script permissions"
      - id: check-case-conflict
        name: "filesystem/names - Check case sensitivity"
      - id: check-symlinks
        name: "filesystem/symlink - Check symlink validity"
      - id: destroyed-symlinks
        name: "filesystem/symlink - Detect broken symlinks"
      - id: check-merge-conflict
        name: "git - Detect conflict markers"
      - id: forbid-new-submodules
        name: "git - Prevent submodule creation"
      - id: no-commit-to-branch
        name: "git - Protect main branches"
        args: ["--branch", "main", "--branch", "master", "--branch", "prod"]
      

  # Python: lint + formatting (Ruff)
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.14.7
    hooks:
      - id: ruff-check
        args: ["--fix"]

  # SQL lint + formatting
  - repo: https://github.com/sqlfluff/sqlfluff
    rev: 0.5.3
    hooks:
      - id: sqlfluff-lint
        name: "SQL - Attempts to fix rule violations."
      - id: sqlfluff-fix
        name: "SQL - Lint SQL code files"

  # Security: detect secrets
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets

  # Spelling and text checks
  - repo: https://github.com/codespell-project/codespell
    rev: v2.2.6
    hooks:
      - id: codespell

  # Docstring coverage
  - repo: https://github.com/econchick/interrogate
    rev: 1.5.0
    hooks:
      - id: interrogate
        args: ["--quiet", "--fail-under=70"]

  # Static typing
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.12.0
    hooks:
      - id: mypy
        additional_dependencies:
          - types-requests
          - types-PyYAML
  # Note: MyPy is the original type checker, but Pyright offers better speed and features.
  # - repo: <https://github.com/RobertCraigie/pyright-python>
  #  rev: v1.1.391
  #  hooks:
  #    - id: pyright
  #      name: "python - Check types"

  # validate-pyproject specifically handles pyproject.toml validation
  - repo: <https://github.com/abravalheri/validate-pyproject>
    rev: v0.23
    hooks:
      - id: validate-pyproject
        name: "python - Validate pyproject.toml"
        additional_dependencies: ["validate-pyproject-schema-store[all]"]
   
  # STRICT
  - repo: <https://github.com/shellcheck-py/shellcheck-py>
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
        name: "shell - Lint shell scripts"
   
  - repo: <https://github.com/hukkin/mdformat>
    rev: 0.7.21
    hooks:
      - id: mdformat
        name: "markdown - Format markdown"
        additional_dependencies:
          - mdformat-gfm          # GitHub-Flavored Markdown support
          - mdformat-ruff         # Python code formatting
          - mdformat-frontmatter  # YAML frontmatter support
          - ruff                  # Required for mdformat-ruff

  # Python security analysis
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.9
    hooks:
      - id: bandit
        args: ["-q", "-ll"]

  # Commit message semantic validation
  - repo: https://github.com/alessandrojcm/commitlint-pre-commit-hook
    rev: v9.16.0
    hooks:
      - id: commitlint
        stages: [commit-msg]
        additional_dependencies:
          - "@commitlint/config-conventional"
  # Note: Commitizen provides a CLI interface for standardized commits, with alternatives like czg for AI-generated commits.
  -  repo:  <https://github.com/commitizen-tools/commitizen> 
      rev:  v4.1.0 
      hooks: 
        -  id:  commitizen 
          name:  "git - Validate commit message" 
          stages: [ commit-msg ]
          
  - repo: local
    hooks:
      - id: pytest-collect
        name: test - Validate test formatting
        entry: ./.venv/bin/pytest tests
        language: system
        types: [python]
        args: ["--collect-only"]
        pass_filenames: false
        always_run: true
      # STRICT
      - id: pytest-fast
        name: test - Run fast tests
        entry: ./.venv/bin/pytest tests
        language: system
        types: [python]
        args: ["--max-timeout=3"]
        pass_filenames: false
        always_run: true

```

Hook-by-hook: what it is and why
Cleanup & config-file hooks
Hooks: trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files

Purpose: repository hygiene.

They remove trailing spaces, normalize file endings, validate YAML syntax, and avoid accidentally committing large
binary files.

Useful for keeping diffs small and preventing CI failures.

Python lint + format - Ruff
Repo: https://github.com/astral-sh/ruff-pre-commit
Docs: https://docs.astral.sh/ruff/rules/

Ruff replaces flake8, isort, and parts of black in a single fast tool.

It formats imports, enforces style rules, and catches common errors.

Ensures consistent Python code across analytics and ML repos.

SQL lint + format - SQLFluff
Repo: https://github.com/sqlfluff/sqlfluff
Docs: https://docs.sqlfluff.com/en/latest/production/pre_commit.html

SQLFluff standardizes SQL formatting and validates SQL structure.

It is essential for dbt-based data pipelines and any analytics project where SQL readability matters.

Security scan - detect-secrets
Repo: https://github.com/Yelp/detect-secrets

Scans staged files and detects API keys, tokens, and credentials.

Prevents leaking sensitive information into Git history.

Spelling & text checks - codespell
Repo: https://github.com/codespell-project/codespell

Detects spelling mistakes in comments, docstrings, Markdown, configs, and SQL.

Improves documentation quality and prevents typos from spreading across the repo.

Docstring coverage - interrogate
Repo: https://github.com/econchick/interrogate

Checks whether modules, functions, and classes have docstrings.

Supports thresholds ( - fail-under=70) to enforce minimal documentation coverage.

Useful for maintaining clarity in rapidly growing ML/ETL codebases.

Static typing - mypy
Repo: https://github.com/pre-commit/mirrors-mypy

Analyzes Python type correctness.

Catches type mismatches, incorrect return types, and missing attributes before runtime.

Important for complex data pipelines, ML preprocessing, and services that depend on strict contracts.

Python security analysis - bandit
Repo: https://github.com/PyCQA/bandit

Flags insecure patterns such as unsafe eval, weak cryptography, and injection-prone operations.

Adds another layer of security before code reaches production.

Commit message semantics - commitlint
Repo: https://github.com/alessandrojcm/commitlint-pre-commit-hook

Validates commit messages using the Conventional Commits specification.

Ensures consistent commit history and enables automated changelogs and versioning.

minimal config file:

{
"extends": ["@commitlint/config-conventional"]
}
How pre-commit works
pre-commit runs only on staged files unless otherwise configured. When you commit, all defined hooks execute in the
configured order. If any hook fails, the commit is blocked until the issue is fixed.

Main commands:

pre-commit install # enable hooks
pre-commit run --all-files # run all hooks on the full repo
Where these hooks are useful
repo is actively developed with multiple contributors
you need to ensure minimal documentation coverage
the team adheres to strict typing
Python code security is important (especially in internal ML/ETL services)
you want to enforce semantic commits for CI and auto-generation of versions
Limitations
MyPy can be slow on large codebases
Interrogate creates noise in early projects with low docstring coverage
Commitlint requires creating .commitlintrc.json or .commitlint.config.js
Bandit gives false-positives on simple utility functions
Codespell requires a whitelist for domain words (e.g. "dbt", "Airflow")

# Sources

1. https://medium.com/@andrii.suruhov/top-pre-commit-hooks-for-data-ml-analytics-projects-dd65ad4bb0a7
   This guide shows how to use pre-commit to enforce code quality in repositories that include Python, SQL,
   configuration files, and utility scripts. The goal is to catch errors early and keep the project consistent.
2. https://pre-commit.com/
   A framework for managing and maintaining multi-language pre-commit hooks.
3. https://gatlenculp.medium.com/effortless-code-quality-the-ultimate-pre-commit-hooks-guide-for-2025-57ca501d9835
   Effortless Code Quality: Ultimate Pre-Commit Hooks Guide for 2025
4. https://freedium-mirror.cfd/https://medium.com/@tej.g/strategic-git-setup-for-fastapi-flask-projects-an-architects-handbook-2955999cc4b1
   Strategic Git Setup for FastAPI/Flask Projects: An Architect's Handbook. this guide, we'll walk through essential Git
   setup steps and powerful development tools you should configure immediately for clean and maintainable code.
5. https://github.com/best-doctor/pre-commit-hooks
   This repo contains BestDoctor's pre-commit hooks for python projects.
6. https://github.com/pre-commit/pre-commit-hooks
   Some out-of-the-box hooks for pre-commit.
7. https://github.com/astral-sh/ruff-pre-commit
   A pre-commit hook for Ruff.
8. https://dev.to/techishdeep/maximize-your-python-efficiency-with-pre-commit-a-complete-but-concise-guide-39a5
   The Power of Pre-Commit for Python Developers: Tips and Best Practices
9. https://github.com/fastapi/full-stack-fastapi-template/blob/master/.pre-commit-config.yaml
10. https://freedium-mirror.cfd/https://levelup.gitconnected.com/ship-better-code-5-essential-pre-commit-hooks-for-python-developers-215e13387cbc
    Ship Better Code: 5 Essential Pre-Commit Hooks for Python Developers

---

# Вердикт для нашего стека (2026-07-28)

Вопрос: переходить ли на фреймворк pre-commit.com или остаться на простых `.git/hooks`.

**Решение: фреймворк НЕ брать. Остаёмся на простых хуках, добавляем в них дешёвые проверки.**

Почему не фреймворк:

- За слот `.git/hooks/pre-commit` уже конкурируют три вещи: `make sdd-check`, ruff format (в WBN и VA) и наш запрет
  `--no-verify`.
- `pre-commit install` при повторном запуске молча перезапишет наш вписанный вручную sdd-check.
- Главные плюсы фреймворка (мульти-язычные тулчейны, автообновление хуков) нам не нужны: один язык, версии уже пинованы
  в uv.lock.
- Даже официальный шаблон FastAPI использует pre-commit в основном как YAML-обёртку над `uv run ruff/mypy` - это мы
  делаем и без него.

Что добавить в наш существующий хук (дёшево, мало ложных срабатываний):

- `ruff check --fix` рядом с format (ловит баги, а не только форматирование);
- маркеры незакрытого мержа (`<<<<<<<`);
- случайные большие файлы (дампы, аудио);
- забытые `breakpoint()` / `pdb.set_trace()`;
- битые YAML/TOML/JSON (у нас несколько workflow-файлов);
- утечка приватных ключей (detect-private-key или gitleaks).

Что не брать и почему:

- bandit - много ложных срабатываний (это признаёт сам источник 1); вместо него можно включить S-правила ruff;
- interrogate (покрытие докстрингами) - шумно на живой кодовой базе;
- commitlint/commitizen - жёсткий гейт на формат коммитов без договорённости команды будет мешать; вернуться позже;
- SQLFluff - сырой SQL мы почти не пишем (SQLAlchemy 2.0);
- хуки под Django (best-doctor) - не наш стек;
- zizmor (линтер безопасности GitHub Actions) - идея здравая, кандидат на потом.

Когда пересмотреть: появится 5-6-й репозиторий, JS-фронтенд/ноутбуки в этих репо,
или логика хуков начнёт дублироваться настолько, что общий версионируемый конфиг окупится.
Если решение изменится - форкать конфиг из `full-stack-fastapi-template` (источник 9),
вставив `make sdd-check` первым local-хуком.

---

# Дополнение к вердикту (2026-07-28, после разбора примера конфига выше)

Из примера в начале файла в наш простой хук взяты ещё 4 проверки
(шаблон `sdd-kit/templates/pre-commit-hook.sh`, раскатано во все репо):

- защита веток: прямой коммит в main/master/prod/stage блокируется,
  в dev - предупреждение (пока команда не договорилась; серверный branch
  protection остаётся главным гейтом); обход для сознательных исключений -
  `SDD_ALLOW_PROTECTED=1`;
- запрет новых сабмодулей/вложенных репозиториев (у нас уже была боль
  с личным репо внутри `web-backend-new/docs/`);
- поиск секретов по паттернам токенов (sk-ant-, ghp_, github_pat_, AKIA,
  xoxb- и т.п.) - шире, чем один private key;
- валидация YAML и TOML рядом с JSON (мягко пропускается, если парсера нет).

Из примера НЕ взято (сверх уже отклонённого вердиктом):
- validate-pyproject - pyproject меняется редко, CI поймает;
- check-case-conflict, shebang-проверки - команда на Linux, кейс редкий;
- pytest-collect/pytest-fast как хук - тесты у нас требуют docker-окружения,
  локальный хук будет либо падать зря, либо вечно пропускаться; место тестов - CI;
- codespell - нужен вайтлист доменных слов, шум; пересмотреть при желании позже.
