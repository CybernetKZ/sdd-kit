#!/usr/bin/env node
// PreCompact hook: write a survival packet before context compaction, so the
// post-compaction agent resumes work instead of re-deriving state.
// Idea ported from SmartAndPoint/ProjectStore (ADR-0008). Never blocks (exit 0).
"use strict";
const { execSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const sh = (cmd) => {
  try { return execSync(cmd, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); }
  catch { return ""; }
};

const changesDir = path.join(root, "openspec", "changes");
let changes = [];
try {
  changes = fs.readdirSync(changesDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== "archive")
    .map((d) => d.name);
} catch { /* no openspec — still useful for branch/diff state */ }

const packet = [
  "# Session state before compaction (written by pre-compact hook)",
  `Written: ${new Date().toISOString()}`,
  "",
  `Branch: ${sh("git rev-parse --abbrev-ref HEAD") || "unknown"}`,
  `Last commit: ${sh("git log -1 --oneline") || "none"}`,
  "",
  "## Active OpenSpec changes",
  changes.length ? changes.map((c) => `- openspec/changes/${c}/`).join("\n") : "- none",
  "",
  "## Uncommitted work (git status)",
  "```",
  sh("git status --short") || "clean",
  "```",
  "",
  "## Diff vs dev (files)",
  "```",
  sh("git diff --stat dev...HEAD 2>/dev/null | tail -20") || "n/a",
  "```",
  "",
  "Resume: read the active change's tasks.md and continue from the first unchecked task.",
  "",
].join("\n");

try {
  const out = path.join(root, ".claude", "last-session-state.md");
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, packet);
} catch { /* never block compaction */ }
process.exit(0);
