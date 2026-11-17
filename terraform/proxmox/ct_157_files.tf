# CT 157 files-blr-lxc. Copyparty pilot: LAN-only web file manager for the
# ZFS media datasets at https://files.alehpineda.com (Caddy .250 only).
# Declared 2026-11-17. Plan: Forge plans/2026-11-17-copyparty-pilot.md.
# Authority: DeathScythe 2026-11-17 4:33 PM CT, Forge 1:1, card t973s5107:
# "Yes, build the copyparty pilot on CT157 with full rights including delete"
# and t974u "Add the arcade mount." (arcade: see below, not mounted yet).
#
# Shape copied from ct_187 (unprivileged, Debian 13 vztmpl, per-mount idmap).
# No NetBird client, no GPU. Only copyparty runs here.
#
# Mounts are existing host datasets only (no new paths on BRL); all
# backup=false (vzdump covers rootfs only). The six 1100:1100 datasets are rw
# with a per-mount idmap mapping container media 1000:1000 -> host 1100:1100:
#   idmap=u:1000:1100:1;g:1000:1100:1
# metube (host 100107:100110) is ro=1 with no idmap.
# Telmate 3.0.2-rc10 mountpoint has no read-only or idmap attribute, so both
# are applied with `pct set 157 --mpN ...` after create while the CT is
# stopped, and recorded here as comments (same as ct_187).
#
# arcade (/media/data/arcade, dataset media/data/arcade) is NOT mounted: it is
# owned by host root 0:0 (not 1100), and RomM CT185 binds only
# arcade/collections ro=1. A 1000->1100 idmap cannot write a root-owned tree,
# and mapping a CT uid onto host uid 0 is not acceptable. Pending the owner's
# choice (chown to 1100 vs. ro bind); mp7 is reserved for it.
#
# After create: pct set 157 --timezone America/Chicago,
# --nameserver "10.10.0.53 10.10.0.55", the mp idmaps/ro. PVE guest firewall
# (fw_allowlists 157: tcp/3923 from 10.10.0.250 only) before first start.
resource "proxmox_lxc" "ct_157" {
  target_node     = var.pm_node
  vmid            = 157
  hostname        = "files-blr-lxc"
  description     = "Copyparty pilot (files.alehpineda.com, LAN only via Caddy .250). Media rw binds with mp idmap 1000->1100."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 1
  memory          = 1024
  swap            = 512
  tags            = "files;media;storage-data2"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct157_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  # mp0-mp5: rw + idmap=u:1000:1100:1;g:1000:1100:1 (pct set after create)
  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data/media/movies"
    mp     = "/media/movies"
    backup = false
  }
  mountpoint {
    key    = "1"
    slot   = 1
    volume = "/media/data/media/tv"
    mp     = "/media/tv"
    backup = false
  }
  mountpoint {
    key    = "2"
    slot   = 2
    volume = "/media/data/media/anime-tv"
    mp     = "/media/anime-tv"
    backup = false
  }
  mountpoint {
    key    = "3"
    slot   = 3
    volume = "/media/data/media/anime-movies"
    mp     = "/media/anime-movies"
    backup = false
  }
  mountpoint {
    key    = "4"
    slot   = 4
    volume = "/media/data/media/music"
    mp     = "/media/music"
    backup = false
  }
  mountpoint {
    key    = "5"
    slot   = 5
    volume = "/media/data/media/audiobooks"
    mp     = "/media/audiobooks"
    backup = false
  }
  # mp6: ro=1, no idmap (pct set after create)
  mountpoint {
    key    = "6"
    slot   = 6
    volume = "/media/data/media/metube"
    mp     = "/media/metube"
    backup = false
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:57"
    ip     = "10.10.0.57/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # Same ignore list as ct_187 (see that file and
    # docs/runbooks/terraform-import.md). mountpoint is ignored so the
    # pct-applied idmap/ro never flap.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
