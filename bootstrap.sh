#!/usr/bin/env bash
echo "[sdd-kit] bootstrap.sh is deprecated — use: install.sh --repo-only /path/to/repo" >&2
exec "$(dirname "$0")/install.sh" --repo-only "$@"
