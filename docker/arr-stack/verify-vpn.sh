#!/bin/bash

# VPN Connection Verification Script for Gluetun + qBittorrent
# Usage: ./verify-vpn.sh

echo "========================================="
echo "  VPN Connection Verification"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if containers are running
echo "1. Checking container status..."
if ! docker ps | grep -q gluetun; then
    echo -e "${RED}✗ Gluetun container is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Gluetun is running${NC}"

if ! docker ps | grep -q qbittorrent; then
    echo -e "${RED}✗ qBittorrent container is not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ qBittorrent is running${NC}"
echo ""

# Get your real IP
echo "2. Checking your real public IP..."
REAL_IP=$(curl -s ifconfig.me)
echo -e "   Your real IP: ${YELLOW}${REAL_IP}${NC}"
echo ""

# Get Gluetun's IP
echo "3. Checking Gluetun's public IP (VPN IP)..."
VPN_IP=$(docker exec gluetun wget -qO- ifconfig.me 2>/dev/null)
if [ -z "$VPN_IP" ]; then
    echo -e "${RED}✗ Could not get VPN IP${NC}"
    exit 1
fi
echo -e "   Gluetun VPN IP: ${GREEN}${VPN_IP}${NC}"
echo ""

# Get qBittorrent's IP
echo "4. Checking qBittorrent's public IP..."
QB_IP=$(docker exec qbittorrent wget -qO- ifconfig.me 2>/dev/null)
if [ -z "$QB_IP" ]; then
    echo -e "${RED}✗ Could not get qBittorrent IP${NC}"
    exit 1
fi
echo -e "   qBittorrent IP: ${GREEN}${QB_IP}${NC}"
echo ""

# Verify IPs are different from real IP
echo "5. Verifying VPN protection..."
if [ "$REAL_IP" = "$VPN_IP" ]; then
    echo -e "${RED}✗ WARNING: VPN IP matches your real IP! VPN may not be working!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ VPN IP is different from your real IP (VPN is working)${NC}"
fi

if [ "$VPN_IP" != "$QB_IP" ]; then
    echo -e "${RED}✗ WARNING: qBittorrent IP doesn't match VPN IP!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ qBittorrent is using the VPN connection${NC}"
fi
echo ""

# Get location information
echo "6. Checking VPN server location..."
LOCATION=$(docker exec gluetun wget -qO- http://ipinfo.io 2>/dev/null)
COUNTRY=$(echo "$LOCATION" | grep -o '"country": "[^"]*"' | cut -d'"' -f4)
CITY=$(echo "$LOCATION" | grep -o '"city": "[^"]*"' | cut -d'"' -f4)
REGION=$(echo "$LOCATION" | grep -o '"region": "[^"]*"' | cut -d'"' -f4)

echo -e "   Country: ${GREEN}${COUNTRY}${NC}"
echo -e "   City: ${GREEN}${CITY}${NC}"
echo -e "   Region: ${GREEN}${REGION}${NC}"
echo ""

# Check expected country (from .env)
EXPECTED_COUNTRY=$(grep SERVER_COUNTRIES ../../.env 2>/dev/null | cut -d'=' -f2)
if [ ! -z "$EXPECTED_COUNTRY" ]; then
    if echo "$LOCATION" | grep -qi "$EXPECTED_COUNTRY"; then
        echo -e "${GREEN}✓ Connected to expected country: ${EXPECTED_COUNTRY}${NC}"
    else
        echo -e "${YELLOW}⚠ Connected country (${COUNTRY}) may differ from expected (${EXPECTED_COUNTRY})${NC}"
    fi
fi
echo ""

# Check Gluetun logs for recent connection
echo "7. Checking recent Gluetun logs..."
docker logs --tail 20 gluetun | grep -i "connected\|public ip\|wireguard" | tail -3
echo ""

echo "========================================="
echo -e "${GREEN}✓ VPN Verification Complete!${NC}"
echo "========================================="
echo ""
echo "Summary:"
echo "  Real IP:       $REAL_IP"
echo "  VPN IP:        $VPN_IP"
echo "  Location:      $CITY, $REGION, $COUNTRY"
echo "  qBittorrent:   Protected ✓"
echo ""
