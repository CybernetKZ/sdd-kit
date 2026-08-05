#!/usr/bin/env node
/**
 * PreToolUse Hook: block git hook-bypass flags (--no-verify, commit -n,
 * -c core.hooksPath=) so agents cannot skip pre-commit/commit-msg/pre-push.
 *
 * ponytail: regex scan, not a shell parser. This guards a cooperative agent
 * against a bad habit, not an adversary (an adversary runs `sh -c` or a
 * script file anyway). A false positive (e.g. "--no-verify" inside a commit
 * message) just makes the agent rephrase - acceptable. Bring back a real
 * tokenizer only if false positives actually hurt.
 *
 * Exit codes: 0 = allow, 2 = block (message on stderr).
 */
'use strict';

function check(cmd) {
  if (!/\bgit(\.exe)?\b/i.test(cmd)) return null;
  if (/--no-verify\b/.test(cmd)) {
    return 'BLOCKED: --no-verify is not allowed. Git hooks must not be bypassed.';
  }
  if (/-c\s*core\.hookspath=/i.test(cmd)) {
    return 'BLOCKED: overriding core.hooksPath is not allowed. Git hooks must not be bypassed.';
  }
  // commit -n / combined short flags containing n (-an, -anm ...); skip -m/-F
  // etc. values is a parser's job - we accept the rare false positive instead.
  if (/\bgit(\.exe)?\b[^|;&\n]*\bcommit\b[^|;&\n]*\s-[a-zA-Z]*n/.test(cmd)) {
    return 'BLOCKED: git commit -n (--no-verify) is not allowed. Git hooks must not be bypassed.';
  }
  return null;
}

// self-check: node block-no-verify.cjs --test
// (before the stdin subscription — with it first the process would sit
// waiting for stdin and the block below would never run standalone)
if (process.argv[2] === '--test') {
  const assert = require('node:assert');
  assert(check('git commit --no-verify -m x'));
  assert(check('git push --no-verify'));
  assert(check('git -c core.hooksPath=/dev/null commit -m x'));
  assert(check('git -ccore.HOOKSPATH=/tmp commit -m x'));
  assert(check('git commit -anm "x"'));
  assert(check('echo hi && git commit -n'));
  assert(!check('git commit -m "safe message"'));
  assert(!check('git push origin dev'));
  assert(!check('ls -n'));
  assert(!check('git log --name-only'));
  console.log('block-no-verify: self-check OK');
  process.exit(0);
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (d) => (raw += d));
process.stdin.on('end', () => {
  let cmd = raw;
  try { cmd = JSON.parse(raw)?.tool_input?.command ?? raw; } catch { /* plain text */ }
  const reason = typeof cmd === 'string' ? check(cmd) : null;
  if (reason) { process.stderr.write(reason + '\n'); process.exit(2); }
  process.exit(0);
});
