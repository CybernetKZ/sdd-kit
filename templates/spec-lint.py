#!/usr/bin/env python3
"""spec-lint: freshness and metadata checks for openspec/specs/**/spec.md,
plus metadata checks for the spec deltas of active openspec/changes/**.

FRESHNESS  compares each spec's `> Last verified: <date> (commit <hash>)` marker
           against the source files named by its `<!-- enforced: ... -->` anchors.
           A spec is STALE when any enforced file changed since that commit.
METADATA   checks that every `### Requirement:` block carries `id` and `enforced`,
           that ids are unique, that only whitelisted metadata keys are used, and
           that `#### Scenario:` blocks never appear under `## Invariants`. Active change
           deltas get the same metadata checks (archived ones are closed history);
           their anchors are reported as advice, never as violations - a delta may
           legitimately name a symbol the change is about to create.

Report goes to STDERR, machine-readable JSON to STDOUT.
Exit codes: 0 = clean or warn-only (default), 1 = metadata violations,
2 = stale/missing anchors. Non-zero only when SPEC_LINT_STRICT=1 (or --strict).
Stdlib only, Python 3.10+.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Metadata keys accepted inside `<!-- key: value -->` comments. Hyphens allowed.
ALLOWED_KEYS = frozenset(
    {
        "id",
        "enforced",
        "entities",
        "source",
        "removal-reason",
        "replacement",
        # keys produced by the spec-miner agent
        "test",
        "verified_by",
        "depends_on",
        "triggers",
        "uncertainty",
        "deferred",
    }
)

META_RE = re.compile(r"^<!--\s*([A-Za-z][A-Za-z0-9_-]*)\s*:\s*(.*?)\s*-->\s*$")
VERIFIED_RE = re.compile(r"^>\s*Last verified:\s*(\S+)\s*\(commit\s+([0-9a-fA-F]{6,40})\)")


def git(root: Path, *args: str) -> tuple[bool, str]:
    """Run git, never raise. Returns (ok, stdout)."""
    try:
        done = subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True, timeout=60
        )
    except (OSError, subprocess.SubprocessError):
        return False, ""
    return done.returncode == 0, done.stdout


def resolve_anchor(anchor: str, root: Path) -> list[str]:
    """Resolve one `enforced` anchor to an existing repo-relative file.

    One anchor may name several files, `;`-separated; each is
    `path/to/file.py` with an optional `:`-suffix holding `,`-separated line
    numbers, `12-34` ranges or symbol names.

    The suffix is validated too: a miner that hallucinates `file.py:no_such_fn`
    used to pass every gate, because only the file was checked (CF defect M1).
    Every named file counts toward freshness - the old parser kept only the
    first one, so edits to the rest went unnoticed.
    """
    files: list[str] = []
    for part in anchor.split(";"):
        resolved = _resolve_one(part.strip(), root)
        if not resolved:
            return []  # one bad part discredits the whole anchor
        files.append(resolved)
    return files


def _resolve_one(anchor: str, root: Path) -> str:
    """Resolve a single-file anchor, or "" when it does not check out."""
    path, _, suffix = anchor.partition(":")
    target = root / path
    if not path or not target.is_file():
        return ""
    if not suffix.strip():
        return path
    try:
        text = target.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    for token in suffix.split(","):
        # ponytail: substring match, not a parser - a symbol that appears
        # anywhere in the file proves the anchor was read, not invented
        token = token.strip().rsplit(".", 1)[-1]
        start = token.split("-", 1)[0]
        if not token:
            continue
        if start.isdigit():
            if int(start) > text.count("\n") + 1:
                return ""
        elif token not in text:
            return ""
    return path


def parse_spec(path: Path) -> dict:
    """Extract the freshness marker, enforced anchors and metadata findings."""
    spec: dict = {"anchors": [], "commit": None, "date": None, "violations": [], "ids": []}
    section = ""
    requirement: dict | None = None
    requirements: list[dict] = []
    lines = path.read_text(encoding="utf-8").splitlines()

    def close(req: dict | None) -> None:
        if req is None:
            return
        for key in ("id", "enforced"):
            if key not in req["keys"]:
                spec["violations"].append(
                    {
                        "kind": f"missing_{key}",
                        "line": req["line"],
                        "message": f"requirement {req['title']!r} has no <!-- {key}: ... --> comment",
                    }
                )
        requirements.append(req)

    for number, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("## "):
            close(requirement)
            requirement = None
            section = stripped[3:].strip()
        elif stripped.startswith("### "):
            close(requirement)
            requirement = None
            if stripped.startswith("### Requirement:"):
                requirement = {
                    "title": stripped[len("### Requirement:") :].strip(),
                    "line": number,
                    "keys": {},
                }
        elif stripped.startswith("#### "):
            if stripped.startswith("#### Scenario:") and section.lower() == "invariants":
                spec["violations"].append(
                    {
                        "kind": "scenario_under_invariants",
                        "line": number,
                        "message": f"scenario {stripped[len('#### Scenario:'):].strip()!r} sits under ## Invariants",
                    }
                )
            close(requirement)  # scenario comments are not requirement metadata
            requirement = None

        match = META_RE.match(stripped)
        if match:
            key, value = match.group(1), match.group(2)
            if key not in ALLOWED_KEYS:
                spec["violations"].append(
                    {
                        "kind": "unknown_key",
                        "line": number,
                        "message": f"metadata key {key!r} is not in the whitelist",
                    }
                )
            if key == "enforced" and value:
                spec["anchors"].append(value)
            if key == "id" and value:
                spec["ids"].append({"id": value, "line": number})
            if requirement is not None:
                requirement["keys"][key] = value
            continue

        verified = VERIFIED_RE.match(stripped)
        if verified and spec["commit"] is None:
            spec["date"], spec["commit"] = verified.group(1), verified.group(2)

    close(requirement)
    spec["requirements"] = len(requirements)
    return spec


def check_deltas(root: Path) -> list[dict]:
    """Metadata-check the spec deltas of active changes, before they reach the canon.

    Deltas were invisible to this script until a change was applied, so a
    fabricated key or symbol only surfaced at implementation time (CF defect M1,
    found again during the phase-4 pilot). Freshness makes no sense here - a
    delta describes behaviour that does not exist yet - and an unresolved anchor
    is legitimate when the change creates the file, so anchors are reported as
    advice and never as a violation.
    """
    out: list[dict] = []
    for path in sorted((root / "openspec" / "changes").glob("*/specs/*/spec.md")):
        if "archive" in path.relative_to(root).parts:
            continue  # history: closed, never re-litigated
        spec = parse_spec(path)
        rel = str(path.relative_to(root))
        unresolved = [a for a in sorted(set(spec["anchors"])) if not resolve_anchor(a, root)]
        # ponytail: no duplicate-id check here - a MODIFIED delta reuses the
        # canonical id by design, so collisions are the normal case, not a bug.
        out.append({"delta": rel, "requirements": spec["requirements"],
                    "violations": spec["violations"], "unresolved_anchors": unresolved})
    return out


def check_freshness(spec: dict, root: Path, cache: dict) -> dict:
    anchors = sorted(set(spec["anchors"]))
    missing, files = [], set()
    for anchor in anchors:
        resolved = resolve_anchor(anchor, root)
        if resolved:
            files.update(resolved)
        else:
            missing.append(anchor)

    commit = spec["commit"]
    if not commit:
        return {"status": "UNVERIFIED", "reason": "no `> Last verified:` line", "stale_files": [],
                "missing_anchors": missing, "enforced_files": len(files)}
    if commit not in cache:
        ok, out = git(root, "diff", "--name-only", f"{commit}..HEAD")
        cache[commit] = sorted(out.split()) if ok else None
    changed = cache[commit]
    if changed is None:
        return {"status": "UNVERIFIED", "reason": f"commit {commit} is not in this clone (shallow "
                "checkout? CI needs actions/checkout with fetch-depth: 0)", "stale_files": [],
                "missing_anchors": missing, "enforced_files": len(files)}

    stale = sorted(files.intersection(changed))
    status = "MISSING" if missing else ("STALE" if stale else "FRESH")
    return {"status": status, "reason": "", "stale_files": stale, "missing_anchors": missing,
            "enforced_files": len(files)}


def self_check() -> int:
    """Assert the anchor resolver, the one piece with real parsing in it."""
    import tempfile

    root = Path(tempfile.mkdtemp())
    (root / "a.py").write_text("line1\ndef real_fn():\n    pass\n", encoding="utf-8")
    (root / "b.py").write_text("class Klass:\n    def meth(self): pass\n", encoding="utf-8")
    cases = {
        "a.py": ["a.py"], "a.py:2": ["a.py"], "a.py:1-3": ["a.py"], "a.py:2,3": ["a.py"],
        "a.py:real_fn": ["a.py"], "a.py:Klass.real_fn": ["a.py"],
        "a.py:real_fn; b.py:Klass.meth": ["a.py", "b.py"],
        # every one of these used to pass the gate
        "a.py:999": [], "a.py:2,999": [], "a.py:ghost_fn": [], "a.py:real_fn,ghost_fn": [],
        "a.py:real_fn; b.py:ghost_fn": [], "nope.py": [], "nope.py:real_fn": [],
    }
    bad = {a: (resolve_anchor(a, root), want) for a, want in cases.items()
           if resolve_anchor(a, root) != want}
    for anchor, (got, want) in bad.items():
        print(f"spec-lint self-check FAIL {anchor!r}: got {got}, want {want}", file=sys.stderr)
    print(f"spec-lint self-check: {len(cases) - len(bad)}/{len(cases)} passed")
    return 1 if bad else 0


def main() -> int:
    if "--self-check" in sys.argv:
        return self_check()
    parser = argparse.ArgumentParser(
        prog="spec-lint.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--root", default=None, help="repository root (default: git root or cwd)")
    parser.add_argument("--strict", action="store_true", help="same as SPEC_LINT_STRICT=1")
    parser.add_argument("--json", action="store_true",
                        help="dump the full JSON payload to stdout (default: human report only)")
    args = parser.parse_args()

    strict = args.strict or os.environ.get("SPEC_LINT_STRICT") == "1"
    if args.root:
        root = Path(args.root).resolve()
    else:
        ok, out = git(Path.cwd(), "rev-parse", "--show-toplevel")
        root = Path(out.strip()).resolve() if ok and out.strip() else Path.cwd()

    specs = sorted((root / "openspec" / "specs").glob("*/spec.md"))
    specs += sorted(p for p in (root / "openspec" / "specs").glob("*/*/spec.md"))
    if not specs:
        if args.json:
            print(json.dumps({"specs": [], "totals": {}, "note": "no specs found"}))
        print(f"spec-lint: no specs under {root}/openspec/specs - nothing to check", file=sys.stderr)
        return 0

    cache: dict[str, list[str] | None] = {}
    results, seen_ids = [], {}
    for path in specs:
        spec = parse_spec(path)
        rel = str(path.relative_to(root))
        for entry in spec["ids"]:
            where = seen_ids.get(entry["id"])
            if where:
                spec["violations"].append({"kind": "duplicate_id", "line": entry["line"],
                                           "message": f"id {entry['id']!r} already used at {where}"})
            else:
                seen_ids[entry["id"]] = f"{rel}:{entry['line']}"
        freshness = check_freshness(spec, root, cache)
        results.append({"spec": rel, "requirements": spec["requirements"],
                        "last_verified_date": spec["date"], "last_verified_commit": spec["commit"],
                        "violations": spec["violations"], **freshness})

    deltas = check_deltas(root)

    totals = {status: sum(1 for r in results if r["status"] == status)
              for status in ("FRESH", "STALE", "UNVERIFIED", "MISSING")}
    violations = sum(len(r["violations"]) for r in results)
    violations += sum(len(d["violations"]) for d in deltas)
    if args.json:
        payload = {"root": str(root), "strict": strict, "specs": results,
                   "totals": {**totals, "specs": len(results), "metadata_violations": violations}}
        print(json.dumps(payload, indent=2, ensure_ascii=False))

    mode = "STRICT" if strict else "WARN-ONLY"
    out = sys.stderr
    # Summary first (agent ergonomics: lead with aggregates, never make the reader count).
    print(f"spec-lint [{mode}] {len(results)} spec(s) checked: "
          + ", ".join(f"{k}={v}" for k, v in totals.items())
          + f"; metadata violations={violations}", file=out)
    for item in results:
        print(f"  {item['status']:<10} {item['spec']}  "
              f"({item['requirements']} req, {item['enforced_files']} enforced file(s), "
              f"verified {item['last_verified_commit'] or '-'})", file=out)
        if item["reason"]:
            print(f"      reason: {item['reason']}", file=out)
        for changed in item["stale_files"]:
            print(f"      changed since last verification: {changed}", file=out)
        for anchor in item["missing_anchors"]:
            print(f"      anchor resolves to no file: {anchor}", file=out)
        for violation in item["violations"]:
            print(f"      {violation['kind']} (line {violation['line']}): {violation['message']}", file=out)
    if deltas:
        bad = sum(1 for d in deltas if d["violations"] or d["unresolved_anchors"])
        print(f"spec-lint: {len(deltas)} change delta(s) checked, {bad} with findings", file=out)
        for item in deltas:
            if not (item["violations"] or item["unresolved_anchors"]):
                continue
            print(f"  DELTA      {item['delta']}  ({item['requirements']} req)", file=out)
            for violation in item["violations"]:
                print(f"      {violation['kind']} (line {violation['line']}): "
                      f"{violation['message']}", file=out)
            for anchor in item["unresolved_anchors"]:
                print(f"      note: anchor does not resolve yet: {anchor} "
                      f"(expected only if this change creates it)", file=out)

    if violations == 0 and not totals["STALE"] and not totals["MISSING"]:
        print("spec-lint: 0 issues found", file=out)

    if not strict:
        print("spec-lint: warn-only mode, exiting 0 (set SPEC_LINT_STRICT=1 to enforce)", file=out)
        return 0
    if violations:
        print("next: fix the metadata violations listed above, then re-run "
              "python3 .claude/scripts/spec-lint.py --strict", file=out)
        return 1
    if totals["STALE"] or totals["MISSING"]:
        print("next: re-verify each STALE/MISSING spec against the code and bump its "
              "'Last verified (commit)' line, then re-run", file=out)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
