# Uptime Kuma seeder (CT184)

Idempotent inventory for `https://uptime.alehpineda.com`. Match on name, create or update, never delete.

Pinned library: `uptime-kuma-api2==2.10.0` (Socket.IO client; Kuma 2 has no REST API for adding monitors). Upstream tests through Uptime Kuma 2.5.0; login against this instance (2.5.9) is the live verification.

## Files

- `monitors.yaml` — 38 v1 monitors, status page, SMTP notification definition, and 6 after-build placeholders (CT185–190). No secrets.
- `seed.py` — validator and seeder.
- `requirements.txt` — pinned dependencies.

## Environment

| Variable | Required for | Purpose |
|---|---|---|
| `KUMA_URL` | seed | Default is the `kuma.url` in the YAML |
| `KUMA_USERNAME` | seed | Admin username |
| `KUMA_PASSWORD` | seed | Admin password. Pass via the environment or stdin, never on the command line |
| `KUMA_TOTP` | seed if 2FA is on | Optional TOTP code. The seeder stops if 2FA blocks login |
| `KUMA_CONNECT_IP` | seed if split-DNS is missing | Pin the URL hostname to this IP (SNI/Host unchanged). Use `10.10.0.250` from a peer that still gets the public CNAME |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_TO` | notification | Optional. SMTP_USER / SMTP_PASSWORD when the relay needs auth. If any required SMTP var is missing, the notification is skipped |

## Usage (from CT176)

```bash
python3 -m venv ~/.local/share/forge/kuma-seeder-venv
~/.local/share/forge/kuma-seeder-venv/bin/pip install -r requirements.txt
cd /path/to/homelab/scripts/uptime-kuma

# No login:
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py --dry-run

# Seed (password already in the environment, not in argv):
export KUMA_USERNAME=admin
export KUMA_PASSWORD   # set by the caller; do not echo
export KUMA_CONNECT_IP=10.10.0.250   # if default DNS returns the public CNAME
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py

# Status only:
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py --status-only
```

Do not pass `--include-placeholders` until CT185–190 exist.

Before the first seed, copy `/opt/uptime-kuma/data` on CT184 to a timestamped `/root/forge-kuma-data-*` directory.
