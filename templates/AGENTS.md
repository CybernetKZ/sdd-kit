# AGENTS.md - context for AI agents

<!-- Limit: 500 lines. Enforced by `make sdd-check`. -->
<!-- CLAUDE.md in this repository is a symlink to this file. -->

## What this service is

TODO: 2-4 sentences - why this repository exists and who consumes it.

## Commands

- Tests and all checks: `make sdd-test` (kit) or the repo's own test entry point
- SDD checks only (specs, context): `make sdd-check`
- Run locally: TODO

## Module map

TODO: a short "directory - responsibility" tree. One line per module.

## Resuming after compaction or a new session

If `.claude/last-session-state.md` exists, read it first - it holds the active
OpenSpec change and uncommitted work from before the last context compaction.

## Specs and contracts

- Store setup is machine-level, done once by `install.sh --machine-only`
  (clones `cybernet-specs` to a fixed path and runs `openspec store
  register`); if `openspec store list` comes back empty on this machine,
  run that install step before continuing.
- Capability specs for this repository: `openspec/specs/`
- Changes go through `openspec/changes/<id>/` (rule: no code without a spec;
  for refactoring/tooling use `skip_specs: true` in the change metadata).
- Cross-service contracts live in the central store repository,
  wired in via `references:` in `openspec/config.yaml`. Read them in order:
  `openspec store list` (which stores are wired in) -> `openspec list --specs
  --store <name>` (which specs exist) -> `openspec show <spec> --type spec
  --store <name>` (the spec text). `openspec view` only renders the local
  dashboard - it never reads the store, so it cannot substitute for this
  sequence.
- A Requirement points at its code with
  `<!-- enforced: path/to/file.py:ClassName.method -->` - repo-relative path
  first, symbol after the colon. Grep these anchors by path to find the spec
  covering a file; write them the same way in new Requirements (spec-lint
  resolves the path and reports MISSING without one).

## Codebase search

- Order: if `graphify-out/graph.json` exists, orient in the graph first, then
  confirm with grep/read; no index yet - go straight to grep/read.
- Probe by SYMBOL, never by prose (a free-form question makes BFS start from its
  capitalized words and returns noise): `graphify explain "<sym>"` (file:line +
  typed edges) first, then `query "<sym>"` (fan-out ≈ blast radius; precise
  reverse deps - grep/ast-grep),
  `path "A" "B"`, `query "<sym1> <sym2>"`.
- Build/update the index: `make sdd-index` (install/refresh also offers it;
  run before a big intake if the graph lags HEAD).
- The graph is navigation/context only, never a CI gate: `[EXTRACTED]` edges
  come from the AST, `[INFERRED]` ones are guesses - confirm both in the
  actual code.

## Do not edit by hand

TODO: list generated files and directories (migrations, generated code).

## Repository rules

TODO: 5-10 key conventions (layering, naming, what is forbidden).
