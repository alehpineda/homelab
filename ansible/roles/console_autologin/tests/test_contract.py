#!/usr/bin/env python3
"""Offline contract for the console autologin role. No SSH and no systemd."""

from pathlib import Path

ROLE = Path(__file__).resolve().parents[1]
ANSIBLE = ROLE.parents[1]
REPO = ANSIBLE.parent


def read(path: Path) -> str:
    return path.read_text()


def main() -> None:
    defaults = read(ROLE / "defaults" / "main.yml")
    tasks = read(ROLE / "tasks" / "main.yml")
    playbook = read(ANSIBLE / "playbooks" / "console-autologin.yml")
    site = read(ANSIBLE / "playbooks" / "site.yml")
    inventory = read(ANSIBLE / "inventory" / "blr.yml.example")
    ct176 = read(REPO / "terraform" / "proxmox" / "ct_176_forge-ws.tf")

    ubuntu_container = "-/sbin/agetty --autologin root --noclear - $TERM"
    ubuntu_console = "-/sbin/agetty --autologin root --noclear --keep-baud - 115200,38400,9600 $TERM"
    debian_container = "-/sbin/agetty --autologin root --noreset --noclear - ${TERM}"
    debian_console = (
        "-/sbin/agetty --autologin root --noreset --noclear --keep-baud "
        "115200,57600,38400,9600 - ${TERM}"
    )
    required = [
        "console_autologin_enabled: false",
        "ollama-blr-lxc: 10.10.0.63",
        "caddy-blr-lxc: 10.10.0.250",
        "ollama-blr-lxc: ubuntu-24.04",
        "caddy-blr-lxc: debian-13",
        f'container: "{ubuntu_container}"',
        f'console: "{ubuntu_console}"',
        f'container: "{debian_container}"',
        f'console: "{debian_console}"',
    ]
    for item in required:
        if item not in defaults:
            raise SystemExit(f"defaults missing {item!r}")
    allowed = defaults.split("console_autologin_allowed:", 1)[1].split("console_autologin_host_os:", 1)[0]
    if "forge-ws-blr-lxc" in allowed:
        raise SystemExit("allow-list must not name CT 176")
    if "10.10.0.76" in defaults:
        raise SystemExit("allow-list must not name CT 176's address")
    if "--noreset" in ubuntu_container or "--noreset" in ubuntu_console:
        raise SystemExit("Ubuntu 24.04 measurement does not include --noreset")
    if "--noreset" not in debian_container or "--noreset" not in debian_console:
        raise SystemExit("Debian 13 measurement keeps --noreset")
    if " - 115200,38400,9600 $TERM" not in ubuntu_console:
        raise SystemExit("Ubuntu console measurement is tty then baud")
    if "115200,57600,38400,9600 - ${TERM}" not in debian_console:
        raise SystemExit("Debian console measurement is baud then tty")
    for line in (ubuntu_container, ubuntu_console, debian_container, debian_console):
        for forbidden in (" -o ", "-o '", "--login-options", "/dev/tty", "/dev/pts", "/dev/console"):
            if forbidden in line:
                raise SystemExit(f"measured ExecStart contains {forbidden!r}")

    for item in (
        "ExecStart=",
        "ExecStart={{ console_autologin_container_execstart }}",
        "ExecStart={{ console_autologin_console_execstart }}",
        "console_autologin_detected_os",
        "ubuntu-24.04",
        "debian-13",
        "inventory_hostname in console_autologin_allowed",
        "console_autologin_enabled | bool",
        "daemon_reload: true",
        "not ansible_check_mode",
        "try-restart",
        "'-o' not in item.stdout",
        "'/dev/' not in item.stdout",
    ):
        if item not in tasks:
            raise SystemExit(f"tasks missing {item!r}")
    if "TTYPath=" in tasks:
        raise SystemExit("drop-in tasks must not override TTYPath")

    if "hosts: console_autologin" not in playbook:
        raise SystemExit("playbook must target only the opt-in group")
    if "console_autologin_enabled: true" not in playbook:
        raise SystemExit("playbook must opt in")
    if "console-autologin" in site:
        raise SystemExit("site.yml must not import console autologin")
    if "forge-ws-blr-lxc" in playbook or "ct_176" in playbook:
        raise SystemExit("playbook must not name CT 176")

    if "console_autologin:" not in inventory:
        raise SystemExit("example inventory missing the opt-in group")
    group = inventory.split("console_autologin:", 1)[1]
    if "hosts: {}" not in group:
        raise SystemExit("example inventory group must stay empty")
    if "forge-ws" in group:
        raise SystemExit("opt-in group comments must not include CT 176")

    if "autologin" in ct176 or "password =" in ct176:
        raise SystemExit("CT 176 declaration must stay free of autologin and a password assignment")

    print("console autologin contract ok")


if __name__ == "__main__":
    main()
