#!/usr/bin/env python3
"""Surgically set general.enable_metrics and general.open_metrics in settings.yml.

Usage: set_searxng_open_metrics.py SETTINGS.yml PASSWORD_FILE
Prints 'changed' or 'ok' on stdout. Never prints the password.
Preserves the rest of the file, including comments and key order.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def _yaml_single_quoted(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: set_searxng_open_metrics.py SETTINGS.yml PASSWORD_FILE", file=sys.stderr)
        return 2
    settings_path = Path(sys.argv[1])
    pass_path = Path(sys.argv[2])
    password = pass_path.read_text(encoding="utf-8").strip()
    if not password:
        print("password file is empty", file=sys.stderr)
        return 2
    text = settings_path.read_text(encoding="utf-8")

    general = re.search(r"(?m)^general:\n(?P<body>(?:[ \t]+.*\n)*)", text)
    if not general:
        print("no top-level general: block found", file=sys.stderr)
        return 2
    body = general.group("body")

    def set_key(block: str, key: str, rendered: str) -> str:
        pat = re.compile(rf"^([ \t]+){re.escape(key)}:[ \t]*.*$", re.M)
        m = pat.search(block)
        if m:
            return pat.sub(rf"\1{key}: {rendered}", block, count=1)
        indent = "  "
        m2 = re.search(r"^([ \t]+)\S", block, re.M)
        if m2:
            indent = m2.group(1)
        if not block.endswith("\n"):
            block += "\n"
        return block + f"{indent}{key}: {rendered}\n"

    new_body = set_key(body, "enable_metrics", "true")
    new_body = set_key(new_body, "open_metrics", _yaml_single_quoted(password))
    if new_body == body and re.search(r"(?m)^[ \t]+enable_metrics:[ \t]*true\s*$", body) and re.search(
        r"(?m)^[ \t]+open_metrics:[ \t]*" + re.escape(_yaml_single_quoted(password)) + r"\s*$", body
    ):
        print("ok")
        return 0
    if new_body == body:
        # open_metrics already present but maybe differently quoted; treat as ok
        # only when enable_metrics is true and the raw password is already the value.
        em = re.search(r"(?m)^[ \t]+enable_metrics:[ \t]*(\S+)", body)
        om = re.search(r"(?m)^[ \t]+open_metrics:[ \t]*(.*)$", body)
        if em and em.group(1).strip().lower() in {"true", "yes"} and om:
            raw = om.group(1).strip()
            if raw in {_yaml_single_quoted(password), '"' + password.replace('"', '\\"') + '"', password}:
                print("ok")
                return 0
        print("general block unchanged but not already in the desired state", file=sys.stderr)
        return 2

    new_text = text[: general.start("body")] + new_body + text[general.end("body") :]
    settings_path.write_text(new_text, encoding="utf-8")
    print("changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
