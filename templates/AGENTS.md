# AGENTS.md - context for AI agents

<!-- Limit: 500 lines. Enforced by `make sdd-check`. -->
<!-- CLAUDE.md in this repository is a symlink to this file. -->

## What this service is

TODO: 2-4 sentences - why this repository exists and who consumes it.

## Commands

- Tests and all checks: `make test`
- SDD checks only (specs, context): `make sdd-check`
- Run locally: TODO

## Module map

TODO: a short "directory - responsibility" tree. One line per module.

## Resuming after compaction or a new session

If `.claude/last-session-state.md` exists, read it first - it holds the active
OpenSpec change and uncommitted work from before the last context compaction.

## Specs and contracts

- Capability specs for this repository: `openspec/specs/`
- Changes go through `openspec/changes/<id>/` (rule: no code without a spec;
  for refactoring/tooling use `skip_specs: true` in the change metadata).
- Cross-service contracts live in the central store repository,
  wired in via `references:` in `openspec/config.yaml`.
- A Requirement points at its code with
  `<!-- enforced: path/to/file.py:ClassName.method -->` - repo-relative path
  first, symbol after the colon. Grep these anchors by path to find the spec
  covering a file; write them the same way in new Requirements (spec-lint
  resolves the path and reports MISSING without one).

## Codebase search

- Order: if `graphify-out/graph.json` exists, start with a graph query
  (`graphify query "<question>"`) for orientation, then confirm with
  grep/read; no index yet — go straight to grep/read.
- Build/update the index: `make sdd-index` (manual, run before a big intake).
- The graph is navigation/context only (ADR-0004) — its edges are INFERRED,
  never treat them as verified facts; always confirm in the actual code.

## Do not edit by hand

TODO: list generated files and directories (migrations, generated code).

## Repository rules

TODO: 5-10 key conventions (layering, naming, what is forbidden).
