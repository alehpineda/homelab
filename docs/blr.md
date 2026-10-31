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
| LXC guests | CTID **100–113** (14 containers). Audit on 2026-10-31: 12 running, 2 stopped. Which two are stopped is not listed here. |

Guest hostnames and per-CT addresses are omitted on purpose. Fill those in
a later import plan, not in this skeleton.

## Existing CTIDs

These IDs already exist on the node. Do not destroy or recreate them from
Terraform until a separate approved plan imports them and the plan output
shows no destroy.

`100` `101` `102` `103` `104` `105` `106` `107` `108` `109` `110` `111` `112` `113`

New containers, if a later plan creates any, need an explicit VMID outside
this range.

## Storage

Names only. Paths and credentials stay on the node.

| Name | Role in this skeleton |
|------|------------------------|
| `local-lvm` | Default root-disk storage for a future LXC (`pm_storage`). |
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
