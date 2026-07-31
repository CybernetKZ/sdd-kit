Read /tmp/sdd-review.diff (a diff of this branch / pull request against its base).
Review it following the rules in .claude/agents/backend-reviewer.md
and .claude/agents/database-reviewer.md
(read them first; apply each where relevant). Repo context: AGENTS.md.
If /tmp/tools.txt exists, Read it too - static-tool leads
(radon/complexipy/vulture/semgrep) for the changed files; verify each lead in
code before reporting it. semgrep security findings that verify as real are at
least HIGH.
Report ONLY CRITICAL and HIGH issues, each with file:line and a one-line fix.
If there are none, reply exactly: LGTM - no CRITICAL/HIGH issues.
