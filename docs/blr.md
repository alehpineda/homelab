# BRL (Barbatos Lupus Rex)

Public facts for the standalone Proxmox VE node used by this homelab.
This page is a pointer for later Terraform and Ansible work. It does not
authorize creating, changing, or destroying guests.

No API tokens, passwords, SSH private keys, or share credentials belong
here or anywhere else in git.

## Node

| Fact | Value |
|------|--------|
| Node name | `barbatoslupusrex` |
| Role | Standalone Proxmox VE (not a cluster) |
| LAN address | `10.10.0.21` |
| NetBird address | `100.85.104.18` |
| API URL shape | `https://10.10.0.21:8006/api2/json` or `https://100.85.104.18:8006/api2/json` |
| PVE version | Not recorded in this skeleton. Run `pveversion` on the node before any later apply. |
| Virtual machines | 0 |
| LXC guests | 24 containers on the node, including CT 176. CT 175 replaced destroyed CT 163 on 2026-11-05. CT 155 and CT 156 recorded 2026-11-03 from pct (onboot=1, listed running). Prior check: 18 running, 3 stopped (166, 167, 168). CT 176 (`forge-ws-blr-lxc`) day-1: XFCE 4.20 + xrdp + Grok Bot 0.78.5 + Google Chrome stable from Google's apt repo, set as the default browser. |


## Existing CTIDs

These IDs already exist on the node, including CT 176. Do not destroy or
recreate a live guest from Terraform until a separate approved plan imports
it and the plan output shows no destroy. CT 176 create-time fields are
ignored so the existing guest is not modified.

Renumbered 2026-11-01 (Option Y): static IPs on 10.10.0.0/24, gateway
10.10.0.1, CTID last two digits = IP last octet. CT 175 keeps
`10.10.0.63` from the destroyed CT 163, so its last octet is not 175.

| CTID | Hostname | IP | Bridge | State |
|---|---|---|---|---|
| 150 | blr-nb-lxc (NetBird) | 10.10.0.50 | vmbr0 | running |
| 151 | blr-nb-lxc-b (NetBird peer B) | 10.10.0.51 | vmbr1 | running |
| 153 | adguard-blr-lxc | 10.10.0.53 | vmbr0 | running |
| 154 | unbound-blr-lxc | 10.10.0.54 | vmbr0 | running |
| 155 | adguard-blr-lxc-b (AG-B) | 10.10.0.55 | vmbr1 | running |
| 156 | adguardsync-blr-lxc | 10.10.0.56 | vmbr0 | running |
| 160 | searxng-blr-lxc | 10.10.0.60 | vmbr0 | running |
| 161 | vaultwarden-blr-lxc | 10.10.0.61 | vmbr0 | running |
| 162 | openbao | 10.10.0.62 | vmbr0 | running |
| 164 | firecrawl-blr-lxc | 10.10.0.64 | vmbr0 | running |
| 165 | honcho-blr-lxc | 10.10.0.65 | vmbr0 | running |
| 166 | gitlab | 10.10.0.66 | vmbr0 | stopped |
| 167 | hermesagent | 10.10.0.67 | vmbr0 | stopped |
| 168 | ubuntu | 10.10.0.68 | vmbr0 | stopped |
| 169 | postiz-blr-lxc | 10.10.0.69 | vmbr0 | running |
| 171 | grafana-blr-lxc | 10.10.0.71 | vmbr0 | running |
| 172 | prometheus-blr-lxc | 10.10.0.72 | vmbr0 | running |
| 173 | loki-blr-lxc | 10.10.0.73 | vmbr0 | running |
| 174 | pve-exporter-blr-lxc | 10.10.0.74 | vmbr0 | running |
| 175 | ollama-blr-lxc | 10.10.0.63 | vmbr0 | running |
| 176 | forge-ws-blr-lxc | 10.10.0.76 | vmbr0 | created |
| 180 | jellyfin-blr-lxc | 10.10.0.80 | vmbr1 | running |
| 181 | metube | 10.10.0.81 | vmbr0 | running |
| 250 | caddy-blr-lxc | 10.10.0.250 | vmbr0 | running |

DNS: AdGuard primary 10.10.0.53 (BRL), AdGuard secondary 10.10.0.1 (Flint),
Unbound upstream 10.10.0.54:5335. DHCP option 6 = 10.10.0.53, 10.10.0.1.
AdGuard sync installed but disabled. CT 155 `adguard-blr-lxc-b` is
10.10.0.55 on vmbr1. CT 156 `adguardsync-blr-lxc` is 10.10.0.56 on vmbr0.
`grafana.alehpineda.com` rewrites to
10.10.0.250 (Caddy on CT 250). Monitoring wiring, without secrets, is in
[blr-monitoring.md](blr-monitoring.md).

Flint DHCP reservations for 10.10.0.71–10.10.0.74 (MACs on CTs 171–174)
are still pending.

New containers, if a later plan creates any, need an explicit VMID not in this list.
There is no CT 163 (destroyed 2026-11-05; Ollama is CT 175) and no CT 170.
CT 176 is `forge-ws-blr-lxc` at 10.10.0.76. Create-time Terraform fields
are ignored; do not apply a replacement. Models for CT 175 live on the host
ZFS dataset `media/ollama-models`, bind-mounted at guest `/mnt/ollama-models`.
The guest runs Ollama 0.40.15 from the official installer (upgraded from
community-script 0.35.1 on 2026-11-06). Live tags are `ai;storage-data2`.
GPU inference uses Vulkan on the Intel Arc Pro B60. Ansible sets
`OLLAMA_MODELS` on the mount; see
[runbooks/ollama-models.md](runbooks/ollama-models.md).

## Storage

Names only. Paths and credentials stay on the node.

| Name | Role in this skeleton |
|------|------------------------|
| `data2` | Root-disk storage for all CTs and default `pm_storage`. CT 175 rootfs is 24G on `data2`. |
| `media` | Media storage on the node. Not wired to Terraform. |
| `media/ollama-models` | ZFS dataset, host mount `/media/ollama-models`. CT 175 mp0 binds it at guest `/mnt/ollama-models` with `backup=0`. Measured 2026-11-05: used about 203G, refquota 400G. Not a Terraform resource. |
| SMB mounts | Present on the node. Do not encode share users or passwords in this repo. |

## API access

Later `terraform plan` / `import` should use an API token with the least
privilege that still lets the Telmate provider read the guest (a read-only
token when the provider's permission check allows it). Keep the token id
and secret in the environment (`PM_API_TOKEN_ID`, `PM_API_TOKEN_SECRET`)
or a secret store. Do not commit them.

See [terraform/proxmox/README.md](../terraform/proxmox/README.md) and
[docs/runbooks/lxc-change.md](runbooks/lxc-change.md).
