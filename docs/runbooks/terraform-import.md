# Runbook: Terraform import of BRL CTs 100-113

Imported 2026-11-01 with Terraform 1.9.8 and telmate/proxmox 3.0.2-rc10.
Import and plan only read from PVE. No apply was run.

## Where to run

The PVE API (`10.10.0.21:8006`) is reachable from the LAN and NetBird, not
from the cloud box. Run from a host on either network (2026-11-01 run: barbatos).

## Env setup (secrets in env only)

```bash
cd terraform/proxmox
export PM_API_URL='https://10.10.0.21:8006/api2/json'
export PM_API_TOKEN_ID='grokaudit@pve!forge'     # PVEAuditor, read-only
export PM_API_TOKEN_SECRET='<from your secret store>'
export TF_VAR_pm_tls_insecure=true                # node uses its self-signed cert
export TF_VAR_pm_minimum_permission_check=false   # read-only token fails Telmate's write-permission precheck
terraform init && terraform validate
```

Without `pm_minimum_permission_check=false`, Telmate refuses the auditor
token ("permissions ... are not sufficient ... VM.Allocate ..."). Import and
plan work without those privileges. Do not use this token for apply.

## Import commands

```bash
for id in 100 101 102 103 104 105 106 107 108 109 110 111 112 113; do
  terraform import proxmox_lxc.ct_$id barbatoslupusrex/lxc/$id
done
terraform plan -detailed-exitcode   # exit 0 expected
```

Pilot was CT 102 (adguard), then the other 13 were imported as a batch.

## Expected plan (redacted)

```
proxmox_lxc.ct_100: Refreshing state... [id=barbatoslupusrex/lxc/100]
...
proxmox_lxc.ct_113: Refreshing state... [id=barbatoslupusrex/lxc/113]

No changes. Your infrastructure matches the configuration.
```

## Why each ignore_changes entry exists

- `ostemplate`, `password`, `ssh_public_keys`, `start`: create-time only, not read back.
- `description`: community-scripts HTML blob; not worth tracking.
- `target_node`, `cmode`, `network`, `mountpoint`, `rootfs[0].storage`: Telmate
  rc10 import leaves these null in state. Without ignoring them, plan shows
  `rootfs.storage forces replacement` (pilot, CT 102). The blocks still mirror
  `pct config` so the files stay accurate documentation.

## Known gaps

- `mountpoint` has no read-only attribute in Telmate rc10. CT 104 mp0-mp2 are
  `ro=1` on the node; the files note this in a comment.
- `dev0`/`dev1` GPU passthrough (104, 105) and raw `lxc.*` lines (`/dev/net/tun`
  on 100, 101, 104-107, 110) are not modelled by Telmate. They live only on the node.
- `timezone` and `ip6=auto` (105) are not in the Telmate schema or are
  ignored with `network`.
- Because network, mountpoints, and devices are ignored, a future apply cannot
  manage them. Evaluate bpg/proxmox in a separate plan if that matters.

## Rollback

`terraform state rm proxmox_lxc.ct_<id>`, or delete the local state. Guests
are untouched because import and plan never write to PVE.
State is local and gitignored; never commit it.

## 2026-11-01 renumber (Option Y)

CTs were renumbered and moved to static IPs (CTID last octet = IP last octet,
10.10.0.0/24). The `ct_*.tf` files now use the new IDs. Local state still
points at the old IDs: `terraform state rm proxmox_lxc.ct_<old>` then
`terraform import proxmox_lxc.ct_<new> barbatoslupusrex/lxc/<new>` for each,
then `terraform plan` must show no changes before any apply.
