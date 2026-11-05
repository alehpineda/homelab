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

# Console root password for a future proxmox_lxc create. Telmate's `password`
# argument is the Proxmox API `password` field (root inside the guest at
# create). It is not an SSH daemon setting. Leave this null for plan and
# import. Supply a real value only with TF_VAR_lxc_root_password from a
# secret store, and only for a resource that sets `password` on create.
# No default secret. Do not put the value in terraform.tfvars or git.
variable "lxc_root_password" {
  description = "Sensitive create-time console root password for a future proxmox_lxc. Sets the root password only and does not configure automatic console login. Null leaves every declared guest unchanged. Set TF_VAR_lxc_root_password from a secret store. Never commit the value."
  type        = string
  sensitive   = true
  default     = null

  validation {
    # The conditional operator evaluates only the chosen branch, so trimspace
    # is not called when the variable is null.
    condition     = var.lxc_root_password == null ? true : length(trimspace(var.lxc_root_password)) > 0
    error_message = "lxc_root_password must be null or a non-empty value supplied outside git."
  }
}
