# Dashboard editor access (CT 191 Homepage, CT 198 Homer)

Wolff (observability bot) owns dashboard tiles under the rollout flow
(Forge deploys, Wolff adds monitors and tiles). He runs as `grokops` from
CT 176 with the forge key (`~/.ssh/id_ed25519_forge`, public key only on the
guests, fingerprint `SHA256:B0BznGN4uG7ub8EpB9qyE62MzZfygeGqgZA6gWIgC1s`).

Authority: DeathScythe 2026-11-13 10:15 PM CT: "Yes, add the grokops key on
CT191 and CT198 via IaC".

## What it grants

| CT | File | Directory |
|----|------|-----------|
| 191 homepage-blr-lxc (10.10.0.91) | `/opt/homepage/config/services.yaml` root:dashcfg 0664 | `/opt/homepage/config` root:dashcfg 2775 |
| 198 homer-blr-lxc (10.10.0.98) | `/opt/homer/assets/config.yml` root:dashcfg 0664 | `/opt/homer/assets` root:dashcfg 2775 |

- User `grokops`: password locked, not in `sudo`, no sudoers drop-in.
- Group `dashcfg` (system group), `grokops` is the only member.
- Directory group write is needed for atomic-rename editors (`sed -i`,
  vim, Ansible `copy`). It also lets the group create, rename, or delete
  other files in that one directory (on CT 191 the other Homepage YAMLs).
  setgid keeps new files in `dashcfg`. A renamed-in file becomes owned by
  `grokops`; the services run as root and still read it.
- Before state on both: directory root:root 0755, file root:root 0644.
- No restart: Homepage hot-reloads `services.yaml`; Homer is a static
  `python3 -m http.server 8010`.

## Apply

```bash
cd ansible
ansible-playbook --syntax-check playbooks/dashboards.yml
ansible-playbook playbooks/dashboards.yml --check --diff
ansible-playbook playbooks/dashboards.yml
```

Set `dashboard_editor_pubkeys` per host in the gitignored `inventory/blr.yml`.
The first live apply (2026-11-13) was done through
`sudo -n pct exec <ctid>` from BRL with an equivalent script; backups and
before/after state are in `/root/forge-grokops-20261113/` on each guest.

## Terraform

`ssh_public_keys` on `proxmox_lxc.ct_191` / `ct_198` is root's create-time
key list and is in `ignore_changes`. It is not used for this: changing it
would not reach `grokops`, and Telmate treats `ssh_public_keys` as
ForceNew, so dropping it from `ignore_changes` would plan a replacement.

## Verify (as grokops from CT 176)

```bash
ssh -i ~/.ssh/id_ed25519_forge -o IdentitiesOnly=yes grokops@10.10.0.91 'id; test -w /opt/homepage/config/services.yaml && echo writable; sudo -n true'
```

Expect `dashcfg` in `id`, `writable`, and `sudo: a password is required`.

## Rollback (per guest, as root via pct exec)

```bash
chown root:root /opt/homepage/config /opt/homepage/config/services.yaml && chmod 755 /opt/homepage/config && chmod 644 /opt/homepage/config/services.yaml && userdel -r grokops && groupdel dashcfg
```

Homer: same with `/opt/homer/assets` and `config.yml`. A script copy lives
at `/root/forge-grokops-20261113/rollback.sh <cfgfile>`.
