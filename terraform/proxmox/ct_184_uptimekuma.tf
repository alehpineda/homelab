# CT 184 uptimekuma-blr-lxc. Owner-only Uptime Kuma. Declared 2026-11-09.
# See /workspace/forge/plans/2026-11-09-uptime-kuma.md (Forge).
# Standing pref: LXC via IaC. Community-script install inside this guest
# (not the host ct/uptimekuma.sh curl|bash, which would create a second CT).
# Authority: DeathScythe 2026-11-09 ~11:20 PM CT (t663s3536): "Yes, build
# Uptime Kuma on CT184 as planned: uptime.alehpineda.com, 2c/2G/8G,
# notifications later".
#
# Install method (day-1, after create): Proxmox community-scripts
# uptimekuma (ct/uptimekuma.sh → install/uptimekuma-install.sh), run
# inside the IaC-created CT. Debian 13 unprivileged, Node 22 + npm,
# tarball from louislam/uptime-kuma, systemd uptime-kuma.service on
# port 3001. Pin Uptime Kuma 2.5.9 (latest stable as of 2026-11-09;
# GitHub tag 2.5.9). Not Docker. Updates via the script's `update`
# helper; backup /opt/uptime-kuma/data first (v2 has no JSON restore).
# Root is locked (lxc_root_password left null; install wrapper uses a
# PASSWORD sentinel so customize() does not unlock root).
#
# Sizing is the approved bump over the script floor (1/1024/4G): 2
# cores / 2048 MiB / 8G root, for Node 22 + Chromium monitors and
# SQLite history. nesting=1 for community-scripts / systemd / Chromium.
# No keyctl. No tun. No extra mounts.
#
# Template is the Debian 13 vztmpl already on BRL local (same as CT183).
# Confirm it is still on local before apply. nameserver omitted: DNS via
# Flint option 6, like ct_176 / ct_183. timezone America/Chicago is a
# pct setting and is not in the Telmate proxmox_lxc schema. After
# create: pct set 184 --timezone America/Chicago, then pct start 184.
# No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_183: the provider does not round-trip the
# block cleanly after import. Create still sends it.
resource "proxmox_lxc" "ct_184" {
  target_node  = var.pm_node
  vmid         = 184
  hostname     = "uptimekuma-blr-lxc"
  description  = "Owner Uptime Kuma. Community-script install. Admin vhost uptime.alehpineda.com."
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 2
  memory       = 2048
  swap         = 512
  tags         = "community-script;monitoring;kuma;storage-data2"
  # Create-time only. Ignored after create. Public keys only.
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct184_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:84"
    ip     = "10.10.0.84/24"
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
