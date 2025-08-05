#!/bin/bash

# OzNet SSL Persistence Fix Script
# This script fixes SSL certificate persistence issues after server restarts

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

# Check if certificates exist and are valid
check_certificates() {
    log "Checking SSL certificates..."
    
    local cert_file="/etc/ssl/oznet/cert.pem"
    local key_file="/etc/ssl/oznet/key.pem"
    local ca_file="/etc/ssl/oznet-ca/certs/ca.crt"
    
    # Check if certificates exist
    if [[ ! -f "$cert_file" ]]; then
        warn "Server certificate not found: $cert_file"
        return 1
    fi
    
    if [[ ! -f "$key_file" ]]; then
        warn "Server private key not found: $key_file"
        return 1
    fi
    
    if [[ ! -f "$ca_file" ]]; then
        warn "CA certificate not found: $ca_file"
        return 1
    fi
    
    # Check certificate validity
    if ! openssl x509 -in "$cert_file" -text -noout > /dev/null 2>&1; then
        warn "Server certificate is invalid or corrupted"
        return 1
    fi
    
    if ! openssl rsa -in "$key_file" -check > /dev/null 2>&1; then
        warn "Server private key is invalid or corrupted"
        return 1
    fi
    
    # Check certificate expiration
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [[ $days_until_expiry -lt 30 ]]; then
        warn "Certificate expires in $days_until_expiry days"
    else
        log "✓ Certificate is valid for $days_until_expiry days"
    fi
    
    log "✓ All certificates are present and valid"
    return 0
}

# Fix certificate permissions
fix_certificate_permissions() {
    log "Fixing certificate permissions..."
    
    # Set proper permissions for SSL directories
    chmod 755 /etc/ssl/oznet
    chmod 755 /etc/ssl/oznet-ca
    
    # Set proper permissions for certificates
    chmod 644 /etc/ssl/oznet/cert.pem
    chmod 600 /etc/ssl/oznet/key.pem
    chmod 644 /etc/ssl/oznet-ca/certs/ca.crt
    
    # Set proper ownership
    chown root:root /etc/ssl/oznet/cert.pem
    chown root:root /etc/ssl/oznet/key.pem
    chown root:root /etc/ssl/oznet-ca/certs/ca.crt
    
    # Fix client certificate permissions
    if [[ -f /var/oznet/certs/oznet-ca.crt ]]; then
        chown www-data:www-data /var/oznet/certs/oznet-ca.crt
        chmod 644 /var/oznet/certs/oznet-ca.crt
    fi
    
    # Update local certificate copies
    if [[ -d /var/oznet/certs/local ]]; then
        create_local_cert_copies
    fi
    
    log "✓ Certificate permissions fixed"
}

# Regenerate certificates if needed
regenerate_certificates() {
    log "Regenerating SSL certificates..."
    
    # Create necessary directories
    mkdir -p /etc/ssl/oznet-ca/{private,certs,newcerts,crl}
    mkdir -p /etc/ssl/oznet/{private,certs}
    mkdir -p /var/oznet/certs
    
    # Set proper permissions
    chmod 700 /etc/ssl/oznet-ca/private
    chmod 700 /etc/ssl/oznet/private
    
    # Clear existing CA database to avoid conflicts
    log "Clearing existing CA database..."
    rm -f /etc/ssl/oznet-ca/index.txt
    rm -f /etc/ssl/oznet-ca/serial
    rm -f /etc/ssl/oznet-ca/index.txt.attr
    rm -f /etc/ssl/oznet-ca/crlnumber
    
    # Create fresh CA database
    touch /etc/ssl/oznet-ca/index.txt
    echo "01" > /etc/ssl/oznet-ca/serial
    
    # Generate Root CA
    log "Generating Root CA..."
    openssl genrsa -out /etc/ssl/oznet-ca/private/ca.key 4096
    chmod 600 /etc/ssl/oznet-ca/private/ca.key
    
    openssl req -new -x509 -days 3650 -key /etc/ssl/oznet-ca/private/ca.key \
        -out /etc/ssl/oznet-ca/certs/ca.crt \
        -subj "/C=ES/ST=State/L=City/O=OzNet/OU=IT/CN=OzNet Root CA"
    
    # Generate server certificate
    log "Generating server certificate..."
    openssl genrsa -out /etc/ssl/oznet/private/server.key 2048
    chmod 600 /etc/ssl/oznet/private/server.key
    
    # Create certificate signing request
    cat > /etc/ssl/oznet/openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ES
ST = State
L = City
O = OzNet
OU = IT
CN = *.oznet

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.oznet
DNS.2 = home.oznet
DNS.3 = hub.oznet
DNS.4 = files.oznet
DNS.5 = server.oznet
DNS.6 = mail.oznet
DNS.7 = wiki.oznet
DNS.8 = 3dprint.oznet
IP.1 = 172.26.0.1
EOF
    
    # Generate CSR
    openssl req -new -key /etc/ssl/oznet/private/server.key \
        -out /etc/ssl/oznet/server.csr \
        -config /etc/ssl/oznet/openssl.cnf
    
    # Create CA configuration
    cat > /etc/ssl/oznet-ca/openssl.cnf << EOF
[ca]
default_ca = CA_default

[CA_default]
dir = /etc/ssl/oznet-ca
certs = \$dir/certs
crl_dir = \$dir/crl
new_certs_dir = \$dir/newcerts
database = \$dir/index.txt
private_key = \$dir/private/ca.key
certificate = \$dir/certs/ca.crt
serial = \$dir/serial
crlnumber = \$dir/crlnumber
crl = \$dir/crl/ca.crl
RANDFILE = \$dir/private/.rand

private_key_dir = \$dir/private
default_days = 365
default_crl_days = 30
default_md = sha256
name_opt = ca_default
cert_opt = ca_default
policy = policy_strict
x509_extensions = v3_ca

[policy_strict]
countryName = match
stateOrProvinceName = match
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[req]
default_bits = 2048
distinguished_name = req_distinguished_name
string_mask = utf8only
default_md = sha256
x509_extensions = v3_ca

[req_distinguished_name]
countryName = Country Name (2 letter code)
stateOrProvinceName = State or Province Name
localityName = Locality Name
0.organizationName = Organization Name
organizationalUnitName = Organizational Unit Name
commonName = Common Name
emailAddress = Email Address

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.oznet
DNS.2 = home.oznet
DNS.3 = hub.oznet
DNS.4 = files.oznet
DNS.5 = server.oznet
DNS.6 = mail.oznet
DNS.7 = wiki.oznet
DNS.8 = 3dprint.oznet
IP.1 = 172.26.0.1
EOF
    
    # Sign certificate with CA
    openssl ca -batch -config /etc/ssl/oznet-ca/openssl.cnf \
        -in /etc/ssl/oznet/server.csr \
        -out /etc/ssl/oznet/cert.pem \
        -extensions v3_req
    
    # Copy private key to expected location
    cp /etc/ssl/oznet/private/server.key /etc/ssl/oznet/key.pem
    
    # Create client certificate
    cp /etc/ssl/oznet-ca/certs/ca.crt /var/oznet/certs/oznet-ca.crt
    
    # Create local copies for distribution
    create_local_cert_copies
    
    # Fix permissions
    fix_certificate_permissions
    
    log "✓ Certificates regenerated successfully"
}

# Create local copies of certificates for distribution
create_local_cert_copies() {
    log "Creating local copies of certificates for distribution..."
    
    # Create local certs directory
    mkdir -p /var/oznet/certs/local
    
    # Copy CA certificate
    cp /etc/ssl/oznet-ca/certs/ca.crt /var/oznet/certs/local/oznet-ca.crt
    
    # Copy server certificate (for reference)
    cp /etc/ssl/oznet/cert.pem /var/oznet/certs/local/oznet-server.crt
    
    # Create certificate bundle (CA + server cert)
    cat /etc/ssl/oznet-ca/certs/ca.crt /etc/ssl/oznet/cert.pem > /var/oznet/certs/local/oznet-bundle.crt
    
    # Create certificate information file
    cat > /var/oznet/certs/local/README.txt << 'EOF'
OzNet SSL Certificates for Client Distribution
==============================================

This directory contains the latest SSL certificates for OzNet services.

Files:
- oznet-ca.crt          - Root CA certificate (install this on clients)
- oznet-server.crt      - Server certificate (for reference only)
- oznet-bundle.crt      - Certificate bundle (CA + server)
- install-ca.sh         - Installation script for Linux/macOS
- README.txt           - This file

Installation Instructions:
=========================

Linux (Ubuntu/Debian):
  sudo cp oznet-ca.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates

Linux (RHEL/CentOS/Fedora):
  sudo cp oznet-ca.crt /etc/pki/ca-trust/source/anchors/
  sudo update-ca-trust

macOS:
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain oznet-ca.crt

Windows:
  1. Double-click oznet-ca.crt
  2. Click "Install Certificate"
  3. Choose "Local Machine"
  4. Choose "Place all certificates in the following store"
  5. Click "Browse" and select "Trusted Root Certification Authorities"
  6. Click "OK" and "Next"

Certificate Details:
===================
- Issuer: OzNet Root CA
- Valid for: *.oznet domains
- Expires: See certificate for details

After installation, restart your browser for changes to take effect.

For support, visit: https://home.oznet/docs
EOF
    
    # Create installation script for local copies
    cat > /var/oznet/certs/local/install-ca.sh << 'EOF'
#!/bin/bash

# OzNet CA Certificate Installation Script
# This script installs the OzNet CA certificate on the client system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_CERT="$SCRIPT_DIR/oznet-ca.crt"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

if [[ ! -f "$CA_CERT" ]]; then
    echo "Error: CA certificate not found at $CA_CERT"
    exit 1
fi

echo "Installing OzNet CA certificate..."

# Detect OS and install certificate
if [[ -f /etc/debian_version ]]; then
    # Debian/Ubuntu
    echo "Detected Debian/Ubuntu system..."
    cp "$CA_CERT" /usr/local/share/ca-certificates/oznet-ca.crt
    update-ca-certificates
    echo "✓ CA certificate installed on Debian/Ubuntu"
    
elif [[ -f /etc/redhat-release ]]; then
    # RHEL/CentOS/Fedora
    echo "Detected RHEL/CentOS/Fedora system..."
    cp "$CA_CERT" /etc/pki/ca-trust/source/anchors/oznet-ca.crt
    update-ca-trust
    echo "✓ CA certificate installed on RHEL/CentOS/Fedora"
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "Detected macOS system..."
    security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_CERT"
    echo "✓ CA certificate installed on macOS"
    
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash)
    echo "Detected Windows system..."
    echo "Please manually install the certificate:"
    echo "1. Double-click on $CA_CERT"
    echo "2. Click 'Install Certificate'"
    echo "3. Choose 'Local Machine'"
    echo "4. Choose 'Place all certificates in the following store'"
    echo "5. Click 'Browse' and select 'Trusted Root Certification Authorities'"
    echo "6. Click 'OK' and 'Next'"
    
else
    echo "Unsupported operating system. Please install the certificate manually:"
    echo "Copy $CA_CERT to your system's trusted certificate store"
fi

echo ""
echo "Certificate installation completed!"
echo "You may need to restart your browser for changes to take effect."
echo ""
echo "Test the installation by visiting: https://home.oznet"
EOF
    
    chmod +x /var/oznet/certs/local/install-ca.sh
    
    # Set proper permissions for all files
    chown -R www-data:www-data /var/oznet/certs/local
    chmod 644 /var/oznet/certs/local/*.crt
    chmod 644 /var/oznet/certs/local/*.txt
    chmod 755 /var/oznet/certs/local/*.sh
    
    # Create a zip file for easy distribution
    cd /var/oznet/certs/local
    zip -r oznet-certificates.zip . > /dev/null 2>&1 || {
        # If zip is not available, create a tar.gz
        tar -czf oznet-certificates.tar.gz . > /dev/null 2>&1 || true
    }
    
    log "✓ Local certificate copies created in /var/oznet/certs/local/"
    log "✓ Distribution package created (zip or tar.gz)"
}

# Create systemd service dependency
create_ssl_service() {
    log "Creating SSL certificate service..."
    
    cat > /etc/systemd/system/oznet-ssl.service << EOF
[Unit]
Description=OzNet SSL Certificate Service
Before=nginx.service
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c '
    if [[ ! -f /etc/ssl/oznet/cert.pem ]] || [[ ! -f /etc/ssl/oznet/key.pem ]]; then
        echo "SSL certificates missing, regenerating..."
        /usr/bin/bash $(pwd)/scripts/fix-ssl-persistence.sh --regenerate
    else
        echo "SSL certificates found, fixing permissions..."
        /usr/bin/bash $(pwd)/scripts/fix-ssl-persistence.sh --fix-permissions
    fi
'
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    systemctl daemon-reload
    systemctl enable oznet-ssl
    
    # Update nginx service to depend on SSL service
    if [[ -f /etc/systemd/system/nginx.service ]]; then
        # Create override directory
        mkdir -p /etc/systemd/system/nginx.service.d
        
        cat > /etc/systemd/system/nginx.service.d/override.conf << EOF
[Unit]
After=oznet-ssl.service
Requires=oznet-ssl.service
EOF
    fi
    
    log "✓ SSL certificate service created"
}

# Test SSL configuration
test_ssl() {
    log "Testing SSL configuration..."
    
    # Test nginx configuration
    if nginx -t; then
        log "✓ Nginx configuration is valid"
    else
        error "✗ Nginx configuration is invalid"
    fi
    
    # Test SSL connection
    if curl -s -k https://localhost > /dev/null 2>&1; then
        log "✓ SSL connection is working"
    else
        warn "✗ SSL connection may not be working"
    fi
    
    # Test certificate chain
    if openssl s_client -connect localhost:443 -servername home.oznet < /dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
        log "✓ Certificate chain is valid"
    else
        warn "✗ Certificate chain may have issues"
    fi
}

# Restart services
restart_services() {
    log "Restarting services..."
    
    # Restart SSL service
    systemctl restart oznet-ssl
    
    # Restart nginx
    systemctl restart nginx
    
    # Restart OzNet application
    if systemctl is-active --quiet oznet; then
        systemctl restart oznet
    fi
    
    log "✓ Services restarted"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --check              Check certificate status (default)"
    echo "  --fix-permissions    Fix certificate permissions"
    echo "  --regenerate         Regenerate all certificates"
    echo "  --create-service     Create systemd service for SSL persistence"
    echo "  --test               Test SSL configuration"
    echo "  --restart            Restart all services"
    echo "  --create-copies      Create local certificate copies for distribution"
    echo "  --all                Run all fixes (recommended)"
    echo "  --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0                   # Check certificate status"
    echo "  $0 --all             # Run all fixes"
    echo "  $0 --regenerate      # Regenerate certificates only"
    echo "  $0 --create-copies   # Create local certificate copies only"
}

# Main function
main() {
    local check_flag=true
    local fix_permissions_flag=false
    local regenerate_flag=false
    local create_service_flag=false
    local test_flag=false
    local restart_flag=false
    local create_copies_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                check_flag=true
                shift
                ;;
            --fix-permissions)
                check_flag=false
                fix_permissions_flag=true
                shift
                ;;
            --regenerate)
                check_flag=false
                regenerate_flag=true
                shift
                ;;
            --create-service)
                check_flag=false
                create_service_flag=true
                shift
                ;;
            --test)
                check_flag=false
                test_flag=true
                shift
                ;;
            --restart)
                check_flag=false
                restart_flag=true
                shift
                ;;
            --create-copies)
                check_flag=false
                create_copies_flag=true
                shift
                ;;
            --all)
                check_flag=false
                fix_permissions_flag=true
                regenerate_flag=true
                create_service_flag=true
                test_flag=true
                restart_flag=true
                create_copies_flag=true
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
    
    log "Starting OzNet SSL persistence fix..."
    
    check_root
    
    # Run requested operations
    if [[ "$check_flag" == true ]]; then
        if ! check_certificates; then
            warn "Certificate issues detected. Run with --all to fix them."
        fi
    fi
    
    if [[ "$fix_permissions_flag" == true ]]; then
        fix_certificate_permissions
    fi
    
    if [[ "$regenerate_flag" == true ]]; then
        regenerate_certificates
    fi
    
    if [[ "$create_service_flag" == true ]]; then
        create_ssl_service
    fi
    
    if [[ "$test_flag" == true ]]; then
        test_ssl
    fi
    
    if [[ "$restart_flag" == true ]]; then
        restart_services
    fi
    
    if [[ "$create_copies_flag" == true ]]; then
        create_local_cert_copies
    fi
    
    log "SSL persistence fix completed!"
    echo
    echo -e "${BLUE}=== SSL Status ===${NC}"
    echo
    echo -e "${GREEN}Certificate Locations:${NC}"
    echo "  • Server Cert: /etc/ssl/oznet/cert.pem"
    echo "  • Server Key: /etc/ssl/oznet/key.pem"
    echo "  • CA Cert: /etc/ssl/oznet-ca/certs/ca.crt"
    echo "  • Client Cert: /var/oznet/certs/oznet-ca.crt"
    echo "  • Local Copies: /var/oznet/certs/local/"
    echo
    echo -e "${GREEN}Services:${NC}"
    echo "  • oznet-ssl: $(systemctl is-active oznet-ssl 2>/dev/null || echo 'not installed')"
    echo "  • nginx: $(systemctl is-active nginx 2>/dev/null || echo 'not running')"
    echo "  • oznet: $(systemctl is-active oznet 2>/dev/null || echo 'not running')"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Install CA certificate on client devices"
    echo "  2. Test SSL connections: https://home.oznet"
    echo "  3. Monitor logs: sudo journalctl -u oznet-ssl -f"
}

# Run main function
main "$@" 