# Read-only policy for Prometheus scrapes of OpenBao
# GET /v1/sys/metrics?format=prometheus
# Issued once as an orphan periodic token (period 768h, no default policy,
# display-name prometheus). Token itself is not in git.
path "sys/metrics" {
  capabilities = ["read"]
}
