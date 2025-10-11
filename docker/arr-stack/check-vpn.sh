#!/bin/bash

# Simple VPN Verification Script
# Usage: ./check-vpn.sh

echo "========================================="
echo "  🔒 VPN CONNECTION STATUS"
echo "========================================="
echo ""

# Get IPs
REAL_IP=$(curl -s https://api.ipify.org)
VPN_IP=$(docker exec gluetun wget -qO- https://api.ipify.org 2>/dev/null)
QB_IP=$(docker exec qbittorrent wget -qO- https://api.ipify.org 2>/dev/null)

# Display results
echo "📍 Your Real IP:      $REAL_IP"
echo "🔐 Gluetun VPN IP:    $VPN_IP"
echo "📥 qBittorrent IP:    $QB_IP"
echo ""

# Verification
if [ "$REAL_IP" != "$VPN_IP" ] && [ "$VPN_IP" = "$QB_IP" ]; then
    echo "✅ VPN is working correctly!"
    echo "✅ qBittorrent is protected by VPN"
    
    # Get location from Gluetun logs
    LOCATION=$(docker logs gluetun 2>&1 | grep "Public IP address is" | tail -1 | sed 's/.*Public IP address is .* (\(.*\) - source:.*/\1/')
    if [ ! -z "$LOCATION" ]; then
        echo "📡 VPN Location: $LOCATION"
    fi
else
    echo "❌ WARNING: VPN may not be working correctly!"
    [ "$REAL_IP" = "$VPN_IP" ] && echo "   - VPN IP matches your real IP"
    [ "$VPN_IP" != "$QB_IP" ] && echo "   - qBittorrent IP doesn't match VPN IP"
fi
echo ""
echo "========================================="
