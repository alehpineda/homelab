# Read-only policy for Prometheus scrapes of OpenBao
# GET /v1/sys/metrics?format=prometheus
# Periodic orphan token (period 768h, no default policy, display-name prometheus).
# renew-self / lookup-self let CT172's monthly timer keep the token from expiring.
# Token itself is not in git.
path "sys/metrics" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
