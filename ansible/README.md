# Ansible skeleton for BRL

Stub inventory and playbooks for guests on `barbatoslupusrex`. `site.yml`
only imports `playbooks/ping.yml`. `playbooks/ollama.yml` and `playbooks/caddy.yml` are separate and do not
run unless you invoke them.

Do not run these playbooks as a change against live guests until a separate
plan says so. A ping is still an SSH connection; use it only against hosts
you meant to reach. `ollama.yml` restarts `ollama` when its drop-in changes.

`alehpineda/ansible-playbooks` is a different repository. This skeleton does
not vendor or modify it. Hosts that repo has already hardened may listen on
SSH port **4488**. Fresh LXCs often still listen on **22**. Set
`ansible_port` per host in the local inventory.

## Layout

| Path | Purpose |
|------|---------|
| `ansible.cfg` | Inventory path and `roles_path`. Run commands from `ansible/`. |
| `inventory/blr.yml.example` | Shape for groups `pve` and `lxc`. |
| `inventory/blr.yml` | Local copy. Gitignored. |
| `group_vars/all.yml.example` | Non-secret defaults. |
| `playbooks/ping.yml` | `ansible.builtin.ping` only. |
| `playbooks/site.yml` | Imports the ping playbook. Does not import `ollama.yml`, `caddy.yml`, or console autologin. |
| `playbooks/ollama.yml` | Ensures `OLLAMA_MODELS` on `ollama-blr-lxc`. |
| `playbooks/caddy.yml` | Ensures the CT 250 Caddy boot drop-in. Does not restart Caddy. |
| `roles/caddy_boot/` | That playbook. File plus `daemon-reload` only. |
| `playbooks/console-autologin.yml` | Opt-in root console autologin. Not run by `site.yml`. |
| `roles/ollama/` | Drop-in, mount check, and non-recursive ownership. |
| `playbooks/grokbot-headless.yml` | Opt-in always-on Grok Bot on CT 176. Not run by `site.yml`. |
| `roles/grokbot_headless/` | Xvfb `:99` + Grok Bot user units, linger, empty-password keyring. See `docs/runbooks/ct176-headless-grokbot.md`. |
| `playbooks/dashboards.yml` | CT 191 Homepage / CT 198 Homer: `grokops` key, `dashcfg` group write on the tile config only. No sudo. Not run by `site.yml`. |
| `roles/dashboard_editor/` | That playbook. See `docs/runbooks/dashboard-editor.md`. |
| `roles/console_autologin/` | Getty drop-ins for that playbook. Default off. |
| `playbooks/arr.yml` | CT 182 Docker, Dockge, and the phase-1 stack. Not run by `site.yml`. |
| `roles/arr/` | That playbook. Skips gluetun, qBittorrent, and Watchtower when `.env` is missing. |
| `playbooks/logging.yml` | Loki CT 173 config, OpenObserve CT 177, Alloy agents, Prometheus remote_write. Per-phase `--tags`. Not run by `site.yml`. |
| `roles/loki_config/` | `/etc/loki/config.yml` (30d compactor retention). `-verify-config` before replace. |
| `roles/openobserve/` | OpenObserve OSS pinned binary, service user, hardened unit, `/etc/openobserve/openobserve.env` 0600 from controller secret files. |
| `roles/alloy/` | Grafana Alloy pinned + held; per-host sources fan out to Loki and OpenObserve. |
| `roles/prometheus_remote_write/` | Marked `remote_write` block to OpenObserve; `promtool check config` before replace. |

## Inventory

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
# Edit blr.yml. Set real guest addresses and the correct ansible_port.
```

Node addresses you can use for the `pve` group:

- NetBird: `100.85.104.18`
- LAN: `10.10.0.21`

`example-lxc` in the example file is a placeholder (`10.10.0.50`). Replace
it or remove it before a ping you expect to succeed. `ollama-blr-lxc` is
CT 175 at `10.10.0.63` port 22, which is what `playbooks/ollama.yml`
targets. Copying the example and running `site.yml` will try to ping that
guest too. Do not commit `blr.yml`, SSH keys, or vault passwords.

## Syntax check and ping

Syntax check does not connect:

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/ping.yml
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/ollama.yml
ansible-playbook --syntax-check playbooks/grokbot-headless.yml
ansible-playbook --syntax-check playbooks/arr.yml
ansible-playbook --syntax-check playbooks/caddy.yml
```

A live ping connects with SSH. It does not install or configure anything,
and it is out of scope for the skeleton pull request:

```bash
ansible-playbook playbooks/ping.yml --limit barbatoslupusrex
```

Prefer NetBird when you are off-LAN. Confirm `ansible_port` before retrying
a timeout: **4488** on hardened hosts, **22** on a fresh LXC.

## Console root autologin

`playbooks/console-autologin.yml` targets the `console_autologin` inventory
group and sets `console_autologin_enabled: true`. The role default is
`false`, and the example group is empty, so a copied inventory does not
select a guest. `site.yml` does not import the playbook. Opening this
change is not approval to run it.

Approved members are only:

| Inventory hostname | Address | Guest |
|---|---|---|
| `ollama-blr-lxc` | `10.10.0.63` | CT 175 |
| `caddy-blr-lxc` | `10.10.0.250` | CT 250 |
| `arr-blr-lxc` | `10.10.0.82` | CT 182 |

CT 176 (`forge-ws-blr-lxc`) is not a member. The role rejects any other
hostname or address. In the gitignored inventory, replace the empty group
with:

```yaml
console_autologin:
  hosts:
    ollama-blr-lxc:
      ansible_host: 10.10.0.63
      ansible_port: 22
    caddy-blr-lxc:
      ansible_host: 10.10.0.250
      ansible_port: 22
    arr-blr-lxc:
      ansible_host: 10.10.0.82
      ansible_port: 22
```

The role writes two drop-ins and leaves vendor `TTYPath` in place
(`/dev/pts/%I` for `container-getty@.service`, `/dev/console` for
`console-getty.service`). agetty's `-` uses that inherited tty. A blank
`ExecStart=` clears the distro command first.

Packaged units compared for this encoding, not by editing a guest:

| Distro | systemd | Stock `ExecStart` login options |
|---|---|---|
| Ubuntu 24.04 (`systemd 255.4-1ubuntu8.18`) | util-linux 2.39.3 | `-o '-p -- \\u'` on both gettys. Console form is tty `-`, then `115200,38400,9600`. |
| Debian 13 (`systemd 257.13-1~deb13u1`) | util-linux 2.41.5 | `-o '-- \\u'` plus `--noreset`. Console form lists `115200,57600,38400,9600` before `-`. |
| Ubuntu 26.04 (CT 182) | measured agetty at `/usr/sbin/agetty` | `--noreset` and `--issue-file` kept. `-o` is absent. Console form lists `115200,57600,38400,9600` before `-`. |

`--autologin` adds `login -f`. `--login-options` (`-o`) is what the stock
units pass to `login`, and it is how `-f` gets replaced. Each drop-in
starts with a blank `ExecStart=` and then sets the command measured for
that distro. The role reads the guest distro and refuses to write a
drop-in when it is not the distro recorded for that hostname.

Ubuntu 24.04, measured on CT 175 (`ollama-blr-lxc`). No `--noreset`. Tty,
then baud. `$TERM`:

```
ExecStart=-/sbin/agetty --autologin root --noclear - $TERM
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud - 115200,38400,9600 $TERM
```

Debian 13, measured on CT 250 (`caddy-blr-lxc`). Stock flags kept, `-o`
removed, `--autologin root` added. Baud list, then tty. `${TERM}`:

```
ExecStart=-/sbin/agetty --autologin root --noreset --noclear - ${TERM}
ExecStart=-/sbin/agetty --autologin root --noreset --noclear --keep-baud 115200,57600,38400,9600 - ${TERM}
```

Ubuntu 26.04, measured for CT 182 (`arr-blr-lxc`). Not Ubuntu 24.04.
`/usr/sbin/agetty`, `--noreset` and `--issue-file` kept, `-o` absent.
Container form is tty, then `${TERM}`. Console form is baud, then tty:

```
ExecStart=-/usr/sbin/agetty --autologin root --noreset --noclear --issue-file=/etc/issue:/etc/issue.d:/run/issue.d:/usr/lib/issue.d - ${TERM}
ExecStart=-/usr/sbin/agetty --autologin root --noreset --noclear --issue-file=/etc/issue:/etc/issue.d:/run/issue.d:/usr/lib/issue.d --keep-baud 115200,57600,38400,9600 - ${TERM}
```

CT 250's live run restarted `container-getty@tty1`, `container-getty@tty2`,
and `console-getty`. Root shells were verified on all three. No tty1
session was active beforehand. The root password was left in place. SSH
stays without password authentication. Caddy stayed active and was not
restarted; its admin endpoint returned HTTP 200, and an HTTP 308 was
observed. CT 176 was not changed. The on-guest files are not copied into
git; the lines above are the measured contents. This playbook was not
run for that measurement.

Anyone who can open the Proxmox console for that guest gets a root shell
without a password. That is the console permission boundary. It is root
inside the guest. Unprivileged container root is not host root. `pct enter`
is a different path and is already root.

The first run that changes a drop-in reloads systemd and `try-restart`s
`console-getty` plus active `container-getty@` instances. That closes
those console sessions. A second run with the same files does not restart
them. The play still reads the merged `ExecStart` and fails if `-o` is
present, `--autologin root` is missing, or a `/dev/` path was hardcoded.

### Rollback

On the guest, as root:

```bash
rm -f /etc/systemd/system/container-getty@.service.d/autologin.conf
rm -f /etc/systemd/system/console-getty.service.d/autologin.conf
rmdir /etc/systemd/system/container-getty@.service.d 2>/dev/null || true
rmdir /etc/systemd/system/console-getty.service.d 2>/dev/null || true
systemctl daemon-reload
systemctl try-restart console-getty.service
systemctl list-units --type=service --state=running --no-legend --plain 'container-getty@*' \
  | awk '{print $1}' | while read -r unit; do systemctl try-restart "$unit"; done
```

Vendor `ExecStart` returns, including its `-o` login options, so the
console prompts again. The root password and SSH configuration stay as
they were. This pull request does not run the rollback.

## Ollama models path (CT 175)

`playbooks/ollama.yml` applies `roles/ollama` to `ollama-blr-lxc` only.
It is not part of `site.yml`. Run it only after a separate plan names
CT 175. Procedure and the ZFS dataset note:
[docs/runbooks/ollama-models.md](../docs/runbooks/ollama-models.md).

What the role does, and does not do:

- Writes `/etc/systemd/system/ollama.service.d/models.conf` with
  `Environment=OLLAMA_MODELS=/mnt/ollama-models`. It does not edit
  `/etc/systemd/system/ollama.service`.
- Leaves the official-installer unit in place. systemd merges the drop-in
  afterward. CT 175 runs Ollama 0.40.15 (upgraded from community-script
  0.35.1 on 2026-11-06). GPU inference is Vulkan on the Intel Arc Pro B60
  and is not configured by this role.
- Requires the unit file to already exist. It does not install or upgrade
  Ollama. `ollama_version` in `roles/ollama/defaults/main.yml` records
  0.40.15; the role does not apply that pin.
- Requires `findmnt --mountpoint /mnt/ollama-models` to succeed, so a
  missing mp0 cannot create a directory on the 24G rootfs. It does not
  create the host ZFS dataset `media/ollama-models` or change pct mp0.
- Sets root:root mode `0755` on `/mnt/ollama-models` and does not recurse.
  Override `ollama_models_owner` from the gitignored inventory or `-e`
  if the unit `User=` is not root. Defaults live in
  `roles/ollama/defaults/main.yml`.
- Reloads systemd and restarts `ollama` only when the drop-in content
  changes. A second run with the same file does not restart the service.

Syntax check (no SSH):

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/ollama.yml
```

Live run, only when approved:

```bash
ansible-playbook playbooks/ollama.yml
```


## Caddy boot drop-in (CT 250)

`playbooks/caddy.yml` applies `roles/caddy_boot` to `caddy-blr-lxc` only.
It is not part of `site.yml`. Run it only after a separate plan names
CT 250. The same drop-in was applied live on 2026-11-10; a later playbook
run should be a no-op besides confirming the file.

What the role does, and does not do:

- Writes `/etc/systemd/system/caddy.service.d/10-forge-boot.conf` with
  `Wants=`/`After=network-online.target`, `StartLimitIntervalSec=0`,
  `Restart=on-failure`, and `RestartSec=3s`. It does not edit
  `/etc/systemd/system/caddy.service` or the Caddyfile.
- Requires the unit file to already exist. It does not install or
  upgrade Caddy.
- Reloads systemd when the drop-in content changes. It does **not**
  restart `caddy`; the running process is left alone. The new restart
  policy applies to the next start or crash.
- This guest uses ifupdown2. `networking.service` is wanted by
  `network-online.target` but does not order `Before=` it, and there is
  no `ifupdown-wait-online` or enabled `systemd-networkd-wait-online`.
  The drop-in still declares `Wants`/`After` `network-online.target`,
  and `Restart=on-failure` is what covers the bind-before-IP race.
  The role does not enable a wait-online unit or set
  `net.ipv4.ip_nonlocal_bind`.

Syntax check (no SSH):

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/caddy.yml
```

Live run, only when approved:

```bash
ansible-playbook playbooks/caddy.yml
```

## Arr (CT 182)

`playbooks/arr.yml` applies `roles/arr` to `arr-blr-lxc` only. It is not
part of `site.yml`. Procedure, Watchtower, and the VPN checks:
[docs/runbooks/arr-phase1.md](../docs/runbooks/arr-phase1.md). Phase 2
apps in the same compose:
[docs/runbooks/arr-phase2.md](../docs/runbooks/arr-phase2.md).

The role installs Docker and Dockge, copies the pinned compose, and does
not start the stack when `/opt/stacks/arr/.env` is missing or empty. It
does not print that file and it does not run `docker compose config`.

Syntax check (no SSH):

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/arr.yml
```

## grokaudit on LXCs

`playbooks/grokaudit.yml` applies `roles/lxc_grokaudit` to the
`grokaudit_lxc` group. It is not part of `site.yml`. The owner approved
it on 2026-11-09 for Surface Scout's read-only inventory and exposure checks.

- User `grokaudit`, uid/gid **2990**, `/bin/bash`, password locked.
- `authorized_keys` holds only the secops public key (`0700` / `0600`).
- No `sudo`, `wheel`, `docker`, `adm` or `lxd`. The play fails if one appears.
- uid 1000 is avoided on purpose. CT 182 maps guest uid 1000 to host
  uid 1100 (media), and the *arr apps run as that uid.
- Refused guests: CT 161 Vaultwarden, CT 169 Postiz and CT 183 Seerr
  (world-readable vault DB, `.env` or API keys), and CT 176 (uses `scout`).

Day-1 for a new LXC: add it to `grokaudit_lxc` in the gitignored inventory,
then run:

```bash
ansible-playbook playbooks/grokaudit.yml --limit <hostname>
```

Rollback on the guest, as root: `userdel -r grokaudit`.

## Secrets

Never commit inventory files that contain credentials, `.env`, vault
password files, or private keys. `ansible.cfg` leaves host-key checking on.
