output "target_node" {
  description = "Proxmox node that hosts the imported CTs."
  value       = var.pm_node
}

output "guest_note" {
  description = "Operator reminder. This output does not read live Proxmox state."
  value       = "CTIDs 150,151,153,154,155,156,160-169,171-174,176,180,181,250 are declared (ct_*.tf, prevent_destroy). No apply without a separate approved plan. 151, 169, and 171-174 were imported 2026-11-03. CT 250 is already imported. 155 and 156 are pending import. CT 176 (forge-ws-blr-lxc) create-time fields are ignored; do not apply."
}
