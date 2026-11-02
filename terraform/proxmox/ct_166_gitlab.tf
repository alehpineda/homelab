# CT 166 gitlab. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_166 barbatoslupusrex/lxc/166
resource "proxmox_lxc" "ct_166" {
  target_node  = var.pm_node
  vmid         = 166
  hostname     = "gitlab"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = false
  cores        = 4
  memory       = 16384
  swap         = 512
  tags         = "community-script;devtools;git"

  rootfs {
    storage = var.pm_storage
    size    = "40G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:4A:4B:A9"
    ip     = "10.10.0.66/24"
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
