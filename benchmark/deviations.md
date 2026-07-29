# Deviations & pre-run amendments

- 2026-07-29 (pre-run): run command amended — added `--model sonnet` (explicit
  pin; fresh config has no default) and `--allowedTools "Bash(*)"` (headless
  acceptEdits blocks all shell commands; discovered during arm B prep session,
  verified with a haiku smoke test). Applies identically to both arms.
- 2026-07-29 (pre-run): spec seeding for arm B was done AFTER task selection
  (Web-2314 was frozen first, kit generated second — reverse of the
  recommended order). Mitigation: seeded capability chosen from repo
  structure (api-gateway authorization/forwarding is a core capability), not
  from the ticket text. Contamination risk acknowledged: the seeded spec
  covers the same subsystem the task touches.
- 2026-07-29: arm B prep session could not run `openspec validate` itself
  (permission sandbox); conductor validated manually after the session —
  1 passed, 0 failed (strict).
- Kit prep cost (break-even input): bootstrap.sh ~6 s, $0; LLM prep session
  (AGENTS.md fill + gateway spec seeding, sonnet, 9.5 min): **$3.60**
  (57k output, 5.1M cacheRead, 270k cacheCreation + $0.0008 haiku).
