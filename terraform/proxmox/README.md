# Terraform skeleton for BRL (Proxmox LXC)

Minimal Telmate/proxmox root module for the standalone node
`barbatoslupusrex`. Live guests are declared in `ct_<id>_<name>.tf` for
import. The example guest in `main.tf` is commented out. Running apply
from this tree is not approved and must not create or destroy a container.

This directory does not approve an apply. Create and destroy of any guest,
including CTIDs 150, 151, 153, 154, 155, 156, 160–162, 164–169, 171–176, 180–184, and 250, wait for a separate approved plan. CT 176 create-time fields are declared and ignored so the existing guest is not modified. CT 182 (`arr-blr-lxc`) is live. CT 183 (`seerr-blr-lxc`) is live. CT 184 (`uptimekuma-blr-lxc`) is declared. See [docs/runbooks/arr-phase1.md](../../docs/runbooks/arr-phase1.md). Follow
[docs/runbooks/lxc-change.md](../../docs/runbooks/lxc-change.md).

Node facts (no secrets): [docs/blr.md](../../docs/blr.md).
Monitoring and Postiz wiring: [docs/blr-monitoring.md](../../docs/blr-monitoring.md).

| Fact | Value |
|------|--------|
| Node | `barbatoslupusrex` |
| LAN | `10.10.0.21` |
| NetBird | `100.85.104.18` |
| Existing CTIDs | 150, 151, 153, 154, 155, 156, 160–162, 164–169, 171–176, 180, 181, 182, 183, 184, 250 |
| CT 183 | `seerr-blr-lxc` at 10.10.0.83. Live. Seerr v3.5.1 via community-script (`seerr.service`, port 5055). Root locked. Family ingress planned via Caddy .251 (family/guest ingress, planned). |
| CT 184 | `uptimekuma-blr-lxc` at 10.10.0.84. Declared. Uptime Kuma 2.5.9 via community-script (`uptime-kuma.service`, port 3001). 2 cores / 2048 MiB / 8G. Root locked. Admin vhost `uptime.alehpineda.com` on Caddy .250. |
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

## Console root password (future create only)

`var.lxc_root_password` is the Telmate `proxmox_lxc.password` argument: the
Proxmox API `password` field, which sets the console root password inside
the guest at create. It does not change SSH (`PermitRootLogin`,
`PasswordAuthentication`, or `ssh_public_keys`).

### Password and automatic login are different

A configured password lets root authenticate when a prompt asks for one.
Automatic root login opens a root shell with no login prompt. This variable
does not configure that. Telmate `password` is not PVE `cmode`, and it does
not write getty or autologin configuration inside the guest.

The read-only comparison is complete. CT 170, CT 171, and CT 181 omit the
login prompt because their guest agetty units override `ExecStart` with
`--autologin root`. `cmode` is `tty` on those guests and on CT 175 and
CT 250, so `cmode` does not account for the difference.

On 2026-11-05 at 4:26 PM CT the operator approved a CT 175-only pilot.
Getty overrides were applied on that guest. The effective `ExecStart`
includes `--autologin root`. A `login -f root` shell was verified on tty2
and on `/dev/console`, and the operator then validated autologin in the
console. The root password was left in place, SSH stays key-only, and
Ollama on CT 175 returned HTTP 200. That pilot did not change CT 250 or
CT 176. CT 250 was later measured on Debian 13: stock getty flags kept,
`-o` removed, and `--autologin root` added. Restarts were
`container-getty@tty1`, `container-getty@tty2`, and `console-getty`, with
root shells on each. No tty1 session was active beforehand. The root
password stayed, SSH stayed without password authentication, and Caddy
stayed active (admin HTTP 200, an HTTP 308 observed, service not
restarted). CT 176 stayed unchanged.

This Terraform variable still does not install getty units or set `cmode`.
The opt-in encoding is `ansible/playbooks/console-autologin.yml`, with a
separate measured ExecStart for Ubuntu 24.04 and Debian 13. `site.yml`
does not import it, and this change does not run it.

Supply it only for a new guest whose approved plan sets
`password = var.lxc_root_password`:

```bash
# from a secret store; the value must not be written to git or tfvars
export TF_VAR_lxc_root_password='<from-your-secret-store>'
```

Leave the variable unset for `plan` and `import`. It defaults to `null`,
has no example value, and is `sensitive`. A blank string fails the
variable validation when Terraform evaluates variables (`terraform plan`).
`terraform validate` does not run that rule. `terraform.tfvars.example`
does not contain the key.

Checked against telmate/proxmox `3.0.2-rc10` (`resourceLxc`, the resource
registered as `proxmox_lxc`) and proxmox-api-go
`v0.0.0-20260830211552-9cba66824699`:

- Schema: `password` is optional, `Sensitive`, and `ForceNew` ("Proxmox
  doesn't support password changes") in `proxmox/resource_lxc.go`.
- Create (not clone) copies it onto `ConfigLxc.Password`. `CreateLxc`
  JSON-encodes the struct (`password,omitempty`) and POSTs the container.
  An empty string is omitted.
- `UpdateConfig` deletes `password` before `SetLxcConfig`, so an in-place
  update does not send a password. The clone path calls `UpdateConfig`
  after the clone, so a clone does not send one either.
- Read leaves `d.Set("password", ...)` commented ("Only applicable on
  create and not readable"). Import therefore stores no password.

`terraform providers schema -json` on the installed `3.0.2-rc10` plugin
reports `proxmox_lxc.password` as optional and sensitive. That JSON does
not include `ForceNew`. `ForceNew: true` is in `resource_lxc.go` at the
tag the lock file installs, next to the comment the provider binary still
contains.

`ForceNew` means a password difference is a replacement plan. Every
`proxmox_lxc` in this module already lists `password` in
`lifecycle.ignore_changes`, so that difference is ignored on update and
the guest is not rotated or replaced. Create still applies the initial
value. Do not remove `password` from `ignore_changes` to try to rotate one.

State: after a create that set `password`, Terraform keeps the config
value because Read does not refresh it. `sensitive` redacts the CLI plan.
The local `terraform.tfstate` still holds the plaintext string. `*.tfstate`
and `*.tfvars` are gitignored. Keep the state file on the operator host,
mode-restricted, and out of git. This root module has no remote backend, so
nothing here encrypts state. `terraform state pull` and a failed `CreateLxc`
error can include the API parameter map (the provider formats that map into
the error). Treat those logs as secret. `prevent_destroy` on each guest
rejects a destroy. The Proxmox guest `protection` flag is a separate API
field and this change does not set it.

Day-1 passwords on guests that already exist were set when those containers
were created. This module does not read, receive, or rotate them. Live
console root passwords for CT 175 and CT 250 were applied outside this
change. CT 176 (`proxmox_lxc.ct_176`) has no `password` argument and stays
that way: login remains the deathscythe account. `ct_175_ollama.tf`
declares CT 175 and does not set `password`. The live CT 175 agetty
autologin pilot is the opt-in Ansible role; see the section above.

CT 175's Ollama API is 0.40.15 (from 0.35.1 on 2026-11-06). Tags in
`ct_175_ollama.tf` are `ai;storage-data2`. Facts are in
[docs/blr.md](../../docs/blr.md).

The commented `example_service` block in `main.tf` shows the two lines a
future create needs. Uncommenting it is not approval to apply.

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

CT 183 (`seerr-blr-lxc`) is live on BRL at `10.10.0.83` (created 2026-11-09 via targeted apply). Seerr v3.5.1 is installed from the community-scripts seerr installer (`ct/seerr.sh`) as native systemd `seerr.service` on port 5055. Not Docker. Root is locked. Family ingress is planned via Caddy .251 (family/guest ingress, planned).

CT 184 (`uptimekuma-blr-lxc`) is declared at `10.10.0.84` (2 cores / 2048 MiB / 8G root on data2). Day-1 install is the community-scripts uptimekuma installer inside the IaC guest (Node 22, Uptime Kuma 2.5.9, systemd `uptime-kuma` on port 3001). Not Docker. Do not run `ct/uptimekuma.sh` on the PVE host. Root is locked. Admin vhost is `uptime.alehpineda.com` on Caddy `.250`. After create, run `pct set 184 --timezone America/Chicago` then `pct start 184`.

The Telmate `proxmox_lxc` resource cannot set the container timezone. After create, run `pct set 183 --timezone America/Chicago`. The same applies to other CTs created this way.

## PVE guest firewall (not owned by Terraform)

Since 2026-11-09, CTs 164, 172, 173, 174, 175, 180, 181, 182, 183, and 184 run with
`net0 firewall=1` and a per-CT PVE firewall (`policy_in: DROP`, `ipfilter: 1`,
`GROUP ct_base` plus per-CT allows). The Telmate provider keeps `network` in
`ignore_changes`, so Terraform does not read or flap the NIC flag. The Ansible
role `pve_guest_firewall` owns it; see
[docs/runbooks/pve-guest-firewall.md](../../docs/runbooks/pve-guest-firewall.md).

## Rollback

For this skeleton, rollback is git: close the pull request or revert it.
No vzdump is required for a docs-and-code change that never applied.

For a later apply, roll back with the CT snapshot or vzdump from the
runbook, then fix git. Do not destroy a live CT to "clean up" state.
