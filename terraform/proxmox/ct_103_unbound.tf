# CT 103 unbound-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_103 barbatoslupusrex/lxc/103
resource "proxmox_lxc" "ct_103" {
  target_node  = var.pm_node
  vmid         = 103
  hostname     = "unbound-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 512
  swap         = 512
  tags         = "community-script;dns;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "2G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:45:48:AA"
    ip     = "dhcp"
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
