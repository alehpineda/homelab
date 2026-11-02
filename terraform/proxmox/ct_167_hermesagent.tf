# CT 167 hermesagent. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_167 barbatoslupusrex/lxc/167
resource "proxmox_lxc" "ct_167" {
  target_node  = var.pm_node
  vmid         = 167
  hostname     = "hermesagent"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = false
  cores        = 4
  memory       = 8192
  swap         = 512
  tags         = "agent;ai;automation;community-script"

  rootfs {
    storage = var.pm_storage
    size    = "40G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:F0:24:12"
    ip     = "10.10.0.67/24"
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
