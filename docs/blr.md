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
| LXC guests | 14 containers. Live check 2026-11-01: 11 running, 3 stopped (166, 167, 168). |


## Existing CTIDs

These IDs already exist on the node. Do not destroy or recreate them from
Terraform until a separate approved plan imports them and the plan output
shows no destroy.

Renumbered 2026-11-01 (Option Y): static IPs on 10.10.0.0/24, gateway
10.10.0.1, CTID last two digits = IP last octet.

| CTID | Hostname | IP | Bridge | State |
|---|---|---|---|---|
| 150 | blr-nb-lxc (NetBird) | 10.10.0.50 | vmbr0 | running |
| 153 | adguard-blr-lxc | 10.10.0.53 | vmbr0 | running |
| 154 | unbound-blr-lxc | 10.10.0.54 | vmbr0 | running |
| 160 | searxng-blr-lxc | 10.10.0.60 | vmbr0 | running |
| 161 | vaultwarden-blr-lxc | 10.10.0.61 | vmbr0 | running |
| 162 | openbao | 10.10.0.62 | vmbr0 | running |
| 163 | ollama-blr-lxc | 10.10.0.63 | vmbr0 | running |
| 164 | firecrawl-blr-lxc | 10.10.0.64 | vmbr0 | running |
| 165 | honcho-blr-lxc | 10.10.0.65 | vmbr0 | running |
| 166 | gitlab | 10.10.0.66 | vmbr0 | stopped |
| 167 | hermesagent | 10.10.0.67 | vmbr0 | stopped |
| 168 | ubuntu | 10.10.0.68 | vmbr0 | stopped |
| 180 | jellyfin-blr-lxc | 10.10.0.80 | vmbr1 | running |
| 181 | metube | 10.10.0.81 | vmbr0 | running |

DNS: AdGuard primary 10.10.0.53 (BRL), AdGuard secondary 10.10.0.1 (Flint),
Unbound upstream 10.10.0.54:5335. DHCP option 6 = 10.10.0.53, 10.10.0.1.
AdGuard sync installed but disabled.

New containers, if a later plan creates any, need an explicit VMID not in this list.

## Storage

Names only. Paths and credentials stay on the node.

| Name | Role in this skeleton |
|------|------------------------|
| `data2` | Root-disk storage for all CTs and default `pm_storage`. |
| `media` | Media storage on the node. Not wired to Terraform. |
| SMB mounts | Present on the node. Do not encode share users or passwords in this repo. |

## API access

Later `terraform plan` / `import` should use an API token with the least
privilege that still lets the Telmate provider read the guest (a read-only
token when the provider's permission check allows it). Keep the token id
and secret in the environment (`PM_API_TOKEN_ID`, `PM_API_TOKEN_SECRET`)
or a secret store. Do not commit them.

See [terraform/proxmox/README.md](../terraform/proxmox/README.md) and
[docs/runbooks/lxc-change.md](runbooks/lxc-change.md).
