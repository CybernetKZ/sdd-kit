#!/usr/bin/env bash
# scripts/sdd/doctor.sh — shim so the whole SDD surface lives under
# scripts/sdd/ (ADR-0026); the real diagnostics stay in .claude/scripts/.
cd "$(git rev-parse --show-toplevel)" || exit 1
exec bash .claude/scripts/sdd-doctor.sh "$@"
