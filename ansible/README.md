# Ansible skeleton for BRL

Stub inventory and playbooks for guests on `barbatoslupusrex`. Nothing here
configures a host. `site.yml` only imports `playbooks/ping.yml`.

Do not run these playbooks as a change against live guests until a separate
plan says so. A ping is still an SSH connection; use it only against hosts
you meant to reach.

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
| `playbooks/site.yml` | Imports the ping playbook. |
| `roles/` | Empty until a later plan adds roles. |

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
it or remove it before a ping you expect to succeed. Do not commit
`blr.yml`, SSH keys, or vault passwords.

## Syntax check and ping

Syntax check does not connect:

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/ping.yml
ansible-playbook --syntax-check playbooks/site.yml
```

A live ping connects with SSH. It does not install or configure anything,
and it is out of scope for the skeleton pull request:

```bash
ansible-playbook playbooks/ping.yml --limit barbatoslupusrex
```

Prefer NetBird when you are off-LAN. Confirm `ansible_port` before retrying
a timeout: **4488** on hardened hosts, **22** on a fresh LXC.

## Secrets

Never commit inventory files that contain credentials, `.env`, vault
password files, or private keys. `ansible.cfg` leaves host-key checking on.
