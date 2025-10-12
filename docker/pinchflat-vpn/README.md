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

1. **Copy the environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your values:**
   ```bash
   nano .env
   ```
   
   Required changes:
   - `DOCKER_VOLUMES_PATH`: Path where Docker volumes will be stored
   - `WIREGUARD_PRIVATE_KEY`: Your WireGuard private key
   - `TZ`: Your timezone (e.g., `America/New_York`, `Europe/London`)
   - `SERVER_COUNTRIES`: VPN server country (optional)

3. **Start the stack:**
   ```bash
   docker-compose up -d
   ```

4. **Access Pinchflat:**
   - Open your browser to: `http://localhost:8945`

## 📁 Directory Structure

```
pinchflat-vpn/
├── docker-compose.yml    # Main compose file
├── .env                  # Your environment variables (not committed)
├── .env.example          # Example environment file
└── README.md            # This file
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
| `DOT` | Enable DNS over TLS | `on` | ❌ |
| `DOT_PROVIDERS` | DoT provider | `cloudflare` | ❌ |
| `DNS_ADDRESS` | Internal DNS address | `127.0.0.1` | ❌ |
| `PINCHFLAT_PORT` | Pinchflat web UI port | `8945` | ❌ |

### Volume Mappings

The stack creates the following volumes:

- `${DOCKER_VOLUMES_PATH}/gluetun-pinchflat:/gluetun` - Gluetun configuration
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
