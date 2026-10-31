output "target_node" {
  description = "Proxmox node this skeleton targets. No guests are declared."
  value       = var.pm_node
}

output "guest_note" {
  description = "Operator reminder. This output does not read live Proxmox state."
  value       = "No proxmox_lxc resources are enabled. Existing CTIDs 100-113 are unmanaged."
}
