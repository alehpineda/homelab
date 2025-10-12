#!/bin/bash

# Gluetun VPN Reconnection Script
# Restarts Gluetun container to force a new VPN connection
# Usage: Add to crontab to run every 2 hours

CONTAINER_NAME="gluetun"
LOG_FILE="$HOME/gluetun-reconnect.log"

# Timestamp
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting VPN reconnection..." | tee -a "$LOG_FILE"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $CONTAINER_NAME is not running!" | tee -a "$LOG_FILE"
    exit 1
fi

# Get current IP before restart
OLD_IP=$(docker exec "$CONTAINER_NAME" wget -qO- https://api.ipify.org 2>/dev/null)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Current VPN IP: $OLD_IP" | tee -a "$LOG_FILE"

# Restart Gluetun container
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting $CONTAINER_NAME..." | tee -a "$LOG_FILE"
docker restart "$CONTAINER_NAME"

# Wait for VPN to reconnect
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for VPN to reconnect..." | tee -a "$LOG_FILE"
sleep 15

# Get new IP
NEW_IP=$(docker exec "$CONTAINER_NAME" wget -qO- https://api.ipify.org 2>/dev/null)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] New VPN IP: $NEW_IP" | tee -a "$LOG_FILE"

# Verify IP changed
if [ "$OLD_IP" != "$NEW_IP" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ VPN reconnection successful! IP changed." | tee -a "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ Warning: IP did not change (may be same server)" | tee -a "$LOG_FILE"
fi

# Check qBittorrent is still accessible
if docker ps | grep -q "qbittorrent"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ qBittorrent is running" | tee -a "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ ERROR: qBittorrent is not running!" | tee -a "$LOG_FILE"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reconnection complete." | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"
