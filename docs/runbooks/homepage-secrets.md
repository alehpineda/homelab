# Homepage secret files (CT 191)

Homepage plan steps 2.2 (secret plumbing) and 2.9 (`LOG_TARGETS=stdout`),
plus `proxmox.yaml` group write for Wolff (step 2.6 config, via the
`dashboard_editor` list in `inventory/blr.yml`).

Authority: DeathScythe 2026-11-16 10:50 AM CT, Wolff 1:1 (t99u): "Yes and
yes.", confirmed 10:53 AM CT (t100u) as the answer to "What's left in the
plan needs new API keys or accounts, so each piece waits for your yes".

## Layout

| Path | Owner / mode | Notes |
|------|--------------|-------|
| `/etc/homepage/secrets/` | root:root 0700 | `homepage.service` runs as `User=root`; CT 191 has no `homepage` user or group |
| `/etc/homepage/secrets/<file>` | root:root 0600 | one value per file, no trailing newline |
| `/etc/systemd/system/homepage.service.d/forge-secrets.conf` | root:root 0644 | `LOG_TARGETS=stdout` + `HOMEPAGE_FILE_<NAME>=<path>` |

Config files reference a value as `{{HOMEPAGE_FILE_<NAME>}}`. Homepage reads
the file server-side; `/api/services` does not return widget credentials.
`grokops`/`dashcfg` can edit the YAML but cannot read the secret files.

Names (`homepage_secret_files` in the role defaults): GRAFANA_TOKEN,
PVE_TOKEN_ID, PVE_TOKEN_SECRET, PBS_TOKEN_ID, PBS_TOKEN_SECRET, JELLYFIN_KEY,
SONARR_KEY, RADARR_KEY, LIDARR_KEY, PROWLARR_KEY, BAZARR_KEY, QBIT_KEY,
SEERR_KEY, ADGUARD_USER, ADGUARD_PASS. A name is wired only when its file
exists and is non-empty; the play prints the pending names.

Secret values are never in git. Place a value out of band, then run the
play (it restarts Homepage once, only when the drop-in changes):

```bash
cd ansible
ansible-playbook -i inventory/blr.yml playbooks/homepage-secrets.yml --check --diff
ansible-playbook -i inventory/blr.yml playbooks/homepage-secrets.yml
```

## Credentials behind the files (ids only)

| Files | Credential | Scope |
|-------|------------|-------|
| pve_token_id / pve_token_secret | PVE `homepage@pve!homepage` (privsep) | PVEAuditor on `/` (user and token) |
| pbs_token_id / pbs_token_secret | PBS `homepage@pbs!homepage` | Audit on `/` (user and token) |
| jellyfin_key | Jellyfin API key app `homepage` | Jellyfin API keys are admin-level |
| sonarr/radarr/lidarr/prowlarr/bazarr/seerr/qbit | app API keys handed over by Jack | app-admin keys |
| adguard_user / adguard_pass | AdGuard A user `homepage` (NetTit) | AdGuard read |
| grafana_token | Grafana SA `homepage-viewer` (Viewer) | pending |

## Verify

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/api/healthcheck
systemctl show homepage -p DropInPaths -p NRestarts
journalctl -u homepage -n 20 -o cat
```

## Rollback

```bash
rm /etc/systemd/system/homepage.service.d/forge-secrets.conf && systemctl daemon-reload && systemctl restart homepage
```

Then revoke the tokens (PVE/PBS token delete, Jellyfin key delete, Grafana
SA delete) and, only with a yes, remove `/etc/homepage/secrets`.
