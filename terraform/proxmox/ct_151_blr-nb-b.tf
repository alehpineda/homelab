# CT 151 blr-nb-lxc-b (NetBird peer B). Declared from live config, pending import.
# See docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_151 barbatoslupusrex/lxc/151
# nesting, keyctl, and /dev/net/tun are pct features. Telmate rc10 does not
# model them. ignore_changes matches ct_150.
resource "proxmox_lxc" "ct_151" {
  target_node  = var.pm_node
  vmid         = 151
  hostname     = "blr-nb-lxc-b"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 512
  swap         = 512
  tags         = "community-script;network;storage-data2;vpn"

  rootfs {
    storage = var.pm_storage
    size    = "4G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr1"
    hwaddr = "BC:24:11:0F:E8:D0"
    ip     = "10.10.0.51/24"
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
