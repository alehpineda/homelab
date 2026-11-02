# CT 161 vaultwarden-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_161 barbatoslupusrex/lxc/161
resource "proxmox_lxc" "ct_161" {
  target_node  = var.pm_node
  vmid         = 161
  hostname     = "vaultwarden-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 4
  memory       = 6144
  swap         = 512
  tags         = "community-script;password-manager;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "20G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:35:AB:A4"
    ip     = "10.10.0.61/24"
    gw     = "10.10.0.1"
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
