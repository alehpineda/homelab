# CT 112 metube. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_112 barbatoslupusrex/lxc/112
resource "proxmox_lxc" "ct_112" {
  target_node  = var.pm_node
  vmid         = 112
  hostname     = "metube"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 2048
  swap         = 512
  tags         = "community-script;media;storage-data2;youtube"

  rootfs {
    storage = var.pm_storage
    size    = "10G"
  }

  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data/media/metube"
    mp     = "/opt/metube_downloads"
    backup = false
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:D8:06:85"
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
