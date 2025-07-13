#!/bin/bash

# OzNet Configuration Update Script
# This script updates server configurations from the local repository

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

# Backup existing configuration
backup_config() {
    local config_file="$1"
    local backup_dir="/etc/oznet/backups"
    
    if [[ -f "$config_file" ]]; then
        mkdir -p "$backup_dir"
        local timestamp=$(date +'%Y%m%d_%H%M%S')
        local backup_file="$backup_dir/$(basename "$config_file").$timestamp"
        cp "$config_file" "$backup_file"
        log "Backed up $config_file to $backup_file"
    fi
}

# Update Nginx configuration
update_nginx() {
    log "Updating Nginx configuration..."
    
    # Backup existing config
    backup_config "/etc/nginx/sites-available/oznet"
    
    # Copy new configuration
    cp config/nginx.conf /etc/nginx/sites-available/oznet
    
    # Test configuration
    if nginx -t; then
        log "✓ Nginx configuration test passed"
    else
        error "✗ Nginx configuration test failed"
    fi
    
    # Restart nginx
    systemctl restart nginx
    log "✓ Nginx restarted successfully"
}

# Update DNS configuration
update_dns() {
    log "Updating DNS configuration..."
    
    # Backup existing config
    backup_config "/etc/dnsmasq.d/oznet.conf"
    
    # Copy new configuration
    cp config/dnsmasq.conf /etc/dnsmasq.d/oznet.conf
    
    # Restart dnsmasq
    systemctl restart dnsmasq
    log "✓ DNS service restarted successfully"
}

# Update SSL certificates
update_ssl() {
    log "Updating SSL certificates..."
    
    # Create SSL directory if it doesn't exist
    mkdir -p /etc/ssl/oznet
    
    # Backup existing certificates
    backup_config "/etc/ssl/oznet/cert.pem"
    backup_config "/etc/ssl/oznet/key.pem"
    
    # Generate new self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/oznet/key.pem \
        -out /etc/ssl/oznet/cert.pem \
        -subj "/C=ES/ST=State/L=City/O=OzNet/CN=*.oznet"
    
    log "✓ SSL certificates updated"
}

# Update OzNet application
update_oznet() {
    log "Updating OzNet application..."
    
    # Install/update Node.js dependencies
    npm install
    
    # Restart OzNet service
    systemctl restart oznet
    log "✓ OzNet service restarted"
}

# Update environment configuration
update_env() {
    log "Updating environment configuration..."
    
    # Create .env file if it doesn't exist
    if [[ ! -f .env ]]; then
        cat > .env << EOF
PORT=3000
FILES_ROOT=/var/oznet/files
NODE_ENV=production
EOF
        log "✓ Created .env file"
    else
        log "✓ .env file already exists"
    fi
}

# Test all services
test_services() {
    log "Testing all services..."
    
    # Check if services are running
    local services=("oznet" "dnsmasq" "nginx")
    local service_names=("OzNet" "DNS" "Nginx")
    
    for i in "${!services[@]}"; do
        if systemctl is-active --quiet "${services[$i]}"; then
            log "✓ ${service_names[$i]} service is running"
        else
            warn "✗ ${service_names[$i]} service is not running"
        fi
    done
    
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
    
    # Test SSL
    if curl -s -k https://localhost > /dev/null 2>&1; then
        log "✓ SSL is working"
    else
        warn "✗ SSL may not be working"
    fi
}

# Display update summary
display_summary() {
    log "Configuration update completed!"
    echo
    echo -e "${BLUE}=== Update Summary ===${NC}"
    echo
    echo -e "${GREEN}Updated Services:${NC}"
    echo "  • Nginx configuration"
    echo "  • DNS configuration"
    echo "  • SSL certificates"
    echo "  • OzNet application"
    echo
    echo -e "${GREEN}Test URLs:${NC}"
    echo "  • http://home.oznet"
    echo "  • http://hub.oznet"
    echo "  • http://files.oznet"
    echo "  • http://server.oznet"
    echo
    echo -e "${YELLOW}If you experience issues, check the logs:${NC}"
    echo "  • nginx: sudo tail -f /var/log/nginx/error.log"
    echo "  • oznet: sudo journalctl -u oznet -f"
    echo "  • dnsmasq: sudo tail -f /var/log/dnsmasq.log"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --all              Update all configurations (default)"
    echo "  --nginx            Update only Nginx configuration"
    echo "  --dns              Update only DNS configuration"
    echo "  --ssl              Update only SSL certificates"
    echo "  --app              Update only OzNet application"
    echo "  --env              Update only environment configuration"
    echo "  --test             Test services after update"
    echo "  --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0                 # Update all configurations"
    echo "  $0 --nginx         # Update only Nginx"
    echo "  $0 --nginx --test  # Update Nginx and test"
}

# Main function
main() {
    local update_all=true
    local update_nginx_flag=false
    local update_dns_flag=false
    local update_ssl_flag=false
    local update_app_flag=false
    local update_env_flag=false
    local test_services_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                update_all=true
                shift
                ;;
            --nginx)
                update_all=false
                update_nginx_flag=true
                shift
                ;;
            --dns)
                update_all=false
                update_dns_flag=true
                shift
                ;;
            --ssl)
                update_all=false
                update_ssl_flag=true
                shift
                ;;
            --app)
                update_all=false
                update_app_flag=true
                shift
                ;;
            --env)
                update_all=false
                update_env_flag=true
                shift
                ;;
            --test)
                test_services_flag=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    log "Starting OzNet configuration update..."
    
    check_root
    
    # Update configurations based on flags
    if [[ "$update_all" == true ]] || [[ "$update_nginx_flag" == true ]]; then
        update_nginx
    fi
    
    if [[ "$update_all" == true ]] || [[ "$update_dns_flag" == true ]]; then
        update_dns
    fi
    
    if [[ "$update_all" == true ]] || [[ "$update_ssl_flag" == true ]]; then
        update_ssl
    fi
    
    if [[ "$update_all" == true ]] || [[ "$update_app_flag" == true ]]; then
        update_oznet
    fi
    
    if [[ "$update_all" == true ]] || [[ "$update_env_flag" == true ]]; then
        update_env
    fi
    
    # Test services if requested
    if [[ "$test_services_flag" == true ]]; then
        test_services
    fi
    
    display_summary
}

# Run main function
main "$@" 