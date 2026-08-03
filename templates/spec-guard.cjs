#!/usr/bin/env node
/**
 * PreToolUse hook: forbids the agent from editing code
 * when the repository has no active change under openspec/changes/<id>/.
 *
 * Enabled ONLY when the repository root contains a .spec-guard-paths file —
 * a list of path prefixes (one per line) that count as code.
 * No file means the hook stays silent (opt-in per repository).
 *
 * Exit codes: 0 = allow, 2 = block (message on stderr).
 * Keep it simple: prefix matching only; no AST/glob until it actually hurts.
 */
'use strict';
const fs = require('fs');
const path = require('path');

let raw = '';
process.stdin.on('data', (d) => (raw += d));
process.stdin.on('end', () => {
  let input;
  try { input = JSON.parse(raw); } catch { process.exit(0); }
  const file = input?.tool_input?.file_path;
  if (!file) process.exit(0);

  // Repository root comes from Claude Code (same as pre-compact.js).
  const root = process.env.CLAUDE_PROJECT_DIR;
  if (!root) process.exit(0);

  const guardFile = path.join(root, '.spec-guard-paths');
  if (!fs.existsSync(guardFile)) process.exit(0); // not enabled in this repo

  const prefixes = fs.readFileSync(guardFile, 'utf8')
    .split('\n').map((s) => s.trim()).filter((s) => s && !s.startsWith('#'));
  const rel = path.relative(root, path.resolve(file));
  if (!prefixes.some((p) => rel === p || rel.startsWith(p.replace(/\/?$/, '/')))) {
    process.exit(0); // file is outside the guarded code paths
  }

  // An active change is any directory under openspec/changes/ except archive/.
  const changesDir = path.join(root, 'openspec', 'changes');
  let active = [];
  try {
    active = fs.readdirSync(changesDir, { withFileTypes: true })
      .filter((e) => e.isDirectory() && e.name !== 'archive');
  } catch { /* no openspec — blocked below */ }

  if (active.length === 0) {
    console.error(
      `BLOCKED: editing code (${rel}) without an active change in openspec/changes/. ` +
      `Create a change first (/opsx:propose or 'openspec new change'); ` +
      `refactor/tooling work needs one too — just add skip_specs: true to its .openspec.yaml.`
    );
    process.exit(2);
  }
  process.exit(0);
});
