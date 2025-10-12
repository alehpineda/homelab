# Environment Configuration Guide

## 📋 Environment-Specific Settings

This guide helps you configure optimal settings for different environments.

---

## 🧪 Local Testing Environment

**Purpose**: Development, testing, debugging

### Recommended `.env` Settings:

```bash
# Faster updates for testing
UPDATER_PERIOD="1h"

# Local timezone
TZ=America/Mexico_City

# Local volume path
DOCKER_VOLUMES_PATH="/home/username/Documents/07_Containers/00_docker/volumes"

# Optional: Different ports to avoid conflicts
PORTAINER_HTTP_PORT=9000
PORTAINER_HTTPS_PORT=9443
QBITTORRENT_PORT=8085
```

**Why these settings?**
- ✅ **1h updater**: Fast server list updates for testing different configurations
- ✅ **Local paths**: Keep data in your user directory
- ✅ **Standard ports**: Easy to remember and access

---

## 🚀 Staging/Production Environment

**Purpose**: Long-running, stable deployment

### Recommended `.env` Settings:

```bash
# Efficient updates for production
UPDATER_PERIOD="24h"

# Server timezone
TZ=UTC  # or your server's timezone

# Production volume path
DOCKER_VOLUMES_PATH="/opt/docker/volumes"
# OR
DOCKER_VOLUMES_PATH="/srv/docker/volumes"

# Same ports as local (for consistency)
PORTAINER_HTTP_PORT=9000
PORTAINER_HTTPS_PORT=9443
QBITTORRENT_PORT=8085
```

**Why these settings?**
- ✅ **24h updater**: Efficient, server lists don't change that often
- ✅ **System paths**: Standard locations for production data
- ✅ **UTC timezone**: Standard for servers (or use your location)

---

## 🔄 Quick Environment Switch

### Method 1: Multiple .env Files (Recommended)

```bash
# Create environment-specific files
.env.local      # Local testing
.env.staging    # Staging server
.env.production # Production server
```

**Usage:**
```bash
# Local
docker-compose up -d

# Staging
docker-compose --env-file .env.staging up -d

# Production
docker-compose --env-file .env.production up -d
```

### Method 2: Conditional Values in Single .env

```bash
# Comment/uncomment based on environment

# Local Testing
UPDATER_PERIOD="1h"
DOCKER_VOLUMES_PATH="/home/username/Documents/07_Containers/00_docker/volumes"

# Staging/Production (comment above, uncomment below)
#UPDATER_PERIOD="24h"
#DOCKER_VOLUMES_PATH="/opt/docker/volumes"
```

---

## 📊 Setting Comparison Table

| Setting | Local | Staging/Prod | Reason |
|---------|-------|--------------|--------|
| **UPDATER_PERIOD** | `1h` | `24h` | Testing vs efficiency |
| **DOCKER_VOLUMES_PATH** | User home | `/opt` or `/srv` | Permissions & standards |
| **TZ** | Local timezone | UTC or server TZ | Accurate timestamps |
| **PUID/PGID** | `1000` | Check `id` | File permissions |
| **Restart Policy** | `unless-stopped` | `unless-stopped` | Same for both |

---

## 🔧 Environment-Specific Configurations

### Local Testing

**docker-compose.override.yml** (optional, gitignored):
```yaml
version: '3.9'

services:
  gluetun:
    environment:
      - UPDATER_PERIOD=1h
      - LOG_LEVEL=debug  # More verbose logging
```

### Staging/Production

**docker-compose.staging.yml**:
```yaml
version: '3.9'

services:
  gluetun:
    environment:
      - UPDATER_PERIOD=24h
      - LOG_LEVEL=info  # Standard logging
    
  qbittorrent:
    # Production-specific settings
    deploy:
      resources:
        limits:
          memory: 2G
```

**Usage:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

---

## 🎯 Deployment Checklist

### Before Deploying to Staging/Production:

- [ ] Update `UPDATER_PERIOD` to `24h`
- [ ] Change `DOCKER_VOLUMES_PATH` to system location
- [ ] Set appropriate `TZ` for server location
- [ ] Verify `PUID`/`PGID` match server user
- [ ] Set strong `QBITTORRENT_WEBUI_PASSWORD`
- [ ] Backup `.env` file securely
- [ ] Test VPN connection after deployment
- [ ] Verify DNS leak protection
- [ ] Test kill switch functionality
- [ ] Document any custom settings

---

## 💡 Pro Tips

### 1. **Keep .env files separate**
```bash
homelab/
├── .env                  # Local (gitignored)
├── .env.local           # Local template
├── .env.staging         # Staging template
└── .env.production      # Production template (without secrets)
```

### 2. **Use version control for templates**
- ✅ Commit: `.env.example`, `.env.staging.example`
- ❌ Never commit: `.env`, `.env.staging`, `.env.production` (with real secrets)

### 3. **Document differences**
Keep a `DEPLOYMENT.md` noting what changes between environments

### 4. **Automate with scripts**
```bash
#!/bin/bash
# deploy-staging.sh
cp .env.staging .env
docker-compose up -d
```

---

## 📝 Example Configurations

### .env.local
```bash
DOCKER_VOLUMES_PATH="/home/deathscythe/Documents/07_Containers/00_docker/volumes"
UPDATER_PERIOD="1h"
TZ=America/Mexico_City
```

### .env.staging
```bash
DOCKER_VOLUMES_PATH="/opt/docker/volumes"
UPDATER_PERIOD="24h"
TZ=UTC
```

---

**Last Updated**: October 4, 2025
