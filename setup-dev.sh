#!/usr/bin/env bash
echo "[sdd-kit] setup-dev.sh is deprecated — use: install.sh --machine-only" >&2
exec "$(dirname "$0")/install.sh" --machine-only "$@"
