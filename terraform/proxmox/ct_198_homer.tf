# CT 198 homer-blr-lxc. Admin Homer. Declared 2026-11-10.
# See /workspace/forge/plans/2026-11-10-ten-services.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/*.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-10 1:44 AM CT (t695s3713): "Yes, open the
# IaC PR and build in waves, including the CT182 grow, mount, and short
# pause"; "Linkwarden on family .251"; "Keep MyIP on .250". 1:45 AM CT
# (t696u): "Yes, I want both change detection and price buddy".
#
# Install method (day-1, after create): community-scripts homer (install/homer-install.sh). Static homer.zip served
# by python3 -m http.server 8010. YAML /opt/homer/assets/config.yml.
# Ingress: Caddy 10.10.0.250 (admin) -> http://10.10.0.98:8010.

# Template is the Debian 13 vztmpl already on BRL local. nameserver is set
# after create to AdGuard A/B (10.10.0.53 / 10.10.0.55); Flint .1 cannot
# resolve GitHub for the community-scripts network_check (same deviation
# as CT184-190). timezone America/Chicago is a pct setting and is not in the
# Telmate proxmox_lxc schema. After create: pct set 198 --timezone
# America/Chicago, nameservers, then pct start 198. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183 / ct_184.
resource "proxmox_lxc" "ct_198" {
  target_node     = var.pm_node
  vmid            = 198
  hostname        = "homer-blr-lxc"
  description     = "Admin Homer dashboard. TRIAL; two of Homepage/Homarr/Homer will be torn down after the pick. Community-script install."
  arch            = "amd64"
  ostype          = "debian"
  unprivileged    = true
  onboot          = true
  cores           = 1
  memory          = 512
  swap            = 512
  tags            = "admin;community-script;homer;storage-data2;trial"
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct198_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "2G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:98"
    ip     = "10.10.0.98/24"
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
