#!/usr/bin/env python3
"""Exit 1 when a required KEY has no value. Print missing key names only."""

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print("usage")
        return 1
    path = Path(sys.argv[1])
    required = sys.argv[2:]
    present = set()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        print("unreadable")
        return 1
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if key.strip() in required and value.strip():
            present.add(key.strip())
    missing = [key for key in required if key not in present]
    if missing:
        print(" ".join(missing))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
