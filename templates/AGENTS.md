# AGENTS.md — context for AI agents

<!-- Limit: 500 lines. Enforced by `make sdd-check`. -->
<!-- CLAUDE.md in this repository is a symlink to this file. -->

## What this service is

TODO: 2-4 sentences — why this repository exists and who consumes it.

## Commands

- Tests and all checks: `make test`
- SDD checks only (specs, context): `make sdd-check`
- Run locally: TODO

## Module map

TODO: a short "directory — responsibility" tree. One line per module.

## Resuming after compaction or a new session

If `.claude/last-session-state.md` exists, read it first — it holds the active
OpenSpec change and uncommitted work from before the last context compaction.

## Specs and contracts

- Capability specs for this repository: `openspec/specs/`
- Changes go through `openspec/changes/<id>/` (rule: no code without a spec;
  for refactoring/tooling use `skip_specs: true` in the change metadata).
- Cross-service contracts live in the central store repository,
  wired in via `references:` in `openspec/config.yaml`.

## Do not edit by hand

TODO: list generated files and directories (migrations, generated code).

## Repository rules

TODO: 5-10 key conventions (layering, naming, what is forbidden).
