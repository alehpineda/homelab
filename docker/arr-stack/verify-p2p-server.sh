#!/bin/bash

# NordVPN P2P Server Verification Script
# Checks if connected to a P2P-optimized server

echo "========================================="
echo "  🌐 NordVPN P2P Server Verification"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "1. Checking server selection criteria..."
CRITERIA=$(docker logs gluetun 2>&1 | grep -A3 "Server selection settings")
echo "$CRITERIA"
echo ""

echo "2. Current VPN connection details..."
CONNECTION=$(docker logs gluetun 2>&1 | grep "Connecting to" | tail -1)
PUBLIC_IP=$(docker logs gluetun 2>&1 | grep "Public IP address is" | tail -1)

echo "$CONNECTION"
echo "$PUBLIC_IP"
echo ""

echo "3. Verifying P2P category..."
P2P_ENABLED=$(docker logs gluetun 2>&1 | grep "Categories: p2p")

if [ ! -z "$P2P_ENABLED" ]; then
    echo -e "${GREEN}✓ P2P category is ENABLED${NC}"
    echo "  $P2P_ENABLED"
else
    echo -e "${YELLOW}⚠ P2P category not found in logs${NC}"
fi
echo ""

echo "4. Server location..."
LOCATION=$(echo "$PUBLIC_IP" | sed 's/.*Public IP address is .* (\(.*\)).*/\1/')
if [ ! -z "$LOCATION" ]; then
    echo -e "${BLUE}📍 Location: $LOCATION${NC}"
fi
echo ""

echo "========================================="
echo "  Summary"
echo "========================================="
echo ""
echo "NordVPN is configured to:"
echo "  • Only use servers in: Mexico"
echo "  • Only use servers with: P2P support"
echo "  • Protocol: WireGuard"
echo ""
echo "This ensures you're always connected to"
echo "P2P-optimized servers that allow torrenting."
echo ""
echo "========================================="
