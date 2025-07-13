#!/bin/bash

# OzNet CA Certificate Generation Script
# This script creates a Certificate Authority and generates certificates for OzNet

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

# Create CA directory structure
create_ca_structure() {
    log "Creating CA directory structure..."
    
    mkdir -p /etc/ssl/oznet-ca/{private,certs,newcerts,crl}
    mkdir -p /etc/ssl/oznet-ca/private
    chmod 700 /etc/ssl/oznet-ca/private
    
    # Create server SSL directory structure
    mkdir -p /etc/ssl/oznet/{private,certs}
    chmod 700 /etc/ssl/oznet/private
    
    # Create CA database
    touch /etc/ssl/oznet-ca/index.txt
    echo "01" > /etc/ssl/oznet-ca/serial
    
    log "✓ CA directory structure created"
}

# Generate Root CA
generate_root_ca() {
    log "Generating Root CA certificate..."
    
    # Create CA private key
    openssl genrsa -out /etc/ssl/oznet-ca/private/ca.key 4096
    chmod 600 /etc/ssl/oznet-ca/private/ca.key
    
    # Create CA certificate
    openssl req -new -x509 -days 3650 -key /etc/ssl/oznet-ca/private/ca.key \
        -out /etc/ssl/oznet-ca/certs/ca.crt \
        -subj "/C=ES/ST=State/L=City/O=OzNet/OU=IT/CN=OzNet Root CA"
    
    log "✓ Root CA certificate generated"
}

# Generate server certificate
generate_server_cert() {
    log "Generating server certificate..."
    
    # Create server directory structure
    mkdir -p /etc/ssl/oznet/private
    chmod 700 /etc/ssl/oznet/private
    
    # Create server private key
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
    
    # Sign certificate with CA
    openssl ca -batch -config /etc/ssl/oznet-ca/openssl.cnf \
        -in /etc/ssl/oznet/server.csr \
        -out /etc/ssl/oznet/cert.pem \
        -extensions v3_req
    
    # Copy private key to expected location
    cp /etc/ssl/oznet/private/server.key /etc/ssl/oznet/key.pem
    
    log "✓ Server certificate generated"
}

# Create CA configuration
create_ca_config() {
    log "Creating CA configuration..."
    
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

[policy_loose]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
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

[v3_intermediate_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[usr_cert]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[server_cert]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

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
    
    log "✓ CA configuration created"
}

# Create client certificate for distribution
create_client_cert() {
    log "Creating client certificate package..."
    
    mkdir -p /var/oznet/certs
    
    # Copy CA certificate for clients
    cp /etc/ssl/oznet-ca/certs/ca.crt /var/oznet/certs/oznet-ca.crt
    
    # Create installation script for clients
    cat > /var/oznet/certs/install-ca.sh << 'EOF'
#!/bin/bash

# OzNet CA Certificate Installation Script
# This script installs the OzNet CA certificate on the client system

set -e

CA_CERT="/var/oznet/certs/oznet-ca.crt"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Detect OS and install certificate
if [[ -f /etc/debian_version ]]; then
    # Debian/Ubuntu
    echo "Installing CA certificate on Debian/Ubuntu..."
    cp "$CA_CERT" /usr/local/share/ca-certificates/oznet-ca.crt
    update-ca-certificates
    echo "✓ CA certificate installed on Debian/Ubuntu"
    
elif [[ -f /etc/redhat-release ]]; then
    # RHEL/CentOS/Fedora
    echo "Installing CA certificate on RHEL/CentOS/Fedora..."
    cp "$CA_CERT" /etc/pki/ca-trust/source/anchors/oznet-ca.crt
    update-ca-trust
    echo "✓ CA certificate installed on RHEL/CentOS/Fedora"
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "Installing CA certificate on macOS..."
    security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_CERT"
    echo "✓ CA certificate installed on macOS"
    
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash)
    echo "Installing CA certificate on Windows..."
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

echo "Certificate installation completed!"
echo "You may need to restart your browser for changes to take effect."
EOF
    
    chmod +x /var/oznet/certs/install-ca.sh
    
    log "✓ Client certificate package created in /var/oznet/certs/"
}

# Display instructions
display_instructions() {
    log "CA certificate generation completed!"
    echo
    echo -e "${BLUE}=== Certificate Information ===${NC}"
    echo
    echo -e "${GREEN}CA Certificate:${NC}"
    echo "  • Location: /etc/ssl/oznet-ca/certs/ca.crt"
    echo "  • Client copy: /var/oznet/certs/oznet-ca.crt"
    echo
    echo -e "${GREEN}Server Certificate:${NC}"
    echo "  • Certificate: /etc/ssl/oznet/cert.pem"
    echo "  • Private Key: /etc/ssl/oznet/key.pem"
    echo
    echo -e "${GREEN}To install on clients:${NC}"
    echo "  1. Copy /var/oznet/certs/oznet-ca.crt to client"
    echo "  2. Run: sudo /var/oznet/certs/install-ca.sh"
    echo "  3. Restart browser"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Update nginx configuration to use new certificates"
    echo "  2. Restart nginx: sudo systemctl restart nginx"
    echo "  3. Install CA certificate on client devices"
}

# Main function
main() {
    log "Starting OzNet CA certificate generation..."
    
    check_root
    
    create_ca_structure
    create_ca_config
    generate_root_ca
    generate_server_cert
    create_client_cert
    display_instructions
}

# Run main function
main "$@" 