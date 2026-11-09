# CT 155 adguard-blr-lxc-b (AG-B). Declared from live config, pending import.
# See docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_155 barbatoslupusrex/lxc/155
# nameserver omitted: the live CT has an empty nameserver and uses host DNS.
# timezone America/Chicago and features nesting=1,keyctl=1 are live. Omitted
# like ct_153. Telmate reads features only when the block is set, so
# ignore_changes stays identical to ct_153.
resource "proxmox_lxc" "ct_155" {
  target_node  = var.pm_node
  vmid         = 155
  hostname     = "adguard-blr-lxc-b"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 512
  swap         = 512
  tags         = "adblock;community-script"

  rootfs {
    # Moved data2 -> local-lvm (nvme0) 2026-11-09, BRL storage plan B.
    storage = "local-lvm"
    size    = "2G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr1"
    hwaddr = "BC:24:11:9D:BE:3C"
    ip     = "10.10.0.55/24"
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
