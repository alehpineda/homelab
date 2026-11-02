# CT 168 ubuntu. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_168 barbatoslupusrex/lxc/168
resource "proxmox_lxc" "ct_168" {
  target_node  = var.pm_node
  vmid         = 168
  hostname     = "ubuntu"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = false
  cores        = 4
  memory       = 32768
  swap         = 512
  tags         = "community-script;os"

  rootfs {
    storage = var.pm_storage
    size    = "128G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:95:E5:6E"
    ip     = "10.10.0.68/24"
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
