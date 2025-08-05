#!/bin/bash

# OzNet Setup Script
# This script automates the installation and configuration of OzNet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Update system
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
}

# Install dependencies
install_dependencies() {
    log "Installing system dependencies..."
    apt install -y curl wget git build-essential dnsmasq nginx certbot python3-certbot-nginx
}

# Install Node.js
install_nodejs() {
    log "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    
    # Verify installation
    node --version
    npm --version
}

# Install ZeroTier
install_zerotier() {
    log "Installing ZeroTier..."
    curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg' | gpg --import && \
    if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | bash; fi
    
    # Start ZeroTier service
    systemctl enable zerotier-one
    systemctl start zerotier-one
}

# Configure ZeroTier network
configure_zerotier() {
    log "Configuring ZeroTier network..."
    zerotier-cli join 9bee8941b563441a
    
    log "Please authorize this device in the ZeroTier network management interface"
    log "Network ID: 9bee8941b563441a"
    read -p "Press Enter after authorizing the device..."
}

# Configure DNS
configure_dns() {
    log "Configuring DNS (dnsmasq)..."
    
    # Create dnsmasq configuration directory if it doesn't exist
    mkdir -p /etc/dnsmasq.d
    
    # Create OzNet configuration file
    cat > /etc/dnsmasq.d/oznet.conf << EOF
# Dominio personalizado
domain=oznet

# Entradas personalizadas
address=/home.oznet/172.26.0.1
address=/hub.oznet/172.26.0.1
address=/files.oznet/172.26.0.1
address=/server.oznet/172.26.0.1
address=/mail.oznet/172.26.0.1
address=/wiki.oznet/172.26.0.1
address=/3dprint.oznet/172.26.0.1

# Asegura que escuche en la interfaz ZeroTier
interface=zt+  # "zt" es el prefijo de interfaces ZeroTier
listen-address=172.26.0.1

# DNS servers for external queries
server=8.8.8.8
server=1.1.1.1
server=8.8.4.4

# Cache configuration
cache-size=1000
neg-ttl=3600
local-ttl=3600

# Logging
log-queries
log-facility=/var/log/dnsmasq.log
EOF
    
    # Restart dnsmasq
    systemctl restart dnsmasq
    systemctl enable dnsmasq
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Run SSL persistence fix to ensure proper certificate setup
    log "Setting up SSL certificates with persistence..."
    bash scripts/fix-ssl-persistence.sh --all
    
    # Copy Nginx configuration
    cp config/nginx.conf /etc/nginx/sites-available/oznet
    
    # Enable site
    ln -sf /etc/nginx/sites-available/oznet /etc/nginx/sites-enabled/
    
    # Test configuration
    nginx -t
    
    # Restart Nginx
    systemctl restart nginx
    systemctl enable nginx
}

# Create directories
create_directories() {
    log "Creating OzNet directories..."
    
    mkdir -p /var/oznet/{files,logs,static}
    mkdir -p /var/log/oznet
    
    # Set permissions
    chown -R www-data:www-data /var/oznet
    chmod -R 755 /var/oznet
}

# Install OzNet application
install_oznet() {
    log "Installing OzNet application..."
    
    # Install Node.js dependencies
    npm install
    
    # Create systemd service
    cat > /etc/systemd/system/oznet.service << EOF
[Unit]
Description=OzNet Web Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$(pwd)
Environment=NODE_ENV=production
Environment=FILES_ROOT=/var/oznet/files
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable oznet
    systemctl start oznet
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP/HTTPS
    ufw allow 80
    ufw allow 443
    
    # Allow DNS
    ufw allow 53
    
    # Allow ZeroTier
    ufw allow 9993
    
    # Enable firewall
    ufw --force enable
}

# Create environment file
create_env() {
    log "Creating environment configuration..."
    
    cat > .env << EOF
PORT=3000
FILES_ROOT=/var/oznet/files
NODE_ENV=production
EOF
}

# Test installation
test_installation() {
    log "Testing installation..."
    
    # Check if services are running
    systemctl is-active --quiet oznet && log "✓ OzNet service is running" || error "✗ OzNet service is not running"
    systemctl is-active --quiet dnsmasq && log "✓ DNS service is running" || error "✗ DNS service is not running"
    systemctl is-active --quiet nginx && log "✓ Nginx service is running" || error "✗ Nginx service is not running"
    systemctl is-active --quiet zerotier-one && log "✓ ZeroTier service is running" || error "✗ ZeroTier service is not running"
    
    # Test DNS resolution
    if nslookup home.oznet 127.0.0.1 > /dev/null 2>&1; then
        log "✓ DNS resolution is working"
    else
        warn "✗ DNS resolution may not be working"
    fi
    
    # Test web server
    if curl -s http://localhost:3000 > /dev/null; then
        log "✓ Web server is responding"
    else
        warn "✗ Web server may not be responding"
    fi
}

# Display final information
display_info() {
    log "Installation completed successfully!"
    echo
    echo -e "${BLUE}=== OzNet Installation Summary ===${NC}"
    echo
    echo -e "${GREEN}Services:${NC}"
    echo "  • home.oznet - Documentation"
    echo "  • hub.oznet - Service management"
    echo "  • files.oznet - File server"
    echo "  • server.oznet - Main server"
    echo
    echo -e "${GREEN}Network Information:${NC}"
    echo "  • ZeroTier Network ID: 9bee8941b563441a"
    echo "  • DNS Server: 172.26.0.1"
    echo "  • Web Server: Port 3000"
    echo
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Configure your devices to use DNS: 172.26.0.1"
    echo "  2. Join the ZeroTier network on your devices"
    echo "  3. Access services at: http://home.oznet"
    echo
    echo -e "${YELLOW}For support, check the documentation at: http://home.oznet/docs${NC}"
}

# Main installation function
main() {
    log "Starting OzNet installation..."
    
    check_root
    update_system
    install_dependencies
    install_nodejs
    install_zerotier
    configure_zerotier
    configure_dns
    configure_nginx
    create_directories
    create_env
    install_oznet
    configure_firewall
    test_installation
    display_info
}

# Run main function
main "$@" 