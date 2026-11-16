# BRL monitoring and Postiz (applied 2026-11-02 / 2026-11-03)

Human source of truth for guests and wiring that already exist on
`barbatoslupusrex`. Terraform declares the LXCs only
(`terraform/proxmox/ct_169_postiz.tf`, `ct_171_grafana.tf`,
`ct_172_prometheus.tf`, `ct_173_loki.tf`, `ct_174_pve_exporter.tf`).
Those five guests were imported 2026-11-03. Do not `terraform apply`
from this note.

Terraform `tags` on 169 and 171–174 mirror the community-script defaults
on the live guests. `nameserver` is omitted in those files: the live CTs
have an empty nameserver and inherit host DNS.

In-guest files stay on the guests. This page does not contain passwords,
API tokens, Grafana admin credentials, Caddyfile bodies, AdGuard YAML, or
`prometheus.yml`.

## Guests

All Debian, unprivileged, `onboot=1`, gateway `10.10.0.1`, bridge `vmbr0`,
root disk on `data2`. Community-scripts, no Docker, so `features.nesting`
is not set (same as the firecrawl and jellyfin declarations).

| CTID | Hostname | IP | Role | Listen |
|------|----------|----|------|--------|
| 169 | postiz-blr-lxc | 10.10.0.69 | Postiz 2.25.3 | nginx :80 (in-guest) |
| 171 | grafana-blr-lxc | 10.10.0.71 | Grafana 13.3.0 | :3000 |
| 172 | prometheus-blr-lxc | 10.10.0.72 | Prometheus | :9090 LAN |
| 173 | loki-blr-lxc | 10.10.0.73 | Loki 3.7.9 | :3100 LAN |
| 174 | pve-exporter-blr-lxc | 10.10.0.74 | prometheus-pve-exporter | :9221 LAN |
| 177 | openobserve-blr-lxc | 10.10.0.77 | OpenObserve OSS 1.1.2 (declared 2026-11-11, not created yet) | :5080 via Caddy `.250` |

Resources: 169 is 4 cores / 8192 MB / 20G; 171 is 1 / 1024 MB / 8G; 172 is
2 / 2048 MB / 20G; 173 is 1 / 1024 MB / 20G; 174 is 1 / 512 MB / 4G;
177 is 2 / 2048 MB / 8G root + 30G data volume (`mp0`, `backup=1`).
Swap in Terraform is 512 MB, matching the other `ct_*.tf` files.

`vzdump` job `forge-backup-ssd` includes 169 and 171–174. Unattended
upgrades are security-only with automatic reboot off (same pattern as
CT 180).

## Grafana

Datasources provisioned on CT 171:

- Prometheus `http://10.10.0.72:9090` (uid `prometheus-brl`, default)
- Loki `http://10.10.0.73:3100` (uid `loki-brl`)

Root URL `https://grafana.alehpineda.com`. Org name `Homelab`. Anonymous
auth is off. The admin password lives outside git.

Dashboard uid `pve-blr-v1` (folder Proxmox, title Proxmox — BRL) is the
org home dashboard. Version 2 adds host load average and host `vmbr0`
RX/TX from node_exporter. URL:
`https://grafana.alehpineda.com/d/pve-blr-v1/proxmox-e28094-brl`.

## What is published

Only Grafana is exposed. Prometheus, Loki, and pve-exporter stay on the
LAN. They have no Caddy hostnames.

- Caddy CT 250 reverse-proxies `grafana.alehpineda.com` to
  `http://10.10.0.71:3000`. Ports 80/443 on CT 250 stay limited to
  `10.10.0.0/24` and `100.85.0.0/16` by nftables inside the CT.
- AdGuard CT 153 rewrites `grafana.alehpineda.com` to `10.10.0.250`.
- NetTit Homelab-AdGuard matches `grafana.alehpineda.com` (DNS-only, no
  NetBird reverse proxy).

Postiz is already published at `https://postiz.alehpineda.com`. Its
app config is not in this repo.

## Prometheus scrape jobs

Job names only. Target URLs are LAN addresses; credentials are not here.

| Job | Scrapes |
|-----|---------|
| `prometheus` | CT 172 itself |
| `pve` | PVE API on `10.10.0.21` through pve-exporter `10.10.0.74:9221` (API token on the guest) |
| `node` | `10.10.0.21:9100` (instance `barbatoslupusrex`) |

## Host node_exporter

Debian package `prometheus-node-exporter` 1.9.0 on `barbatoslupusrex`,
listening on `:9100`. The host firewall accepts that port from the
Prometheus CT only:

```
IN ACCEPT -source 10.10.0.72 -p tcp -dport 9100
```

The host firewall also accepts SMTP from CT 182 to the host relay.
`policy_in` stays `DROP`. The rule is matched on its fields, not on its
position. The procedure is in
[runbooks/pve-postfix-arr.md](runbooks/pve-postfix-arr.md):

```
IN ACCEPT -source 10.10.0.82/32 -dest 10.10.0.21/32 -p tcp -dport 25 -comment CT182 Watchtower SMTP to PVE relay
```

node_exporter is not in Caddy and is not a vzdump guest.

## Uptime Kuma (CT184)

Guest declaration: `terraform/proxmox/ct_184_uptimekuma.tf`.
UI: `https://uptime.alehpineda.com` (Caddy `.250`, admin-only).
Monitor inventory and the idempotent seeder live in
[`scripts/uptime-kuma/`](../scripts/uptime-kuma/README.md).
The seeder creates or updates by name and never deletes. Email alerts use
Gmail SMTP (`smtp.gmail.com:587` STARTTLS, notification `Forge email (Gmail)`),
To `deathscythe+kuma@mail.grokbot.com`. The app password is supplied at run
time via `SMTP_PASSWORD`; it is not in the repo. Grafana/Prometheus remain
the metrics path; Kuma is up/down, cert-expiry, and SMTP alerting.

Version and service environment are pinned by
`ansible/playbooks/uptime-kuma.yml` (role `uptime_kuma`): Uptime Kuma
2.5.11 on Node.js 22.23.5 (NodeSource `nodejs=22.23.5-1nodesource1`, apt pin
`/etc/apt/preferences.d/forge-nodejs-pin`) and `UPTIME_KUMA_LOG_FORMAT=json` in the drop-in
`/etc/systemd/system/uptime-kuma.service.d/10-forge-env.conf`. Journal lines
are then one JSON object each: `{"time", "module", "level", "msg"}` (`time`
is RFC3339 with the America/Chicago offset; `level` is info/warn/error/debug).
An upgrade builds the new tree beside the running one, stops once, takes a
cold copy of `data/` to `/root/forge-kuma-data-<YYYYMMDD-HHMM>` (sha256
manifest beside it), swaps trees and starts once. Take
`pct snapshot 184 pre-kuma-<ver>-<date>` on the host first.

Rollback: `systemctl stop uptime-kuma`, move `/opt/uptime-kuma` aside, move
`/opt/uptime-kuma-<old>.prev` back, copy the cold backup to
`/opt/uptime-kuma/data`, start (or `pct rollback 184 <snapshot>`).

## Logging: Loki and OpenObserve side by side (2026-11-11)

Plan: Forge `/workspace/forge/plans/openobserve-loki-plan-20261111.md`.
Runbook: [runbooks/logging-loki-openobserve.md](runbooks/logging-loki-openobserve.md).

- Grafana Alloy (`ansible/roles/alloy`) runs on each log source and sends the
  same entries to Loki CT 173 (`/loki/api/v1/push`) and OpenObserve CT 177
  (`/api/default/loki/api/v1/push`, stream = `o2_stream_name` = `job`).
- Phase 1 sources: BRL host journald (`pve_journal`), CT 250 Caddy access log
  (`caddy_access`), CT 182 Docker (`arr_docker`). AdGuard querylog
  (`adguard_query`) is phase 1b.
- Labels: `host`, `job`, plus `unit`/`level` (journal), `filename` (files),
  `container` (Docker).
- Retention 30 days on both: Loki compactor (`ansible/roles/loki_config`),
  OpenObserve `ZO_COMPACT_DATA_RETENTION_DAYS=30`.
- Prometheus CT 172 also remote_writes `pve` and `node` jobs (noisy families
  dropped) to OpenObserve (`ansible/roles/prometheus_remote_write`).
  Grafana -> Prometheus is unchanged.
- `openobserve.alehpineda.com` -> Caddy `.250` (admin only; `.251` falls
  through to `abort`). Loki keeps no hostname; Grafana is its UI.
- OpenObserve root and ingest credentials live outside git (controller
  files `~/.config/forge/openobserve_root`, `openobserve_ingest`).
- vzdump `forge-backup-ssd` gains 177 (both disks).

## Still pending

Flint DHCP reservations for `10.10.0.71`–`10.10.0.74` (MACs on CTs
171–174) and `10.10.0.77` (`02:46:4F:52:01:77`, CT 177) are still pending. Until those exist, the static addresses in
the LXC configs are what Terraform records.

## Alloy /metrics on the BRL host (2026-11-14)

BRL Alloy listens on `10.10.0.21:12345` (CUSTOM_ARGS in `/etc/default/alloy`,
role var `alloy_http_listen_addr` on the alloy_host play). The PVE host
firewall (`host.fw`, not managed by IaC) has
`IN ACCEPT -source 10.10.0.72 -p tcp -dport 12345` (comment
"prometheus CT172 alloy /metrics (forge 2026-11-14)"). Prometheus job `alloy`,
target `10.10.0.21:12345`, labels host=barbatoslupusrex ct=host. Applied by the
owner-run root script `brl-alloy-lan-listener-20261114.sh` (has `--rollback`).

## Metrics wave 2: Jellyfin, Navidrome, SearXNG (2026-11-14)

Owner yes in Wolff 1:1 at 5:14 PM CT. Prometheus CT172 scrapes LAN
`/metrics` with labels `job`/`instance`/`host`/`ct`/`service`/`env`.

- Jellyfin CT180: `EnableMetrics` in `/etc/jellyfin/system.xml` (needs a
  Jellyfin restart). Port 8096 is already open to `10.10.0.0/24`, which
  includes Prometheus; do not tighten that to `.72` only. Job `jellyfin`.
- Navidrome CT186: `Prometheus.Enabled` in `/etc/navidrome/navidrome.toml`
  (equivalent to `ND_PROMETHEUS_ENABLED`). Guest fw tcp/4533 from alias
  `prometheus`. Job `navidrome`.
- SearXNG CT160: `general.enable_metrics: true` plus `general.open_metrics`
  (HTTP basic-auth password). The password file lives only on CT172 at
  `/etc/prometheus/searxng_metrics_pass` (0600 root:root); it is not in
  git. Guest fw tcp/8888 from `prometheus`. Job `searxng`.
- Caddy CT250 family ingress (`.251`): `respond /metrics* 404` on the
  jellyfin, navidrome, and searxng vhosts, same pattern as Grafana and
  OpenObserve. The `.250` listener already `abort`s those hostnames.

Enable the app flags with `ansible/playbooks/metrics.yml` (tags
`metrics_jellyfin`, `metrics_navidrome`, `metrics_searxng`). Apply one
CT at a time. The SearXNG play reads the password from
`searxng_metrics_pass_file` on the controller and never logs it.

