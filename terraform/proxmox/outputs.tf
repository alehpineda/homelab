output "target_node" {
  description = "Proxmox node that hosts the imported CTs."
  value       = var.pm_node
}

output "guest_note" {
  description = "Operator reminder. This output does not read live Proxmox state."
  value       = "CTIDs 150,151,153,154,155,156,160-162,164-169,171-176,180,181,182,183,250 are declared (ct_*.tf, prevent_destroy). No apply without a separate approved plan. 151, 169, and 171-174 were imported 2026-11-03. CT 250 is already imported. 155 and 156 are pending import. CT 175 replaces destroyed CT 163 and is pending state rm of proxmox_lxc.ct_163 plus import. CT 176 (forge-ws-blr-lxc) create-time fields are ignored; do not apply. CT 182 (arr-blr-lxc) is live. CT 183 (seerr-blr-lxc) is live on BRL (created 2026-11-09). Seerr v3.5.1 is installed via the community-scripts seerr installer (native systemd seerr.service, port 5055, listens on 10.10.0.83). Root is locked. Family ingress is planned via Caddy .251 (family/guest ingress, planned). There is no CT 163 or CT 170."
}
