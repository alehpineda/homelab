#!/bin/bash
#
# Pinchflat + Gluetun VPN Stack Setup Script
# This script prepares the required directories and configuration files
#

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Pinchflat + Gluetun VPN Stack Setup ===${NC}\n"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo "Please create .env from .env.example:"
    echo "  cp .env.example .env"
    echo "  nano .env  # Edit with your values"
    exit 1
fi

# Source the .env file to get DOCKER_VOLUMES_PATH
source .env

# Validate DOCKER_VOLUMES_PATH is set
if [ -z "$DOCKER_VOLUMES_PATH" ]; then
    echo -e "${RED}ERROR: DOCKER_VOLUMES_PATH not set in .env file${NC}"
    exit 1
fi

echo -e "${YELLOW}Using DOCKER_VOLUMES_PATH: ${DOCKER_VOLUMES_PATH}${NC}\n"

# Create Gluetun volume directory structure
echo "Creating volume directories..."
mkdir -p "${DOCKER_VOLUMES_PATH}/gluetun-pinchflat/auth"
mkdir -p "${DOCKER_VOLUMES_PATH}/pinchflat"
mkdir -p "${DOCKER_VOLUMES_PATH}/media/youtube"

echo -e "${GREEN}✓${NC} Volume directories created"

# Copy auth-config.toml to volume
if [ -f "auth-config.toml" ]; then
    echo "Copying auth-config.toml..."
    cp auth-config.toml "${DOCKER_VOLUMES_PATH}/gluetun-pinchflat/auth/config.toml"
    echo -e "${GREEN}✓${NC} Auth config copied to: ${DOCKER_VOLUMES_PATH}/gluetun-pinchflat/auth/config.toml"
else
    echo -e "${RED}ERROR: auth-config.toml not found in current directory${NC}"
    exit 1
fi

# Set proper permissions
echo "Setting permissions..."
if [ "$(id -u)" = "0" ]; then
    # Running as root, set ownership based on PUID/PGID from .env
    PUID=${PUID:-1000}
    PGID=${PGID:-1000}
    chown -R ${PUID}:${PGID} "${DOCKER_VOLUMES_PATH}/gluetun-pinchflat"
    chown -R ${PUID}:${PGID} "${DOCKER_VOLUMES_PATH}/pinchflat"
    chown -R ${PUID}:${PGID} "${DOCKER_VOLUMES_PATH}/media/youtube"
    echo -e "${GREEN}✓${NC} Permissions set (PUID=${PUID}, PGID=${PGID})"
else
    echo -e "${YELLOW}⚠${NC} Not running as root, skipping permission changes"
    echo "  If you encounter permission issues, run: sudo chown -R ${PUID:-1000}:${PGID:-1000} ${DOCKER_VOLUMES_PATH}/{gluetun-pinchflat,pinchflat,media}"
fi

echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
echo -e "\nYou can now start the stack with:"
echo -e "  ${YELLOW}docker-compose up -d${NC}\n"
echo -e "Access Pinchflat at: ${YELLOW}http://localhost:${PINCHFLAT_PORT:-8945}${NC}\n"
