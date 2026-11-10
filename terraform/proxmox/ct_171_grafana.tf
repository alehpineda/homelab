# CT 171 grafana-blr-lxc. Declared from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_171 barbatoslupusrex/lxc/171
# Community-script Grafana. No Docker, so features.nesting is omitted (same as
# firecrawl and jellyfin). Published only via Caddy; see docs/blr-monitoring.md.
resource "proxmox_lxc" "ct_171" {
  target_node  = var.pm_node
  vmid         = 171
  hostname     = "grafana-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 1024
  swap         = 512
  tags = "community-script;monitoring;visualization"
  # Static LXCs do not get Flint DHCP option 6. Live 2026-11-10: pct set --nameserver "10.10.0.53 10.10.0.55".
  nameserver   = "10.10.0.53 10.10.0.55"

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    hwaddr   = "BC:24:11:D5:94:F1"
    ip       = "10.10.0.71/24"
    gw       = "10.10.0.1"
    firewall = false
  }

  lifecycle {
    prevent_destroy = true
    # ostemplate/password/ssh_public_keys/start: create-time only.
    # target_node, cmode, network, mountpoint, rootfs[0].storage: Telmate
    # 3.0.2-rc10 import does not read these back, so they would force
    # replacement. They match pct config; see docs/runbooks/terraform-import.md.
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
