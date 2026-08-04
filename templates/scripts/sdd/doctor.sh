#!/usr/bin/env bash
# scripts/sdd/doctor.sh — shim so the whole SDD surface lives under
# scripts/sdd/ (ADR-0026); the real diagnostics stay in .claude/scripts/.
exec bash .claude/scripts/sdd-doctor.sh "$@"
