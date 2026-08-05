Read /tmp/sdd-review.diff (a diff of this branch / pull request against its base).
Review it following the rules of the `backend-reviewer` and `database-reviewer`
agents (they come from the code-conventions plugin - locate them and read them
first, then apply each where relevant; if neither is available, say so in one
line at the top of the report and review with the repo's own rules).
Repo context: AGENTS.md.
If /tmp/tools.txt exists, Read it too - static-tool leads
(radon/complexipy/vulture/semgrep) for the changed files; verify each lead in
code before reporting it. semgrep security findings that verify as real are at
least HIGH.
Report ONLY CRITICAL and HIGH issues, each with file:line and a one-line fix.
Language: write each finding's explanation in Russian (the developer reads it);
keep the `[SEVERITY] file:line - ... (action)` frame, severity, action tags,
and the exact `LGTM - no CRITICAL/HIGH issues` string in English.
If there are none, reply exactly: LGTM - no CRITICAL/HIGH issues.
