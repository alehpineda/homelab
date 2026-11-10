# CT 188 dispatcharr-blr-lxc. Admin Dispatcharr (IPTV). Declared 2026-11-09.
# See /workspace/forge/plans/2026-11-09-six-services.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/*.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-09 ~11:51 PM CT (t669s3555): "Yes, build
# RomM, Navidrome, Audiobookshelf, Dispatcharr, NetBox and Wazuh as planned"
# plus the three widget choices (Wazuh 4/8G/50G, new audiobooks dataset,
# Dispatcharr GPU passthrough).
#
# Install method (day-1, after create): community-scripts dispatcharr
# (install/dispatcharr-install.sh). Postgres 16 + Redis, nginx :9191.
# Expected v0.33.0. Root locked. No media mounts.
# GPU: /dev/dri/renderD128 gid=993 and /dev/dri/card0 gid=44 are added
# with pct set after create (same as live CT180). Telmate rc10 is not
# used for these device nodes. setup_hwaccel runs during install.
# Disk bumped to 16G (script floor is 8G).

# Template is the Debian 13 vztmpl already on BRL local (same as CT183/184).
# Confirm it is still on local before apply. nameserver is set after create
# to AdGuard A/B (10.10.0.53 / 10.10.0.55); Flint .1 cannot resolve GitHub
# for the community-scripts network_check (same deviation as CT184).
# timezone America/Chicago is a pct setting and is not in the Telmate
# proxmox_lxc schema. After create: pct set 188 --timezone America/Chicago,
# nameservers, then pct start 188. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_184.
resource "proxmox_lxc" "ct_188" {
  target_node     = var.pm_node
  vmid            = 188
  hostname        = "dispatcharr-blr-lxc"
  description     = "Admin Dispatcharr (IPTV). Community-script install. GPU via pct after create."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 2
  memory          = 4096
  swap            = 512
  tags            = "community-script;admin;media;dispatcharr;storage-data2"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct188_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "16G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:88"
    ip     = "10.10.0.88/24"
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
