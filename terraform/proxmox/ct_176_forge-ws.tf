# CT 176 forge-ws-blr-lxc (Forge workstation). Declared 2026-11-05.
# The guest does not exist. This file does not approve terraform apply
# or pct create. Create, then import, is a separate gated step.
# Template at create: ubuntu-26.04-standard_26.04-1_amd64 on local.
# ostemplate stays unset; it is create-time only, same as every sibling.
# nameserver omitted: DNS via Flint option 6, like ct_155.
# timezone America/Chicago is a pct setting. Omitted like ct_155.
# features nesting=1,keyctl=1 are set at pct create. Omitted like ct_155.
# Telmate reads features only when the block is set, so ignore_changes
# stays identical to ct_155.
# hwaddr omitted: every sibling MAC was copied from a live guest, and no
# undeclared-then-created CT invents one. Proxmox assigns BC:24:11:xx:xx:xx
# at create; record it on import. network stays in ignore_changes.
# Root disk is var.pm_storage (data2) at 40G.
resource "proxmox_lxc" "ct_176" {
  target_node  = var.pm_node
  vmid         = 176
  hostname     = "forge-ws-blr-lxc"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 4
  memory       = 8192
  swap         = 2048
  tags         = "forge;workstation;desktop"

  rootfs {
    storage = var.pm_storage
    size    = "40G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "10.10.0.76/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start: create-time only.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. They match pct config; see docs/runbooks/terraform-import.md.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
