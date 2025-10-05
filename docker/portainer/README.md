# Portainer Community Edition

This directory contains the Docker Compose configuration for Portainer CE, a lightweight service delivery platform for containerized applications.

## 📋 Overview

- **Image**: `portainer/portainer-ce:2.33.2-alpine`
- **Web UI Ports**: 
  - HTTP: 9000 (configurable via `PORTAINER_HTTP_PORT`)
  - HTTPS: 9443 (configurable via `PORTAINER_HTTPS_PORT`)
- **Data Persistence**: `${DOCKER_VOLUMES_PATH}/portainer_data`

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+ 
- Docker Compose 2.0+
- Access to `/var/run/docker.sock`

### Local Development Setup

1. **Navigate to the homelab root directory**:
   ```bash
   cd /path/to/homelab
   ```

2. **Copy the environment template** (if not already done):
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` file** and set your local paths:
   ```bash
   DOCKER_VOLUMES_PATH=/home/yourusername/Documents/07_Containers/00_docker/volumes
   PORTAINER_HTTP_PORT=9000
   PORTAINER_HTTPS_PORT=9443
   TZ=UTC
   ```

4. **Create the volumes directory** (if it doesn't exist):
   ```bash
   mkdir -p $DOCKER_VOLUMES_PATH/portainer_data
   ```

5. **Deploy Portainer**:
   ```bash
   cd docker/portainer
   docker-compose up -d
   ```

6. **Access Portainer**:
   - HTTP: http://localhost:9000
   - HTTPS: https://localhost:9443

### Staging/Production Setup

1. **On the target server**, set appropriate paths in `.env`:
   ```bash
   DOCKER_VOLUMES_PATH=/opt/docker/volumes
   # or
   DOCKER_VOLUMES_PATH=/srv/docker/volumes
   ```

2. **Adjust firewall settings** if needed:
   ```bash
   sudo ufw allow 9000/tcp  # HTTP (consider using reverse proxy instead)
   sudo ufw allow 9443/tcp  # HTTPS
   ```

3. **Deploy**:
   ```bash
   docker-compose up -d
   ```

## 🔧 Configuration

### Environment Variables

All configuration is done via environment variables in the root `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_VOLUMES_PATH` | *required* | Base path for all Docker volumes |
| `PORTAINER_HTTP_PORT` | `9000` | HTTP port for web interface |
| `PORTAINER_HTTPS_PORT` | `9443` | HTTPS port for web interface |
| `TZ` | `UTC` | Timezone for container |

### Volume Mounts

- **`/etc/localtime`** (read-only): Syncs container time with host
- **`/var/run/docker.sock`** (read-only): Docker socket access for container management
- **`${DOCKER_VOLUMES_PATH}/portainer_data:/data`**: Persistent Portainer data (users, settings, etc.)

### Security Features

- ✅ `restart: unless-stopped` - Automatic recovery after crashes/reboots
- ✅ `no-new-privileges:true` - Prevents privilege escalation
- ✅ Read-only mounts for system files and Docker socket
- ✅ Isolated bridge network

## 📊 Management

### View logs
```bash
docker-compose logs -f portainer
```

### Stop Portainer
```bash
docker-compose down
```

### Update Portainer
1. Edit `docker-compose.yml` to use the new version tag
2. Pull new image and recreate container:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

### Backup Portainer data
```bash
# Local
tar -czf portainer_backup_$(date +%Y%m%d).tar.gz \
  ${DOCKER_VOLUMES_PATH}/portainer_data

# Staging/Production
tar -czf /backups/portainer_backup_$(date +%Y%m%d).tar.gz \
  /opt/docker/volumes/portainer_data
```

### Restore from backup
```bash
# Stop Portainer first
docker-compose down

# Extract backup
tar -xzf portainer_backup_YYYYMMDD.tar.gz -C ${DOCKER_VOLUMES_PATH}/

# Start Portainer
docker-compose up -d
```

## 🌐 Deploying Other Services via Portainer

When deploying other Docker Compose stacks through Portainer's web UI:

1. **Environment Variables**: Define them in Portainer's stack deployment UI
2. **Volume Paths**: Use consistent `${DOCKER_VOLUMES_PATH}` paths
3. **Networks**: Consider creating shared networks for inter-service communication
4. **Naming**: Use clear stack names (they become network/volume prefixes)

### Example: Creating a shared network
```bash
docker network create homelab
```

Then in your compose files:
```yaml
networks:
  homelab:
    external: true
```

## 🔍 Troubleshooting

### Cannot access Portainer web UI
- Check if container is running: `docker ps | grep portainer`
- Check logs: `docker-compose logs portainer`
- Verify ports are not in use: `sudo netstat -tlnp | grep -E '9000|9443'`

### Permission denied errors
- Ensure user is in `docker` group: `sudo usermod -aG docker $USER`
- Check Docker socket permissions: `ls -l /var/run/docker.sock`

### Container keeps restarting
- Check logs: `docker-compose logs --tail=50 portainer`
- Verify volume path exists and is writable

## 📚 Additional Resources

- [Portainer Documentation](https://docs.portainer.io/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Portainer Docker Hub](https://hub.docker.com/r/portainer/portainer-ce)

## 🏷️ Version Information

- **Current Image**: `portainer/portainer-ce:2.33.2-alpine`
- **Last Updated**: October 4, 2025
- **Compose Version**: 3.9
