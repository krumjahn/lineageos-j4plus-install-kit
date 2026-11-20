#!/usr/bin/env python3
"""
adb-ui.py - drive the phone's screen over ADB from the command line.

This is the UI driver that was rewritten during the original session, after the
first version matched the wrong element and silently did nothing useful.

The problem it solves: `uiautomator dump` returns every text on screen, including
status lines and summaries. A naive `grep` for "update" will happily match
"Last successful check for update on Nov 13" - a stale summary line - when what
you wanted was the "Check for update" BUTTON. Tapping the summary does nothing
and, worse, makes the automation report success.

So this scores candidates instead of taking the first match:

    exact text match          +100
    element is clickable      +40
    resource-id contains
      "button" or "btn"       +25
    shorter text is preferred  (tie-break)

Usage
-----

    python3 adb-ui.py texts
        Dump every visible text element with its bounds.

    python3 adb-ui.py dump
        Dump the full XML hierarchy to stdout.

    python3 adb-ui.py find "Check for update"
        Show the scored candidates for a phrase, best first.

    python3 adb-ui.py tap-any "Check for update" "Download and install"
        Tap the best-scoring element matching any of the given phrases.
        Exits non-zero if nothing matched.

    python3 adb-ui.py tap 540 1200
        Tap an absolute coordinate.

    python3 adb-ui.py tap-text "Check for update"
        Tap the element whose text exactly equals the given string.

Requirements
------------

    adb on PATH, one device connected and authorised.

Notes
-----

* This talks to the phone over ADB only. It does not need root.
* If the screen is off or locked, wake and dismiss it first:
      adb shell input keyevent 224      # KEYCODE_WAKEUP
      adb shell wm dismiss-keyguard
      adb shell settings put system screen_off_timeout 1800000
      adb shell svc power stayon true
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

# uiautomator dump writes to a path on the device; we pull it back and parse.
REMOTE_DUMP = "/sdcard/window_dump.xml"

EXACT_TEXT = 100
CLICKABLE = 40
BUTTONISH_ID = 25
# Penalties, applied to the score.
LONGER_TEXT = 1  # per character beyond a short ideal
NON_CLICKABLE = 15


def adb(*args: str, binary: bool = False):
    """Run an adb command. Returns stdout as str (or bytes when binary=True)."""
    cmd = ["adb", *args]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode != 0:
        err = result.stderr.decode("utf-8", "replace").strip()
        raise RuntimeError(f"{' '.join(cmd)} failed: {err}")
    if binary:
        return result.stdout
    return result.stdout.decode("utf-8", "replace")


def dump_hierarchy() -> str:
    """Dump the current UI hierarchy and return it as XML text."""
    # Some builds need the argument; harmless if ignored.
    try:
        adb("shell", "uiautomator", "dump", REMOTE_DUMP)
    except RuntimeError:
        adb("shell", "uiautomator", "dump")
    return adb("exec-out", "cat", REMOTE_DUMP, binary=True).decode("utf-8", "replace")


def parse(xml_text: str) -> list[dict]:
    """Parse the hierarchy into flat candidate dicts."""
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return []

    candidates: list[dict] = []
    for node in root.iter("node"):
        text = node.get("text", "") or ""
        desc = node.get("content-desc", "") or ""
        rid = node.get("resource-id", "") or ""
        clickable = node.get("clickable", "false") == "true"
        bounds = node.get("bounds", "") or ""
        label = text or desc
        if not label and not rid:
            continue
        candidates.append(
            {
                "text": label,
                "resource_id": rid,
                "clickable": clickable,
                "bounds": bounds,
                "center": parse_bounds(bounds),
            }
        )
    return candidates


def parse_bounds(bounds: str):
    """'[0,0][1080,1920]' -> (540, 960). Returns None if unparseable."""
    nums = re.findall(r"-?\d+", bounds or "")
    if len(nums) != 4:
        return None
    x1, y1, x2, y2 = (int(n) for n in nums)
    return ((x1 + x2) // 2, (y1 + y2) // 2)


def score(candidate: dict, phrase: str) -> int:
    """Score a candidate against a phrase. Higher is better; 0 means no match."""
    label = candidate["text"].strip()
    low = label.lower()
    want = phrase.lower()

    if low == want:
        value = EXACT_TEXT
    elif want in low:
        value = 45
    elif low in want and len(low) >= 3:
        value = 25
    else:
        return 0

    if candidate["clickable"]:
        value += CLICKABLE
    else:
        value -= NON_CLICKABLE

    rid = candidate["resource_id"].lower()
    if "button" in rid or "btn" in rid:
        value += BUTTONISH_ID

    # Prefer shorter, more specific labels over long prose.
    value -= max(0, len(label) - 24) * LONGER_TEXT // 4

    return value


def best_matches(candidates: list[dict], phrases: list[str]) -> list[tuple[int, dict]]:
    scored: list[tuple[int, dict]] = []
    for candidate in candidates:
        total = 0
        for phrase in phrases:
            total = max(total, score(candidate, phrase))
        if total > 0:
            scored.append((total, candidate))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return scored


def do_tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))
    print(f"tapped {x},{y}")


def cmd_texts(candidates: list[dict]) -> None:
    for c in candidates:
        clickable = "clickable" if c["clickable"] else ""
        rid = f"  [{c['resource_id']}]" if c["resource_id"] else ""
        print(f"{c['bounds']:<28} {clickable:<9} {c['text']}{rid}")


def cmd_find(candidates: list[dict], phrases: list[str]) -> int:
    scored = best_matches(candidates, phrases)
    if not scored:
        print("no candidate matched", file=sys.stderr)
        return 1
    for value, c in scored[:10]:
        clickable = "clickable" if c["clickable"] else ""
        print(f"score {value:>4}  {c['bounds']:<28} {clickable:<9} {c['text']}")
    return 0


def cmd_tap_any(candidates: list[dict], phrases: list[str]) -> int:
    scored = best_matches(candidates, phrases)
    if not scored:
        print(f"nothing matched {phrases!r}", file=sys.stderr)
        return 1
    value, c = scored[0]
    if not c["center"]:
        print("matched element has no usable bounds", file=sys.stderr)
        return 1
    print(f'match "{c["text"]}" (score {value}) -> "{c["text"]}" @ {c["center"]}')
    do_tap(*c["center"])
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2

    command = argv[1]
    args = argv[2:]

    if command == "dump":
        print(dump_hierarchy())
        return 0

    if command in ("tap", "tap-text", "texts", "find", "tap-any"):
        candidates = parse(dump_hierarchy())
    else:
        print(f"unknown command {command!r}", file=sys.stderr)
        print(__doc__)
        return 2

    if command == "texts":
        cmd_texts(candidates)
        return 0

    if command == "find":
        if not args:
            print("find needs a phrase", file=sys.stderr)
            return 2
        return cmd_find(candidates, args)

    if command == "tap-any":
        if not args:
            print("tap-any needs at least one phrase", file=sys.stderr)
            return 2
        return cmd_tap_any(candidates, args)

    if command == "tap-text":
        if not args:
            print("tap-text needs text", file=sys.stderr)
            return 2
        for c in candidates:
            if c["text"].strip() == args[0] and c["center"]:
                print(f'match "{c["text"]}" @ {c["center"]}')
                do_tap(*c["center"])
                return 0
        print(f"no exact match for {args[0]!r}", file=sys.stderr)
        return 1

    if command == "tap":
        if len(args) < 2:
            print("tap needs x y", file=sys.stderr)
            return 2
        do_tap(int(args[0]), int(args[1]))
        return 0

    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
