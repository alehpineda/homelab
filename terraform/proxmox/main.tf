# CTIDs 150, 151, 153, 154, 160–169, 171–174, 180, 181, 250 on barbatoslupusrex are
# declared in ct_<id>_<name>.tf (docs/runbooks/terraform-import.md). Each has
# prevent_destroy. terraform plan must show 0 to add/change/destroy.
# 169 and 171–174 were imported 2026-11-03. CT 250 is already imported.
# CT 151 is pending import. There is no CT 170.
# Do not terraform apply until a separate plan names the change and is
# approved. See docs/runbooks/lxc-change.md.
#
# Preferences for a future container: unprivileged, one service per CT,
# explicit vmid outside the in-use CTIDs, start = false until checks pass.
# Telmate crashes if rootfs is omitted, so the example includes it.

# resource "proxmox_lxc" "example_service" {
#   target_node  = var.pm_node
#   hostname     = "example-service"
#   description  = "One service per CT. Not enabled in the skeleton."
#   ostemplate   = var.pm_ostemplate
#   unprivileged = true
#   onboot       = false
#   start        = false
#   # Set an explicit VMID outside the in-use CTIDs. Do not leave vmid at 0 (next free)
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
