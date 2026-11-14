#!/usr/bin/env python3
"""Offline proof that an unchanged Kuma monitor produces no seeder diff."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import seed  # noqa: E402

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "unchanged-monitors.json"


class _MonitorType:
    """Stand-in for uptime_kuma_api.MonitorType, which exposes .value."""

    def __init__(self, value: str) -> None:
        self.value = value


def inventory() -> dict[str, dict]:
    cfg = seed.load_config(ROOT / "monitors.yaml")
    monitors, _placeholders = seed.validate(cfg)
    return {mon["name"]: mon for mon in monitors}


def as_seeded(mon: dict) -> dict:
    """Shape seed() actually compares: normalized YAML plus the API type enum."""
    merged = dict(mon)
    merged["type"] = _MonitorType(mon["type"])
    return merged


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    desired = inventory()
    saved = {mon["name"]: mon for mon in json.loads(FIXTURE.read_text())}

    non_http = [mon for mon in desired.values() if mon["type"] not in {"http", "keyword"}]
    require(bool(non_http), "inventory has no ping, port, or DNS monitors to check")
    for mon in non_http:
        existing = dict(mon)
        # Kuma/library default when this seeder does not send status codes.
        existing["accepted_statuscodes"] = ["200-299"]
        if not existing.get("description"):
            existing["description"] = None
        if mon.get("dns_last_result"):
            existing["dns_last_result"] = "198.41.0.4"
        changes = seed._needs_update(as_seeded(mon), existing)
        require(changes == [], f"{mon['name']} unchanged monitor diffed: {changes}")

    for name, existing in saved.items():
        changes = seed._needs_update(as_seeded(desired[name]), existing)
        require(changes == [], f"fixture {name} diffed: {changes}")

    http = dict(saved["AdGuard UI"])
    for spelling in ('["300-399","200-299"]', "200-299, 300-399", ["300-399", "200-299"]):
        http["accepted_statuscodes"] = spelling
        changes = seed._needs_update(as_seeded(desired["AdGuard UI"]), http)
        require(changes == [], f"status code spelling {spelling!r} diffed: {changes}")

    http["accepted_statuscodes"] = "200-299"
    changes = seed._needs_update(as_seeded(desired["AdGuard UI"]), http)
    require(
        changes == ["accepted_statuscodes"],
        f"real status-code drift not reported: {changes}",
    )

    ping = dict(saved["Flint ping"])
    ping["hostname"] = "10.10.0.99"
    changes = seed._needs_update(as_seeded(desired["Flint ping"]), ping)
    require(changes == ["hostname"], f"real hostname drift not reported: {changes}")

    drift = dict(saved["AdGuard UI"])
    drift["accepted_statuscodes"] = ["200-299"]
    drift_rows = seed.plan_monitors([desired["AdGuard UI"]], {"AdGuard UI": drift})
    drift_text = seed.format_plan(drift_rows, inventory=1)
    require("  AdGuard UI: update" in drift_text, drift_text)
    require("accepted_statuscodes:" in drift_text and "->" in drift_text, drift_text)
    require("200-299" in drift_text and "300-399" in drift_text, drift_text)

    loaded = seed.load_monitor_fixture(FIXTURE)
    rows = seed.plan_monitors(list(desired.values()), loaded)
    text = seed.format_plan(rows, inventory=len(desired))
    for name in saved:
        require(f"  {name}: unchanged" in text, f"plan omitted unchanged {name}:\n{text}")
    require("plan: no monitor rewrites" in text, text)
    require(": update" not in text, text)

    completed = subprocess.run(
        [sys.executable, str(ROOT / "seed.py"), "--dry-run", "--plan-fixture", str(FIXTURE)],
        check=False,
        capture_output=True,
        text=True,
    )
    require(completed.returncode == 0, completed.stderr + completed.stdout)
    require(text in completed.stdout, f"dry-run plan did not match formatter:\n{completed.stdout}")

    plain = subprocess.run(
        [sys.executable, str(ROOT / "seed.py"), "--dry-run"],
        check=False,
        capture_output=True,
        text=True,
    )
    require(plain.returncode == 0, plain.stderr + plain.stdout)
    require("diffs not computed" in plain.stdout, plain.stdout)
    print("plan ok: unchanged monitors produce no diff")


if __name__ == "__main__":
    main()
