# CT 169 postiz-blr-lxc. Declared from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_169 barbatoslupusrex/lxc/169
# Community-script Postiz. features.nesting is omitted: firecrawl and jellyfin
# (the closest community-script siblings) do not set it. Swap is 512, matching
# every other ct_*.tf.
resource "proxmox_lxc" "ct_169" {
  target_node  = var.pm_node
  vmid         = 169
  hostname     = "postiz-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 4
  memory       = 8192
  swap         = 512
  nameserver   = "10.10.0.53"
  tags         = "postiz"

  rootfs {
    storage = var.pm_storage
    size    = "20G"
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    hwaddr   = "BC:24:11:6C:EA:5B"
    ip       = "10.10.0.69/24"
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
