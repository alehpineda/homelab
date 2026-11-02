# CT 165 honcho-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_165 barbatoslupusrex/lxc/165
resource "proxmox_lxc" "ct_165" {
  target_node  = var.pm_node
  vmid         = 165
  hostname     = "honcho-blr-lxc"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 4
  memory       = 8192
  swap         = 512
  tags         = "community-script;os;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "32G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:21:F3:9F"
    ip     = "10.10.0.65/24"
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
