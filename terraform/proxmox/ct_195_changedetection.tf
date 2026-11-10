# CT 195 changedetection-blr-lxc. Admin Change Detection. Declared 2026-11-10.
# See /workspace/forge/plans/2026-11-10-ten-services.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/*.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-10 1:44 AM CT (t695s3713): "Yes, open the
# IaC PR and build in waves, including the CT182 grow, mount, and short
# pause"; "Linkwarden on family .251"; "Keep MyIP on .250". 1:45 AM CT
# (t696u): "Yes, I want both change detection and price buddy".
#
# Install method (day-1, after create): community-scripts changedetection (install/changedetection-install.sh).
# Python 3.13/uv + Node 24 Browserless (Chrome/Firefox/WebKit/Edge).
# Disk bumped to 16G (script floor is 10G). Browserless :3000 stays fw-closed.
# Ingress: Caddy 10.10.0.250 (admin) -> http://10.10.0.95:5000.

# Template is the Debian 13 vztmpl already on BRL local. nameserver is set
# after create to AdGuard A/B (10.10.0.53 / 10.10.0.55); Flint .1 cannot
# resolve GitHub for the community-scripts network_check (same deviation
# as CT184-190). timezone America/Chicago is a pct setting and is not in the
# Telmate proxmox_lxc schema. After create: pct set 195 --timezone
# America/Chicago, nameservers, then pct start 195. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_184.
resource "proxmox_lxc" "ct_195" {
  target_node     = var.pm_node
  vmid            = 195
  hostname        = "changedetection-blr-lxc"
  description     = "Admin Change Detection (changedetection.io + Browserless). Community-script install. :5000."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 4
  memory          = 4096
  swap            = 512
  tags            = "admin;changedetection;community-script;storage-data2"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct195_ssh_public_keys
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
    hwaddr = "02:46:4F:52:01:95"
    ip     = "10.10.0.95/24"
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
