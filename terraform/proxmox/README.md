# Terraform skeleton for BRL (Proxmox LXC)

Minimal Telmate/proxmox root module for the standalone node
`barbatoslupusrex`. Live guests are declared in `ct_<id>_<name>.tf` for
import. The example guest in `main.tf` is commented out. Running apply
from this tree is not approved and must not create or destroy a container.

This directory does not approve an apply. Create and destroy of any guest,
including CTIDs 150, 151, 153, 154, 155, 156, 160–162, 164–169, 171–176, 180, 181, and 250, wait for a separate approved plan. CT 176 create-time fields are declared and ignored so the existing guest is not modified. Follow
[docs/runbooks/lxc-change.md](../../docs/runbooks/lxc-change.md).

Node facts (no secrets): [docs/blr.md](../../docs/blr.md).
Monitoring and Postiz wiring: [docs/blr-monitoring.md](../../docs/blr-monitoring.md).

| Fact | Value |
|------|--------|
| Node | `barbatoslupusrex` |
| LAN | `10.10.0.21` |
| NetBird | `100.85.104.18` |
| Existing CTIDs | 150, 151, 153, 154, 155, 156, 160–162, 164–169, 171–176, 180, 181, 250 |
| CT 176 day-1 | XFCE 4.20 + xrdp + Grok Bot 0.78.5 + Google Chrome stable (default browser) |
| Provider | `telmate/proxmox` `3.0.2-rc10` |

`3.0.2-rc10` is the latest registry tag as of 2026-10-31 and is still a
release candidate. The pin is exact so init does not float to a newer RC.

## What you need locally

- Terraform >= 1.5
- Network access to the Proxmox API (LAN or NetBird)
- An API token stored outside git

```bash
export PM_API_URL='https://100.85.104.18:8006/api2/json'
# LAN alternative: https://10.10.0.21:8006/api2/json
# Single quotes matter: the token id contains !
export PM_API_TOKEN_ID='user@pam!token-name'
export PM_API_TOKEN_SECRET='replace-with-secret-from-your-secret-store'
```

Use a least-privilege token. For a later import, prefer a token that can
read the guest without VM.Allocate or VM.Destroy if the provider's
permission check accepts it. `pm_tls_insecure` defaults to `false` and is
not read from the environment. Set it in `terraform.tfvars` (gitignored)
only when you have decided the node certificate is safe to skip.

Do not commit `.env`, `terraform.tfvars`, `*.tfstate`, or `.terraform/`.

## Init, format, validate, plan

`validate` does not need API credentials. `plan` does, and it talks to the
node. `plan` still must not be followed by `apply` until a change plan is
approved.

```bash
cd terraform/proxmox
terraform fmt -check
terraform init
terraform validate
terraform plan
```

`terraform init -backend=false` is enough when you only want validate and
you are not configuring a remote backend. This skeleton uses the local
backend, which is another reason not to commit state.

Optional non-secret overrides: copy `terraform.tfvars.example` to
`terraform.tfvars`.

## Import

CTIDs 150, 153, 154, 160–168, 180, and 181 are declared in `ct_<id>_<name>.tf` and were imported on
2026-11-01. CT 250 (caddy), CT 151 (`blr-nb-lxc-b`, NetBird peer B), CT 169
(postiz), and CTs 171–174 (monitoring) were imported by 2026-11-03. CT 155
(`adguard-blr-lxc-b`, AG-B) and CT 156 (`adguardsync-blr-lxc`) are declared
and pending import from `~/forge-tf/mod/`. CT 176 (`forge-ws-blr-lxc`)
create-time fields (`ostemplate`, `ssh_public_keys`, `start`, `features`)
are ignored so the existing guest is not modified. Do not apply from this
declaration. Day-1: XFCE 4.20 + xrdp + Grok Bot 0.78.5 + Google Chrome stable
from Google's apt repo, set as the default browser.
See `docs/runbooks/terraform-import.md` for the env setup, the import
commands, and the expected 0-diff plan. Import only with an approved
plan. Do not apply. Tags on 169 and 171–174 match the live
community-script values, and those files omit `nameserver` so the guests
keep inheriting host DNS. CT 151 tags are `network;storage-data2;vpn` and
`nameserver` is `10.10.0.1`. CT 155 tags are `adblock;community-script`
and CT 156 tags are `community-script;os` (pct order; no `storage-data2`
suffix). Both omit `nameserver`. State backup from the CT 151 import:
`~/forge-tf/mod/terraform.tfstate.bak-20261103-ct151`.

CT 175 (`ollama-blr-lxc`) replaces destroyed CT 163. `ct_163_ollama.tf` is
gone. Before import, `terraform state rm proxmox_lxc.ct_163` (state only;
CT 163 is already gone), then
`terraform import proxmox_lxc.ct_175 barbatoslupusrex/lxc/175`. A following
plan must be 0-diff. Do not apply. Tags are `ai;storage-data2`. The guest
runs Ollama 0.40.15 from the official installer (upgraded from
community-script 0.35.1 on 2026-11-06). Models stay on ZFS
`media/ollama-models`, mounted at guest `/mnt/ollama-models`. GPU
inference is Vulkan on the Intel Arc Pro B60. Features, DRI devices, the
models dataset, and the `OLLAMA_MODELS` drop-in are documented in
`docs/runbooks/terraform-import.md` and `docs/runbooks/ollama-models.md`.

## Rollback

For this skeleton, rollback is git: close the pull request or revert it.
No vzdump is required for a docs-and-code change that never applied.

For a later apply, roll back with the CT snapshot or vzdump from the
runbook, then fix git. Do not destroy a live CT to "clean up" state.
