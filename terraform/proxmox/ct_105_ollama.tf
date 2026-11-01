# CT 105 ollama-blr-lxc. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_105 barbatoslupusrex/lxc/105
resource "proxmox_lxc" "ct_105" {
  target_node  = var.pm_node
  vmid         = 105
  hostname     = "ollama-blr-lxc"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 8
  memory       = 4096
  swap         = 512
  tags         = "ai;community-script;storage-data2"

  rootfs {
    storage = var.pm_storage
    size    = "280G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:DB:3D:D7"
    ip     = "dhcp"
    ip6    = "auto"
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
