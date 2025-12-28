#!/bin/bash

# OzNet DNS Cleanup Script
# Trims DNS configuration to only essential entries

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

log "Starting DNS cleanup..."

# Backup existing DNS configuration
if [ -f /etc/dnsmasq.d/oznet.conf ]; then
    BACKUP_FILE="/etc/dnsmasq.d/oznet.conf.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backing up existing configuration to $BACKUP_FILE..."
    sudo cp /etc/dnsmasq.d/oznet.conf "$BACKUP_FILE"
fi

# Create minimal DNS configuration
log "Creating minimal DNS configuration..."
sudo tee /etc/dnsmasq.d/oznet.conf > /dev/null << 'EOF'
# dnsmasq minimal configuration for OzNet
# Only for ZeroTier, VPN, and game servers - NO public HTTP services

# Basic configuration
port=53
domain-needed
bogus-priv
no-resolv
no-poll

# DNS servers for external queries
server=8.8.8.8
server=1.1.1.1
server=8.8.4.4

# OzNet domain configuration
domain=oznet

# Essential service mappings (internal access only)
address=/home.oznet/172.26.0.1
address=/server.oznet/172.26.0.2

# ZeroTier interface configuration
interface=zt+
listen-address=172.26.0.1

# Cache configuration
cache-size=1000
neg-ttl=3600
local-ttl=3600

# Logging
log-queries
log-facility=/var/log/dnsmasq.log
EOF

# Restart dnsmasq if running
if systemctl is-active --quiet dnsmasq 2>/dev/null; then
    log "Restarting dnsmasq service..."
    sudo systemctl restart dnsmasq || warn "Failed to restart dnsmasq"
fi

log "✓ DNS cleanup completed!"
echo
echo -e "${GREEN}DNS entries retained:${NC}"
echo "  • 172.26.0.1 → home.oznet"
echo "  • 172.26.0.2 → server.oznet"
echo
echo -e "${GREEN}Usage:${NC}"
echo "  • ZeroTier network access"
echo "  • VPN connections"
echo "  • Game servers"
echo
echo -e "${YELLOW}Removed DNS entries:${NC}"
echo "  • hub.oznet (service moved to external repository)"
echo "  • files.oznet (service moved to external repository)"
echo "  • mail.oznet (service moved to external repository)"
echo "  • wiki.oznet (service moved to external repository)"
echo "  • 3dprint.oznet (service moved to external repository)"
echo "  • cam.oznet (service moved to external repository)"
echo
echo -e "${GREEN}Public access:${NC}"
echo "  • All public services now accessible through Cloudflare Tunnel"
echo "  • Using public domain with Cloudflare-managed SSL"
