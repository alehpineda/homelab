#!/bin/bash
# VPN IP Rotation Script for Pinchflat
# Purpose: Restart Gluetun to get new VPN IP and avoid rate limiting
# Usage: Add to cron for hourly execution

set -euo pipefail

# Configuration
COMPOSE_DIR="${COMPOSE_DIR:-/opt/docker/pinchflat-vpn}"
LOG_FILE="${LOG_FILE:-/var/log/pinchflat-vpn-rotation.log}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Change to compose directory
cd "$COMPOSE_DIR" || {
    log "ERROR: Cannot find directory $COMPOSE_DIR"
    exit 1
}

log "Starting VPN IP rotation..."

# Get current IP
CURRENT_IP=$(docker exec gluetun-pinchflat wget -qO- https://api.ipify.org 2>/dev/null || echo "unknown")
log "Current VPN IP: $CURRENT_IP"

# Restart gluetun to get new IP
log "Restarting gluetun container..."
docker compose restart gluetun

# Wait for VPN to reconnect (30 seconds)
log "Waiting 30 seconds for VPN to reconnect..."
sleep 30

# Verify new IP
NEW_IP=$(docker exec gluetun-pinchflat wget -qO- https://api.ipify.org 2>/dev/null || echo "unknown")
log "New VPN IP: $NEW_IP"

# Check if pinchflat is still running (it should auto-restart due to depends_on)
PINCHFLAT_STATUS=$(docker inspect -f '{{.State.Running}}' pinchflat 2>/dev/null || echo "false")

if [ "$PINCHFLAT_STATUS" != "true" ]; then
    log "WARNING: Pinchflat not running, restarting..."
    docker compose restart pinchflat
    sleep 5
fi

# Verify everything is healthy
log "Checking container health..."
docker compose ps

log "VPN rotation complete. IP changed from $CURRENT_IP to $NEW_IP"
