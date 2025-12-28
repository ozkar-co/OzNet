#!/bin/bash

# OzNet Nginx Cleanup Script
# Removes all Nginx configurations and services from OzNet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

log "Starting Nginx cleanup..."

# Stop nginx if running
if systemctl is-active --quiet nginx 2>/dev/null; then
    log "Stopping nginx service..."
    sudo systemctl stop nginx || warn "Failed to stop nginx"
fi

# Disable nginx if enabled
if systemctl is-enabled --quiet nginx 2>/dev/null; then
    log "Disabling nginx service..."
    sudo systemctl disable nginx || warn "Failed to disable nginx"
fi

# Remove nginx configuration files
if [ -f /etc/nginx/sites-available/oznet ]; then
    log "Removing nginx site configuration..."
    sudo rm -f /etc/nginx/sites-available/oznet
fi

if [ -L /etc/nginx/sites-enabled/oznet ]; then
    log "Removing nginx site symlink..."
    sudo rm -f /etc/nginx/sites-enabled/oznet
fi

# Remove nginx override for oznet-ssl dependency
if [ -d /etc/systemd/system/nginx.service.d ]; then
    log "Removing nginx service overrides..."
    sudo rm -rf /etc/systemd/system/nginx.service.d
fi

# Reload systemd
log "Reloading systemd..."
sudo systemctl daemon-reload || warn "Failed to reload systemd"

log "✓ Nginx cleanup completed!"
echo
echo -e "${YELLOW}Note: Nginx package is still installed but no longer configured for OzNet${NC}"
echo -e "${YELLOW}You can uninstall it with: sudo apt remove nginx (or equivalent)${NC}"
echo
echo -e "${GREEN}Reason for removal:${NC}"
echo "  • OzNet now uses Cloudflare Tunnel for public access"
echo "  • Cloudflare handles all TLS/SSL termination"
echo "  • No need for local reverse proxy"
