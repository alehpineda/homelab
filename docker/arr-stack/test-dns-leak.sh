#!/bin/bash

# DNS Leak Test Script
# Tests if DNS queries are leaking outside the VPN tunnel

echo "========================================="
echo "  🔍 DNS LEAK TEST"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "1. Checking DNS servers in use..."
echo "   Gluetun DNS:"
docker exec gluetun cat /etc/resolv.conf | grep nameserver
echo ""
echo "   qBittorrent DNS:"
docker exec qbittorrent cat /etc/resolv.conf | grep nameserver
echo ""

echo "2. Testing DNS resolution through Gluetun..."
echo "   Performing DNS lookup for whoami.akamai.net..."
GLUETUN_DNS_IP=$(docker exec gluetun nslookup whoami.akamai.net 2>/dev/null | grep -A1 "Name:" | grep "Address:" | head -1 | awk '{print $2}')
echo "   Result: $GLUETUN_DNS_IP"
echo ""

echo "3. Checking if DNS is going through VPN..."
# Get DNS leak test
echo "   Fetching DNS leak test from dnsleaktest.com..."
DNS_LEAK=$(docker exec gluetun wget -qO- https://bash.ws/dnsleak 2>/dev/null | head -20)

if echo "$DNS_LEAK" | grep -qi "dns"; then
    echo -e "${GREEN}✓ DNS leak test completed${NC}"
    echo "$DNS_LEAK"
else
    echo -e "${YELLOW}⚠ Could not fetch DNS leak test${NC}"
fi
echo ""

echo "4. Checking Gluetun's DNS over TLS (DoT) status..."
DOT_STATUS=$(docker logs gluetun 2>&1 | grep -i "DNS over TLS" | tail -1)
if echo "$DOT_STATUS" | grep -qi "enabled\|on"; then
    echo -e "${GREEN}✓ DNS over TLS is enabled${NC}"
else
    echo -e "${YELLOW}⚠ DNS over TLS might not be enabled${NC}"
fi
echo "   $DOT_STATUS"
echo ""

echo "5. Verifying DNS provider..."
DNS_PROVIDER=$(docker logs gluetun 2>&1 | grep -i "DNS over TLS provider\|using.*DNS" | tail -1)
echo "   $DNS_PROVIDER"
echo ""

echo "6. Quick DNS leak check (IP-based)..."
YOUR_IP=$(curl -s https://api.ipify.org)
VPN_IP=$(docker exec gluetun wget -qO- https://api.ipify.org 2>/dev/null)

echo "   Your real IP:  $YOUR_IP"
echo "   VPN IP:        $VPN_IP"

if [ "$YOUR_IP" != "$VPN_IP" ]; then
    echo -e "${GREEN}✓ IP is properly masked by VPN${NC}"
else
    echo -e "${RED}✗ WARNING: IP might be leaking!${NC}"
fi
echo ""

echo "========================================="
echo "  RECOMMENDATIONS"
echo "========================================="
echo ""
echo "For maximum DNS leak protection:"
echo "1. Enable DNS over TLS (DoT) in .env:"
echo "   DOT=on"
echo "   DOT_PROVIDERS=cloudflare"
echo ""
echo "2. Available DoT providers:"
echo "   - cloudflare (1.1.1.1)"
echo "   - google (8.8.8.8)"
echo "   - quad9 (9.9.9.9)"
echo ""
echo "3. Test online at:"
echo "   - https://dnsleaktest.com"
echo "   - https://ipleak.net"
echo ""
