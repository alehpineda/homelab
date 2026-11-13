# CT 182 arr-blr-lxc. Phase 1 of the bael *arr move. Declared 2026-11-08.
# The guest is not on the node yet. This file does not apply it.
# See docs/runbooks/arr-phase1.md. Do not merge from this declaration.
#
# Template is the same vztmpl CT 176 used at create. Confirm it is still
# on local before apply. Static LXCs do not get Flint DHCP option 6;
# nameserver must be set. Flint .1 timed out to ghcr.io / engine hosts
# on 2026-11-10. Live: pct set 182 --nameserver "10.10.0.53 10.10.0.55"
# (needs a CT reboot to rewrite resolv.conf).
# timezone America/Chicago is a pct setting and is not in
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
# All mounts backup=false. Do not create host directories.
# The phase-1 directories are root:root 0755. Mapped uid 1100 cannot
# write. Changing ownership needs an explicit yes.
# mp0–mp2 are the phase-1 binds. mp2 is the usenet parent and stays
# before every usenet child.
#   mp0  /media/data/media    -> /data/media
#   mp1  /media/data/torrents -> /data/downloads
#   mp2  /media/data/usenet   -> /data/usenet
# qBittorrent uses /data/downloads.
#
# mp3–mp20 match live pct config 182. mp5, mp7, mp8, mp9, and mp10 are
# ro=1 on the node. Telmate 3.0.2-rc10 mountpoint has no read-only
# attribute, same as ct_180, so that flag stays a comment.
# lifecycle.ignore_changes includes mountpoint, so a plan hides added,
# removed, or drifted mounts and will not apply a mount change onto a
# guest that already exists.
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
  nameserver   = "10.10.0.53 10.10.0.55"
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
    size    = "24G" # grown 16G -> 24G 2026-11-10 for Listenarr (pct resize)
  }

  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data/media"
    mp     = "/data/media"
    backup = false
  }

  mountpoint {
    key    = "1"
    slot   = 1
    volume = "/media/data/torrents"
    mp     = "/data/downloads"
    backup = false
  }

  mountpoint {
    key    = "2"
    slot   = 2
    volume = "/media/data/usenet"
    mp     = "/data/usenet"
    backup = false
  }

  mountpoint {
    key    = "3"
    slot   = 3
    volume = "/media/data/media/movies"
    mp     = "/data/media/movies"
    backup = false
  }

  mountpoint {
    key    = "4"
    slot   = 4
    volume = "/media/data/media/tv"
    mp     = "/data/media/tv"
    backup = false
  }

  # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  mountpoint {
    key    = "5"
    slot   = 5
    volume = "/media/data/media/metube"
    mp     = "/data/media/metube"
    backup = false
  }

  mountpoint {
    key    = "6"
    slot   = 6
    volume = "/media/data/media/music"
    mp     = "/data/media/music"
    backup = false
  }

  # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  mountpoint {
    key    = "7"
    slot   = 7
    volume = "/media/data/media/books"
    mp     = "/data/media/books"
    backup = false
  }

  # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  mountpoint {
    key    = "8"
    slot   = 8
    volume = "/media/data/media/documents"
    mp     = "/data/media/documents"
    backup = false
  }

  # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  mountpoint {
    key    = "9"
    slot   = 9
    volume = "/media/data/media/photos"
    mp     = "/data/media/photos"
    backup = false
  }

  # ro=1 in pct config. Telmate rc10 mountpoint has no read-only attribute.
  mountpoint {
    key    = "10"
    slot   = 10
    volume = "/media/data/media/backups"
    mp     = "/data/media/backups"
    backup = false
  }

  mountpoint {
    key    = "11"
    slot   = 11
    volume = "/media/data/torrents/books"
    mp     = "/data/downloads/books"
    backup = false
  }

  mountpoint {
    key    = "12"
    slot   = 12
    volume = "/media/data/torrents/movies"
    mp     = "/data/downloads/movies"
    backup = false
  }

  mountpoint {
    key    = "13"
    slot   = 13
    volume = "/media/data/torrents/music"
    mp     = "/data/downloads/music"
    backup = false
  }

  mountpoint {
    key    = "14"
    slot   = 14
    volume = "/media/data/torrents/tv"
    mp     = "/data/downloads/tv"
    backup = false
  }

  # Usenet children stay after mp2, the usenet parent.
  mountpoint {
    key    = "15"
    slot   = 15
    volume = "/media/data/usenet/complete"
    mp     = "/data/usenet/complete"
    backup = false
  }

  mountpoint {
    key    = "16"
    slot   = 16
    volume = "/media/data/usenet/incomplete"
    mp     = "/data/usenet/incomplete"
    backup = false
  }

  mountpoint {
    key    = "17"
    slot   = 17
    volume = "/media/data/usenet/complete/books"
    mp     = "/data/usenet/complete/books"
    backup = false
  }

  mountpoint {
    key    = "18"
    slot   = 18
    volume = "/media/data/usenet/complete/movies"
    mp     = "/data/usenet/complete/movies"
    backup = false
  }

  mountpoint {
    key    = "19"
    slot   = 19
    volume = "/media/data/usenet/complete/music"
    mp     = "/data/usenet/complete/music"
    backup = false
  }

  mountpoint {
    key    = "20"
    slot   = 20
    volume = "/media/data/usenet/complete/tv"
    mp     = "/data/usenet/complete/tv"
    backup = false
  }

  # Listenarr (2026-11-10): leaf bind of the audiobooks ZFS dataset. The
  # parent mp0 bind does not propagate nested datasets. Added on the node
  # with `pct set 182 --mp21 ...` (bind mounts need root@pam, not the token).
  mountpoint {
    key    = "21"
    slot   = 21
    volume = "/media/data/media/audiobooks"
    mp     = "/data/media/audiobooks"
    backup = false
  }

  # Anime TV and Anime Movies: leaf binds. The parent mp0 bind does not
  # propagate nested datasets. rw, backup=0, same shape as mp3, mp4, mp6,
  # and mp21.
  mountpoint {
    key    = "22"
    slot   = 22
    volume = "/media/data/media/anime-tv"
    mp     = "/data/media/anime-tv"
    backup = false
  }

  mountpoint {
    key    = "23"
    slot   = 23
    volume = "/media/data/media/anime-movies"
    mp     = "/data/media/anime-movies"
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
    # ignore_changes on mountpoint hides drift: mp3–mp23 added on the
    # node, a changed mp, or a missing ro=1 do not appear in the plan.
    # net0 firewall=1 and the PVE guest firewall (.fw rules/options) are owned by
    # ansible role pve_guest_firewall (group_vars/all/fw_allowlists.yml), live
    # 2026-11-09. `network` stays in ignore_changes so Terraform never flaps the flag.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
