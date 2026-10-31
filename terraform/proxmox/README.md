# Terraform skeleton for BRL (Proxmox LXC)

Minimal Telmate/proxmox root module for the standalone node
`barbatoslupusrex`. It declares **no** `proxmox_lxc` resources. The example
guest in `main.tf` is commented out. Running apply from this tree today
should not create or destroy a container.

This directory does not approve an apply. Create and destroy of any guest,
including CTIDs 100–113, wait for a separate approved plan. Follow
[docs/runbooks/lxc-change.md](../../docs/runbooks/lxc-change.md).

Node facts (no secrets): [docs/blr.md](../../docs/blr.md).

| Fact | Value |
|------|--------|
| Node | `barbatoslupusrex` |
| LAN | `10.10.0.21` |
| NetBird | `100.85.104.18` |
| Existing CTIDs | 100–113 |
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

## Import (later, not part of this skeleton)

Import is a state write. Do not import CTIDs 100–113 until a plan names
one guest, the resource block exists (the example below is commented out
today), and a backup or snapshot exists.

Telmate import id format is `<node>/lxc/<vmid>`:

```bash
# Example only. Do not run until example_service is a real resource and
# the VMID is the one named in an approved plan.
# terraform import proxmox_lxc.example_service barbatoslupusrex/lxc/100
```

After import, `terraform plan` must show no destroy and no surprise
replace. If it does, stop. `terraform state rm` drops the state entry and
leaves the guest on the node; use it only when the runbook says the state
entry is the problem.

## Rollback

For this skeleton, rollback is git: close the pull request or revert it.
No vzdump is required for a docs-and-code change that never applied.

For a later apply, roll back with the CT snapshot or vzdump from the
runbook, then fix git. Do not destroy a live CT to "clean up" state.
