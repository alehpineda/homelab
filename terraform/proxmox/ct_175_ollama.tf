# CT 175 ollama-blr-lxc. Replaces destroyed CT 163. Declared from live
# config 2026-11-05, pending import. See docs/runbooks/terraform-import.md.
# State still holding the old guest:
#   terraform state rm proxmox_lxc.ct_163
# Import:
#   terraform import proxmox_lxc.ct_175 barbatoslupusrex/lxc/175
# Do not apply. CT 163 is gone on the node.
#
# timezone America/Chicago and features nesting=1,keyctl=1 are live. Omitted
# like ct_155. Telmate 3.0.2-rc10 reads features into state only when the
# block is already set, so leaving it unset keeps a post-import plan at
# 0-diff and leaves ignore_changes identical to the other ct_*.tf files.
#
# dev0 /dev/dri/renderD128,gid=993 and dev1 /dev/dri/card0,gid=44 are the
# Intel Arc Pro B60. Inference uses Vulkan. Telmate 3.0.2-rc10 has no devN
# attribute. They stay on the node. Do not model them as mountpoints.
#
# Ollama 0.40.15 is the official installer (2026-11-06), not the
# community-script 0.35.1 unit. Live tags dropped community-script.
#
# mp0 binds host /media/ollama-models (ZFS dataset media/ollama-models,
# refquota 400G) at /mnt/ollama-models, backup=0. The dataset is not a
# Terraform resource. The mountpoint block is declared and ignored, same
# as ct_180 and ct_181.
resource "proxmox_lxc" "ct_175" {
  target_node  = var.pm_node
  vmid         = 175
  hostname     = "ollama-blr-lxc"
  arch         = "amd64"
  ostype       = "ubuntu"
  unprivileged = true
  onboot       = true
  cores        = 8
  memory       = 32768
  swap         = 4096
  tags         = "ai;storage-data2"
  # Static LXCs do not get Flint DHCP option 6. Live 2026-11-10: pct set --nameserver "10.10.0.53 10.10.0.55".
  nameserver   = "10.10.0.53 10.10.0.55"

  rootfs {
    storage = var.pm_storage
    size    = "24G"
  }

  mountpoint {
    key    = "0"
    slot   = 0
    volume = "/media/ollama-models"
    mp     = "/mnt/ollama-models"
    # backup=0 in pct config. Telmate's backup default is false; set it
    # so the file matches the live mp0 line.
    backup = false
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    hwaddr = "BC:24:11:DB:3D:D7"
    ip     = "10.10.0.63/24"
    gw     = "10.10.0.1"
    ip6    = "auto"
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
