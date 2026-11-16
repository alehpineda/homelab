# Dashboard editor access (CT 191 Homepage, CT 198 Homer)

Wolff (observability bot) owns dashboard tiles under the rollout flow
(Forge deploys, Wolff adds monitors and tiles). He runs as `grokops` from
CT 176 with the forge key (`~/.ssh/id_ed25519_forge`, public key only on the
guests, fingerprint `SHA256:B0BznGN4uG7ub8EpB9qyE62MzZfygeGqgZA6gWIgC1s`).

Authority: DeathScythe 2026-11-13 10:15 PM CT: "Yes, add the grokops key on
CT191 and CT198 via IaC". DeathScythe 2026-11-16 9:48 AM CT, Wolff 1:1 card
t92s569: "Yes, have Forge give you write access to Homepage settings,
widgets and bookmarks".

## What it grants

| CT | Files | Directory |
|----|-------|-----------|
| 191 homepage-blr-lxc (10.10.0.91) | `/opt/homepage/config/services.yaml`, `settings.yaml`, `widgets.yaml`, `bookmarks.yaml`, `proxmox.yaml` root:dashcfg 0664 | `/opt/homepage/config` root:dashcfg 2775 |
| 198 homer-blr-lxc (10.10.0.98) | `/opt/homer/assets/config.yml` root:dashcfg 0664 | `/opt/homer/assets` root:dashcfg 2775 |

- User `grokops`: password locked, not in `sudo`, no sudoers drop-in.
- Group `dashcfg` (system group), `grokops` is the only member.
- Directory group write is needed for atomic-rename editors (`sed -i`,
  vim, Ansible `copy`). It also lets the group create, rename, or delete
  other files in that one directory (on CT 191 the remaining Homepage
  YAMLs such as `docker.yaml`). setgid keeps new files in `dashcfg`. A
  renamed-in file becomes owned by `grokops`; the services run as root
  and still read it.
- Before state on both (2026-11-13): directory root:root 0755, file
  root:root 0644. After that apply, only `services.yaml` / Homer
  `config.yml` were `root:dashcfg` 0664. On 2026-11-16 the other three
  Homepage YAMLs were brought to the same owner and mode, and
  `proxmox.yaml` followed later that day (Homepage plan step 2.6).
- No restart: Homepage hot-reloads these YAML files; Homer is a static
  `python3 -m http.server 8010`.
- The role accepts `dashboard_editor_config_files` (list, preferred) or
  the legacy singular `dashboard_editor_config_file`.

## Apply

```bash
cd ansible
ansible-playbook --syntax-check playbooks/dashboards.yml
ansible-playbook playbooks/dashboards.yml --check --diff
ansible-playbook playbooks/dashboards.yml
```

Set `dashboard_editor_pubkeys` per host in the gitignored `inventory/blr.yml`,
and set `dashboard_editor_config_files` to the list above (update the local
copy if it still has only `dashboard_editor_config_file: services.yaml`).
The first live apply (2026-11-13) was done through
`sudo -n pct exec <ctid>` from BRL with an equivalent script; backups and
before/after state are in `/root/forge-grokops-20261113/` on each guest.
The 2026-11-16 Homepage settings/widgets/bookmarks mode change was also
applied through `pct exec`; backups are in
`/root/forge-homepage-write-20261116/` on CT 191.

## Terraform

`ssh_public_keys` on `proxmox_lxc.ct_191` / `ct_198` is root's create-time
key list and is in `ignore_changes`. It is not used for this: changing it
would not reach `grokops`, and Telmate treats `ssh_public_keys` as
ForceNew, so dropping it from `ignore_changes` would plan a replacement.

## Verify (as grokops from CT 176)

```bash
ssh -i ~/.ssh/id_ed25519_forge -o IdentitiesOnly=yes grokops@10.10.0.91 'id; for f in services.yaml settings.yaml widgets.yaml bookmarks.yaml proxmox.yaml; do test -w /opt/homepage/config/$f && echo $f writable; done; sudo -n true'
```

Expect `dashcfg` in `id`, `writable` for all four files, and
`sudo: a password is required`.

## Rollback (per guest, as root via pct exec)

To undo only the 2026-11-16 Homepage grant (leave grokops and
`services.yaml` as they were on 2026-11-13):

```bash
chown root:root /opt/homepage/config/settings.yaml /opt/homepage/config/widgets.yaml /opt/homepage/config/bookmarks.yaml /opt/homepage/config/proxmox.yaml && chmod 644 /opt/homepage/config/settings.yaml /opt/homepage/config/widgets.yaml /opt/homepage/config/bookmarks.yaml /opt/homepage/config/proxmox.yaml
```

To unwind the whole editor grant on CT 191:

```bash
chown root:root /opt/homepage/config /opt/homepage/config/services.yaml /opt/homepage/config/settings.yaml /opt/homepage/config/widgets.yaml /opt/homepage/config/bookmarks.yaml && chmod 755 /opt/homepage/config && chmod 644 /opt/homepage/config/services.yaml /opt/homepage/config/settings.yaml /opt/homepage/config/widgets.yaml /opt/homepage/config/bookmarks.yaml && userdel -r grokops && groupdel dashcfg
```

Homer: same with `/opt/homer/assets` and `config.yml`. A script copy lives
at `/root/forge-grokops-20261113/rollback.sh <cfgfile>`.
