# CT 160 searxng-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_160 barbatoslupusrex/lxc/160
resource "proxmox_lxc" "ct_160" {
  target_node  = var.pm_node
  vmid         = 160
  hostname     = "searxng-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 2
  memory       = 2048
  swap         = 512
  tags         = "community-script;search;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "7G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:97:92:7D"
    ip     = "10.10.0.60/24"
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
