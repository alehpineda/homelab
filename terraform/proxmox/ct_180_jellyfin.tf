# CT 180 jellyfin-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_180 barbatoslupusrex/lxc/180
resource "proxmox_lxc" "ct_180" {
  target_node  = var.pm_node
  vmid         = 180
  hostname     = "jellyfin-blr-lxc"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 8
  memory       = 8192
  swap         = 512
  tags         = "community-script;media;storage-data2"
  # Static LXCs do not get Flint DHCP option 6. Live 2026-11-10: pct set --nameserver "10.10.0.53 10.10.0.55".
  nameserver   = "10.10.0.53 10.10.0.55"

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

  mountpoint {
    key    = "3"
    slot   = 3
    volume = "/media/data/media/anime-tv"
    mp     = "/media/anime-tv"
    # ro=1, backup=0 in pct config. Telmate rc10 mountpoint has no read-only attribute.
    backup = false
  }

  mountpoint {
    key    = "4"
    slot   = 4
    volume = "/media/data/media/anime-movies"
    mp     = "/media/anime-movies"
    # ro=1, backup=0 in pct config. Telmate rc10 mountpoint has no read-only attribute.
    backup = false
  }

  network {
    name   = "eth0"
    bridge = "vmbr1"
    hwaddr = "BC:24:11:CC:9B:32"
    ip     = "10.10.0.80/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start: create-time only.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. They match pct config; see docs/runbooks/terraform-import.md.
    # net0 firewall=1 and the PVE guest firewall (.fw rules/options) are owned by
    # ansible role pve_guest_firewall (group_vars/all/fw_allowlists.yml), live
    # 2026-11-09. `network` stays in ignore_changes so Terraform never flaps the flag.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
