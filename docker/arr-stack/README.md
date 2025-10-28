# 📺 Arr-Stack - Complete VPN-Protected Media Automation

A comprehensive Docker-based media automation stack with **10 services**, all protected by VPN with kill switch, DNS leak protection, and Cloudflare bypass capabilities.

## 📋 Table of Contents

- [Overview](#-overview)
- [Services & Architecture](#-services--architecture)
- [Quick Start](#-quick-start)
- [Migration Guide](#-migration-guide-upgrading-from-previous-version) ⚠️ **Read if upgrading!**
- [Initial Configuration](#️-initial-configuration)
- [Advanced Features](#-advanced-features)
- [Security & VPN Protection](#-security--vpn-protection)
- [Bandwidth Management](#-bandwidth-management)
- [Monitoring & Maintenance](#-monitoring--maintenance)
- [Troubleshooting](#-troubleshooting)
- [Reference](#-reference)

---

## 🎯 Overview

### What is This Stack?

A complete, VPN-protected media automation system that:
- **Downloads** media via torrents (with VPN protection)
- **Manages** TV shows, movies, music, and subtitles automatically
- **Bypasses** Cloudflare protection on indexers
- **Provides** user-friendly request interface for family/friends
- **Ensures** complete privacy with DNS leak protection and kill switch
- **Optimizes storage** using hardlinks to eliminate file duplication

### Services Included

**VPN & Download:**
- **Gluetun** - VPN client (NordVPN with WireGuard) protecting all services
- **qBittorrent** - Torrent client with VPN protection

**Media Management:**
- **Prowlarr** - Centralized indexer manager for all *arr apps
- **Sonarr** - TV show automation
- **Radarr** - Movie automation
- **Lidarr** - Music automation
- **Bazarr** - Subtitle automation
- **Jackett** - Alternative indexer proxy (legacy support)

**Utilities:**
- **FlareSolverr** - Cloudflare bypass proxy for protected indexers
- **Jellyseerr** - User-friendly media request manager

**🔒 All 10 services run through Gluetun VPN with kill switch protection!**

---

## 🏗️ Services & Architecture

### Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| qBittorrent | 8085 | Torrent download client |
| Prowlarr | 9696 | Indexer management |
| Sonarr | 8989 | TV show automation |
| Radarr | 7878 | Movie automation |
| Lidarr | 8686 | Music automation |
| Bazarr | 6767 | Subtitle automation |
| Jackett | 9117 | Indexer proxy (alternative) |
| FlareSolverr | 8191 | Cloudflare bypass (API only) |
| Jellyseerr | 5055 | Media request manager |

### Architecture Diagram

```
Internet
    ↓
Gluetun (VPN) ← All services route through here
    ↓
    ├── qBittorrent (Download Client)
    ├── FlareSolverr (Cloudflare Bypass)
    │       ↓
    ├── Prowlarr (Indexer Manager) ← Syncs to all *arr apps
    │       ↓
    ├── Sonarr/Radarr/Lidarr (Media Management)
    │       ↓
    ├── Bazarr (Subtitle Download)
    │       ↓
    └── Jellyseerr (User Requests) → Media Library
```

### Complete Request Flow

```
User → Jellyseerr (Request Movie/TV)
         ↓
    Radarr/Sonarr (Searches via Prowlarr)
         ↓
    Prowlarr → Indexers (with FlareSolverr if Cloudflare protected)
         ↓
    qBittorrent (Downloads via Gluetun VPN)
         ↓
    Radarr/Sonarr (Imports & Organizes)
         ↓
    Bazarr (Downloads Subtitles)
         ↓
    Jellyseerr → User Notification "Media Available!"
```

---

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- NordVPN account with WireGuard configured
- `/dev/net/tun` device available on host

### Installation Steps

#### 1. Navigate to homelab root directory
```bash
cd /path/to/homelab
```

#### 2. Copy environment template
```bash
cp .env.example .env
```

#### 3. Get NordVPN WireGuard private key
- Follow: https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/nordvpn.md#obtain-your-wireguard-private-key
- Or use NordVPN dashboard to generate WireGuard credentials

#### 4. Configure `.env` file
```bash
# Required: Add your WireGuard private key
WIREGUARD_PRIVATE_KEY=your-actual-private-key-here

# Optional: Adjust other settings
SERVER_COUNTRIES=Mexico  # Or your preferred country
TZ=America/Mexico_City   # Or your timezone
```

#### 5. Create volume directories

**Note:** This stack uses a unified `/data` mount structure to enable hardlinks and eliminate file duplication.

```bash
# Create service configuration directories
mkdir -p ${DOCKER_VOLUMES_PATH}/gluetun
mkdir -p ${DOCKER_VOLUMES_PATH}/qbittorrent
mkdir -p ${DOCKER_VOLUMES_PATH}/prowlarr
mkdir -p ${DOCKER_VOLUMES_PATH}/sonarr
mkdir -p ${DOCKER_VOLUMES_PATH}/radarr
mkdir -p ${DOCKER_VOLUMES_PATH}/lidarr
mkdir -p ${DOCKER_VOLUMES_PATH}/bazarr
mkdir -p ${DOCKER_VOLUMES_PATH}/jackett
mkdir -p ${DOCKER_VOLUMES_PATH}/jellyseerr

# Create unified media directory structure (required for hardlinks)
mkdir -p ${DOCKER_VOLUMES_PATH}/media/downloads/{tv,movies,music}
mkdir -p ${DOCKER_VOLUMES_PATH}/media/{tv,movies,music}
```

**Directory Structure Explained:**
```
${DOCKER_VOLUMES_PATH}/media/
├── downloads/          # qBittorrent saves files here
│   ├── tv/            # TV show downloads (category: tv-sonarr)
│   ├── movies/        # Movie downloads (category: movies-radarr)
│   └── music/         # Music downloads (category: music-lidarr)
├── tv/                # Sonarr hardlinks final TV shows here
├── movies/            # Radarr hardlinks final movies here
└── music/             # Lidarr hardlinks final music here
```

**Why This Structure?**
- ✅ **No Duplication**: Files use hardlinks (same file, multiple locations)
- ✅ **Continue Seeding**: qBittorrent keeps seeding from `/data/downloads`
- ✅ **Organized Library**: *arr apps manage organized media in `/data/tv`, `/data/movies`, `/data/music`
- ✅ **Space Efficient**: One copy on disk, appears in multiple places

#### 6. Deploy the stack
```bash
cd docker/arr-stack
docker-compose up -d
```

#### 7. Configure UFW firewall (Required for optimal downloads)

**Open BitTorrent port for incoming peer connections:**
```bash
# Allow qBittorrent P2P traffic (required for optimal performance)
sudo ufw allow 6881/tcp comment 'qBittorrent P2P'
sudo ufw allow 6881/udp comment 'qBittorrent P2P'
sudo ufw reload

# Verify the rules
sudo ufw status | grep 6881
```

**Why this is needed:**
- ✅ Allows incoming peer connections (faster downloads)
- ✅ Improves upload ratios and seeding capability
- ✅ Increases available peer pool
- ⚠️ Without this, you can only make outgoing connections (slower downloads)

**Note:** You may also need to configure port forwarding on your router:
- Forward external port `6881` (TCP + UDP) → Your server's internal IP

#### 8. Verify all services are running
```bash
docker-compose ps
```

Expected: All 10 services showing "running" status.

#### 9. Access services

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| qBittorrent | http://localhost:8085 | User: `admin`, PW: Check logs |
| Prowlarr | http://localhost:9696 | Set up authentication |
| Sonarr | http://localhost:8989 | Set up authentication |
| Radarr | http://localhost:7878 | Set up authentication |
| Lidarr | http://localhost:8686 | Set up authentication |
| Bazarr | http://localhost:6767 | Set up authentication |
| Jackett | http://localhost:9117 | Set up authentication |
| FlareSolverr | http://localhost:8191 | No UI (API only) |
| Jellyseerr | http://localhost:5055 | Create admin account |

**Get qBittorrent password:**
```bash
docker logs qbittorrent | grep "temporary password"
```

---

## 🔄 Migration Guide (Upgrading from Previous Version)

### Breaking Changes in v2.0

**Volume Structure Change:** This version consolidates multiple volume mounts into a unified `/data` path structure to enable hardlinks and eliminate file duplication.

**Required Directory Structure:**
```
${DOCKER_VOLUMES_PATH}/media/
├── downloads/          # qBittorrent download location
│   ├── tv/            # Category: tv-sonarr
│   ├── movies/        # Category: movies-radarr
│   └── music/         # Category: music-lidarr
├── tv/                # Sonarr managed library (hardlinked)
├── movies/            # Radarr managed library (hardlinked)
└── music/             # Lidarr managed library (hardlinked)
```

**What Changed:**
- ❌ **Old:** Separate mounts: `/downloads`, `/tv`, `/movies`, `/music`
- ✅ **New:** Single mount: `/data` (contains all subdirectories)
- ✅ **Why:** Enables hardlinks (same filesystem requirement)

### Migration Steps

#### 1. Backup Your Data

```bash
# Stop the current stack
cd docker/arr-stack
docker-compose down

# Backup existing configuration
tar -czf arr-stack-backup-$(date +%Y%m%d).tar.gz \
  ${DOCKER_VOLUMES_PATH}/{gluetun,qbittorrent,prowlarr,sonarr,radarr,lidarr,bazarr,jellyseerr}

# Backup existing media (if applicable)
tar -czf media-backup-$(date +%Y%m%d).tar.gz \
  ${DOCKER_VOLUMES_PATH}/media/
```

#### 2. Create New Directory Structure

```bash
# Create unified media structure
mkdir -p ${DOCKER_VOLUMES_PATH}/media/downloads/{tv,movies,music}
mkdir -p ${DOCKER_VOLUMES_PATH}/media/{tv,movies,music}
```

#### 3. Migrate Existing Downloads (if any)

**Option A: Move files to new structure (recommended for active downloads)**
```bash
# If you have existing downloads in qbittorrent/downloads
mv ${DOCKER_VOLUMES_PATH}/qbittorrent/downloads/* \
   ${DOCKER_VOLUMES_PATH}/media/downloads/

# Organize by type if needed
mv ${DOCKER_VOLUMES_PATH}/media/downloads/*tv* ${DOCKER_VOLUMES_PATH}/media/downloads/tv/
mv ${DOCKER_VOLUMES_PATH}/media/downloads/*movie* ${DOCKER_VOLUMES_PATH}/media/downloads/movies/
```

**Option B: Start fresh (recommended for new installations)**
```bash
# Remove old downloads directory
rm -rf ${DOCKER_VOLUMES_PATH}/qbittorrent/downloads
```

#### 4. Migrate Existing Media Library

**If you already have organized media:**
```bash
# Move existing media to new locations (if different from current structure)
# Skip this if your media is already in ${DOCKER_VOLUMES_PATH}/media/{tv,movies,music}

# Example:
# mv /old/path/to/tv/* ${DOCKER_VOLUMES_PATH}/media/tv/
# mv /old/path/to/movies/* ${DOCKER_VOLUMES_PATH}/media/movies/
# mv /old/path/to/music/* ${DOCKER_VOLUMES_PATH}/media/music/
```

#### 5. Update docker-compose.yml

```bash
# Pull the latest version
git pull origin master

# Or manually update your docker-compose.yml with the new volume mounts
```

#### 6. Deploy Updated Stack

```bash
cd docker/arr-stack
docker-compose up -d
```

#### 7. Reconfigure Services

**You must reconfigure the following in each service:**

**qBittorrent:**
- Default Save Path: `/data/downloads`
- Categories: Create `tv-sonarr`, `movies-radarr`, `music-lidarr`
- Category paths: `/data/downloads/tv`, `/data/downloads/movies`, `/data/downloads/music`

**Sonarr:**
- Settings → Media Management → ✅ Use Hardlinks instead of Copy
- Root Folder: Change from `/tv` to `/data/tv`
- Re-add download client with category `tv-sonarr`

**Radarr:**
- Settings → Media Management → ✅ Use Hardlinks instead of Copy
- Root Folder: Change from `/movies` to `/data/movies`
- Re-add download client with category `movies-radarr`

**Lidarr:**
- Settings → Media Management → ✅ Use Hardlinks instead of Copy
- Root Folder: Change from `/music` to `/data/music`
- Re-add download client with category `music-lidarr`

**Bazarr:**
- Update Sonarr path to: `/data/tv`
- Update Radarr path to: `/data/movies`

#### 8. Verify Hardlinks Are Working

```bash
# Download a test file via Sonarr/Radarr
# Then check if hardlinks were created:

docker exec sonarr ls -li /data/downloads/tv/test-file.mkv
docker exec sonarr ls -li /data/tv/Show/test-file.mkv

# If the inode numbers (first column) match, hardlinks are working! ✓
```

#### 9. Clean Up Old Structure (Optional)

**Only after verifying everything works:**
```bash
# Remove old downloads directory if you moved everything
rm -rf ${DOCKER_VOLUMES_PATH}/qbittorrent/downloads
```

### Troubleshooting Migration

**Services can't see media:**
- Verify paths in each service UI match `/data/*` structure
- Check permissions: `sudo chown -R 1000:1000 ${DOCKER_VOLUMES_PATH}/media`

**Files are being copied instead of hardlinked:**
- Ensure "Use Hardlinks instead of Copy" is enabled in *arr apps
- Verify downloads and media are in the same `/data` parent directory
- Check filesystem supports hardlinks (most modern filesystems do)

**Active downloads lost:**
- Re-add torrents manually in qBittorrent
- Point to new location: `/data/downloads/[tv|movies|music]/`

### Rollback Procedure

If you need to rollback:
```bash
# Stop new stack
docker-compose down

# Restore from backup
cd ${DOCKER_VOLUMES_PATH}
tar -xzf /path/to/arr-stack-backup-YYYYMMDD.tar.gz

# Checkout previous version
git checkout <previous-commit>

# Restart
docker-compose up -d
```

---

## ⚙️ Initial Configuration

### Configuration Order (Recommended)

1. ✅ Configure Prowlarr (indexer manager)
2. ✅ Configure qBittorrent (download client)
3. ✅ Configure Sonarr/Radarr/Lidarr (media management)
4. ✅ Configure Bazarr (subtitles)
5. ✅ Enable FlareSolverr in Prowlarr
6. ✅ Configure Jellyseerr (user requests)

### Step 1: Configure Prowlarr (Indexer Manager)

**Purpose:** Centrally manage all torrent/usenet indexers

1. **Access:** http://localhost:9696
2. **Setup authentication:**
   - Settings → General → Authentication
   - Set username and password
3. **Add indexers:**
   - Indexers → Add Indexer
   - Search for public trackers (1337x, RARBG, etc.)
   - Add your private trackers if available
4. **Configure apps:**
   - Settings → Apps → Add Application
   - Add Sonarr, Radarr, Lidarr
   - Prowlarr syncs indexers to all apps automatically!

### Step 2: Configure qBittorrent

1. **Access:** http://localhost:8085
2. **Get password:** `docker logs qbittorrent | grep "temporary password"`
3. **Login:** user: `admin`, password from logs
4. **Set permanent password:** Tools → Options → Web UI
5. **Configure download paths:**
   - Tools → Options → Downloads
   - Default Save Path: `/data/downloads`
   - **Create categories and paths:**
     - Category: `tv-sonarr` → Path: `/data/downloads/tv`
     - Category: `movies-radarr` → Path: `/data/downloads/movies`
     - Category: `music-lidarr` → Path: `/data/downloads/music`
6. **Configure bandwidth** (see [Bandwidth Management](#-bandwidth-management))
7. **Save API credentials** for later use in *arr apps

**Important:** The category paths are critical for hardlinks to work properly!

### Step 3: Configure Sonarr (TV Shows)

1. **Access:** http://localhost:8989
2. **Settings → Media Management:**
   - ✅ Rename Episodes
   - ✅ Replace Illegal Characters
   - ✅ **Use Hardlinks instead of Copy** ← IMPORTANT!
   - Episode Format: `{Series Title} - S{season:00}E{episode:00} - {Episode Title}`
3. **Settings → Download Clients:**
   - Add → qBittorrent
   - Host: `gluetun` (or `localhost`)
   - Port: `8085`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `tv-sonarr`
   - ❌ **Remove Completed** (keep seeding!)
4. **Settings → General → Security:**
   - Set API Key (save this!)
5. **Add Root Folder:** `/data/tv`

### Step 4: Configure Radarr (Movies)

1. **Access:** http://localhost:7878
2. **Settings → Media Management:**
   - ✅ Rename Movies
   - ✅ Replace Illegal Characters
   - ✅ **Use Hardlinks instead of Copy** ← IMPORTANT!
   - Movie Format: `{Movie Title} ({Release Year})`
3. **Settings → Download Clients:**
   - Add → qBittorrent
   - Host: `gluetun` (or `localhost`)
   - Port: `8085`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `movies-radarr`
   - ❌ **Remove Completed** (keep seeding!)
4. **Settings → General → Security:**
   - Set API Key (save this!)
5. **Add Root Folder:** `/data/movies`

### Step 5: Configure Lidarr (Music)

1. **Access:** http://localhost:8686
2. **Settings → Media Management:**
   - ✅ Rename Tracks
   - ✅ **Use Hardlinks instead of Copy** ← IMPORTANT!
   - Standard Track Format: `{Artist Name} - {Album Title} - {track:00} - {Track Title}`
3. **Settings → Download Clients:**
   - Add → qBittorrent
   - Host: `gluetun` (or `localhost`)
   - Port: `8085`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `music-lidarr`
   - ❌ **Remove Completed** (keep seeding!)
4. **Add Root Folder:** `/data/music`

### Step 6: Configure Bazarr (Subtitles)

1. **Access:** http://localhost:6767
2. **Settings → General:**
   - Set authentication
3. **Settings → Sonarr:**
   - ✅ Enabled
   - Address: `sonarr`
   - Port: `8989`
   - API Key: (from Sonarr)
   - Base URL: (leave blank unless using a reverse proxy with path prefix)
4. **Settings → Radarr:**
   - ✅ Enabled
   - Address: `radarr`
   - Port: `7878`
   - API Key: (from Radarr)
   - Base URL: (leave blank unless using a reverse proxy with path prefix)
5. **Settings → Subtitles:**
   - Add subtitle providers (OpenSubtitles, etc.)
   - Configure languages (English, Spanish, etc.)

### Step 7: Connect Prowlarr to *arr Apps

1. **In Prowlarr:** Settings → Apps → Add Application
2. **For Sonarr:**
   - Name: Sonarr
   - Sync Level: Full Sync
   - Prowlarr Server: http://localhost:9696
   - Sonarr Server: http://sonarr:8989
   - API Key: (from Sonarr)
3. **Repeat for Radarr and Lidarr**
4. **Sync:** Prowlarr automatically configures all indexers in each app!

### Step 8: Configure FlareSolverr (Cloudflare Bypass)

**Purpose:** Bypass Cloudflare protection on torrent indexers

#### What is FlareSolverr?

FlareSolverr is a proxy server that bypasses Cloudflare and DDoS-GUARD protection. Many public torrent indexers use Cloudflare to prevent scraping.

#### When to Use FlareSolverr:

**Use for indexers that:**
- Show Cloudflare challenge pages
- Return 403 Forbidden errors
- Have JavaScript-based protection
- Common examples: 1337x, EZTV, TorrentGalaxy

**Don't need for:**
- Private trackers with direct API access
- Usenet indexers
- Indexers without Cloudflare protection

#### Configuration in Prowlarr:

1. **Settings → Indexers → Add Indexer** (e.g., 1337x)
2. **In indexer settings:**
   - Add tag: `flaresolverr`
   - FlareSolverr URL: `http://flaresolverr:8191`
   - Test and Save
3. **Prowlarr will now use FlareSolverr** for that indexer

#### Test FlareSolverr is Working:

```bash
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd":"request.get","url":"https://1337x.to/","maxTimeout":60000}'
```

You should get a JSON response with page content.

### Step 9: Configure Jellyseerr (Media Request Manager)

**Purpose:** User-friendly interface for requesting movies/TV shows

#### What is Jellyseerr?

Jellyseerr provides a beautiful, modern interface for requesting media. Perfect for sharing your media server with family/friends who don't need to learn Sonarr/Radarr.

#### Benefits:

- 🎨 Beautiful UI (much nicer than Sonarr/Radarr)
- 👥 Multi-user support with request limits
- 🔔 Notifications (Email/Discord/Slack)
- 🎯 Request approval workflow
- 📊 Discover trending media
- 🔍 Unified search

#### Initial Setup:

1. **Access:** http://localhost:5055
2. **Create admin account:**
   - Email: your-email@example.com
   - Password: (choose strong password)
   - Username: admin

#### Connect to Media Server (Optional):

If you have Plex/Jellyfin/Emby:
- Select your media server type
- Enter server URL and credentials
- Shows existing library to users

If you don't:
- Click "Skip" - Jellyseerr works standalone!

#### Connect to Sonarr:

1. **Settings → Services → Sonarr**
2. **Click "Add Sonarr Server"**
3. **Configure:**
   - ✅ Default Server
   - Server Name: `Sonarr`
   - Hostname or IP: `sonarr`
   - Port: `8989`
   - API Key: (from Sonarr → Settings → General → Security)
   - Quality Profile: Select default (e.g., "HD-1080p")
   - Root Folder: Select `/tv`
4. **Test** → should show ✅ success
5. **Save Changes**

#### Connect to Radarr:

1. **Settings → Services → Radarr**
2. **Click "Add Radarr Server"**
3. **Configure:**
   - ✅ Default Server
   - Server Name: `Radarr`
   - Hostname or IP: `radarr`
   - Port: `7878`
   - API Key: (from Radarr → Settings → General → Security)
   - Quality Profile: Select default (e.g., "HD-1080p")
   - Root Folder: Select `/movies`
4. **Test** → should show ✅ success
5. **Save Changes**

#### Configure Notifications (Optional):

**Email:**
- Settings → Notifications → Email
- Configure SMTP settings
- Test and enable

**Discord:**
- Create Discord webhook
- Settings → Notifications → Discord
- Paste webhook URL
- Enable for: Request approved, Media available, Request declined

#### Create Users:

1. **Settings → Users → Create Local User**
2. **Fill in:**
   - Email, Username, Password
3. **Set Permissions:**
   - Request Movies
   - Request TV Shows
   - Auto-approve (for trusted users)
4. **Set Limits (optional):**
   - Movies per week: 10
   - TV shows per week: 5

---

## 🎨 Advanced Features

### Hardlinks & Storage Optimization

**What are Hardlinks?**

Hardlinks allow the same file to exist in multiple locations without duplicating disk space. Instead of copying the file, the filesystem creates a new directory entry pointing to the same data.

**How It Works:**
```
Before (Copy - Wastes Space):
/data/downloads/movies/Movie.mkv       [10 GB]
/data/movies/Movie (2024)/Movie.mkv    [10 GB]  ← DUPLICATE!
Total: 20 GB used

After (Hardlink - No Duplication):
/data/downloads/movies/Movie.mkv       [10 GB]
/data/movies/Movie (2024)/Movie.mkv    [Points to same data]
Total: 10 GB used (50% space saved!)
```

**Benefits:**
- ✅ **No Duplication**: One copy on disk, appears in multiple places
- ✅ **Continue Seeding**: qBittorrent keeps seeding from `/data/downloads`
- ✅ **Organized Library**: *arr apps manage clean structure in `/data/tv`, `/data/movies`, `/data/music`
- ✅ **Delete Safety**: File persists until removed from ALL locations
- ✅ **Instant Moves**: No data copying, instant "relocation"

**Requirements:**
- ✅ Same filesystem/volume (why we use `/data` parent directory)
- ✅ Hardlinks enabled in *arr apps (Settings → Media Management)
- ✅ Download client categories configured correctly

**Verify Hardlinks Are Working:**
```bash
# Check inode numbers (should match if hardlinked)
docker exec sonarr ls -li /data/downloads/tv/show.mkv
docker exec sonarr ls -li /data/tv/Show/Season/show.mkv

# If first column (inode) matches → hardlinks working! ✓
```

**Important Notes:**
- Hardlinks only work within same filesystem
- Deleting from one location doesn't affect the other
- Space freed only when file deleted from ALL hardlinked locations
- Cannot hardlink across different mount points

---

### Quality Profiles (Recommended)

**For TV Shows (Sonarr):**
- 1080p Web-DL/BluRay for most content
- 720p for older shows or storage saving
- 4K only if you have bandwidth and storage

**For Movies (Radarr):**
- 1080p BluRay/Web-DL
- Or 720p to save space
- 4K for special movies if desired

**For Music (Lidarr):**
- FLAC for quality
- MP3 320kbps for portability
- Or both!

### qBittorrent Categories

Set up automatic categories for organization:
- `tv-sonarr` - TV shows from Sonarr
- `movies-radarr` - Movies from Radarr
- `music-lidarr` - Music from Lidarr
- `manual` - Manual downloads

### Prowlarr vs Jackett

**Prowlarr (Recommended):**
- ✅ Modern, actively developed
- ✅ Automatically syncs indexers to all *arr apps
- ✅ Better integration
- ✅ FlareSolverr support built-in

**Jackett (Legacy):**
- ⚠️ Older, but still works
- ⚠️ Manual configuration in each *arr app
- ✅ More indexers available
- ✅ Good for specific trackers Prowlarr doesn't support

**Recommendation:** Use Prowlarr, add Jackett only if you need specific indexers

### FlareSolverr Best Practices

**When to Use:**
- Indexers with Cloudflare protection
- Rate-limited public trackers
- Sites with JavaScript challenges

**Configuration Tips:**
- Only enable for indexers that need it (adds latency)
- Monitor logs for failed bypasses
- Update FlareSolverr regularly (Cloudflare changes defenses)

**Common Compatible Indexers:**
- 1337x
- EZTV
- TorrentGalaxy
- Many public trackers

### Jellyseerr Tips

**Request Management:**
- Set up auto-approval for trusted users
- Configure request limits (e.g., 10 movies/week)
- Enable notifications (Discord, Slack, Email)

**Integration:**
- Can connect to Plex/Jellyfin/Emby to show existing library
- Users only see what they have access to
- Prevents duplicate requests

---

## 🔒 Security & VPN Protection

### Current Security Status

Your arr-stack has **multiple layers of security**:

#### 1. Kill Switch (Hardware-Level) ✅

- **Built-in** via `network_mode: "service:gluetun"`
- qBittorrent **cannot** access internet without VPN
- If Gluetun stops or VPN drops → qBittorrent loses all connectivity
- This is a **HARD kill switch** (not software-based)

**How It Works:**

```yaml
qbittorrent:
  network_mode: "service:gluetun"  # This is the kill switch!
```

**Protection Types:**
1. ✅ Container stopped: qBittorrent can't access internet
2. ✅ VPN disconnected: Gluetun's firewall blocks traffic
3. ✅ Network issues: No fallback to non-VPN connection
4. ✅ Boot protection: qBittorrent can't start without Gluetun

#### 2. DNS Leak Protection ✅

- DNS over TLS (DoT) enabled with Cloudflare
- All DNS queries encrypted via TLS
- Gluetun runs its own DNS server (127.0.0.1)
- No DNS queries leak to your ISP

**How DNS Protection Works:**

```
Your App (qBittorrent)
    ↓
Gluetun's DNS Server (127.0.0.1:53)
    ↓
DNS over TLS (encrypted)
    ↓
Cloudflare (1.1.1.1) via VPN Tunnel
    ↓
Internet
```

**Benefits:**
1. Encrypted DNS: Queries encrypted with TLS
2. No ISP snooping: Your ISP can't see DNS queries
3. VPN tunnel: All DNS traffic through VPN
4. Privacy: Cloudflare doesn't log queries

**DNS Configuration (in `.env`):**
```bash
DOT=on                      # DNS over TLS enabled
DOT_PROVIDERS=cloudflare    # Using Cloudflare (1.1.1.1)
DNS_ADDRESS=127.0.0.1       # Gluetun's internal DNS server
```

**Available DNS Providers:**

| Provider | Address | Privacy | Speed |
|----------|---------|---------|-------|
| `cloudflare` | 1.1.1.1 | Excellent | Very Fast |
| `google` | 8.8.8.8 | Good | Very Fast |
| `quad9` | 9.9.9.9 | Excellent | Fast |
| `adguard` | - | Excellent | Fast (blocks ads) |

### Testing Your Security

#### Test 1: DNS Leak Test

```bash
cd /path/to/arr-stack
./test-dns-leak.sh
```

**Expected results:**
- ✅ DNS server: 127.0.0.1 (Gluetun's internal DNS)
- ✅ VPN IP ≠ Real IP
- ✅ DNS over TLS: Enabled

#### Test 2: Kill Switch Test

```bash
./test-killswitch.sh
```

**What it does:**
1. Checks VPN is connected
2. Stops Gluetun container
3. Tries to access internet from qBittorrent (should FAIL)
4. Restarts Gluetun
5. Verifies connectivity restored

**Expected results:**
- ✅ qBittorrent **cannot** access internet when Gluetun is stopped
- ✅ Kill switch is working

#### Test 3: Quick VPN Check

```bash
./check-vpn.sh
```

**Checks:**
- VPN connection status
- IP addresses (real vs VPN)
- qBittorrent using VPN

#### Test 4: Manual IP Verification

```bash
# Real IP
curl -s https://api.ipify.org

# VPN IP (Gluetun)
docker exec gluetun wget -qO- https://api.ipify.org

# qBittorrent IP (should match VPN)
docker exec qbittorrent wget -qO- https://api.ipify.org
```

### Online DNS Leak Tests

**dnsleaktest.com (Recommended):**
```bash
docker exec gluetun wget -qO- https://bash.ws/dnsleak
```
- Visit https://dnsleaktest.com
- Run "Standard Test" or "Extended Test"
- Should show VPN provider's DNS servers (not your ISP)

**ipleak.net (Comprehensive):**
- Visit https://ipleak.net
- Checks: IP, DNS, WebRTC, torrent IP
- All should show VPN IP

**browserleaks.com/dns:**
- Detailed DNS analysis
- Shows all DNS servers used

### VPN Auto-Reconnection

Automatically reconnect VPN to get fresh IP addresses and avoid stale connections.

#### Method 1: Cron Job (Recommended)

**Step 1: Test the script**
```bash
cd /path/to/arr-stack
./reconnect-vpn.sh
```

**Step 2: Create log directory**
```bash
sudo mkdir -p /var/log
sudo touch /var/log/gluetun-reconnect.log
sudo chown $USER:$USER /var/log/gluetun-reconnect.log
```

**Step 3: Add to crontab**
```bash
crontab -e
```

Add for reconnection every 2 hours:
```cron
# Reconnect Gluetun VPN every 2 hours
0 */2 * * * /path/to/arr-stack/reconnect-vpn.sh >> /var/log/gluetun-reconnect.log 2>&1
```

**Alternative schedules:**
```cron
# Every hour
0 * * * * /path/to/reconnect-vpn.sh

# Every 4 hours
0 */4 * * * /path/to/reconnect-vpn.sh

# Daily at 3 AM
0 3 * * * /path/to/reconnect-vpn.sh
```

**Step 4: Check logs**
```bash
tail -f /var/log/gluetun-reconnect.log
```

#### Why Reconnect Periodically?

**Benefits:**
1. Fresh IP Address: Get different VPN server IP
2. Avoid Detection: Some services detect long-lived VPN connections
3. Load Balancing: Distribute across different VPN servers
4. Connection Quality: Refresh stale connections
5. Security: Reduce correlation of activities to single IP

**Considerations:**
1. Active Downloads: Briefly interrupts torrents (resume automatically)
2. Timing: Schedule during low-activity periods
3. Server Load: Don't reconnect too frequently (every 2h recommended)

**Recommended Schedules:**

| Use Case | Frequency | Cron | Reason |
|----------|-----------|------|--------|
| Testing | Every 30 min | `*/30 * * * *` | Quick testing |
| Light Use | Every 6 hours | `0 */6 * * *` | Minimal disruption |
| **Normal Use** | **Every 2 hours** | `0 */2 * * *` | **Recommended** ⭐ |
| Heavy Use | Every hour | `0 * * * *` | Fresh connections |
| Daily | Once daily | `0 3 * * *` | Minimal reconnects |

### Security Best Practices

1. **Regular testing:**
   - Run `./check-vpn.sh` daily
   - Run `./test-dns-leak.sh` weekly
   - Run `./test-killswitch.sh` after config changes

2. **Monitor logs:**
   ```bash
   docker-compose logs -f gluetun
   ```

3. **Keep updated:**
   - Update Gluetun image regularly
   - Check for NordVPN server updates
   - Review Gluetun changelog

4. **Security checklist:**
   - ✅ VPN connected (different IP)
   - ✅ DNS over TLS enabled
   - ✅ Kill switch tested
   - ✅ No WebRTC leaks (browser-based)
   - ✅ Regular IP/DNS leak tests

---

## 🌐 Bandwidth Management

### Connection: 2 Gbps Fiber

#### Recommended Limits (1/10th of Total Bandwidth)

- **Total:** 2 Gbps (2000 Mbps)
- **Target:** 1/10th = 200 Mbps
- **In MB/s:** 25 MB/s
- **In KiB/s:** 25,000 KiB/s

### Configuration Method 1: Web UI (Recommended)

#### Access qBittorrent:
```
http://localhost:8085
Username: admin
Password: [check logs: docker logs qbittorrent | grep "temporary password"]
```

#### Steps:

1. **Click ⚙️ Settings** (top right) or **Tools → Options**
2. **Go to Speed tab**
3. **Set the following:**

**Global Rate Limits:**
```
Upload rate limit:   25000 KiB/s  (200 Mbps)
Download rate limit: 25000 KiB/s  (200 Mbps)
```

**Connection Limits:**
```
Global maximum connections:            500
Maximum connections per torrent:       100
Global maximum upload slots:           300
Maximum upload slots per torrent:      20
```

4. **Click Save**

### Bandwidth Calculation Reference

#### Common Fractions of 2 Gbps:

| Fraction | Mbps | MB/s | KiB/s | Use Case |
|----------|------|------|-------|----------|
| **1/10** | **200** | **25** | **25,000** | **Light usage** ⭐ |
| 1/5 | 400 | 50 | 50,000 | Moderate usage |
| 1/4 | 500 | 62.5 | 62,500 | Heavy usage |
| 1/2 | 1000 | 125 | 125,000 | Maximum (not recommended) |

**Conversion Formula:**
```
Mbps ÷ 8 = MB/s
MB/s × 1000 = KiB/s (approximately)

Example:
200 Mbps ÷ 8 = 25 MB/s
25 MB/s × 1000 = 25,000 KiB/s
```

### Schedule-Based Limits (Advanced)

**Use Case:**
- **Peak hours (8 AM - 11 PM):** Lower limits (100 Mbps)
- **Off-peak (11 PM - 8 AM):** Higher limits (400 Mbps)

**Configuration in qBittorrent:**

1. ✅ Enable "Schedule the use of alternative rate limits"
2. **From:** `08:00` **To:** `23:00`
3. **Alternative limits:**
   - Upload: `12500` KiB/s (100 Mbps)
   - Download: `12500` KiB/s (100 Mbps)
4. **Regular limits** (11 PM - 8 AM):
   - Upload: `50000` KiB/s (400 Mbps)
   - Download: `50000` KiB/s (400 Mbps)

### Recommended Presets

**Conservative (1/20th - 100 Mbps):**
```
Upload:   12500 KiB/s
Download: 12500 KiB/s
Max connections: 300
```

**Balanced (1/10th - 200 Mbps):** ⭐ **RECOMMENDED**
```
Upload:   25000 KiB/s
Download: 25000 KiB/s
Max connections: 500
```

**Aggressive (1/5th - 400 Mbps):**
```
Upload:   50000 KiB/s
Download: 50000 KiB/s
Max connections: 800
```

### Optimization Tips

#### 1. Connection Limits

Good for 2 Gbps:
```
Global connections: 500-800
Per torrent: 100-150
```

#### 2. Disk Cache

Reduce disk writes (good for SSDs):
```ini
DiskWriteCacheSize=128  # MB
DiskWriteCacheTTL=60    # seconds
```

#### 3. Upload/Download Ratio

For better performance, prioritize upload:
```
Upload: 25000 KiB/s (full 1/10th)
Download: 20000 KiB/s (slightly less)
```
This improves your ratio and often increases download speeds.

#### 4. Queue Settings

Don't download too many torrents simultaneously:
```
Maximum active downloads: 3-5
Maximum active uploads: 5-8
Maximum active torrents: 10
```

### Important Notes

1. **VPN Overhead:** VPN encryption adds ~5-10% overhead
2. **ISP Throttling:** Some ISPs may throttle VPN traffic
3. **Shared Connection:** Adjust limits if others use your internet
4. **Testing:** Start conservative and increase gradually
5. **Seeding:** Consider higher upload limits for good ratios

---

## 📊 Monitoring & Maintenance

### Monitoring

#### Check All Services

```bash
# Quick status
docker-compose ps

# View all logs
docker-compose logs -f

# Specific service logs
docker-compose logs -f sonarr
docker-compose logs -f radarr
docker-compose logs -f gluetun
```

#### Resource Usage

```bash
docker stats
```

#### Bandwidth Monitoring

**In qBittorrent Web UI:**
- Bottom status bar shows current speeds

**Via Docker Stats:**
```bash
docker stats qbittorrent
```

**Via System Tools:**
```bash
watch -n 1 "docker exec gluetun cat /sys/class/net/tun0/statistics/rx_bytes && docker exec gluetun cat /sys/class/net/tun0/statistics/tx_bytes"
```

### Maintenance

#### Update All Services

```bash
cd /path/to/arr-stack
docker-compose pull
docker-compose up -d
```

#### Backup Configuration

```bash
# Backup all *arr configs
tar -czf arr-stack-backup-$(date +%Y%m%d).tar.gz \
  ${DOCKER_VOLUMES_PATH}/{gluetun,qbittorrent,prowlarr,sonarr,radarr,lidarr,bazarr,jellyseerr}
```

#### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart sonarr

# Restart Gluetun (VPN)
docker-compose restart gluetun
```

#### Stop the Stack

```bash
docker-compose down
```

---

## 🚨 Troubleshooting

### VPN & Network Issues

#### VPN not connecting

```bash
# Check Gluetun logs
docker logs gluetun

# Common issues:
# - Invalid WIREGUARD_PRIVATE_KEY
# - NordVPN account issues
# - /dev/net/tun not available
```

#### VPN IP check shows local IP

VPN is not connected. Check Gluetun logs:
```bash
docker logs gluetun | grep -i "vpn\|connected\|error"
```

#### DNS leak detected

**Solution:**
1. Verify DoT is enabled:
   ```bash
   docker logs gluetun | grep "DNS over TLS"
   ```
2. Check DoT providers setting in `.env`
3. Restart: `docker-compose restart`

#### Kill switch not working

**Solution:**
1. Verify network mode in `docker-compose.yml`:
   ```yaml
   network_mode: "service:gluetun"
   ```
2. Don't add separate network configurations to qBittorrent
3. Run test: `./test-killswitch.sh`

### Service Issues

#### Service won't start

```bash
# Check logs
docker logs <service-name>

# Check permissions
ls -la ${DOCKER_VOLUMES_PATH}/<service>

# Fix permissions
sudo chown -R 1000:1000 ${DOCKER_VOLUMES_PATH}/<service>
```

#### Can't access qBittorrent web UI

```bash
# Verify containers running
docker ps | grep -E 'gluetun|qbittorrent'

# Check if port is listening
sudo netstat -tlnp | grep 8085

# Check qBittorrent logs
docker logs qbittorrent

# Verify Gluetun is running
docker ps | grep gluetun
```

Access via: http://localhost:8085

#### Can't connect to qBittorrent from *arr apps

- Verify Gluetun is running: `docker ps | grep gluetun`
- Check qBittorrent container: `docker ps | grep qbittorrent`
- In *arr apps, use host: `gluetun` or `localhost`
- Port: `8085`

### Download Issues

#### Downloads not starting

1. Check indexers in Prowlarr
2. Verify qBittorrent connection in *arr app
3. Check VPN connection: `./check-vpn.sh`
4. Review *arr logs for errors

#### Downloads not working / Permission errors

```bash
# Check permissions on downloads directory
ls -ld ${DOCKER_VOLUMES_PATH}/qbittorrent/downloads

# Fix permissions
sudo chown -R 1000:1000 ${DOCKER_VOLUMES_PATH}/qbittorrent
```

### FlareSolverr Issues

#### Indexer still failing with FlareSolverr

- Check Prowlarr/Jackett logs
- Increase timeout to 60s
- Verify FlareSolverr is running: `docker ps | grep flaresolverr`

#### FlareSolverr using too much CPU/RAM

- Only enable for indexers that need it
- Don't enable for all indexers

#### FlareSolverr not responding

```bash
# Restart FlareSolverr
docker-compose restart flaresolverr

# Check logs
docker logs flaresolverr
```

### Jellyseerr Issues

#### Can't connect to Sonarr/Radarr

- Use hostname `sonarr` or `radarr`, not `localhost`
- Verify API key is correct
- Ensure services are running: `docker ps`

#### Requests not processing

- Check if auto-approve is enabled
- Admin may need to manually approve
- Check Sonarr/Radarr logs for errors

#### Notifications not working

- Verify SMTP settings correct
- Test email from Jellyseerr settings
- Check spam folder

### General Troubleshooting

#### Finding PUID and PGID

```bash
# Get your user's PUID and PGID
id $USER

# Use these values in .env file
```

#### Fix all permissions

```bash
sudo chown -R 1000:1000 ${DOCKER_VOLUMES_PATH}/*
```

---

## 📚 Reference

### Environment Variables

All configuration via `.env` file:

#### VPN Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VPN_SERVICE_PROVIDER` | `nordvpn` | VPN provider |
| `VPN_TYPE` | `wireguard` | VPN protocol |
| `WIREGUARD_PRIVATE_KEY` | *required* | WireGuard private key |
| `WIREGUARD_ADDRESSES` | `10.5.0.2/32` | VPN interface address |
| `SERVER_COUNTRIES` | `Mexico` | VPN server country |
| `UPDATER_PERIOD` | `1h` | Server list update frequency |

#### DNS Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `DOT` | `on` | DNS over TLS enabled |
| `DOT_PROVIDERS` | `cloudflare` | DNS provider |
| `DNS_ADDRESS` | `127.0.0.1` | Gluetun's internal DNS |

#### qBittorrent Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `QBITTORRENT_WEBUI_PORT` | `8085` | Web UI port |
| `PUID` | `1000` | User ID for permissions |
| `PGID` | `1000` | Group ID for permissions |

#### FlareSolverr Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `FLARESOLVERR_PORT` | `8191` | FlareSolverr API port |
| `LOG_LEVEL` | `info` | Log level (info, debug, error) |
| `LOG_HTML` | `false` | Log HTML responses |
| `CAPTCHA_SOLVER` | `none` | Captcha solver option |

#### Jellyseerr Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `JELLYSEERR_PORT` | `5055` | Jellyseerr web UI port |
| `JELLYSEERR_LOG_LEVEL` | `info` | Log level |

### Directory Structure

**Updated in v2.0:** Unified `/data` mount structure for hardlink support.

```
${DOCKER_VOLUMES_PATH}/
├── gluetun/              # VPN configuration
├── qbittorrent/          # qBittorrent configuration only
├── prowlarr/             # Prowlarr configuration
├── sonarr/               # Sonarr configuration
├── radarr/               # Radarr configuration
├── lidarr/               # Lidarr configuration
├── bazarr/               # Bazarr configuration
├── jackett/              # Jackett configuration
├── flaresolverr/         # FlareSolverr (minimal data)
├── jellyseerr/           # Jellyseerr configuration
└── media/                # Unified media directory (shared by all services)
    ├── downloads/        # qBittorrent download location
    │   ├── tv/          # TV downloads (category: tv-sonarr)
    │   ├── movies/      # Movie downloads (category: movies-radarr)
    │   └── music/       # Music downloads (category: music-lidarr)
    ├── tv/              # Sonarr organized TV (hardlinked from downloads)
    ├── movies/          # Radarr organized movies (hardlinked from downloads)
    └── music/           # Lidarr organized music (hardlinked from downloads)
```

**Key Changes from Previous Version:**
- ❌ **Removed:** `${DOCKER_VOLUMES_PATH}/qbittorrent/downloads` 
- ✅ **Added:** `${DOCKER_VOLUMES_PATH}/media/downloads/{tv,movies,music}`
- ✅ **Changed:** All services mount `${DOCKER_VOLUMES_PATH}/media:/data`
- ✅ **Benefit:** Hardlinks eliminate file duplication while maintaining seeding

### Service URLs Quick Reference

```bash
qBittorrent:  http://localhost:8085
Prowlarr:     http://localhost:9696
Sonarr:       http://localhost:8989
Radarr:       http://localhost:7878
Lidarr:       http://localhost:8686
Bazarr:       http://localhost:6767
Jackett:      http://localhost:9117
FlareSolverr: http://localhost:8191
Jellyseerr:   http://localhost:5055
```

### Common Commands

```bash
# Start stack
docker-compose up -d

# Stop stack
docker-compose down

# View logs
docker-compose logs -f

# Restart service
docker-compose restart <service>

# Update all
docker-compose pull && docker-compose up -d

# Check VPN
./check-vpn.sh

# Test DNS leak
./test-dns-leak.sh

# Test kill switch
./test-killswitch.sh

# Reconnect VPN
./reconnect-vpn.sh

# Verify P2P server
./verify-p2p-server.sh

# Check status
docker-compose ps

# Resource usage
docker stats
```

### Portainer Deployment

When deploying via Portainer:

1. **Portainer → Stacks → Add Stack**
2. **Name:** `arr-stack`
3. **Upload or paste** `docker-compose.yml`
4. **Add environment variables:**
   - `DOCKER_VOLUMES_PATH`: `/opt/docker/volumes`
   - `WIREGUARD_PRIVATE_KEY`: Your private key
   - `TZ`: Your timezone
   - All other variables from `.env`
5. **Deploy**

### Security Features Summary

- ✅ VPN Protection: All traffic routes through Gluetun/NordVPN
- ✅ Kill Switch: Hardware-level via network mode
- ✅ DNS Leak Protection: DNS over TLS with Cloudflare
- ✅ Automatic restart: `unless-stopped` policy
- ✅ No privilege escalation: `no-new-privileges:true`
- ✅ P2P Optimized: NordVPN P2P servers
- ✅ Isolated Network: Services share Gluetun namespace
- ✅ Configurable via environment: No secrets in compose file

### Additional Resources

- [Gluetun Documentation](https://github.com/qdm12/gluetun-wiki)
- [NordVPN WireGuard Setup](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/nordvpn.md)
- [qBittorrent Documentation](https://github.com/qbittorrent/qBittorrent/wiki)
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Prowlarr Wiki](https://wiki.servarr.com/prowlarr)
- [TRaSH Guides](https://trash-guides.info/) - Quality profiles
- [LinuxServer.io qBittorrent](https://docs.linuxserver.io/images/docker-qbittorrent)

### Version Information

- **Stack Version:** `v2.0` (Hardlinks support)
- **Gluetun:** `v3.40.0` (Latest stable as of Oct 2025)
- **qBittorrent:** `5.1.2` (Latest stable as of Sept 2025)
- **Compose Version:** 3.9
- **Total Services:** 10 (all VPN protected)
- **Last Updated:** October 23, 2025

**What's New in v2.0:**
- ✨ Unified `/data` volume structure for hardlink support
- ✨ Eliminates file duplication (saves 50% disk space)
- ✨ Maintains seeding while organizing library
- ⚠️ Breaking change - requires migration (see [Migration Guide](#-migration-guide-upgrading-from-previous-version))

### Important Notes

1. **VPN Account Required:** Active NordVPN subscription needed
2. **Kill Switch:** qBittorrent cannot access internet without VPN (by design)
3. **Firewall Configuration:** You must open port 6881 (TCP+UDP) in UFW for optimal download speeds (see step 7 in Quick Start)
4. **Port Forwarding:** NordVPN doesn't support it; consider different provider if needed
5. **Legal Use:** Only download content you have legal right to download
5. **Active Downloads:** Brief interruption during VPN reconnections (auto-resume)
6. **Shared Connection:** Adjust bandwidth if others use your internet
7. **FlareSolverr:** Only for Cloudflare-protected indexers (adds latency)
8. **Jellyseerr:** Perfect for family sharing with request limits
9. **Hardlinks:** Require same filesystem - ensure `/data` is on single volume
10. **Migration:** Upgrading from v1.x? See [Migration Guide](#-migration-guide-upgrading-from-previous-version)

---

**🎉 Your complete arr-stack documentation - everything in one place!**
