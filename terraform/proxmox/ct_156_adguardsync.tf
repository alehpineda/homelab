# CT 156 adguardsync-blr-lxc (Sync). Declared from live config, pending import.
# See docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_156 barbatoslupusrex/lxc/156
# features and timezone are omitted like ct_153. Telmate reads features only
# when the block is set, so ignore_changes stays identical to ct_153.
resource "proxmox_lxc" "ct_156" {
  target_node  = var.pm_node
  vmid         = 156
  hostname     = "adguardsync-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 256
  swap         = 512
  tags         = "community-script;os"
  # Static LXCs do not get Flint DHCP option 6. Live 2026-11-10: pct set --nameserver "10.10.0.53 10.10.0.55".
  nameserver   = "10.10.0.53 10.10.0.55"

  rootfs {
    storage = var.pm_storage
    size    = "2G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:27:FD:2D"
    ip     = "10.10.0.56/24"
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
