#!/bin/bash
# Debug script for Pinchflat GitOps deployment on bael.lan
# Run this on bael.lan after Portainer deployment fails

set -e

COMPOSE_DIR="/data/compose/23/docker/pinchflat-vpn"

echo "==================================="
echo "Pinchflat GitOps Deployment Debug"
echo "==================================="
echo ""

echo "=== 1. GitOps Directory Structure ==="
ls -la "$COMPOSE_DIR"
echo ""

echo "=== 2. Config Subdirectory ==="
if [ -d "$COMPOSE_DIR/config" ]; then
    echo "✅ config/ directory exists"
    ls -la "$COMPOSE_DIR/config/"
else
    echo "❌ config/ directory does NOT exist"
fi
echo ""

echo "=== 3. Auth Config File Check ==="
if [ -f "$COMPOSE_DIR/config/auth-config.toml" ]; then
    echo "✅ auth-config.toml is a FILE"
    echo ""
    echo "Content:"
    cat "$COMPOSE_DIR/config/auth-config.toml"
elif [ -d "$COMPOSE_DIR/config/auth-config.toml" ]; then
    echo "❌ auth-config.toml is a DIRECTORY (this is the problem!)"
    ls -la "$COMPOSE_DIR/config/auth-config.toml"
else
    echo "❌ auth-config.toml does NOT exist"
fi
echo ""

echo "=== 4. Old Auth Config in Root (should not exist) ==="
if [ -d "$COMPOSE_DIR/auth-config.toml" ]; then
    echo "❌ OLD auth-config.toml DIRECTORY still exists in root!"
    ls -la "$COMPOSE_DIR/auth-config.toml"
elif [ -f "$COMPOSE_DIR/auth-config.toml" ]; then
    echo "⚠️  OLD auth-config.toml FILE exists in root (should be in config/)"
else
    echo "✅ No old auth-config.toml in root (correct)"
fi
echo ""

echo "=== 5. Docker Compose Volume Mount ==="
echo "Checking gluetun volumes section in docker-compose.yml:"
grep -A 3 "volumes:" "$COMPOSE_DIR/docker-compose.yml" | head -6
echo ""

echo "=== 6. Environment File Check ==="
if [ -f "$COMPOSE_DIR/.env" ]; then
    echo "✅ .env file exists"
    echo "Required variables present:"
    grep -E "^(DOCKER_VOLUMES_PATH|WIREGUARD_PRIVATE_KEY|VPN_SERVICE_PROVIDER|TZ)=" "$COMPOSE_DIR/.env" || echo "⚠️  Some required variables missing"
else
    echo "❌ .env file does NOT exist"
fi
echo ""

echo "=== 7. Manual Docker Compose Test ==="
echo "Attempting to start stack manually..."
cd "$COMPOSE_DIR"
docker-compose up -d

echo ""
echo "Waiting 10 seconds for containers to initialize..."
sleep 10
echo ""

echo "=== 8. Container Status ==="
docker ps -a --filter "name=gluetun-pinchflat" --filter "name=pinchflat" --format "table {{.Names}}\t{{.Status}}\t{{.State}}"
echo ""

echo "=== 9. Gluetun Logs (last 100 lines) ==="
echo "Looking for errors..."
if docker ps -a --format '{{.Names}}' | grep -q "gluetun-pinchflat"; then
    docker logs --tail 100 gluetun-pinchflat 2>&1
else
    echo "❌ gluetun-pinchflat container not found"
fi
echo ""

echo "=== 10. Container Mount Inspection ==="
if docker ps -a --format '{{.Names}}' | grep -q "gluetun-pinchflat"; then
    echo "Checking if auth-config.toml is properly mounted:"
    docker inspect gluetun-pinchflat --format '{{json .Mounts}}' | jq '.[] | select(.Destination == "/gluetun/auth/config.toml")'
    
    echo ""
    echo "Verifying file exists inside container:"
    docker exec gluetun-pinchflat ls -la /gluetun/auth/config.toml 2>&1 || echo "❌ File not accessible in container"
    
    echo ""
    echo "Checking if file is readable:"
    docker exec gluetun-pinchflat cat /gluetun/auth/config.toml 2>&1 | head -5 || echo "❌ File not readable in container"
else
    echo "❌ Cannot inspect - container not running"
fi
echo ""

echo "=== 11. Healthcheck Test ==="
if docker ps --format '{{.Names}}' | grep -q "gluetun-pinchflat"; then
    echo "Testing healthcheck endpoint:"
    docker exec gluetun-pinchflat wget --quiet --tries=1 -O - http://localhost:8000/v1/publicip/ip 2>&1 || echo "❌ Healthcheck failed"
else
    echo "❌ Container not running - cannot test healthcheck"
fi
echo ""

echo "==================================="
echo "Debug complete!"
echo "==================================="
echo ""
echo "Common issues and fixes:"
echo "1. If config/auth-config.toml is a directory: Remove it and pull from git again"
echo "2. If auth-config.toml is missing: Check Portainer git sync logs"
echo "3. If .env is missing: Portainer may not have environment variables configured"
echo "4. If bind mount fails: Check file permissions on host"
echo ""
