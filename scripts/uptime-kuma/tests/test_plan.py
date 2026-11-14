#!/usr/bin/env python3
"""Offline proof that an unchanged Kuma monitor produces no seeder diff."""

from __future__ import annotations

import json
import os
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


def seeder_env(**overrides: str) -> dict[str, str]:
    """Child env with notification switches cleared unless a test sets them."""
    env = os.environ.copy()
    env.pop("KUMA_SKIP_NOTIFICATION", None)
    env.pop("SMTP_PASSWORD", None)
    env.update(overrides)
    return env


def check_skip_notification(desired: dict[str, dict], saved: dict[str, dict]) -> None:
    """--skip-notification (and KUMA_SKIP_NOTIFICATION=1) leaves SMTP alone."""
    saved_env = os.environ.get("KUMA_SKIP_NOTIFICATION")
    try:
        os.environ.pop("KUMA_SKIP_NOTIFICATION", None)
        require(seed.skip_notification_enabled(False) is False, "unset env enabled skip")
        require(seed.skip_notification_enabled(True) is True, "flag did not enable skip")
        os.environ["KUMA_SKIP_NOTIFICATION"] = "1"
        require(
            seed.skip_notification_enabled(False) is True,
            "KUMA_SKIP_NOTIFICATION=1 did not enable skip",
        )
        os.environ["KUMA_SKIP_NOTIFICATION"] = "true"
        require(seed.skip_notification_enabled(False) is True, "true did not enable skip")
        os.environ["KUMA_SKIP_NOTIFICATION"] = "0"
        require(seed.skip_notification_enabled(False) is False, "0 enabled skip")
        require(seed.skip_notification_enabled(True) is True, "flag lost to KUMA_SKIP_NOTIFICATION=0")
        os.environ["KUMA_SKIP_NOTIFICATION"] = ""
        require(seed.skip_notification_enabled(False) is False, "empty env enabled skip")
    finally:
        if saved_env is None:
            os.environ.pop("KUMA_SKIP_NOTIFICATION", None)
        else:
            os.environ["KUMA_SKIP_NOTIFICATION"] = saved_env

    missing_password = {"name": "Forge email (Gmail)", "smtpPassword": None}
    try:
        seed.notification_to_upsert(missing_password, skip_notification=False)
    except SystemExit as exc:
        require(
            str(exc) == "SMTP_PASSWORD is required to apply or test the notification",
            f"password error changed: {exc}",
        )
    else:
        raise SystemExit("missing SMTP_PASSWORD did not abort")

    require(
        seed.notification_to_upsert(missing_password, skip_notification=True) is None,
        "skip still required SMTP_PASSWORD",
    )
    require(
        seed.notification_to_upsert(None, skip_notification=False) is None,
        "incomplete SMTP was treated as an upsert",
    )
    present = {"smtpPassword": "secret"}
    require(
        seed.notification_to_upsert(present, skip_notification=False) is present,
        "configured SMTP was not upserted",
    )

    linked = {"notificationIDList": [2, 1]}
    require(
        seed.notification_link_changes(linked, None) == [],
        "skip/diff with no ids changed notification links",
    )
    require(
        seed.notification_link_changes(linked, [1, 2]) == [],
        "matching notification links were reported as a diff",
    )
    require(
        seed.notification_link_changes({"notificationIDList": {1: True}}, [1]) == [],
        "dict notificationIDList was treated as a diff",
    )
    require(
        seed.notification_link_changes({"notificationIDList": [9]}, [1]) == ["notificationIDList"],
        "real notification link drift was not reported",
    )
    require(
        seed.notification_payload(None) == {},
        "omitted notification ids still sent notificationIDList (would unlink)",
    )
    require(
        seed.notification_payload([4]) == {"notificationIDList": [4]},
        "apply payload dropped notificationIDList",
    )

    only_links = dict(saved["AdGuard UI"])
    only_links["notificationIDList"] = [7]
    rows = seed.plan_monitors(
        [desired["AdGuard UI"]],
        {"AdGuard UI": only_links},
        notification_ids=None,
    )
    require(
        rows[0]["action"] == "unchanged" and rows[0]["changes"] == [],
        f"plan diffed notification links while skipping: {rows}",
    )
    linked_plan = seed.format_plan(rows, inventory=1, skip_notification=True)
    require(
        "notification skipped; monitor notification links left unchanged" in linked_plan,
        linked_plan,
    )
    require("notificationIDList" not in linked_plan, linked_plan)
    plain_plan = seed.format_plan(rows, inventory=1)
    require("notification skipped" not in plain_plan, plain_plan)

    drifted = seed.plan_monitors(
        [desired["AdGuard UI"]],
        {"AdGuard UI": only_links},
        notification_ids=[1],
    )
    require(drifted[0]["action"] == "update", f"apply diff ignored notification links: {drifted}")
    require(
        any("notificationIDList" in change for change in drifted[0]["changes"]),
        f"apply diff omitted notificationIDList: {drifted}",
    )

    loaded = seed.load_monitor_fixture(FIXTURE)
    base_rows = seed.plan_monitors(list(desired.values()), loaded)
    base_text = seed.format_plan(base_rows, inventory=len(desired))
    skipped_text = seed.format_plan(base_rows, inventory=len(desired), skip_notification=True)
    require(base_text in skipped_text, "skip plan dropped the monitor diff")
    require("notificationIDList" not in skipped_text, skipped_text)

    flagged = subprocess.run(
        [
            sys.executable,
            str(ROOT / "seed.py"),
            "--dry-run",
            "--plan-fixture",
            str(FIXTURE),
            "--skip-notification",
        ],
        check=False,
        capture_output=True,
        text=True,
        env=seeder_env(),
    )
    require(flagged.returncode == 0, flagged.stderr + flagged.stdout)
    require(skipped_text in flagged.stdout, f"plan ignored --skip-notification:\n{flagged.stdout}")
    require("Forge email (Gmail):" not in flagged.stdout, flagged.stdout)
    require("SMTP_PASSWORD" not in flagged.stdout + flagged.stderr, flagged.stdout + flagged.stderr)

    created_name = next(name for name in desired if name not in saved)
    warning = (
        f"WARNING: new monitor {created_name} created with no notification link (--skip-notification)"
    )
    missing_rows = seed.plan_monitors([desired[created_name]], {})
    missing_plan = seed.format_plan(missing_rows, inventory=1, skip_notification=True)
    require(warning in missing_plan, missing_plan)
    require(
        "WARNING:" not in seed.format_plan(missing_rows, inventory=1),
        "plan warned about a new monitor without --skip-notification",
    )
    kept_rows = seed.plan_monitors(
        [desired["AdGuard UI"]],
        {"AdGuard UI": saved["AdGuard UI"]},
    )
    kept_plan = seed.format_plan(kept_rows, inventory=1, skip_notification=True)
    require("WARNING:" not in kept_plan, kept_plan)
    require(warning in flagged.stdout, f"dry-run plan omitted new-monitor warning:\n{flagged.stdout}")
    require(seed.new_monitor_notification_warning(created_name) == warning, "warning text drifted")

    from_env = subprocess.run(
        [
            sys.executable,
            str(ROOT / "seed.py"),
            "--dry-run",
            "--plan-fixture",
            str(FIXTURE),
        ],
        check=False,
        capture_output=True,
        text=True,
        env=seeder_env(KUMA_SKIP_NOTIFICATION="1"),
    )
    require(from_env.returncode == 0, from_env.stderr + from_env.stdout)
    require(skipped_text in from_env.stdout, f"plan ignored KUMA_SKIP_NOTIFICATION:\n{from_env.stdout}")

    conflict = subprocess.run(
        [
            sys.executable,
            str(ROOT / "seed.py"),
            "--dry-run",
            "--skip-notification",
            "--test-notification",
        ],
        check=False,
        capture_output=True,
        text=True,
        env=seeder_env(),
    )
    require(conflict.returncode != 0, conflict.stdout + conflict.stderr)
    require(
        "cannot be combined" in (conflict.stderr + conflict.stdout),
        conflict.stderr + conflict.stdout,
    )


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
        env=seeder_env(),
    )
    require(completed.returncode == 0, completed.stderr + completed.stdout)
    require(text in completed.stdout, f"dry-run plan did not match formatter:\n{completed.stdout}")
    require("notification skipped" not in completed.stdout, completed.stdout)
    require("WARNING:" not in completed.stdout, completed.stdout)
    require("Forge email (Gmail):" in completed.stdout, completed.stdout)

    plain = subprocess.run(
        [sys.executable, str(ROOT / "seed.py"), "--dry-run"],
        check=False,
        capture_output=True,
        text=True,
        env=seeder_env(),
    )
    require(plain.returncode == 0, plain.stderr + plain.stdout)
    require("diffs not computed" in plain.stdout, plain.stdout)
    require("notification skipped" not in plain.stdout, plain.stdout)

    check_skip_notification(desired, saved)
    print("plan ok: unchanged monitors produce no diff")


if __name__ == "__main__":
    main()
