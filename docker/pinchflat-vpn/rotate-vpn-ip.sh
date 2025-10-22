#!/bin/bash
# VPN IP Rotation Script for Pinchflat
# Purpose: Restart Gluetun to get new VPN IP and avoid rate limiting
# Usage: Add to cron for hourly execution

set -euo pipefail

# Configuration
COMPOSE_DIR="${COMPOSE_DIR:-/opt/docker/pinchflat-vpn}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
LOG_FILE="${LOG_FILE:-/var/log/pinchflat-vpn-rotation.log}"

# Container and service names (from docker-compose.yml)
GLUETUN_CONTAINER="gluetun-pinchflat"
PINCHFLAT_CONTAINER="pinchflat"
GLUETUN_SERVICE="gluetun"
PINCHFLAT_SERVICE="pinchflat"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Change to compose directory
cd "$COMPOSE_DIR" || {
    log "ERROR: Cannot find directory $COMPOSE_DIR"
    exit 1
}

# Validate compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    log "ERROR: Compose file not found: $COMPOSE_DIR/$COMPOSE_FILE"
    exit 1
fi

log "Starting VPN IP rotation..."

# Get current IP
CURRENT_IP=$(docker exec "$GLUETUN_CONTAINER" wget -qO- https://api.ipify.org 2>/dev/null || echo "unknown")
log "Current VPN IP: $CURRENT_IP"

# Restart gluetun to get new IP
log "Restarting gluetun service..."
docker compose -f "$COMPOSE_FILE" restart "$GLUETUN_SERVICE"

# Wait for VPN to reconnect (30 seconds)
log "Waiting 30 seconds for VPN to reconnect..."
sleep 30

# Verify new IP
NEW_IP=$(docker exec "$GLUETUN_CONTAINER" wget -qO- https://api.ipify.org 2>/dev/null || echo "unknown")
log "New VPN IP: $NEW_IP"

# Check if pinchflat is still running (it should auto-restart due to depends_on)
PINCHFLAT_STATUS=$(docker inspect -f '{{.State.Running}}' "$PINCHFLAT_CONTAINER" 2>/dev/null || echo "false")

if [ "$PINCHFLAT_STATUS" != "true" ]; then
    log "WARNING: Pinchflat not running, restarting..."
    docker compose -f "$COMPOSE_FILE" restart "$PINCHFLAT_SERVICE"
    sleep 5
fi

# Verify everything is healthy
log "Checking container health..."
docker compose -f "$COMPOSE_FILE" ps

log "VPN rotation complete. IP changed from $CURRENT_IP to $NEW_IP"
