#!/bin/bash

# Kill Switch Test Script
# Verifies that qBittorrent cannot access the internet without VPN

echo "========================================="
echo "  🛡️  KILL SWITCH TEST"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}This test will verify that qBittorrent ONLY works when VPN is connected.${NC}"
echo ""

# Check initial status
echo "Step 1: Checking initial VPN status..."
VPN_IP_BEFORE=$(docker exec gluetun wget -qO- https://api.ipify.org 2>/dev/null)
QB_IP_BEFORE=$(docker exec qbittorrent wget -qO- https://api.ipify.org 2>/dev/null)

if [ ! -z "$VPN_IP_BEFORE" ]; then
    echo -e "   ${GREEN}✓ VPN is connected${NC}"
    echo "   VPN IP: $VPN_IP_BEFORE"
    echo "   qBittorrent IP: $QB_IP_BEFORE"
else
    echo -e "   ${RED}✗ VPN is not connected${NC}"
    exit 1
fi
echo ""

# Test kill switch
echo "Step 2: Testing kill switch by stopping Gluetun..."
echo -e "   ${YELLOW}⚠ Stopping Gluetun container...${NC}"
docker stop gluetun > /dev/null 2>&1
sleep 3

echo ""
echo "Step 3: Attempting to access internet from qBittorrent (should FAIL)..."
QB_TEST=$(timeout 10 docker exec qbittorrent wget -qO- https://api.ipify.org 2>&1)

if [ -z "$QB_TEST" ] || echo "$QB_TEST" | grep -qi "timeout\|failed\|error\|unable"; then
    echo -e "   ${GREEN}✓✓✓ KILL SWITCH IS WORKING! ✓✓✓${NC}"
    echo -e "   ${GREEN}qBittorrent CANNOT access internet without VPN${NC}"
    KILLSWITCH_OK=true
else
    echo -e "   ${RED}✗✗✗ KILL SWITCH FAILED! ✗✗✗${NC}"
    echo -e "   ${RED}qBittorrent can still access internet: $QB_TEST${NC}"
    KILLSWITCH_OK=false
fi
echo ""

# Restore VPN
echo "Step 4: Restarting Gluetun..."
docker start gluetun > /dev/null 2>&1
echo "   Waiting for VPN to reconnect (15 seconds)..."
sleep 15

echo ""
echo "Step 5: Verifying VPN and qBittorrent are working again..."
VPN_IP_AFTER=$(docker exec gluetun wget -qO- https://api.ipify.org 2>/dev/null)
QB_IP_AFTER=$(docker exec qbittorrent wget -qO- https://api.ipify.org 2>/dev/null)

if [ ! -z "$VPN_IP_AFTER" ] && [ ! -z "$QB_IP_AFTER" ]; then
    echo -e "   ${GREEN}✓ VPN reconnected successfully${NC}"
    echo "   VPN IP: $VPN_IP_AFTER"
    echo "   qBittorrent IP: $QB_IP_AFTER"
else
    echo -e "   ${YELLOW}⚠ VPN might still be reconnecting. Wait a moment and check with ./check-vpn.sh${NC}"
fi
echo ""

echo "========================================="
echo "  TEST SUMMARY"
echo "========================================="
echo ""

if [ "$KILLSWITCH_OK" = true ]; then
    echo -e "${GREEN}✅ KILL SWITCH: WORKING${NC}"
    echo ""
    echo "Your setup is secure! qBittorrent can ONLY access"
    echo "the internet through the VPN tunnel."
    echo ""
    echo "How it works:"
    echo "  • qBittorrent uses network_mode: 'service:gluetun'"
    echo "  • This means it shares Gluetun's network stack"
    echo "  • If Gluetun stops or VPN drops = No internet for qBittorrent"
    echo "  • This is a HARDWARE kill switch (not software-based)"
else
    echo -e "${RED}❌ KILL SWITCH: NOT WORKING${NC}"
    echo ""
    echo "WARNING: qBittorrent can access internet without VPN!"
    echo "Check your docker-compose.yml configuration."
fi
echo ""
echo "========================================="
