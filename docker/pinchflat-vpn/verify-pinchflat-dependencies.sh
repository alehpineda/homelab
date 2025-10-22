#!/bin/bash
# Verify Pinchflat-VPN configuration and dependencies
# Usage: ./verify-pinchflat-dependencies.sh

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Pinchflat-VPN Dependency Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Check if containers exist
echo "1. Checking containers exist..."
if docker ps -a --format '{{.Names}}' | grep -q "gluetun-pinchflat"; then
    echo "   ✅ gluetun-pinchflat container found"
else
    echo "   ❌ gluetun-pinchflat container not found"
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q "^pinchflat$"; then
    echo "   ✅ pinchflat container found"
else
    echo "   ❌ pinchflat container not found"
    exit 1
fi
echo

# Check container status
echo "2. Checking container status..."
GLUETUN_STATUS=$(docker inspect -f '{{.State.Status}}' gluetun-pinchflat)
PINCHFLAT_STATUS=$(docker inspect -f '{{.State.Status}}' pinchflat)

echo "   Gluetun: $GLUETUN_STATUS"
echo "   Pinchflat: $PINCHFLAT_STATUS"

if [ "$GLUETUN_STATUS" != "running" ]; then
    echo "   ⚠️  Gluetun is not running!"
fi

if [ "$PINCHFLAT_STATUS" != "running" ]; then
    echo "   ⚠️  Pinchflat is not running!"
fi
echo

# Check health status
echo "3. Checking Gluetun health..."
HEALTH_STATUS=$(docker inspect -f '{{.State.Health.Status}}' gluetun-pinchflat 2>/dev/null || echo "no-healthcheck")

if [ "$HEALTH_STATUS" = "healthy" ]; then
    echo "   ✅ Gluetun is healthy"
elif [ "$HEALTH_STATUS" = "no-healthcheck" ]; then
    echo "   ⚠️  No health check configured (update compose file)"
else
    echo "   ❌ Gluetun health: $HEALTH_STATUS"
fi
echo

# Check VPN connection
echo "4. Checking VPN connection..."
VPN_IP=$(docker exec gluetun-pinchflat wget -qO- https://api.ipify.org 2>/dev/null || echo "failed")

if [ "$VPN_IP" != "failed" ]; then
    echo "   ✅ VPN connected: $VPN_IP"
else
    echo "   ❌ Cannot get VPN IP"
fi
echo

# Check container uptime
echo "5. Checking container uptime..."
GLUETUN_STARTED=$(docker inspect -f '{{.State.StartedAt}}' gluetun-pinchflat)
PINCHFLAT_STARTED=$(docker inspect -f '{{.State.StartedAt}}' pinchflat)

echo "   Gluetun started: $GLUETUN_STARTED"
echo "   Pinchflat started: $PINCHFLAT_STARTED"

# Calculate time difference (rough check)
GLUETUN_TS=$(date -d "$GLUETUN_STARTED" +%s 2>/dev/null || echo 0)
PINCHFLAT_TS=$(date -d "$PINCHFLAT_STARTED" +%s 2>/dev/null || echo 0)

if [ $GLUETUN_TS -gt 0 ] && [ $PINCHFLAT_TS -gt 0 ]; then
    DIFF=$((PINCHFLAT_TS - GLUETUN_TS))
    if [ $DIFF -ge 30 ]; then
        echo "   ✅ Pinchflat started ${DIFF}s after Gluetun (30s+ delay confirmed)"
    else
        echo "   ⚠️  Pinchflat started ${DIFF}s after Gluetun (less than 30s)"
    fi
fi
echo

# Check depends_on configuration
echo "6. Checking depends_on configuration..."
if docker inspect pinchflat | grep -q "gluetun"; then
    echo "   ✅ Pinchflat depends on Gluetun"
else
    echo "   ⚠️  No dependency found (check compose file)"
fi
echo

# Check control server port
echo "7. Checking Gluetun control server..."
if docker port gluetun-pinchflat | grep -q "8000"; then
    echo "   ✅ Control server port exposed (8000)"
    
    # Test control server
    CONTROL_TEST=$(curl -s http://localhost:8000/v1/publicip/ip 2>/dev/null || echo "failed")
    if [ "$CONTROL_TEST" != "failed" ]; then
        echo "   ✅ Control server responding: $CONTROL_TEST"
    else
        echo "   ⚠️  Control server not responding"
    fi
else
    echo "   ⚠️  Control server port not exposed (add GLUETUN_CONTROL_PORT=8000)"
fi
echo

# Check rotation script
echo "8. Checking rotation script..."
if [ -f "rotate-vpn-ip.sh" ]; then
    echo "   ✅ rotate-vpn-ip.sh exists"
    if [ -x "rotate-vpn-ip.sh" ]; then
        echo "   ✅ Script is executable"
    else
        echo "   ⚠️  Script not executable (run: chmod +x rotate-vpn-ip.sh)"
    fi
else
    echo "   ⚠️  rotate-vpn-ip.sh not found"
fi
echo

# Check cron job
echo "9. Checking automated rotation..."
if crontab -l 2>/dev/null | grep -q "rotate-vpn-ip.sh"; then
    echo "   ✅ Cron job configured"
    crontab -l | grep "rotate-vpn-ip.sh"
else
    echo "   ℹ️  No cron job (rotation is manual only)"
fi
echo

# Check rotation logs
echo "10. Checking rotation logs..."
if [ -f "/var/log/pinchflat-vpn-rotation.log" ]; then
    echo "   ✅ Log file exists"
    LOG_LINES=$(wc -l < /var/log/pinchflat-vpn-rotation.log)
    echo "   📊 Log has $LOG_LINES lines"
    
    if [ $LOG_LINES -gt 0 ]; then
        echo "   📝 Last rotation:"
        tail -3 /var/log/pinchflat-vpn-rotation.log | sed 's/^/      /'
    fi
else
    echo "   ℹ️  No rotation log (not running rotation yet)"
fi
echo

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$GLUETUN_STATUS" = "running" ] && [ "$PINCHFLAT_STATUS" = "running" ] && [ "$VPN_IP" != "failed" ]; then
    echo "✅ All containers running with VPN active"
    echo "🌐 VPN IP: $VPN_IP"
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo "✅ Health checks working"
    fi
    
    if crontab -l 2>/dev/null | grep -q "rotate-vpn-ip.sh"; then
        echo "🔄 Automated rotation: ENABLED"
    else
        echo "🔄 Automated rotation: DISABLED (manual only)"
    fi
else
    echo "⚠️  Some issues detected - review output above"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
