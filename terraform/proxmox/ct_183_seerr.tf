# CT 183 seerr-blr-lxc. Family media requests (Seerr). Declared 2026-11-09.
# The guest is not on the node yet. This file does not apply it.
# See /workspace/forge/plans/2026-11-09-seerr-ct183-family.md (Forge).
# Standing pref: LXC via IaC. Do not merge from this declaration alone —
# merge and create each need their own DeathScythe yes.
#
# Install method (day-1, after create): Proxmox community-scripts seerr
# (ct/seerr.sh → install/seerr-install.sh). Debian 13 unprivileged, pnpm
# build from source, systemd seerr.service on port 5055. Pin Seerr
# v3.5.1 at first install. Updates via the script's update function.
# Not Docker, not compose, not Watchtower.
#
# Sizing matches the community-script defaults (build needs ~3 GB Node
# heap): 4 cores / 4096 MiB / 12G root. nesting=1 for community-scripts
# / systemd. No keyctl. No tun. No media mounts (API-only).
#
# Template is the Debian 13 vztmpl already on BRL local (same as the
# CT177 ingress test). Confirm it is still on local before apply.
# nameserver omitted: DNS via Flint option 6, like ct_176 / ct_182.
# timezone America/Chicago is a pct setting and is not in the Telmate
# schema. No IPv6 on this NIC.
#
# features.nesting is create-time here because features is in
# ignore_changes, same as ct_176 / ct_182: the provider does not
# round-trip the block cleanly after import. Create still sends it.
resource "proxmox_lxc" "ct_183" {
  target_node  = var.pm_node
  vmid         = 183
  hostname     = "seerr-blr-lxc"
  description  = "Family Seerr. Community-script install. No media mounts."
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 4
  memory       = 4096
  swap         = 512
  tags         = "community-script;family;media;seerr;storage-data2"
  # Create-time only. Ignored after create. Public keys only.
  ostemplate      = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ssh_public_keys = var.ct183_ssh_public_keys
  password        = var.lxc_root_password
  start           = false

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "12G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "02:46:4F:52:01:83"
    ip     = "10.10.0.83/24"
    gw     = "10.10.0.1"
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start/features: create-time only.
    # features is ignored so a later read does not drop nesting.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. See docs/runbooks/terraform-import.md.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description, features,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
