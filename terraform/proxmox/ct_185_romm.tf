# CT 185 romm-blr-lxc. Family RomM. Declared 2026-11-09.
# See /workspace/forge/plans/2026-11-09-six-services.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/*.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-09 ~11:51 PM CT (t669s3555): "Yes, build
# RomM, Navidrome, Audiobookshelf, Dispatcharr, NetBox and Wazuh as planned"
# plus the three widget choices (Wazuh 4/8G/50G, new audiobooks dataset,
# Dispatcharr GPU passthrough).
#
# Install method (day-1, after create): Proxmox community-scripts romm
# (install/romm-install.sh) inside the IaC-created CT. Debian 13
# unprivileged, MariaDB + Redis + Angie :80, Node 24 + Python 3.13.
# Pin expected RomM 5.4.1 (latest stable as of 2026-11-09). Root locked.
# Mount: host /media/data/arcade/collections -> /mnt/arcade-collections
# (ro=1 after create). Do not mount over /var/lib/romm/library until
# after install (the installer mkdirs that path). After install, symlink
# /var/lib/romm/library -> /mnt/arcade-collections. No arcade chown, no
# scan in this raise.
# Sizing raised 2026-11-10: 8 cores / 32768 MiB / 8192 MiB swap / 20G root.
# Was the community-script floor (2 cores / 4096 MiB / 512 MiB swap). A
# library scan filled swap on the old size; owner approved the bump.

# Template is the Debian 13 vztmpl already on BRL local (same as CT183/184).
# Confirm it is still on local before apply. nameserver is set after create
# to AdGuard A/B (10.10.0.53 / 10.10.0.55); Flint .1 cannot resolve GitHub
# for the community-scripts network_check (same deviation as CT184).
# timezone America/Chicago is a pct setting and is not in the Telmate
# proxmox_lxc schema. After create: pct set 185 --timezone America/Chicago,
# nameservers, then pct start 185. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_184.
resource "proxmox_lxc" "ct_185" {
  target_node     = var.pm_node
  vmid            = 185
  hostname        = "romm-blr-lxc"
  description     = "Family RomM. Community-script install. Arcade collections ro bind."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 8
  memory          = 32768
  swap            = 8192
  tags            = "community-script;family;media;romm;storage-data2"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct185_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "20G"
  }

  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/data/arcade/collections"
    mp     = "/mnt/arcade-collections"
    backup = false
    # ro=1 is set with pct after create. Telmate rc10 mountpoint has no
    # read-only attribute.
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:85"
    ip     = "10.10.0.85/24"
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
