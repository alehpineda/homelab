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

Resources: 169 is 4 cores / 8192 MB / 20G; 171 is 1 / 1024 MB / 8G; 172 is
2 / 2048 MB / 20G; 173 is 1 / 1024 MB / 20G; 174 is 1 / 512 MB / 4G.
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

## Still pending

Flint DHCP reservations for `10.10.0.71`–`10.10.0.74` (MACs on CTs
171–174) are still pending. Until those exist, the static addresses in
the LXC configs are what Terraform records.
