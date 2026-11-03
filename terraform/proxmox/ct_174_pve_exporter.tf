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
  # nameserver omitted: the live CT has an empty nameserver and uses host DNS.
  tags         = "community-script;monitoring"

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
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description,
      target_node, cmode, network, mountpoint, rootfs[0].storage,
    ]
  }
}
