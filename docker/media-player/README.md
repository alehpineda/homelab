# Media Player Stack

This stack includes Jellyfin and Plex media servers for streaming your media library.

## Services

### Jellyfin
- **Port**: 8096 (HTTP), 8920 (HTTPS)
- **Container**: `jellyfin`
- **Image**: `lscr.io/linuxserver/jellyfin:latest`
- **Description**: Free and open-source media server
- **Access**: http://localhost:8096

### Plex
- **Port**: 32400 (Web UI - via host network)
- **Container**: `plex`
- **Image**: `lscr.io/linuxserver/plex:latest`
- **Description**: Popular media server with rich client ecosystem
- **Access**: http://localhost:32400/web
- **Note**: Uses host networking for better performance and discovery

## Media Library Structure

Both servers have access to the same media libraries:
- **TV Shows**: `${DOCKER_VOLUMES_PATH}/media/tv`
- **Movies**: `${DOCKER_VOLUMES_PATH}/media/movies`
- **Music**: `${DOCKER_VOLUMES_PATH}/media/music`
- **YouTube**: `${DOCKER_VOLUMES_PATH}/media/youtube` (from Pinchflat)
- **Downloads**: `${DOCKER_VOLUMES_PATH}/media/downloads` (active downloads from qBittorrent via arr-stack)

## Setup Instructions

### 1. Configure Environment Variables

Copy the example environment file and update it with your settings:

```bash
cd docker/media-player
cp .env.example .env
```

Edit the `.env` file and update the following required variables:

```bash
# REQUIRED: Update this path to match your system
DOCKER_VOLUMES_PATH="/path/to/your/docker/volumes"

# Optional: Adjust these if needed
PUID=1000              # Your user ID (run: id -u)
PGID=1000              # Your group ID (run: id -g)
TZ=UTC                 # Your timezone (e.g., America/New_York)

# Jellyfin ports (defaults shown, customize if needed)
JELLYFIN_PORT=8096
JELLYFIN_HTTPS_PORT=8920
JELLYFIN_DLNA_PORT=1900
JELLYFIN_DISCOVERY_PORT=7359

# Plex claim token (optional, for initial setup)
PLEX_CLAIM=
```

### 2. Create Media Directories

Ensure the media directories exist:

```bash
mkdir -p ${DOCKER_VOLUMES_PATH}/media/{tv,movies,music,youtube,downloads}
mkdir -p ${DOCKER_VOLUMES_PATH}/jellyfin
```

### 3. Plex Initial Setup (Optional)

To claim your Plex server during initial setup:
1. Visit https://www.plex.tv/claim/
2. Copy the claim token (valid for 4 minutes)
3. Add it to the `.env` file: `PLEX_CLAIM=claim-xxxxxxxxxxxx`
4. Start the container

**Note**: You can also claim the server through the web UI after starting without a claim token.

### 4. Start the Stack

```bash
cd docker/media-player
docker-compose up -d
```

### 5. Verify Services

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f jellyfin
docker-compose logs -f plex
```

### 6. Access the Services

- **Jellyfin**: http://localhost:8096
- **Plex**: http://localhost:32400/web

## Configuration

### Jellyfin
- Complete the initial setup wizard in the web UI
- Add media libraries pointing to:
  - `/data/tv` for TV shows
  - `/data/movies` for movies
  - `/data/music` for music
  - `/data/youtube` for YouTube downloads (from Pinchflat)
  - `/data/downloads` for active downloads (optional - from qBittorrent via arr-stack)

### Plex
- Complete the initial setup wizard in the web UI
- Add media libraries pointing to:
  - `/tv` for TV shows
  - `/movies` for movies
  - `/music` for music
  - `/youtube` for YouTube downloads (from Pinchflat)
  - `/downloads` for active downloads (optional - from qBittorrent via arr-stack)

## Networking

- **Jellyfin**: Uses bridge networking with exposed ports
- **Plex**: Uses host networking for:
  - Better performance
  - Automatic discovery on local network
  - DLNA support
  - No port mapping conflicts

## Integration with Other Stacks

### Arr-Stack Integration
Both media servers can be integrated with the arr-stack (Sonarr, Radarr, Lidarr) for automated media management:

1. The media paths are shared between the stacks
2. Configure Sonarr to save to `${DOCKER_VOLUMES_PATH}/media/tv`
3. Configure Radarr to save to `${DOCKER_VOLUMES_PATH}/media/movies`
4. Configure Lidarr to save to `${DOCKER_VOLUMES_PATH}/media/music`

### Pinchflat Integration
YouTube downloads from Pinchflat are automatically available:
- Pinchflat downloads to `${DOCKER_VOLUMES_PATH}/media/youtube`
- Both Jellyfin and Plex can access this directory
- Create a "YouTube" library in each media server pointing to `/data/youtube` (Jellyfin) or `/youtube` (Plex)

## Volume Persistence

Configuration and metadata are persisted in:
- `${DOCKER_VOLUMES_PATH}/jellyfin` - Jellyfin config and cache
- `${DOCKER_VOLUMES_PATH}/plex` - Plex config and cache

## Troubleshooting

### Jellyfin Issues
```bash
# Check logs
docker-compose logs jellyfin

# Restart service
docker-compose restart jellyfin
```

### Plex Issues
```bash
# Check logs
docker-compose logs plex

# Restart service
docker-compose restart plex

# If claim token expired, remove it from .env and claim via web UI
```

### Permission Issues
Ensure the media files have proper permissions:
```bash
sudo chown -R ${PUID}:${PGID} ${DOCKER_VOLUMES_PATH}/media
```

## Stopping the Stack

```bash
docker-compose down
```

To remove volumes as well:
```bash
docker-compose down -v
```

## Additional Resources

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Plex Documentation](https://support.plex.tv/)
- [LinuxServer.io Jellyfin](https://docs.linuxserver.io/images/docker-jellyfin)
- [LinuxServer.io Plex](https://docs.linuxserver.io/images/docker-plex)
