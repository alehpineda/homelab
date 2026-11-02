# CT 250 caddy. Imported from live config, see docs/runbooks/terraform-import.md.
# Import: terraform import proxmox_lxc.ct_250 barbatoslupusrex/lxc/250
# Ports 80/443 are restricted to 10.10.0.0/24 and 100.85.0.0/16 by nftables
# inside the CT (/etc/nftables.conf), not by Terraform.
resource "proxmox_lxc" "ct_250" {
  target_node  = var.pm_node
  vmid         = 250
  hostname     = "caddy-blr-lxc"
  arch         = "amd64"
  ostype       = "debian"
  unprivileged = true
  onboot       = true
  cores        = 1
  memory       = 512
  swap         = 512
  nameserver   = "10.10.0.53"
  tags         = "caddy;proxy"

  features {
    nesting = true
  }

  rootfs {
    storage = var.pm_storage
    size    = "8G"
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    hwaddr   = "BC:24:11:88:F5:07"
    ip       = "10.10.0.250/24"
    gw       = "10.10.0.1"
    firewall = false
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ostemplate, password, ssh_public_keys, start, description,
      target_node, cmode, network, mountpoint, rootfs[0].storage, features,
    ]
  }
}
