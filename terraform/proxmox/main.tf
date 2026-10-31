# This root module manages no Proxmox guests.
#
# CTIDs 100-113 already exist on barbatoslupusrex. Do not uncomment the
# example, and do not terraform apply a create or destroy, until a separate
# plan names the guest and is approved. See docs/runbooks/lxc-change.md.
#
# Preferences for a future container: unprivileged, one service per CT,
# explicit vmid outside 100-113, start = false until checks pass.
# Telmate crashes if rootfs is omitted, so the example includes it.

# resource "proxmox_lxc" "example_service" {
#   target_node  = var.pm_node
#   hostname     = "example-service"
#   description  = "One service per CT. Not enabled in the skeleton."
#   ostemplate   = var.pm_ostemplate
#   unprivileged = true
#   onboot       = false
#   start        = false
#   # Set an explicit VMID outside 100-113. Do not leave vmid at 0 (next free)
#   # on this node until the free ID is checked against the live list.
#   vmid = 200
#
#   cores  = 1
#   memory = 512
#   swap   = 512
#
#   features {
#     nesting = true
#   }
#
#   rootfs {
#     storage = var.pm_storage
#     size    = "8G"
#   }
#
#   network {
#     name   = "eth0"
#     bridge = var.pm_bridge
#     ip     = "dhcp"
#   }
# }
