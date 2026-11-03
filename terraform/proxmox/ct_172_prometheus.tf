# CT 172 prometheus-blr-lxc. Declared from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_172 barbatoslupusrex/lxc/172
# Community-script Prometheus. LAN-only (:9090). features.nesting omitted
# (no Docker; matches firecrawl and jellyfin). See docs/blr-monitoring.md.
resource "proxmox_lxc" "ct_172" {
  target_node  = var.pm_node
  vmid         = 172
  hostname     = "prometheus-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 2
  memory       = 2048
  swap         = 512
  nameserver   = "10.10.0.53"
  tags         = "prometheus;monitoring"

  rootfs {
    storage = var.pm_storage
    size    = "20G"
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    hwaddr   = "BC:24:11:D1:07:80"
    ip       = "10.10.0.72/24"
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
