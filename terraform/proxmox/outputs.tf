output "target_node" {
  description = "Proxmox node that hosts the imported CTs."
  value       = var.pm_node
}

output "guest_note" {
  description = "Operator reminder. This output does not read live Proxmox state."
  value       = "CTIDs 100-113 are imported (ct_*.tf, prevent_destroy). No apply without a separate approved plan."
}
