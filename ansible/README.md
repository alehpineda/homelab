# Ansible skeleton for BRL

Stub inventory and playbooks for guests on `barbatoslupusrex`. `site.yml`
only imports `playbooks/ping.yml`. `playbooks/ollama.yml` is separate: it
ensures `OLLAMA_MODELS` on CT 175 and does not run unless you invoke it.

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
| `playbooks/site.yml` | Imports the ping playbook. Does not import `ollama.yml`. |
| `playbooks/ollama.yml` | Ensures `OLLAMA_MODELS` on `ollama-blr-lxc`. |
| `roles/ollama/` | Drop-in, mount check, and non-recursive ownership. |

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
```

A live ping connects with SSH. It does not install or configure anything,
and it is out of scope for the skeleton pull request:

```bash
ansible-playbook playbooks/ping.yml --limit barbatoslupusrex
```

Prefer NetBird when you are off-LAN. Confirm `ansible_port` before retrying
a timeout: **4488** on hardened hosts, **22** on a fresh LXC.

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

## Secrets

Never commit inventory files that contain credentials, `.env`, vault
password files, or private keys. `ansible.cfg` leaves host-key checking on.
