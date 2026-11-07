# Runbook: Ollama models path (CT 175)

Guest and dataset facts for the 2026-11-05 Ollama rebuild. This note does
not approve `terraform apply`, `pct` writes, or a live Ansible run.

## Live layout

- CT 175 `ollama-blr-lxc`, `10.10.0.63/24` on vmbr0. CT 163 was destroyed.
  The Option Y last-octet rule does not apply: the rebuild kept `.63`.
- mp0: host `/media/ollama-models` → guest `/mnt/ollama-models`, `backup=0`.
- ZFS dataset `media/ollama-models` on the PVE host. Measured 2026-11-05:
  used about 203G, refquota 400G. Not a Terraform resource. Do not add a
  ZFS resource for it unless a later plan introduces that pattern.
- `OLLAMA_MODELS` belongs in a systemd drop-in on the guest, not in
  Terraform. The unit is the official installer unit for Ollama 0.40.15
  (upgraded from community-script 0.35.1 on 2026-11-06). The previous
  install is kept on the guest at `/root/ollama-backup-0.35.1-20261106`.
  This role does not edit that unit and does not install Ollama.
- GPU inference uses Vulkan on the Intel Arc Pro B60 (`dev0`
  `/dev/dri/renderD128`, `dev1` `/dev/dri/card0`). `features`
  `nesting=1,keyctl=1` and those DRI devices stay on the node.
  Telmate 3.0.2-rc10 does not round-trip them safely. See
  [terraform-import.md](terraform-import.md).

`vzdump` job `forge-backup-ssd` already includes 175 and excludes 163.
No job change is part of this note.

## Ansible

From `ansible/`, with a gitignored inventory copied from the example.
The example lists `ollama-blr-lxc` at `10.10.0.63` port 22. Do not commit
the copy, SSH keys, or vault passwords.

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/ollama.yml
```

Syntax check does not connect. A live run writes
`/etc/systemd/system/ollama.service.d/models.conf` with
`Environment=OLLAMA_MODELS=/mnt/ollama-models`, sets root:root mode `0755`
on that guest path (not recursive), and restarts `ollama` only when the
drop-in file changes. It fails if `/mnt/ollama-models` is not already a
mountpoint, so a missing mp0 cannot create a directory on the 24G rootfs.

```bash
ansible-playbook playbooks/ollama.yml
```

Run that only after a separate plan names CT 175 and is approved.
`playbooks/site.yml` does not import this playbook. Before the first live
run, confirm inside the guest:

```bash
findmnt --mountpoint /mnt/ollama-models
```

Override `ollama_models_owner` or `ollama_models_dir` only with `-e` or
in the gitignored inventory. The default owner is root. `ollama_version`
in the role defaults records `0.40.15` and is not applied by the play.

## Terraform

State migration is `terraform state rm proxmox_lxc.ct_163` then
`terraform import proxmox_lxc.ct_175 barbatoslupusrex/lxc/175`.
Details and the 0-diff plan expectation are in
[terraform-import.md](terraform-import.md). Apply is a separate gated
step: [lxc-change.md](lxc-change.md).
