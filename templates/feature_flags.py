"""Feature flags with a death date (ADR-0007) - the whole system is this file.

Lifecycle (canonical; other docs link here):

1. A flag is declared here, with its `expires` date, as part of an OpenSpec
   change. Owner and ticket are NOT fields - they live in that change and in
   `git blame` of this file.
2. Code reads the flag only through `is_enabled()`, never `os.environ` inline,
   so call sites survive a move to OpenFeature/flagd.
3. Enabling is per-environment: `FLAG_<NAME>=1`. Nothing is on by default;
   the flag name and the env var go in the QA handoff comment (ADR-0011 §3).
4. On expiry the flag AND its dead code branch are removed - that deletion is
   a task in the same tasks.md. `make sdd-flags` enforces it: WARN for
   GRACE_DAYS after `expires`, then FAIL. Extending a date is a diff, so it
   gets discussed at review.
5. Cross-repo contract flags: set the same `expires` date by hand in both
   repos and write it in the contract spec; divergence is caught at change
   review, not by a scanner.

    from feature_flags import is_enabled
    if is_enabled("use_new_telephony"):
        ...
"""

from __future__ import annotations

import datetime as dt
import os
import sys

GRACE_DAYS = 7  # WARN for this long after expires, then FAIL (ADR-0007)

# ponytail: name -> expires (ISO date). A dict and two functions is the entire
# flag system - no owner/ticket fields, no store scan; move to openfeature-sdk
# + flagd only if %-rollout is ever actually needed.
FLAGS: dict[str, str] = {
    # "use_new_telephony": "2026-09-01",
}


def is_enabled(name: str) -> bool:
    if name not in FLAGS:
        raise KeyError(f"unknown feature flag: {name!r} - register it in FLAGS first")
    return os.environ.get(f"FLAG_{name.upper()}", "").lower() in ("1", "true", "yes")


def check() -> int:
    today, failed, warned = dt.date.today(), 0, 0
    for name, expires in FLAGS.items():
        try:
            over = (today - dt.date.fromisoformat(expires)).days
        except (TypeError, ValueError):
            print(f"FAIL: flag {name}: bad expires {expires!r} - need an ISO date (YYYY-MM-DD)")
            failed += 1
            continue
        if over > GRACE_DAYS:
            print(f"FAIL: flag {name} expired {over} days ago")
            print("next: delete the flag and its dead branch, or re-negotiate expires in review")
            failed += 1
        elif over > 0:
            print(f"WARN: flag {name} expired {over} days ago - {GRACE_DAYS - over} days until this blocks CI")
            warned += 1
    if failed:
        return 1
    print(f"sdd-flags: {len(FLAGS)} flags, {warned} warnings, 0 expired past grace - OK")
    return 0


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(check())
    print("feature_flags: use --check; see module docstring for the flag lifecycle")
