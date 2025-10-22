#!/bin/sh
# Gluetun entrypoint wrapper
# Creates auth config file before starting Gluetun

set -e

# Create auth config directory if it doesn't exist
mkdir -p /gluetun/auth

# Create auth config file directly (hardcoded content)
echo "Creating auth config for healthcheck..."
cat > /gluetun/auth/config.toml << 'EOF'
# Gluetun Control Server Authentication Configuration
# Whitelists /v1/publicip/ip for Docker healthcheck

[[roles]]
name = "healthcheck"
routes = ["GET /v1/publicip/ip"]
auth = "none"
EOF

echo "Auth config created successfully"

# Execute the original Gluetun entrypoint
exec /gluetun-entrypoint "$@"
