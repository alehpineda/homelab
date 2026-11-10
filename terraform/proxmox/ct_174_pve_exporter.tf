# CT 174 pve-exporter-blr-lxc. Declared from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_174 barbatoslupusrex/lxc/174
# Community-script prometheus-pve-exporter. LAN-only (:9221). features.nesting
# omitted (no Docker; matches firecrawl and jellyfin). See docs/blr-monitoring.md.
resource "proxmox_lxc" "ct_174" {
  target_node  = var.pm_node
  vmid         = 174
  hostname     = "pve-exporter-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 512
  swap         = 512
  tags = "community-script;monitoring"
  # Static LXCs do not get Flint DHCP option 6. Live 2026-11-10: pct set --nameserver "10.10.0.53 10.10.0.55".
  nameserver   = "10.10.0.53 10.10.0.55"

  rootfs {
    storage = var.pm_storage
    size    = "4G"
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    hwaddr   = "BC:24:11:35:0E:FB"
    ip       = "10.10.0.74/24"
    gw       = "10.10.0.1"
    firewall = false
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start: create-time only.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. They match pct config; see docs/runbooks/terraform-import.md.
    # net0 firewall=1 and the PVE guest firewall (.fw rules/options) are owned by
    # ansible role pve_guest_firewall (group_vars/all/fw_allowlists.yml), live
    # 2026-11-09. `network` stays in ignore_changes so Terraform never flaps the flag.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
