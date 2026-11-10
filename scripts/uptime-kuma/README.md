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
| `KUMA_CONNECT_IP` | optional | Pin the URL hostname to this IP (SNI/Host unchanged). Not needed on CT176: NetBird DNS already returns `10.10.0.250`. Set it only if a peer still gets the public CNAME |
| `SMTP_PASSWORD` | notification | Gmail app password. Required to create, update, or test the notification. Never pass on the command line or write it to the repo |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_TO`, `SMTP_USER` | notification override | Optional. Non-secret defaults live in `monitors.yaml` (Gmail, `ale.hpineda@gmail.com`, `deathscythe+kuma@mail.grokbot.com`). Env wins if set |

## Usage (from CT176)

```bash
python3 -m venv ~/.local/share/forge/kuma-seeder-venv
~/.local/share/forge/kuma-seeder-venv/bin/pip install -r requirements.txt
cd /path/to/homelab/scripts/uptime-kuma

# No login:
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py --dry-run

# Seed (passwords already in the environment, not in argv):
export KUMA_USERNAME=admin
export KUMA_PASSWORD     # set by the caller; do not echo
export SMTP_PASSWORD     # Gmail app password; do not echo
# KUMA_CONNECT_IP is optional; omit it on CT176.
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py

# Create the notification with Default and Apply-on-all off, then fire Kuma's Test:
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py \
  --notification-only --notification-default-off --test-notification

# Status only:
~/.local/share/forge/kuma-seeder-venv/bin/python seed.py --status-only
```

Do not pass `--include-placeholders` until CT185–190 exist.

Before the first seed, copy `/opt/uptime-kuma/data` on CT184 to a timestamped `/root/forge-kuma-data-*` directory.

`resend_interval` in `monitors.yaml` is Kuma's missed-check count, not minutes
(60 critical, 120 for 180s app monitors, 72 for 300s public monitors).
