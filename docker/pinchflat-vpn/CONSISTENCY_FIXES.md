# Container/Service Name Consistency Fixes + Healthcheck Fix

## Date: 2025-10-22

## Problems Identified

### Problem 1: Service vs Container Name Inconsistency
Docker Compose uses two different naming contexts:
1. **Service names** - Used in `docker compose` commands (e.g., `docker compose restart gluetun`)
2. **Container names** - Used in `docker` commands (e.g., `docker exec gluetun-pinchflat`)

Previous scripts mixed these inconsistently and relied on implicit compose file paths.

### Problem 2: Healthcheck Configuration Bug ⚠️ CRITICAL
The healthcheck was trying to access port 8000 (Gluetun HTTP control server) but the control server wasn't explicitly enabled:

**Before:**
```yaml
environment:
  - HTTPPROXY=${HTTPPROXY:-off}  # Wrong variable - this is HTTP proxy, not control server
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8000/v1/publicip/ip"]
```

**Issue**: `HTTPPROXY` controls HTTP proxy feature (port forwarding), NOT the HTTP control server API. The healthcheck would ALWAYS fail because port 8000 wasn't listening.

**Root Cause**: Missing `HTTP_CONTROL_SERVER_ADDRESS` environment variable which actually enables the control server.

## Changes Applied

### 1. `docker-compose.yml` - Fixed Healthcheck Configuration ⚠️ CRITICAL

**Added:**
```yaml
environment:
  # HTTP Control Server for health checks and API control
  - HTTP_CONTROL_SERVER_ADDRESS=:8000
  # Proxy services (not needed for control server)
  - HTTPPROXY=${HTTPPROXY:-off}
  - SHADOWSOCKS=${SHADOWSOCKS:-off}
```

**Why This Matters:**
- ✅ Control server now properly enabled on port 8000
- ✅ Healthcheck can successfully query VPN status
- ✅ Pinchflat waits for healthy status before starting
- ✅ Prevents race conditions where Pinchflat starts before VPN is ready

**Clarified Comments:**
- `HTTP_CONTROL_SERVER_ADDRESS` - Enables control server (required for healthcheck)
- `HTTPPROXY` - HTTP proxy feature (unrelated to control server)

### 2. `.env.example` - Documented Control Server

**Added:**
```bash
# HTTP Control Server (required for healthcheck and rotation)
# This enables the control API on port 8000 for health checks and VPN management
# Do not disable this - it's required for the healthcheck to work
# Note: This is different from HTTPPROXY which is an HTTP proxy feature
HTTP_CONTROL_SERVER_ADDRESS=:8000
```

### 3. `README.md` - Added Control Server Documentation

**Added Section:**
```markdown
### HTTP Control Server
The Gluetun HTTP control server runs on port 8000 and provides:
- **Health monitoring**: Healthcheck endpoint for Docker to verify VPN is connected
- **API access**: Programmatic control for rotation and management
- **Status queries**: Check VPN status, IP, and connection details

**Note**: This is separate from `HTTPPROXY` (which is an HTTP proxy feature). 
The control server is required for the healthcheck to function properly.
```

### 4. `rotate-vpn-ip.sh` - Service/Container Name Consistency

**Added Configuration Section:**
```bash
COMPOSE_DIR="${COMPOSE_DIR:-/opt/docker/pinchflat-vpn}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
LOG_FILE="${LOG_FILE:-/var/log/pinchflat-vpn-rotation.log}"

# Container and service names (from docker-compose.yml)
GLUETUN_CONTAINER="gluetun-pinchflat"
PINCHFLAT_CONTAINER="pinchflat"
GLUETUN_SERVICE="gluetun"
PINCHFLAT_SERVICE="pinchflat"
```

**Added Compose File Validation:**
```bash
if [ ! -f "$COMPOSE_FILE" ]; then
    log "ERROR: Compose file not found: $COMPOSE_DIR/$COMPOSE_FILE"
    exit 1
fi
```

**Updated Commands:**
- `docker compose restart gluetun` → `docker compose -f "$COMPOSE_FILE" restart "$GLUETUN_SERVICE"`
- `docker exec gluetun-pinchflat` → `docker exec "$GLUETUN_CONTAINER"`
- `docker inspect -f '{{.State.Running}}' pinchflat` → `docker inspect -f '{{.State.Running}}' "$PINCHFLAT_CONTAINER"`

### 5. `verify-pinchflat-dependencies.sh` - Service/Container Name Consistency

**Added Configuration Section:**
```bash
COMPOSE_DIR="${COMPOSE_DIR:-$(pwd)}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

# Container and service names (from docker-compose.yml)
GLUETUN_CONTAINER="gluetun-pinchflat"
PINCHFLAT_CONTAINER="pinchflat"
GLUETUN_SERVICE="gluetun"
PINCHFLAT_SERVICE="pinchflat"
```

**Added New Section 0: Compose Validation**
- Validates compose file exists
- Checks service names are defined (`gluetun`, `pinchflat`)
- Verifies container names match expected values
- Provides helpful error messages

**Updated All Container References:**
- All hardcoded `gluetun-pinchflat` → `"$GLUETUN_CONTAINER"`
- All hardcoded `pinchflat` → `"$PINCHFLAT_CONTAINER"`
- All hardcoded `gluetun` (service) → `"$GLUETUN_SERVICE"`

## Benefits

### 🎯 Clear Separation
- Service names clearly identified vs container names
- No ambiguity about which context to use

### 🔧 Configurable
- Override via environment variables:
  - `COMPOSE_DIR` - Where to find compose file
  - `COMPOSE_FILE` - Which compose file to use
  - Container/service names defined once at top

### 🛡️ Safer
- Validates compose file exists before running
- Verifies container names match compose file
- Explicit compose file paths (no directory assumptions)

### 📝 Self-Documenting
- Variable names make intent clear
- Comments explain which context uses which name
- Easier to adapt for other stacks

### 🔄 Reusable
- Pattern can be applied to arr-stack, media-player, samba
- Consistent approach across all Docker stack scripts

## Mapping Reference

| Context | Name Type | Example | Usage |
|---------|-----------|---------|-------|
| Docker Compose | Service Name | `gluetun` | `docker compose restart gluetun` |
| Docker Compose | Service Name | `pinchflat` | `docker compose ps pinchflat` |
| Docker | Container Name | `gluetun-pinchflat` | `docker exec gluetun-pinchflat` |
| Docker | Container Name | `pinchflat` | `docker inspect pinchflat` |

## Testing Recommendations

### Test rotate-vpn-ip.sh:
```bash
# Dry run (check variables)
cd /home/deathscythe/Documents/05_Repositories/00_Github/homelab/docker/pinchflat-vpn
bash -x ./rotate-vpn-ip.sh

# With custom compose dir
COMPOSE_DIR=/custom/path ./rotate-vpn-ip.sh
```

### Test verify-pinchflat-dependencies.sh:
```bash
# From compose directory
cd /home/deathscythe/Documents/05_Repositories/00_Github/homelab/docker/pinchflat-vpn
./verify-pinchflat-dependencies.sh

# From another location
COMPOSE_DIR=/path/to/pinchflat-vpn ./verify-pinchflat-dependencies.sh
```

## Next Steps

1. ✅ Deploy updated scripts to production
2. ⏳ Apply same pattern to arr-stack scripts
3. ⏳ Apply same pattern to media-player scripts
4. ⏳ Apply same pattern to samba scripts (when created)
5. ⏳ Document standard in repository README
