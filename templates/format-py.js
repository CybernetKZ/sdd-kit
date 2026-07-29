#!/usr/bin/env node
/**
 * PostToolUse hook: auto-format a just-edited Python file with ruff.
 * Best-effort and never blocking — always exits 0.
 * Tries `ruff` on PATH first, then `uvx ruff`; silently gives up if neither works.
 */
'use strict';
const { execFileSync } = require('child_process');

let raw = '';
process.stdin.on('data', (d) => (raw += d));
process.stdin.on('end', () => {
  let file;
  try { file = JSON.parse(raw)?.tool_input?.file_path; } catch { process.exit(0); }
  if (!file || !file.endsWith('.py')) process.exit(0);
  for (const argv of [['ruff', 'format', '--quiet', file], ['uvx', 'ruff', 'format', '--quiet', file]]) {
    try { execFileSync(argv[0], argv.slice(1), { stdio: 'ignore' }); break; } catch { /* next */ }
  }
  process.exit(0);
});
