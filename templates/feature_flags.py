"""Feature flags with an expiry date (ADR-0007).

Every flag has an owner, a ticket, and a death date. `make sdd-flags` (part of
`make sdd-check`) fails when a flag outlives its `expires` by more than the
grace period: 7 days of WARN, then FAIL. Extending `expires` is a diff — it
shows up in review.

Cross-repo contract flags (producer and consumer in different repos): the
`expires` date lives ONLY in the contract spec in the central store; here you
set `spec=` instead of `expires=`. The checker reads the date from the store
checkout; no store on the machine -> WARN, not FAIL.

Usage in code — always through the accessor, never read settings inline
(keeps the call sites stable if we ever move to OpenFeature/flagd):

    from feature_flags import is_enabled
    if is_enabled("use_new_telephony"):
        ...

Toggling: environment variable FLAG_<NAME>=1 (e.g. FLAG_USE_NEW_TELEPHONY=1).
"""

from __future__ import annotations

import datetime as dt
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

GRACE_DAYS = 7  # WARN for this long after expires, then FAIL (ADR-0007)


@dataclass(frozen=True)
class FlagMeta:
    owner: str  # who deletes the flag
    ticket: str  # WEB-XXXX that introduced it
    expires: str | None = None  # ISO date; omit only when spec= is set
    spec: str | None = None  # store spec name for cross-repo contract flags


FLAGS: dict[str, FlagMeta] = {
    # "use_new_telephony": FlagMeta(owner="daniil", ticket="WEB-2303",
    #                               spec="telephony-in-redis-stream"),
    # "new_report_layout": FlagMeta(owner="daniil", ticket="WEB-2400",
    #                               expires="2026-09-01"),
}


def is_enabled(name: str) -> bool:
    if name not in FLAGS:
        raise KeyError(f"unknown feature flag: {name!r} — register it in FLAGS first")
    return os.environ.get(f"FLAG_{name.upper()}", "").lower() in ("1", "true", "yes")


# ---------------------------------------------------------------- expiry check
# ponytail: env-var flags + this stdlib checker is the whole system; move to
# openfeature-sdk + flagd only if %-rollout is ever actually needed.

def _store_expires(spec: str, flag: str) -> str | None:
    """Find `<flag> ... expires: YYYY-MM-DD` in the central store's spec."""
    store = Path(os.environ.get("SDD_STORE_DIR", str(Path.home() / "cybernet/cybernet-specs")))
    if not store.is_dir():
        return None
    pat = re.compile(rf"{re.escape(flag)}.*?expires[:=]\s*(\d{{4}}-\d{{2}}-\d{{2}})")
    for md in store.rglob(f"*{spec}*/**/*.md"):
        m = pat.search(md.read_text(errors="ignore"))
        if m:
            return m.group(1)
    for md in store.rglob("*.md"):  # fallback: spec name not a directory
        m = pat.search(md.read_text(errors="ignore"))
        if m:
            return m.group(1)
    return None


def check() -> int:
    today = dt.date.today()
    failed = warned = 0
    for name, meta in FLAGS.items():
        expires = meta.expires
        if meta.spec and not expires:
            expires = _store_expires(meta.spec, name)
            if expires is None:
                print(f"WARN: flag {name}: expires not found in store spec '{meta.spec}' "
                      f"(store missing or date not declared) — declare `expires:` in the contract spec")
                warned += 1
                continue
        if not expires:
            print(f"FAIL: flag {name}: no expires date and no spec= — every flag has a death date")
            failed += 1
            continue
        over = (today - dt.date.fromisoformat(expires)).days
        if over > GRACE_DAYS:
            print(f"FAIL: flag {name} expired {over} days ago (owner: {meta.owner}, {meta.ticket})")
            print(f"next: delete the flag and its dead branch, or re-negotiate expires in review")
            failed += 1
        elif over > 0:
            print(f"WARN: flag {name} expired {over} days ago — {GRACE_DAYS - over} days until this blocks CI")
            warned += 1
    if failed:
        return 1
    print(f"sdd-flags: {len(FLAGS)} flags, {warned} warnings, 0 expired past grace — OK")
    return 0


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.exit(check())
    # self-check: the checker's own date math
    assert (dt.date(2026, 1, 20) - dt.date.fromisoformat("2026-01-10")).days == 10
    print("feature_flags: use --check; see module docstring for usage")
