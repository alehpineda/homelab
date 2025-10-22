# Pinchflat + Gluetun VPN Stack

A Docker Compose stack that runs [Pinchflat](https://github.com/kieraneglin/pinchflat) (YouTube media manager) through a secure VPN connection using [Gluetun](https://github.com/qdm12/gluetun).

## 📋 Overview

This stack provides:
- **Pinchflat**: Automated YouTube channel downloader and media manager
- **Gluetun**: VPN client supporting multiple VPN providers with kill-switch functionality
- **DNS Leak Protection**: DNS-over-TLS (DoT) with Cloudflare
- **Isolated Network**: All Pinchflat traffic routed through the VPN

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- VPN subscription (currently configured for NordVPN)
- WireGuard private key from your VPN provider

### Installation

1. **Copy and edit the environment file:**
   ```bash
   cp .env.example .env
   nano .env  # Edit with your values
   ```
   
   Required changes:
   - `DOCKER_VOLUMES_PATH`: Path where Docker volumes will be stored
   - `WIREGUARD_PRIVATE_KEY`: Your WireGuard private key
   - `TZ`: Your timezone (e.g., `America/New_York`, `Europe/London`)
   - `SERVER_COUNTRIES`: VPN server country (optional)

2. **Start the stack:**
   ```bash
   docker-compose up -d
   ```

3. **Access Pinchflat:**
   - Open your browser to: `http://localhost:8945`

## 📁 Directory Structure

```
pinchflat-vpn/
├── docker-compose.yml    # Main compose file
├── auth-config.toml      # Gluetun control server auth whitelist (required - bind-mounted)
├── .env                  # Your environment variables (not committed)
├── .env.example          # Example environment file
├── README.md             # This file
└── [rotation scripts]    # VPN rotation scripts

Volume structure (auto-created):
${DOCKER_VOLUMES_PATH}/
├── gluetun-pinchflat/    # Gluetun config and data
├── pinchflat/            # Pinchflat config
└── media/
    └── youtube/          # Downloaded media
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DOCKER_VOLUMES_PATH` | Base path for Docker volumes | - | ✅ |
| `TZ` | Timezone | `UTC` | ✅ |
| `PUID` | User ID for file permissions | `1000` | ✅ |
| `PGID` | Group ID for file permissions | `1000` | ✅ |
| `VPN_SERVICE_PROVIDER` | VPN provider name | `nordvpn` | ✅ |
| `VPN_TYPE` | VPN protocol type | `wireguard` | ✅ |
| `WIREGUARD_PRIVATE_KEY` | Your WireGuard private key | - | ✅ |
| `WIREGUARD_ADDRESSES` | VPN IP address | `10.5.0.2/32` | ✅ |
| `SERVER_COUNTRIES` | VPN server country | `United States` | ❌ |
| `SERVER_CATEGORIES` | VPN server category | `Standard VPN servers` | ❌ |
| `UPDATER_PERIOD` | How often to check for VPN updates | `24h` | ❌ |
| `VPN_PORT_FORWARDING` | Enable port forwarding | `off` | ❌ |
| `DOT` | Enable DNS over TLS | `on` | ❌ |
| `DOT_PROVIDERS` | DoT provider | `cloudflare` | ❌ |
| `DNS_ADDRESS` | Internal DNS address | `127.0.0.1` | ❌ |
| `PINCHFLAT_PORT` | Pinchflat web UI port | `8945` | ❌ |
| `GLUETUN_CONTROL_PORT` | Gluetun HTTP control server port | `8000` | ❌ |

### Volume Mappings

The stack creates the following volumes:

- `${DOCKER_VOLUMES_PATH}/gluetun-pinchflat:/gluetun` - Gluetun configuration and data
- `./auth-config.toml:/gluetun/auth/config.toml:ro` - Auth config (read-only bind mount)
- `${DOCKER_VOLUMES_PATH}/pinchflat:/config` - Pinchflat configuration
- `${DOCKER_VOLUMES_PATH}/media/youtube:/downloads` - Downloaded media

## 🔒 Security Features

### VPN Kill-Switch
All traffic from Pinchflat is routed through Gluetun. If the VPN connection drops, Pinchflat loses internet connectivity, preventing IP leaks.

### DNS Leak Protection
- DNS-over-TLS (DoT) enabled by default
- Uses Cloudflare DNS servers
- Prevents DNS queries from leaking outside the VPN tunnel

### Container Security
- `no-new-privileges:true` security option
- Non-root user execution (PUID/PGID)
- Network isolation via service networking

### Startup Dependencies
- Pinchflat waits for Gluetun to be healthy before starting
- Health check ensures VPN connection is established via HTTP control server
- Automatic 30-second grace period for VPN tunnel establishment
- **IMPORTANT**: `HTTP_CONTROL_SERVER_ADDRESS` must be enabled for healthcheck to work

### HTTP Control Server
The Gluetun HTTP control server runs on port 8000 and provides:
- **Health monitoring**: Healthcheck endpoint for Docker to verify VPN is connected
- **API access**: Programmatic control for rotation and management
- **Status queries**: Check VPN status, IP, and connection details

**Authentication**: Starting with Gluetun v3.40.0, the control server requires authentication by default. This stack uses an `auth-config.toml` file (bind-mounted from the repo) to whitelist the `/v1/publicip/ip` endpoint for Docker healthchecks while maintaining security on other endpoints. Port 8000 is not exposed externally for security.

**Note**: This is separate from `HTTPPROXY` (which is an HTTP proxy feature). The control server is required for the healthcheck to function properly.

## 🔄 VPN IP Rotation (Anti-Rate Limiting)

To avoid IP-based rate limiting from YouTube, you can set up automatic VPN IP rotation.

### Option 1: Manual Rotation Script

Use the provided script to manually rotate your VPN IP:

```bash
# Run the rotation script
./rotate-vpn-ip.sh
```

This script:
1. Checks current VPN IP
2. Restarts Gluetun container
3. Waits 30 seconds for reconnection
4. Verifies new IP address
5. Ensures Pinchflat restarts properly

### Option 2: Automated Hourly Rotation (Recommended)

Deploy automated VPN rotation using Ansible:

```bash
# From homelab/ansible directory
ansible-playbook playbooks/configure-pinchflat-vpn-rotation.yml
```

This configures:
- ✅ Hourly cron job for VPN rotation
- ✅ Automatic IP rotation every 60 minutes
- ✅ Logging to `/var/log/pinchflat-vpn-rotation.log`
- ✅ Log rotation (7 days retention)

**View rotation logs:**
```bash
# Real-time monitoring
tail -f /var/log/pinchflat-vpn-rotation.log

# Recent rotations
tail -30 /var/log/pinchflat-vpn-rotation.log
```

**Disable rotation:**
```bash
# Remove cron job
crontab -e
# Delete the line: 0 * * * * cd /opt/docker/pinchflat-vpn && ./rotate-vpn-ip.sh
```

### Option 3: Gluetun Control Server (Advanced)

Gluetun exposes a control server on port 8000 for programmatic control:

```bash
# Get current VPN IP
curl http://localhost:8000/v1/publicip/ip

# Get VPN status
curl http://localhost:8000/v1/openvpn/status
```

You can build custom rotation logic using this API.

## 🛠️ Management Commands

### Start the stack
```bash
docker-compose up -d
```

### Stop the stack
```bash
docker-compose down
```

### View logs
```bash
# All services
docker-compose logs -f

# Gluetun only
docker-compose logs -f gluetun

# Pinchflat only
docker-compose logs -f pinchflat
```

### Restart services
```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart gluetun
docker-compose restart pinchflat
```

### Update images
```bash
docker-compose pull
docker-compose up -d
```

## 🧪 Verification

### Check VPN Connection
```bash
# Check Gluetun logs for successful connection
docker-compose logs gluetun | grep "Connected"

# Verify VPN IP (should show VPN server IP, not your real IP)
docker exec gluetun-pinchflat wget -qO- https://ipinfo.io/ip
```

### Test DNS Leak Protection
```bash
# Check DNS settings
docker exec gluetun-pinchflat cat /etc/resolv.conf
```

### Access Pinchflat UI
Navigate to `http://localhost:8945` in your browser. If you can access the UI, the stack is running correctly.

## 🔧 Troubleshooting

### Pinchflat can't connect to the internet
1. Check Gluetun logs: `docker-compose logs gluetun`
2. Verify VPN credentials in `.env`
3. Ensure VPN service is not blocked by your ISP

### VPN keeps disconnecting
1. Try a different `SERVER_COUNTRIES` value
2. Check your VPN subscription status
3. Verify your `WIREGUARD_PRIVATE_KEY` is correct

### Permission issues with downloads
1. Check PUID/PGID match your user:
   ```bash
   id
   ```
2. Update `.env` with correct values
3. Restart stack: `docker-compose down && docker-compose up -d`

### Port already in use
If port 8945 is already taken:
1. Change `PINCHFLAT_PORT` in `.env`
2. Restart: `docker-compose down && docker-compose up -d`

## 📚 Additional Resources

- [Pinchflat Documentation](https://github.com/kieraneglin/pinchflat)
- [Gluetun Documentation](https://github.com/qdm12/gluetun)
- [Gluetun VPN Provider Setup](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
- [WireGuard Setup Guide](https://www.wireguard.com/quickstart/)

## 🤝 Support

For issues specific to:
- **Pinchflat**: [Pinchflat Issues](https://github.com/kieraneglin/pinchflat/issues)
- **Gluetun**: [Gluetun Issues](https://github.com/qdm12/gluetun/issues)
- **This stack**: Open an issue in this repository

## 📝 License

This configuration is provided as-is. See individual project licenses:
- [Pinchflat License](https://github.com/kieraneglin/pinchflat/blob/main/LICENSE)
- [Gluetun License](https://github.com/qdm12/gluetun/blob/master/LICENSE)
