# CT 104 jellyfin-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_104 barbatoslupusrex/lxc/104
resource "proxmox_lxc" "ct_104" {
  target_node  = var.pm_node
  vmid         = 104
  hostname     = "jellyfin-blr-lxc"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 8
  memory       = 8192
  swap         = 512
  tags         = "community-script;media;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "32G"
  }

  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data/media/movies"
    mp     = "/media/movies"
    # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  }

  mountpoint {
    key    = "1"
    slot   = 1
    volume = "/media/data/media/tv"
    mp     = "/media/tv"
    # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  }

  mountpoint {
    key    = "2"
    slot   = 2
    volume = "/media/data/media/metube"
    mp     = "/media/metube"
    # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
    backup = false
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:CC:9B:32"
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
