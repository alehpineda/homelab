# Homelab Infrastructure as Code

Docker Compose stacks, plus a Terraform (Proxmox LXC) and Ansible skeleton for the BRL node. Compose files under `docker/` are unchanged by the skeleton. The Terraform module does not manage live guests yet.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Deployed Services](#deployed-services)
- [Environment Configuration](#environment-configuration)
- [Deployment](#deployment)
- [Proxmox (BRL)](#proxmox-brl)
- [Ansible](#ansible)
- [Backup & Restore](#backup--restore)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Overview

This repository contains Infrastructure as Code (IaC) for deploying and managing containerized services in a homelab environment. It uses:

- **Docker Compose** for container orchestration (existing stacks under `docker/`)
- **Terraform** with the Telmate Proxmox provider for LXC lifecycle on BRL (skeleton only; no guests declared)
- **Ansible** for guest connectivity checks now, and configuration later ([ansible/README.md](ansible/README.md))
- **Environment-based configuration** for multi-environment support (local, staging, production)

## 🔧 Prerequisites

### Required Software

- **Docker Engine**: 20.10 or higher
- **Docker Compose**: 2.0 or higher
- **Git**: For version control
- **Terraform**: 1.5 or higher (optional; Proxmox skeleton under `terraform/proxmox/`)
- **Ansible**: 2.14 or higher (optional; stub playbooks under `ansible/`)

### System Requirements

- Linux-based OS (tested on Ubuntu/Debian)
- Minimum 2GB RAM
- 10GB free disk space (more depending on services)

### Installation

```bash
# Docker & Docker Compose (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect

# Verify installation
docker --version
docker-compose --version
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/alehpineda/homelab.git
cd homelab
```

### 2. Configure Environment

```bash
# Copy the environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

**Important**: Set `DOCKER_VOLUMES_PATH` to your preferred location:
- **Local**: `/home/yourusername/Documents/07_Containers/00_docker/volumes`
- **Staging**: `/opt/docker/volumes` or `/srv/docker/volumes`

### 3. Create Volume Directory

```bash
# Create the base volumes directory
mkdir -p ${DOCKER_VOLUMES_PATH}

# Or specify the full path
mkdir -p /home/yourusername/Documents/07_Containers/00_docker/volumes
```

### 4. Deploy Your First Service (Portainer)

```bash
cd docker/portainer
docker-compose up -d
```

Access Portainer at: http://localhost:9000

## 📁 Project Structure

```
homelab/
├── .env                      # Environment configuration (gitignored)
├── .env.example              # Environment template (commit this)
├── .gitignore                # Git ignore rules
├── README.md                 # This file
├── LICENSE                   # Project license
│
├── ansible/                  # Guest connectivity stub (see ansible/README.md)
│   ├── ansible.cfg
│   ├── inventory/            # blr.yml.example; copy to gitignored blr.yml
│   ├── group_vars/           # all.yml.example
│   ├── playbooks/            # ping.yml and site.yml
│   └── roles/                # Empty until a later plan
│
├── terraform/proxmox/        # Telmate/proxmox skeleton (no guests enabled)
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf               # Commented LXC example only
│   └── README.md
│
├── docs/                     # BRL facts and the LXC change runbook
│   ├── blr.md
│   └── runbooks/lxc-change.md
│
└── docker/                   # Docker Compose files (left as-is)
    ├── portainer/
    ├── arr-stack/
    ├── arr-stack-v2/
    ├── media-player/
    ├── pinchflat-vpn/
    └── samba/
```

### Volume Organization

All persistent data is stored in `${DOCKER_VOLUMES_PATH}`:

```
${DOCKER_VOLUMES_PATH}/
├── portainer_data/          # Portainer configuration and data
├── nginx_data/              # (Example) Nginx data
├── postgres_data/           # (Example) PostgreSQL data
└── ...
```

## 🐳 Deployed Services

| Service | Port(s) | Description | Status |
|---------|---------|-------------|--------|
| [Portainer CE](docker/portainer/) | 9000 (HTTP)<br>9443 (HTTPS) | Container management platform | ✅ Active |

## ⚙️ Environment Configuration

### Environment Variables

All services are configured via the root `.env` file. Never commit this file to version control!

#### Core Variables

```bash
# Volume paths (required)
DOCKER_VOLUMES_PATH=/path/to/docker/volumes

# Global settings
TZ=UTC  # Your timezone (e.g., America/New_York, Europe/London)
```

#### Service-Specific Variables

See individual service READMEs in `docker/<service>/README.md` for service-specific configuration options.

### Multi-Environment Support

For different environments, use different `.env` files:

```bash
# Local development
.env

# Staging server
.env.staging

# Production server
.env.production
```

Load the appropriate file:
```bash
# Local (uses .env by default)
docker-compose up -d

# Staging
docker-compose --env-file .env.staging up -d
```

## 🚢 Deployment

### Local Development

```bash
# Navigate to service directory
cd docker/<service-name>

# Start service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop service
docker-compose down
```

### Staging/Production

#### Manual Deployment

1. **Prepare the server**:
   ```bash
   # Create volumes directory
   sudo mkdir -p /opt/docker/volumes
   sudo chown -R $USER:$USER /opt/docker/volumes
   
   # Clone repository
   git clone https://github.com/alehpineda/homelab.git /opt/homelab
   cd /opt/homelab
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   nano .env  # Set DOCKER_VOLUMES_PATH=/opt/docker/volumes
   ```

3. **Deploy services**:
   ```bash
   cd docker/portainer
   docker-compose up -d
   ```

#### Ansible

The checked-in playbooks are a connectivity stub, not a Compose deployer.
They do not replace the Docker quick start above.

```bash
cd ansible
cp inventory/blr.yml.example inventory/blr.yml
ansible-playbook --syntax-check playbooks/site.yml
```

Details, including SSH port 4488 on hosts hardened by `alehpineda/ansible-playbooks`
versus port 22 on a fresh LXC: [ansible/README.md](ansible/README.md).

## Proxmox (BRL)

LXC lifecycle for node `barbatoslupusrex` lives in [terraform/proxmox](terraform/proxmox/README.md).
The module pins Telmate/proxmox and ships with **no** live `proxmox_lxc` resources.
Do not `terraform apply` a create or destroy from this skeleton.

Public facts (LAN `10.10.0.21`, NetBird `100.85.104.18`, CTIDs 100–113, no secrets):
[docs/blr.md](docs/blr.md). Change order when a later plan is approved:
[docs/runbooks/lxc-change.md](docs/runbooks/lxc-change.md).

```bash
cd terraform/proxmox
terraform fmt -check
terraform init -backend=false
terraform validate
```

`validate` does not need API credentials. Keep `PM_API_URL`, `PM_API_TOKEN_ID`,
and `PM_API_TOKEN_SECRET` in the environment when you eventually plan.

## 💾 Backup & Restore

### Backup All Volumes

```bash
#!/bin/bash
# backup.sh
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"

mkdir -p $BACKUP_DIR

# Backup all volumes
tar -czf $BACKUP_DIR/homelab_volumes_$BACKUP_DATE.tar.gz \
  ${DOCKER_VOLUMES_PATH}

echo "Backup completed: $BACKUP_DIR/homelab_volumes_$BACKUP_DATE.tar.gz"
```

### Restore from Backup

```bash
# Stop all services first
cd docker/portainer && docker-compose down

# Restore volumes
tar -xzf /backups/homelab_volumes_YYYYMMDD_HHMMSS.tar.gz \
  -C /path/to/restore/location

# Restart services
docker-compose up -d
```

### Automated Backups

Add to crontab for automated daily backups:
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/homelab/scripts/backup.sh
```

## 🔍 Troubleshooting

### Common Issues

#### Services won't start
```bash
# Check if ports are already in use
sudo netstat -tlnp | grep <port>

# Check Docker daemon status
sudo systemctl status docker

# View service logs
cd docker/<service>
docker-compose logs --tail=50
```

#### Permission denied errors
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, then verify
groups | grep docker
```

#### Volume path issues
```bash
# Verify DOCKER_VOLUMES_PATH is set correctly
echo $DOCKER_VOLUMES_PATH

# Check if directory exists and is writable
ls -ld ${DOCKER_VOLUMES_PATH}

# Create if missing
mkdir -p ${DOCKER_VOLUMES_PATH}
```

#### Environment variables not loading
```bash
# Ensure .env is in the correct location (repository root)
ls -la .env

# Load manually for testing
export $(cat .env | grep -v '^#' | xargs)

# Verify variables are set
echo $DOCKER_VOLUMES_PATH
```

### Getting Help

1. Check service-specific README in `docker/<service>/README.md`
2. Review Docker logs: `docker-compose logs -f <service>`
3. Check Docker daemon logs: `sudo journalctl -u docker`
4. Open an issue on GitHub

## 🛡️ Security Best Practices

- ✅ Never commit `.env` files with secrets
- ✅ Use strong passwords for all services
- ✅ Keep Docker and services updated
- ✅ Use reverse proxy with SSL/TLS for production
- ✅ Implement firewall rules (UFW/iptables)
- ✅ Regular backups of critical data
- ✅ Minimize exposed ports
- ⚠️ Avoid giving containers unnecessary Docker socket access

## 🤝 Contributing

This is a personal homelab repository, but suggestions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

See [LICENSE](LICENSE) file for details.

## 🔗 Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Ansible Documentation](https://docs.ansible.com/)
- [r/selfhosted](https://reddit.com/r/selfhosted) - Community for self-hosting enthusiasts

---

**Last Updated**: October 31, 2026  
**Maintained by**: [@alehpineda](https://github.com/alehpineda)
