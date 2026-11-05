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
| LXC guests | 23 containers on the node. CT 155 and CT 156 recorded 2026-11-03 from pct (onboot=1, listed running). Prior check: 18 running, 3 stopped (166, 167, 168). CT 176 is declared in Terraform and is not on the node. |


## Existing CTIDs

These IDs already exist on the node, except CT 176, which is declared and
not created. Do not destroy or recreate a live guest from Terraform until a
separate approved plan imports it and the plan output shows no destroy.
Declaring CT 176 does not create it.

Renumbered 2026-11-01 (Option Y): static IPs on 10.10.0.0/24, gateway
10.10.0.1, CTID last two digits = IP last octet.

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
| 163 | ollama-blr-lxc | 10.10.0.63 | vmbr0 | running |
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
| 176 | forge-ws-blr-lxc | 10.10.0.76 | vmbr0 | declared, not created |
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
There is no CT 170. CT 176 is reserved for `forge-ws-blr-lxc` at 10.10.0.76.
Creating that guest is a separate approved step.

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

## Console root passwords

Guest console root passwords are not in this repo. Containers already on
the node got theirs when they were created (day 1). Terraform does not
read those values back and does not rotate them. CT 175 and CT 250 live
passwords were applied outside this tree. Those passwords authenticate
when a prompt asks. They are not automatic root login. The read-only
comparison is complete: CT 170, CT 171, and CT 181 omit the prompt via
guest agetty `--autologin root`, while `cmode` `tty` matches CT 175 and
CT 250. The operator validated CT 175 autologin after the 4:26 PM CT
pilot on 2026-11-05. CT 250 was then measured on Debian 13 with stock
getty flags kept, `-o` removed, and `--autologin root` added. Root shells
were verified on `container-getty@tty1`, `container-getty@tty2`, and
`console-getty`. Caddy was not restarted. CT 176 stays without autologin.
The opt-in Ansible role is
`console_autologin`; running it is a separate approval. The root password
stays in place and SSH stays key-only. CT 176 stays declared
without a `password` argument; its login is the deathscythe account. A
future create can opt in with `TF_VAR_lxc_root_password` as described in
[terraform/proxmox/README.md](../terraform/proxmox/README.md). Open pull
request #19 owns the CT 175 declaration. SSH root-password policy is
unchanged.
