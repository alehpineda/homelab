output "target_node" {
  description = "Proxmox node that hosts the imported CTs."
  value       = var.pm_node
}

output "guest_note" {
  description = "Operator reminder. This output does not read live Proxmox state."
  value       = "CTIDs 150,153,154,160-168,180,181,250 are declared (ct_*.tf, prevent_destroy). No apply without a separate approved plan."
}
