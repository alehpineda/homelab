# Credentials stay in the environment so they are not written to tfvars or
# this file. Telmate reads these when the matching argument is omitted:
#
#   PM_API_URL            e.g. https://10.10.0.21:8006/api2/json
#                         or https://100.85.104.18:8006/api2/json
#   PM_API_TOKEN_ID       user@realm!token-name  (quote it in the shell; it contains !)
#   PM_API_TOKEN_SECRET   shown once when the token is created
#
# Prefer a least-privilege token. Use a read-only token for plan/import when
# the provider's permission check allows it. pm_tls_insecure has no
# environment variable in Telmate 3.0.2-rc10; set it with pm_tls_insecure
# (default false) if the node certificate is not trusted by this client.
#
# The read-only grokaudit@pve!forge token (PVEAuditor) fails Telmate's
# up-front permission check, which asks for write privileges. import and plan
# only read, so set TF_VAR_pm_minimum_permission_check=false for that token.
provider "proxmox" {
  pm_tls_insecure             = var.pm_tls_insecure
  pm_minimum_permission_check = var.pm_minimum_permission_check
}
