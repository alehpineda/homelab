variable "pm_node" {
  description = "Proxmox node that hosts BRL guests."
  type        = string
  default     = "barbatoslupusrex"
}

variable "pm_bridge" {
  description = "Linux bridge for a future LXC NIC. Not applied while no guest resources are enabled."
  type        = string
  default     = "vmbr0"
}

variable "pm_storage" {
  description = "Storage for a future LXC root disk. BRL container disks are on data2."
  type        = string
  default     = "data2"
}

variable "pm_ostemplate" {
  description = "Volume id of a vztmpl. Placeholder until a later plan names a real template on the node."
  type        = string
  default     = "local:vztmpl/REPLACE-with-real-vztmpl.tar.zst"
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification of the Proxmox API. Leave false unless the node certificate is a known self-signed cert on a trusted path."
  type        = bool
  default     = false
}

variable "pm_minimum_permission_check" {
  description = "Run Telmate's up-front permission check. Set false only with the read-only token for import/plan."
  type        = bool
  default     = true
}
