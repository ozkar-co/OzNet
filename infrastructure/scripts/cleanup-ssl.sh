#!/bin/bash

# OzNet SSL Cleanup Script
# Removes all internal SSL certificates and related infrastructure

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

log "Starting SSL cleanup..."

# Stop oznet-ssl service if running
if systemctl is-active --quiet oznet-ssl 2>/dev/null; then
    log "Stopping oznet-ssl service..."
    sudo systemctl stop oznet-ssl || warn "Failed to stop oznet-ssl"
fi

# Disable oznet-ssl service if enabled
if systemctl is-enabled --quiet oznet-ssl 2>/dev/null; then
    log "Disabling oznet-ssl service..."
    sudo systemctl disable oznet-ssl || warn "Failed to disable oznet-ssl"
fi

# Remove systemd service file
if [ -f /etc/systemd/system/oznet-ssl.service ]; then
    log "Removing oznet-ssl systemd service..."
    sudo rm -f /etc/systemd/system/oznet-ssl.service
fi

# Remove SSL certificates and CA infrastructure
if [ -d /etc/ssl/oznet ]; then
    log "Removing server SSL certificates..."
    sudo rm -rf /etc/ssl/oznet
fi

if [ -d /etc/ssl/oznet-ca ]; then
    log "Removing CA infrastructure..."
    sudo rm -rf /etc/ssl/oznet-ca
fi

# Remove client certificate distribution
if [ -d /var/oznet/certs ]; then
    log "Removing client certificate distribution..."
    sudo rm -rf /var/oznet/certs
fi

# Reload systemd
log "Reloading systemd..."
sudo systemctl daemon-reload || warn "Failed to reload systemd"

log "✓ SSL cleanup completed!"
echo
echo -e "${GREEN}Reason for removal:${NC}"
echo "  • Cloudflare Tunnel handles all TLS/SSL termination"
echo "  • No need for internal certificates"
echo "  • Public services access through Cloudflare's trusted certificates"
echo "  • Internal services (ZeroTier/VPN) don't require HTTPS"
