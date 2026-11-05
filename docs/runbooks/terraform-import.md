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

- `ostemplate`, `ssh_public_keys`, `start`: create-time only, not read back.
- `password`: create-time console root password. On telmate/proxmox
  `3.0.2-rc10`, `proxmox_lxc` marks it `Sensitive` and `ForceNew`, sends it
  only from `CreateLxc`, deletes it inside `UpdateConfig`, and does not
  read it back. `ignore_changes` is what stops a later value from planning
  a replacement. See `terraform/proxmox/README.md`. Imported guests keep
  the password set on day 1. Do not drop `password` from `ignore_changes`.
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
then `terraform plan` must show no changes before any apply. That
re-key was already done before the 2026-11-03 import. Current state is
under Applied below.

## CT 250 caddy (imported)

`ct_250_caddy.tf` declares CT 250. It was already in state on barbatos
before the 2026-11-03 import below, and that run skipped it. Rebuild
command, if state is recreated, still uses the read-only token. A
following `terraform plan` must be 0-diff. This note does not approve
apply.

    terraform import proxmox_lxc.ct_250 barbatoslupusrex/lxc/250

Current state is `~/forge-tf/mod/terraform.tfstate` on barbatos (20
resources after the 2026-11-03 import). It is no longer the pre-renumber
ct_100..ct_113 state.

## CTs 169 and 171–174 (imported 2026-11-03)

Declared 2026-11-03 from live pct facts (Postiz CT 169 from 2026-11-02;
Grafana, Prometheus, Loki, and pve-exporter from 2026-11-03) and imported
the same day. See Applied below. A following `terraform plan` must be
0-diff. Do not apply as part of importing.

Tags in git match the live community-script values. `nameserver` is
omitted: the live CTs have an empty nameserver and inherit host DNS.
Setting `nameserver = "10.10.0.53"` or the short tags from the first
declaration shows an in-place change.

```bash
terraform import proxmox_lxc.ct_169 barbatoslupusrex/lxc/169
terraform import proxmox_lxc.ct_171 barbatoslupusrex/lxc/171
terraform import proxmox_lxc.ct_172 barbatoslupusrex/lxc/172
terraform import proxmox_lxc.ct_173 barbatoslupusrex/lxc/173
terraform import proxmox_lxc.ct_174 barbatoslupusrex/lxc/174
terraform plan -detailed-exitcode   # exit 0 expected
```

These IDs were created after the 2026-11-01 import. There is no CT 170.
Guest wiring (no secrets) is in
[docs/blr-monitoring.md](../blr-monitoring.md).

## Applied (2026-11-03)

Import only. Nothing was applied.

- Approval: user "Yes", Forge 1:1 (t229u), about 10:56 AM CT.
- Repo tip at import: `047631c`. That tip still drifted on tags and
  `nameserver` for 169 and 171–174. The alignment is in git after this
  note.
- Host: barbatos. Tree: `~/forge-tf/mod` (a detached copy, not a git
  repo). Binary: `~/forge-tf/terraform` v1.9.8. Synced from
  `~/forge-tf/homelab` at `047631c`, then `terraform/proxmox/*.tf` copied
  into `mod/`.
- State: `~/forge-tf/mod/terraform.tfstate`. Backup taken before the
  imports: `~/forge-tf/mod/terraform.tfstate.bak-20261103-105730`.
- Token: `grokaudit@pve!forge` (read-only). The secret was copied to a
  mode-600 temp file, shredded after the run, and never printed.
- Imported: `ct_169`, `ct_171`, `ct_172`, `ct_173`, `ct_174` (each
  "Import successful"). Skipped: `ct_250` (already in state). State then
  held 20 resources.
- First plan: exit 2, 0 add / 5 change / 0 destroy. Drift was `tags`
  only (live values are the community-script tags).
- After setting those tags: exit 2, 0/5/0, adding
  `nameserver = "10.10.0.53"`. Live CTs have no nameserver set.
- After removing `nameserver`: exit 0, no changes.

## CT 151 blr-nb-lxc-b (imported 2026-11-03)

Declared 2026-11-03 from live facts for NetBird peer B and imported the
same day from `~/forge-tf/mod/` on barbatos. Import only. Do not apply.
A following `terraform plan` must be 0-diff.

State backup taken before the import:
`~/forge-tf/mod/terraform.tfstate.bak-20261103-ct151`.

Plan against tip `4679654` (the declaration, before this alignment) was
0 add / 1 change / 0 destroy. Live tags are
`network;storage-data2;vpn` (the file had copied CT 150's
`community-script;` prefix). Live `nameserver` is `10.10.0.1`; omitting
it would clear the value on apply. Hostname `blr-nb-lxc-b`, unprivileged,
vmbr1, MAC `BC:24:11:0F:E8:D0`, and `10.10.0.51/24` already matched.
This note records that alignment. It does not approve apply.

```bash
terraform import proxmox_lxc.ct_151 barbatoslupusrex/lxc/151
terraform plan -detailed-exitcode   # exit 0 expected after the tag and nameserver alignment
```

Nesting, keyctl, and `/dev/net/tun` stay on the node; Telmate rc10 does
not model them, and `ignore_changes` matches CT 150. The network block
documents eth0 on vmbr1, `BC:24:11:0F:E8:D0`, `10.10.0.51/24`, gateway
`10.10.0.1` (`network` is ignored after import).

## CTs 155 and 156 (pending import)

Declared 2026-11-03 from live pct for AdGuard B and AdGuard sync. Not
imported. Import only, from `~/forge-tf/mod/`, with the read-only token.
Do not apply. A following plan must be 0-diff.

```bash
terraform import proxmox_lxc.ct_155 barbatoslupusrex/lxc/155
terraform import proxmox_lxc.ct_156 barbatoslupusrex/lxc/156
terraform plan -detailed-exitcode   # exit 0 expected
```

Tags are the live pct strings, with no `storage-data2` suffix: CT 155
`adblock;community-script`, CT 156 `community-script;os`. Telmate's tag
diff suppress sorts and dedupes, so order alone does not plan a change;
the strings still match pct. `nameserver` is omitted on both (live pct
has none). Do not set `nameserver = "10.10.0.53"`; that was an in-place
change on 169 and 171–174.

`timezone` (`America/Chicago` on 155) is not in the Telmate schema.
`features` (`nesting=1,keyctl=1` on 155) are omitted like CT 153. Telmate
copies features into state only when the block is already set, so leaving
it unset keeps the plan at 0-diff and leaves `ignore_changes` identical
to CT 153. Live net0 has no firewall flag, so the network blocks omit
`firewall`. CT 156 memory is 256 (the provider default is 512). Rootfs
size is `2G` on `var.pm_storage` (`data2`); `rootfs[0].storage` is
ignored after import, size is not.

The network blocks document the live NICs (`network` is ignored after
import):

- CT 155 eth0 on vmbr1, `BC:24:11:9D:BE:3C`, `10.10.0.55/24`, gateway `10.10.0.1`
- CT 156 eth0 on vmbr0, `BC:24:11:27:FD:2D`, `10.10.0.56/24`, gateway `10.10.0.1`

## CT 176 forge-ws-blr-lxc (declared, not created)

Declared 2026-11-05. The guest is not on the node. Do not import it and do
not apply from the declaration. Create (`pct create`, with
`nesting=1,keyctl=1`, or a later plan written for that create) is a
separate approved step. After the guest exists, import only:

```bash
terraform import proxmox_lxc.ct_176 barbatoslupusrex/lxc/176
terraform plan -detailed-exitcode   # exit 0 expected after MAC alignment
```

`features` (`nesting=1,keyctl=1`) and `timezone` (`America/Chicago`) are
pct create settings. Both are omitted like CT 155 so `ignore_changes`
stays identical to that file. `hwaddr` is omitted: Proxmox assigns a
`BC:24:11` address at create, and that MAC is recorded on import.
`nameserver` is omitted (Flint option 6 / host DNS). Rootfs is
`var.pm_storage` (`data2`) at `40G`. Intended NIC, documented only
(`network` is ignored after import): eth0 on vmbr0, `10.10.0.76/24`,
gateway `10.10.0.1`. Tags: `forge;workstation;desktop`.

`ct_176_forge-ws.tf` does not set `password`. Login for that guest stays
the deathscythe account. `var.lxc_root_password` is for a later create
that opts in. It is not applied to CT 176, and this declaration does not
change SSH root-password policy.

## Create-time console root password

`var.lxc_root_password` (sensitive, default `null`) is documented in
`terraform/proxmox/README.md`. It sets the create-time root password only.
Automatic root login, a console that opens a root shell with no prompt,
is a separate behavior and is not configured here. Live root passwords
succeed, and CT 175 still presents a login prompt. A read-only comparison
of PVE `cmode` and guest getty configuration is in progress. Autologin
waits for that comparison to be verified and for explicit approval. No
declared `ct_*.tf` sets `password`. Existing guest passwords stay the
day-1 values already on the guests. Live passwords for CT 175 and CT 250
were applied outside this repo and are not imported here. CT 175's
Terraform declaration is open pull request #19; this note does not add
`ct_175_ollama.tf`.

A future create sets `password = var.lxc_root_password` and keeps
`password` in `ignore_changes`. Export `TF_VAR_lxc_root_password` from a
secret store for that create only. Do not write it into state you commit.
After create, the plaintext password sits in local `terraform.tfstate`
because Telmate does not read it back and `sensitive` only redacts the
CLI. State stays gitignored. `prevent_destroy` stays on the guest.
