# CT 190 wazuh-blr-lxc. Admin Wazuh all-in-one. Declared 2026-11-09.
# See /workspace/forge/plans/2026-11-09-six-services.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/*.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-09 ~11:51 PM CT (t669s3555): "Yes, build
# RomM, Navidrome, Audiobookshelf, Dispatcharr, NetBox and Wazuh as planned"
# plus the three widget choices (Wazuh 4/8G/50G, new audiobooks dataset,
# Dispatcharr GPU passthrough).
#
# Install method (day-1, after create): community-scripts wazuh
# (install/wazuh-install.sh) with var_external_installer=yes so the
# official packages.wazuh.com installer is accepted unattended, inside
# the IaC-created CT only. All-in-one (-a): indexer + manager + dashboard
# on :443. Expected Wazuh v4.14.10. Creds in ~/wazuh.creds -> box secret.
# Sizing is the official AIO recommendation for 1-25 agents (approved):
# 4 cores / 8192 MiB / 50G, not the script floor of 4G/35G.
# Do not open 1514/1515/55000 in this raise.

# Template is the Debian 13 vztmpl already on BRL local (same as CT183/184).
# Confirm it is still on local before apply. nameserver is set after create
# to AdGuard A/B (10.10.0.53 / 10.10.0.55); Flint .1 cannot resolve GitHub
# for the community-scripts network_check (same deviation as CT184).
# timezone America/Chicago is a pct setting and is not in the Telmate
# proxmox_lxc schema. After create: pct set 190 --timezone America/Chicago,
# nameservers, then pct start 190. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_184.
resource "proxmox_lxc" "ct_190" {
  target_node     = var.pm_node
  vmid            = 190
  hostname        = "wazuh-blr-lxc"
  description     = "Admin Wazuh AIO. Official installer via pinned in-guest wrapper. Dashboard :443."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 4
  memory          = 8192
  swap            = 512
  tags            = "community-script;admin;security;wazuh;storage-data2"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct190_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "50G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:90"
    ip     = "10.10.0.90/24"
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
