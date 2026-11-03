# CT 173 loki-blr-lxc. Declared from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_173 barbatoslupusrex/lxc/173
# Community-script Loki. LAN-only (:3100). features.nesting omitted
# (no Docker; matches firecrawl and jellyfin). See docs/blr-monitoring.md.
resource "proxmox_lxc" "ct_173" {
  target_node  = var.pm_node
  vmid         = 173
  hostname     = "loki-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 1024
  swap         = 512
  nameserver   = "10.10.0.53"
  tags         = "loki;monitoring"

  rootfs {
    storage = var.pm_storage
    size    = "20G"
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    hwaddr   = "BC:24:11:63:3D:4E"
    ip       = "10.10.0.73/24"
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
