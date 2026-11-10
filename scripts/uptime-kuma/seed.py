#!/usr/bin/env python3
"""Idempotent Uptime Kuma seeder.

Match monitors, tags, the status page, and the SMTP notification by name.
Create or update only. Never delete.

  --dry-run   YAML parse + schema check. No login, no network.
  (default)   Login and seed. Requires KUMA_PASSWORD (and KUMA_USERNAME).
  --status    After seed (or alone with --status-only), print counts by state.

Credentials and SMTP come from the environment. Nothing from this script
is written to the repo, host /tmp, or stdout except names and counts.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Any

import yaml

ALLOWED_STATUS = (
    {f"{lo}-{hi}" for lo, hi in ((100, 199), (200, 299), (300, 399), (400, 499), (500, 599))}
    | {str(i) for i in range(100, 1000)}
)
ALLOWED_TYPES = {"http", "keyword", "ping", "port", "dns"}
MIN_INTERVAL = 20
PINNED_LIB = "2.10.0"
TOTP_HINTS = ("2fa", "twofa", "two-factor", "totp", "otp", "token required")


class SchemaError(ValueError):
    pass


def load_config(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict):
        raise SchemaError("config root must be a mapping")
    return data


def _require(item: dict, keys: list[str], label: str) -> None:
    missing = [k for k in keys if not item.get(k)]
    if missing:
        raise SchemaError(f"{label}: missing {', '.join(missing)}")


def normalize_monitor(raw: dict[str, Any], defaults: dict[str, Any], label: str) -> dict[str, Any]:
    if not isinstance(raw, dict) or not raw.get("name") or not raw.get("type"):
        raise SchemaError(f"{label}: each monitor needs name and type")
    typ = str(raw["type"]).lower()
    if typ not in ALLOWED_TYPES:
        raise SchemaError(f"{label} {raw['name']!r}: unsupported type {typ}")
    interval = int(raw.get("interval") or 60)
    if interval < MIN_INTERVAL:
        raise SchemaError(f"{label} {raw['name']!r}: interval must be >= {MIN_INTERVAL}")
    maxretries = int(raw.get("maxretries", defaults.get("maxretries", 3)))
    retry = int(raw.get("retry_interval") or interval)
    timeout = int(raw.get("timeout") or (
        defaults.get("dns_timeout", 5) if typ == "dns" else defaults.get("timeout", 15)
    ))
    codes = list(raw.get("accepted_statuscodes") or defaults.get("accepted_statuscodes") or ["200-299"])
    for code in codes:
        if str(code) not in ALLOWED_STATUS:
            raise SchemaError(f"{label} {raw['name']!r}: bad accepted_statuscodes {code}")
    mon = {
        "name": raw["name"],
        "type": typ,
        "interval": interval,
        "maxretries": maxretries,
        "retryInterval": retry,
        "resendInterval": int(raw.get("resend_interval") or defaults.get("resend_standard", 360)),
        "timeout": timeout,
        "ignoreTls": bool(raw.get("ignore_tls", defaults.get("ignore_tls", False))),
        "maxredirects": int(raw.get("maxredirects", defaults.get("maxredirects", 10))),
        "expiryNotification": bool(raw.get("expiry_notification", False)),
        "description": raw.get("description") or "",
        "tags": list(raw.get("tags") or []),
        "accepted_statuscodes": [str(c) for c in codes],
        "conditions": raw.get("conditions") if isinstance(raw.get("conditions"), list) else [],
    }
    if typ in {"http", "keyword"}:
        _require(raw, ["url"], f"{label} {raw['name']}")
        mon["url"] = raw["url"]
        mon["method"] = raw.get("method") or "GET"
    if typ == "keyword":
        _require(raw, ["keyword"], f"{label} {raw['name']}")
        mon["keyword"] = raw["keyword"]
        mon["invertKeyword"] = bool(raw.get("invert_keyword", False))
    if typ == "ping":
        _require(raw, ["hostname"], f"{label} {raw['name']}")
        mon["hostname"] = raw["hostname"]
    if typ == "port":
        _require(raw, ["hostname", "port"], f"{label} {raw['name']}")
        mon["hostname"] = raw["hostname"]
        mon["port"] = int(raw["port"])
    if typ == "dns":
        _require(raw, ["hostname", "dns_resolve_server"], f"{label} {raw['name']}")
        mon["hostname"] = raw["hostname"]
        mon["dns_resolve_server"] = raw["dns_resolve_server"]
        mon["dns_resolve_type"] = raw.get("dns_resolve_type") or "A"
        mon["port"] = int(raw.get("port") or 53)
        if raw.get("dns_last_result"):
            mon["dns_last_result"] = str(raw["dns_last_result"])
    return mon


def validate(cfg: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    defaults = cfg.get("defaults") or {}
    monitors_raw = cfg.get("monitors") or []
    placeholders_raw = cfg.get("placeholders") or []
    if not isinstance(monitors_raw, list) or not monitors_raw:
        raise SchemaError("monitors must be a non-empty list")
    monitors = [normalize_monitor(m, defaults, "monitor") for m in monitors_raw]
    placeholders = [normalize_monitor(m, defaults, "placeholder") for m in placeholders_raw]
    names = [m["name"] for m in monitors]
    if len(names) != len(set(names)):
        raise SchemaError("duplicate monitor name in monitors")
    ph_names = [m["name"] for m in placeholders]
    if len(ph_names) != len(set(ph_names)):
        raise SchemaError("duplicate name in placeholders")
    overlap = set(names) & set(ph_names)
    if overlap:
        raise SchemaError(f"placeholder names collide with monitors: {sorted(overlap)}")
    tags = cfg.get("tags") or []
    tag_names = {t["name"] for t in tags}
    for mon in monitors + placeholders:
        for tag in mon["tags"]:
            if tag not in tag_names:
                raise SchemaError(f"{mon['name']!r} references unknown tag {tag!r}")
    page = cfg.get("status_page") or {}
    _require(page, ["slug", "title", "groups"], "status_page")
    known = set(names)
    for group in page["groups"]:
        _require(group, ["name", "monitors"], "status_page group")
        for item in group["monitors"]:
            if item not in known:
                raise SchemaError(f"status_page group {group['name']!r} unknown monitor {item!r}")
    lib = cfg.get("library") or {}
    if str(lib.get("version")) != PINNED_LIB:
        raise SchemaError(f"library.version must be {PINNED_LIB} (found {lib.get('version')})")
    return monitors, placeholders


def _status_name(value: Any) -> str:
    from uptime_kuma_api import MonitorStatus

    if isinstance(value, MonitorStatus):
        return value.name
    mapping = {0: "DOWN", 1: "UP", 2: "PENDING", 3: "MAINTENANCE"}
    if value in mapping:
        return mapping[value]
    return str(value) if value is not None else "UNKNOWN"


def _type_enum(value: str):
    from uptime_kuma_api import MonitorType

    return {
        "http": MonitorType.HTTP,
        "keyword": MonitorType.KEYWORD,
        "ping": MonitorType.PING,
        "port": MonitorType.PORT,
        "dns": MonitorType.DNS,
    }[value]


def _norm(value: Any) -> Any:
    if hasattr(value, "value"):
        value = value.value
    if isinstance(value, str):
        return value
    if isinstance(value, (list, tuple)):
        return [_norm(v) for v in value]
    return value


def _needs_update(desired: dict[str, Any], existing: dict[str, Any]) -> list[str]:
    keys = [
        "type", "interval", "maxretries", "retryInterval", "resendInterval",
        "timeout", "ignoreTls", "maxredirects", "expiryNotification",
        "description", "accepted_statuscodes", "url", "hostname", "port",
        "keyword", "invertKeyword", "method", "dns_resolve_server",
        "dns_resolve_type", "dns_last_result",
    ]
    changed = []
    for key in keys:
        if key not in desired:
            continue
        left, right = _norm(desired[key]), _norm(existing.get(key))
        if key == "accepted_statuscodes":
            if sorted(left or []) != sorted(right or []):
                changed.append(key)
            continue
        if key == "type":
            if str(left).lower() != str(right).lower():
                changed.append(key)
            continue
        if left != right and not (left in ("", None) and right in ("", None)):
            changed.append(key)
    return changed


def _monitor_kwargs(mon: dict[str, Any], notification_ids: list[int] | None) -> dict[str, Any]:
    kwargs: dict[str, Any] = {
        "type": _type_enum(mon["type"]),
        "name": mon["name"],
        "interval": mon["interval"],
        "maxretries": mon["maxretries"],
        "retryInterval": mon["retryInterval"],
        "resendInterval": mon["resendInterval"],
        "timeout": mon["timeout"],
        "ignoreTls": mon["ignoreTls"],
        "description": mon["description"],
        "expiryNotification": mon["expiryNotification"],
        "conditions": mon["conditions"],
    }
    if mon["type"] in {"http", "keyword"}:
        kwargs["url"] = mon["url"]
        kwargs["maxredirects"] = mon["maxredirects"]
        kwargs["accepted_statuscodes"] = mon["accepted_statuscodes"]
        kwargs["method"] = mon["method"]
    if mon["type"] == "keyword":
        kwargs["keyword"] = mon["keyword"]
        kwargs["invertKeyword"] = mon["invertKeyword"]
    if mon["type"] == "ping":
        kwargs["hostname"] = mon["hostname"]
    if mon["type"] == "port":
        kwargs["hostname"] = mon["hostname"]
        kwargs["port"] = mon["port"]
    if mon["type"] == "dns":
        kwargs["hostname"] = mon["hostname"]
        kwargs["dns_resolve_server"] = mon["dns_resolve_server"]
        kwargs["dns_resolve_type"] = mon["dns_resolve_type"]
        kwargs["port"] = mon["port"]
    if notification_ids is not None:
        kwargs["notificationIDList"] = notification_ids
    return kwargs


def _looks_like_totp_block(exc: BaseException | None, payload: Any = None) -> bool:
    chunks = []
    if exc is not None:
        chunks.append(str(exc).lower())
    if isinstance(payload, dict):
        chunks.append(str(payload).lower())
        for key in ("msg", "message", "error"):
            if payload.get(key):
                chunks.append(str(payload[key]).lower())
        if payload.get("tokenRequired") or payload.get("token_required"):
            return True
    text = " ".join(chunks)
    return any(hint in text for hint in TOTP_HINTS) and "login" in text or any(
        hint in text for hint in ("2fa", "two-factor", "totp", "token required")
    )


def smtp_settings(cfg: dict[str, Any]) -> dict[str, Any] | None:
    block = cfg.get("notification") or {}
    if not block:
        return None
    host = os.environ.get(block.get("smtp_host_env") or "SMTP_HOST", "").strip()
    port = os.environ.get(block.get("smtp_port_env") or "SMTP_PORT", "").strip()
    mail_from = os.environ.get(block.get("smtp_from_env") or "SMTP_FROM", "").strip()
    mail_to = os.environ.get(block.get("smtp_to_env") or "SMTP_TO", "").strip() or (
        block.get("default_to") or ""
    )
    if not (host and port and mail_from and mail_to):
        return None
    user = os.environ.get(block.get("smtp_user_env") or "SMTP_USER", "").strip()
    password = os.environ.get(block.get("smtp_password_env") or "SMTP_PASSWORD", "")
    return {
        "name": block.get("name") or "Forge Kuma email",
        "type": "smtp",
        "isDefault": bool(block.get("is_default", True)),
        "applyExisting": bool(block.get("apply_existing", True)),
        "smtpHost": host,
        "smtpPort": int(port),
        "smtpSecure": bool(block.get("smtp_secure", False)),
        "smtpFrom": mail_from,
        "smtpTo": mail_to,
        "smtpUsername": user or None,
        "smtpPassword": password or None,
    }


def print_status_counts(monitors: list[dict[str, Any]], expected_names: set[str]) -> dict[str, int]:
    counts: dict[str, int] = {}
    matched = 0
    extras = 0
    for mon in monitors:
        name = mon.get("name")
        if name in expected_names:
            matched += 1
            label = _status_name(mon.get("status"))
            counts[label] = counts.get(label, 0) + 1
        else:
            extras += 1
    print(f"status: {matched} of {len(expected_names)} inventory monitors")
    for key in ("UP", "PENDING", "DOWN", "MAINTENANCE", "UNKNOWN"):
        if key in counts:
            print(f"  {key}: {counts[key]}")
    leftover = sorted(k for k in counts if k not in {"UP", "PENDING", "DOWN", "MAINTENANCE", "UNKNOWN"})
    for key in leftover:
        print(f"  {key}: {counts[key]}")
    missing = expected_names - {m.get("name") for m in monitors}
    if missing:
        print(f"  missing: {len(missing)} ({', '.join(sorted(missing))})")
    if extras:
        print(f"  other existing monitors (left untouched): {extras}")
    return counts


def login(api, username: str, password: str, totp: str) -> None:
    from uptime_kuma_api.exceptions import UptimeKumaException

    try:
        result = api.login(username, password, token=totp or "")
    except UptimeKumaException as exc:
        if _looks_like_totp_block(exc):
            raise SystemExit("TOTP blocked the Kuma login. Stopped; no monitors were changed.") from exc
        raise SystemExit(f"Kuma login failed: {exc}") from exc
    except Exception as exc:  # noqa: BLE001
        if _looks_like_totp_block(exc):
            raise SystemExit("TOTP blocked the Kuma login. Stopped; no monitors were changed.") from exc
        raise
    if _looks_like_totp_block(None, result):
        raise SystemExit("TOTP blocked the Kuma login. Stopped; no monitors were changed.")
    if isinstance(result, dict) and result.get("ok") is False:
        if _looks_like_totp_block(None, result):
            raise SystemExit("TOTP blocked the Kuma login. Stopped; no monitors were changed.")
        raise SystemExit(f"Kuma login rejected: {result.get('msg') or result}")



def _pin_hostname(hostname: str, ip: str) -> None:
    """Resolve hostname to ip for this process only (SNI/Host stay on the name)."""
    import socket

    wanted = hostname.lower().rstrip(".")
    original = socket.getaddrinfo

    def patched(host, port, family=0, type=0, proto=0, flags=0):
        target = host
        if isinstance(host, str) and host.lower().rstrip(".") == wanted:
            target = ip
        return original(target, port, family, type, proto, flags)

    socket.getaddrinfo = patched  # type: ignore[method-assign]


def seed(cfg: dict[str, Any], monitors: list[dict[str, Any]], include_placeholders: bool) -> None:
    from uptime_kuma_api import NotificationType, UptimeKumaApi
    from uptime_kuma_api.exceptions import UptimeKumaException

    url = os.environ.get("KUMA_URL") or (cfg.get("kuma") or {}).get("url")
    username = os.environ.get("KUMA_USERNAME") or ""
    password = os.environ.get("KUMA_PASSWORD") or ""
    totp = os.environ.get("KUMA_TOTP") or ""
    if not url or not username or not password:
        raise SystemExit("KUMA_URL, KUMA_USERNAME, and KUMA_PASSWORD are required to seed")

    smtp = smtp_settings(cfg)
    if smtp is None:
        print("SMTP env incomplete or absent: skipping Forge Kuma email notification")

    connect_ip = os.environ.get("KUMA_CONNECT_IP", "").strip()
    if connect_ip:
        from urllib.parse import urlparse

        host = urlparse(url).hostname
        if not host:
            raise SystemExit("KUMA_URL has no hostname to pin with KUMA_CONNECT_IP")
        _pin_hostname(host, connect_ip)
        print(f"connecting to {url} (pinned {host} -> {connect_ip})")
    else:
        print(f"connecting to {url}")
    with UptimeKumaApi(url, timeout=60, ssl_verify=True) as api:
        login(api, username, password, totp)
        version = api.version()
        expected = str((cfg.get("kuma") or {}).get("expected_version") or "")
        print(f"server version: {version}")
        if expected and not str(version).startswith(expected):
            print(f"warning: expected {expected}, continuing (library {PINNED_LIB} is runtime-gated)")
        else:
            print(f"verified against Uptime Kuma {version} with uptime-kuma-api2=={PINNED_LIB}")

        # Tags
        existing_tags = {t["name"]: t for t in api.get_tags()}
        tag_ids: dict[str, int] = {}
        for tag in cfg.get("tags") or []:
            current = existing_tags.get(tag["name"])
            if current is None:
                created = api.add_tag(name=tag["name"], color=tag["color"])
                tag_ids[tag["name"]] = created["id"]
                print(f"tag created: {tag['name']}")
            else:
                tag_ids[tag["name"]] = current["id"]
                if current.get("color") != tag["color"]:
                    api.edit_tag(current["id"], name=tag["name"], color=tag["color"])
                    print(f"tag updated: {tag['name']}")

        # Notification
        notification_ids: list[int] | None = None
        if smtp is not None:
            from uptime_kuma_api import NotificationType as NT

            existing_n = {n["name"]: n for n in api.get_notifications()}
            payload = {
                "name": smtp["name"],
                "type": NT.SMTP,
                "isDefault": smtp["isDefault"],
                "applyExisting": smtp["applyExisting"],
                "smtpHost": smtp["smtpHost"],
                "smtpPort": smtp["smtpPort"],
                "smtpSecure": smtp["smtpSecure"],
                "smtpFrom": smtp["smtpFrom"],
                "smtpTo": smtp["smtpTo"],
            }
            if smtp["smtpUsername"]:
                payload["smtpUsername"] = smtp["smtpUsername"]
            if smtp["smtpPassword"]:
                payload["smtpPassword"] = smtp["smtpPassword"]
            current = existing_n.get(smtp["name"])
            if current is None:
                created = api.add_notification(**payload)
                notification_ids = [created["id"]]
                print(f"notification created: {smtp['name']}")
            else:
                api.edit_notification(current["id"], **payload)
                notification_ids = [current["id"]]
                print(f"notification updated: {smtp['name']}")

        existing = {m["name"]: m for m in api.get_monitors()}
        created_ids: dict[str, int] = {}
        for mon in monitors:
            kwargs = _monitor_kwargs(mon, notification_ids)
            current = existing.get(mon["name"])
            if current is None:
                # dns_last_result is not accepted by add_monitor; set on edit.
                add_kwargs = {k: v for k, v in kwargs.items() if k != "dns_last_result"}
                result = api.add_monitor(**add_kwargs)
                mid = result.get("monitorID") or result.get("monitorId")
                created_ids[mon["name"]] = mid
                print(f"monitor created: {mon['name']} ({mid})")
                if mon.get("dns_last_result") and mid:
                    try:
                        api.edit_monitor(int(mid), dns_last_result=mon["dns_last_result"])
                    except (UptimeKumaException, TypeError, ValueError) as exc:
                        print(f"  warning: could not set dns_last_result on {mon['name']}: {exc}")
            else:
                mid = current["id"]
                created_ids[mon["name"]] = mid
                kwargs_edit = dict(kwargs)
                if mon.get("dns_last_result"):
                    kwargs_edit["dns_last_result"] = mon["dns_last_result"]
                changed = _needs_update({**mon, **kwargs_edit}, current)
                if notification_ids is not None:
                    have = current.get("notificationIDList") or []
                    if isinstance(have, dict):
                        have = [int(k) for k, v in have.items() if v] or [int(x) for x in have]
                    if sorted(int(x) for x in have) != sorted(notification_ids):
                        changed.append("notificationIDList")
                if changed:
                    api.edit_monitor(int(mid), **kwargs_edit)
                    print(f"monitor updated: {mon['name']} ({', '.join(changed)})")
                else:
                    print(f"monitor unchanged: {mon['name']}")

        # Tags on monitors (add only; never strip)
        # Refresh once — a second login avoids the stale same-session list.
        try:
            existing = {m["name"]: m for m in api.get_monitors()}
        except Exception:  # noqa: BLE001
            existing = existing
        for mon in monitors:
            mid = created_ids.get(mon["name"]) or (existing.get(mon["name"]) or {}).get("id")
            if not mid:
                continue
            have = existing.get(mon["name"], {}).get("tags") or []
            have_ids = {t.get("id") or t.get("tag_id") for t in have if isinstance(t, dict)}
            for tag_name in mon["tags"]:
                tid = tag_ids.get(tag_name)
                if tid and tid not in have_ids:
                    api.add_monitor_tag(tag_id=tid, monitor_id=int(mid))

        # Status page
        page = cfg["status_page"]
        pages = {p["slug"]: p for p in api.get_status_pages()}
        if page["slug"] not in pages:
            api.add_status_page(page["slug"], page["title"])
            print(f"status page created: {page['slug']}")
        # Build group list from current IDs
        name_to_id = dict(created_ids)
        for mon in api.get_monitors():
            name_to_id.setdefault(mon["name"], mon["id"])
        public_groups = []
        for weight, group in enumerate(page["groups"], start=1):
            public_groups.append({
                "name": group["name"],
                "weight": weight,
                "monitorList": [{"id": name_to_id[n]} for n in group["monitors"] if n in name_to_id],
            })
        api.save_status_page(
            slug=page["slug"],
            title=page["title"],
            description=page.get("description") or "",
            theme=page.get("theme") or "auto",
            published=bool(page.get("published", True)),
            showTags=bool(page.get("show_tags", True)),
            showPoweredBy=bool(page.get("show_powered_by", False)),
            showCertificateExpiry=bool(page.get("show_certificate_expiry", True)),
            publicGroupList=public_groups,
        )
        print(f"status page saved: /status/{page['slug']}")

    # Fresh session for status (avoids stale get_monitors after a mass add).
    with UptimeKumaApi(url, timeout=60, ssl_verify=True) as api:
        login(api, username, password, totp)
        live = api.get_monitors()
        print_status_counts(live, {m["name"] for m in monitors})
        if include_placeholders:
            print("placeholders were included in this run")


def main() -> int:
    parser = argparse.ArgumentParser(description="Idempotent Uptime Kuma seeder")
    parser.add_argument(
        "--config",
        default=str(Path(__file__).resolve().parent / "monitors.yaml"),
        help="Path to monitors.yaml",
    )
    parser.add_argument("--dry-run", action="store_true", help="Parse and validate YAML only; no login")
    parser.add_argument("--status-only", action="store_true", help="Login and print status counts; do not seed")
    parser.add_argument(
        "--include-placeholders",
        action="store_true",
        help="Also create the CT185-190 placeholders (default: skip)",
    )
    args = parser.parse_args()

    try:
        import uptime_kuma_api as _lib

        found = getattr(_lib, "__version__", None)
        if found is None:
            from uptime_kuma_api.__version__ import __version__ as found
        if str(found) != PINNED_LIB and not args.dry_run:
            print(f"warning: installed uptime-kuma-api2 is {found}, pin is {PINNED_LIB}")
    except ImportError:
        if not args.dry_run:
            raise SystemExit(f"uptime-kuma-api2=={PINNED_LIB} is not installed")

    cfg = load_config(Path(args.config))
    monitors, placeholders = validate(cfg)
    print(f"yaml ok: {len(monitors)} monitors, {len(placeholders)} placeholders (not seeded by default)")
    if args.include_placeholders:
        monitors = monitors + placeholders
        print(f"including placeholders: {len(monitors)} total")
    if args.dry_run:
        groups = (cfg.get("status_page") or {}).get("groups") or []
        print(f"status page: {(cfg.get('status_page') or {}).get('slug')} ({len(groups)} groups)")
        print("dry-run complete; no login attempted")
        return 0

    if args.status_only:
        from uptime_kuma_api import UptimeKumaApi

        url = os.environ.get("KUMA_URL") or (cfg.get("kuma") or {}).get("url")
        username = os.environ.get("KUMA_USERNAME") or ""
        password = os.environ.get("KUMA_PASSWORD") or ""
        totp = os.environ.get("KUMA_TOTP") or ""
        if not url or not username or not password:
            raise SystemExit("KUMA_URL, KUMA_USERNAME, and KUMA_PASSWORD are required")
        connect_ip = os.environ.get("KUMA_CONNECT_IP", "").strip()
        if connect_ip:
            from urllib.parse import urlparse

            host = urlparse(url).hostname
            if not host:
                raise SystemExit("KUMA_URL has no hostname to pin with KUMA_CONNECT_IP")
            _pin_hostname(host, connect_ip)
            print(f"connecting to {url} (pinned {host} -> {connect_ip})")
        with UptimeKumaApi(url, timeout=60, ssl_verify=True) as api:
            login(api, username, password, totp)
            print(f"server version: {api.version()}")
            print_status_counts(api.get_monitors(), {m["name"] for m in monitors})
        return 0

    seed(cfg, monitors, include_placeholders=args.include_placeholders)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SchemaError as exc:
        print(f"schema error: {exc}", file=sys.stderr)
        sys.exit(2)
