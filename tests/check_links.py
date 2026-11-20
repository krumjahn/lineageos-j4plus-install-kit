#!/usr/bin/env python3
"""
check_links.py - verify that every relative Markdown link in the repository
points at a file that exists.

External links (http/https) are not fetched. This only catches the local
mistakes: a renamed file, a moved document, a link to a sibling that never
existed. Those are the ones that quietly rot.

Usage:
    python3 tests/check_links.py [root]

Exit code 0 if every relative link resolves, 1 otherwise.
"""

from __future__ import annotations

import os
import re
import sys

LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")
EXTERNAL_PREFIXES = ("http://", "https://", "mailto:", "#", "tel:")


def iter_markdown(root: str):
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip directories that are never part of the source.
        dirnames[:] = [
            d for d in dirnames if d not in {".git", "__pycache__", "node_modules", ".venv"}
        ]
        for name in filenames:
            if name.endswith(".md"):
                yield os.path.join(dirpath, name)


def main(argv: list[str]) -> int:
    root = os.path.abspath(argv[1] if len(argv) > 1 else os.path.dirname(os.path.dirname(__file__)))
    checked = 0
    broken: list[tuple[str, str]] = []

    for path in iter_markdown(root):
        rel = os.path.relpath(path, root)
        try:
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
        except (OSError, UnicodeDecodeError) as exc:
            print(f"  ! could not read {rel}: {exc}", file=sys.stderr)
            continue

        for _label, target in LINK_RE.findall(text):
            target = target.strip()
            if target.startswith(EXTERNAL_PREFIXES):
                continue
            # Drop the anchor and any title suffix.
            clean = target.split("#", 1)[0].split(" ", 1)[0]
            if not clean:
                continue
            checked += 1
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), clean))
            if not os.path.exists(resolved):
                broken.append((rel, target))

    print(f"relative links checked: {checked}")
    if broken:
        print(f"BROKEN: {len(broken)}")
        for src, tgt in broken:
            print(f"  {src}  ->  {tgt}")
        return 1
    print("all relative links resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
