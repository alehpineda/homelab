# CTIDs 150, 151, 153, 154, 155, 156, 160–169, 171–174, 176, 180, 181, 250 on
# barbatoslupusrex are declared in ct_<id>_<name>.tf
# (docs/runbooks/terraform-import.md). Each has prevent_destroy. For guests
# already imported, terraform plan must show 0 to add/change/destroy.
# 151, 169, and 171–174 were imported 2026-11-03. CT 250 is already imported.
# 155 and 156 are pending import. CT 176 is declared and not created; a plan
# that adds it is not approval to apply. There is no CT 170.
# Do not terraform apply until a separate plan names the change and is
# approved. See docs/runbooks/lxc-change.md.
#
# Preferences for a future container: unprivileged, one service per CT,
# explicit vmid outside the in-use CTIDs, start = false until checks pass.
# Telmate crashes if rootfs is omitted, so the example includes it.
# A future create that should have a console root password sets
# `password = var.lxc_root_password` and keeps `password` in ignore_changes.
# That sets a password a prompt can accept. It does not enable automatic
# root login. CT 175 still prompts after a working root password. Autologin
# waits for a verified cmode/getty comparison and explicit approval.
# Existing ct_*.tf resources do not set password. CT 176 stays that way
# (deathscythe login). Open PR 19 owns the CT 175 declaration; do not add it here.

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
#
#   # Create-time console root password. Uncomment only on a new guest whose
#   # approved plan names this create. Export TF_VAR_lxc_root_password first.
#   # password = var.lxc_root_password
#
#   # lifecycle {
#   #   prevent_destroy = true
#   #   # password is ForceNew in Telmate 3.0.2-rc10. ignore_changes keeps a
#   #   # later value from replacing the guest. The provider drops password
#   #   # on update, and Read does not return it.
#   #   ignore_changes = [
#   #     ostemplate, password, ssh_public_keys, start, description,
#   #     target_node, cmode, network, mountpoint, rootfs[0].storage,
#   #   ]
#   # }
# }
