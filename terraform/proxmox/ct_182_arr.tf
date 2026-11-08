# CT 182 arr-blr-lxc. Phase 1 of the bael *arr move. Declared 2026-11-08.
# The guest is not on the node yet. This file does not apply it.
# See docs/runbooks/arr-phase1.md. Do not merge from this declaration.
#
# Template is the same vztmpl CT 176 used at create. Confirm it is still
# on local before apply. nameserver is omitted: DNS via Flint option 6,
# like ct_176. timezone America/Chicago is a pct setting and is not in
# the Telmate schema. No IPv6 on this NIC.
#
# features nesting and keyctl are real proxmox_lxc arguments in Telmate
# 3.0.2-rc10 (resource_lxc.go). They are create-time here because
# features is in ignore_changes, same as ct_176: the provider does not
# round-trip the block cleanly after import. Create still sends them.
#
# Telmate 3.0.2-rc10 has no argument for raw lxc.* lines. resource_lxc.go
# exposes features, mountpoint, network, and rootfs. It does not expose
# idmap or a cgroup device list. Do not invent those attributes. Apply
# the lines below on the host after create and before the first start.
# SetLxcConfig is a partial update and does not delete keys it never
# sends, so a later plan does not strip them.
#
# Idmap, both uid and gid. CT 1000 is host 1100, one id. The surrounding
# ranges stay in the default unprivileged band:
#   lxc.idmap: u 0 100000 1000
#   lxc.idmap: g 0 100000 1000
#   lxc.idmap: u 1000 1100 1
#   lxc.idmap: g 1000 1100 1
#   lxc.idmap: u 1001 101001 64535
#   lxc.idmap: g 1001 101001 64535
# Host prerequisite, not a Terraform resource: a dedicated user and group
# named media, uid 1100 and gid 1100. Recheck passwd and group first.
# host uid 1000 is grokaudit and host uid 1001 is grokops. Preserve the
# existing root subordinate ranges and add only this one-id exception to
# both /etc/subuid and /etc/subgid:
#   root:1100:1
#
# Tun passthrough for gluetun, same schema gap:
#   lxc.cgroup2.devices.allow: c 10:200 rwm
#   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
#
# mp0 binds host /media/data at /data (libraries at
# /data/media/{movies,tv,music}). mp1 binds
# /media/data/torrents/bael-downloads at /data/downloads so qBittorrent
# keeps that in-container path. Both backup=0. The downloads directory
# is the only path phase 1 chowns (host uid:gid 1100). Do not chown the
# libraries or restart CT 180 or CT 181.
resource "proxmox_lxc" "ct_182" {
  target_node  = var.pm_node
  vmid         = 182
  hostname     = "arr-blr-lxc"
  description  = "Phase 1 arr VPN. gluetun and qBittorrent. Media mounts backup=0."
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 4
  memory       = 6144
  swap         = 512
  tags         = "arr;media;storage-data2;vpn"
  # Create-time only. Ignored after create. Public keys only.
  ostemplate      = "local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
  ssh_public_keys = var.ct182_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
    keyctl  = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "16G"
  }

  # Host /media/data, including /media/data/media/{movies,tv,music}.
  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data"
    mp     = "/data"
    backup = false
  }

  # Compatibility alias. qBittorrent keeps /data/downloads.
  mountpoint {
    key    = "1"
    slot   = 1
    volume = "/media/data/torrents/bael-downloads"
    mp     = "/data/downloads"
    backup = false
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:82"
    ip     = "10.10.0.82/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start/features: create-time only.
    # features is ignored so a later read does not drop nesting or keyctl.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. See docs/runbooks/terraform-import.md.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
