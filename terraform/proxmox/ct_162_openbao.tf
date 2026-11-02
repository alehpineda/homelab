# CT 162 openbao. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_162 barbatoslupusrex/lxc/162
resource "proxmox_lxc" "ct_162" {
  target_node  = var.pm_node
  vmid         = 162
  hostname     = "openbao"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 1024
  swap         = 512
  tags         = "community-script;secrets;security;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "4G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:5C:F6:8B"
    ip     = "10.10.0.62/24"
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
