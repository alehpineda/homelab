# CT 187 audiobookshelf-blr-lxc. Family Audiobookshelf. Declared 2026-11-09.
# See /workspace/forge/plans/2026-11-09-six-services.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/*.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-09 ~11:51 PM CT (t669s3555): "Yes, build
# RomM, Navidrome, Audiobookshelf, Dispatcharr, NetBox and Wazuh as planned"
# plus the three widget choices (Wazuh 4/8G/50G, new audiobooks dataset,
# Dispatcharr GPU passthrough).
#
# Install method (day-1, after create): community-scripts audiobookshelf
# (install/audiobookshelf-install.sh). Official apt repo + ffmpeg,
# systemd audiobookshelf :13378. Expected v2.37.2.
# Mount: new ZFS dataset media/data/media/audiobooks (1100:1100) ->
# /audiobooks, ro=1 after create. Dataset must exist before apply of
# this mount. Disk bumped to 8G (script floor is 5G).

# Template is the Debian 13 vztmpl already on BRL local (same as CT183/184).
# Confirm it is still on local before apply. nameserver is set after create
# to AdGuard A/B (10.10.0.53 / 10.10.0.55); Flint .1 cannot resolve GitHub
# for the community-scripts network_check (same deviation as CT184).
# timezone America/Chicago is a pct setting and is not in the Telmate
# proxmox_lxc schema. After create: pct set 187 --timezone America/Chicago,
# nameservers, then pct start 187. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_184.
resource "proxmox_lxc" "ct_187" {
  target_node     = var.pm_node
  vmid            = 187
  hostname        = "audiobookshelf-blr-lxc"
  description     = "Family Audiobookshelf. Community-script install. Audiobooks ro bind."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 2
  memory          = 2048
  swap            = 512
  tags            = "community-script;family;media;audiobookshelf;storage-data2"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct187_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data/media/audiobooks"
    mp     = "/audiobooks"
    backup = false
    # ro=1 is set with pct after create. Telmate rc10 mountpoint has no
    # read-only attribute.
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:87"
    ip     = "10.10.0.87/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start/features: create-time only.
    # features is ignored so a later read does not drop nesting.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. See docs/runbooks/terraform-import.md.
    # net0 firewall=1 and the PVE guest firewall (.fw rules/options) are owned by
    # ansible role pve_guest_firewall (group_vars/all/fw_allowlists.yml).
    # `network` stays in ignore_changes so Terraform never flaps the flag.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
