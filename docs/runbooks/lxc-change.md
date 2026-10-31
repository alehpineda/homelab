# Runbook: change an LXC on BRL

Use this order for any later change to a container on `barbatoslupusrex`.
The IaC skeleton pull request does **not** approve `terraform apply`,
Ansible configuration, or `pct` / `qm` writes. Rollback for that pull
request is to close it or revert it on `master`.

Do the steps below only after a separate plan names the CTID and the
change, and that plan is approved.

## 1. Backup or snapshot the target CT

On the node, before Terraform or Ansible touches the guest:

- Take a CT snapshot, or
- Run `vzdump` for that VMID to storage you can restore from.

Record the snapshot name or the vzdump archive path outside git. Do not
paste tokens or backup encryption secrets into the repo.

Confirm you are on the intended guest (VMID and hostname). Existing
CTIDs **100–113** are already in use. See [docs/blr.md](../blr.md).

## 2. Plan

From `terraform/proxmox`, with `PM_API_URL`, `PM_API_TOKEN_ID`, and
`PM_API_TOKEN_SECRET` set in the environment (not in a committed file):

```bash
terraform fmt -check
terraform init
terraform plan -out=tfplan
```

Read `tfplan` with `terraform show tfplan`. Do not commit `tfplan` (it can contain
sensitive values). For an existing guest the only acceptable first outcome is
an import or an in-place update that matches the approved change. A plan
that **creates** or **destroys** a guest stops here until a plan written
for that action is approved.

`terraform plan` does not change the guest. `terraform apply` does.

## 3. Approve

Apply only after the plan output is reviewed and the change is approved.
Approval to open the skeleton pull request is not approval to apply.

## 4. Apply

```bash
terraform apply tfplan
```

`tfplan` is the file saved from the reviewed `terraform plan -out=tfplan`.
Watch for VMID collisions with 100–113.

## 5. Verify with Ansible

Ansible in this repo is a connectivity stub. It does not configure guests.

From `ansible/`, using a **local** inventory copied from
`inventory/blr.yml.example` (do not commit it):

```bash
ansible-playbook playbooks/ping.yml --limit <hostname>
```

Hardened hosts brought up with `alehpineda/ansible-playbooks` may listen
on SSH port **4488**. Fresh LXCs often still listen on **22**. Set
`ansible_port` per host. A failed ping is a stop, not a prompt to change
SSH config from this repo.

Reach the node over NetBird `100.85.104.18` or LAN `10.10.0.21`.

## 6. Rollback

Pick the smallest action that restores the guest. In order:

1. Restore the CT snapshot taken in step 1, or restore the vzdump archive.
2. Revert the git change that described the guest and re-plan. Do not
   apply a destroy to "undo" a bad create unless that destroy was approved.
3. `terraform state rm` only when the runbook for that incident says the
   state entry is wrong and the guest itself must be left as-is. Removing
   state does not delete the container. It also does not fix a container
   Terraform already changed.

If the only change was the skeleton pull request, close it or revert the
merge commit. No guest restore is required for that git-only change.

## Stop conditions

- Plan shows destroy of any CTID in 100–113.
- Plan shows a create you did not name in the approved change.
- Backup or snapshot failed.
- API token would be written into `terraform.tfvars`, `.env`, or shell history you commit.
