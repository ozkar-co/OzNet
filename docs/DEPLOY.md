# OzNet Deployment Guide

This guide explains how to deploy OzNet updates to your server via SSH.

## Prerequisites

- SSH access to your server
- Root or sudo privileges on the server
- Git repository cloned on your local machine

## Quick Deployment

### 1. Update Local Repository

First, ensure your local repository is up to date:

```bash
# On your local machine
git pull origin main
```

### 2. Deploy to Server

Connect to your server and run the deployment:

```bash
# SSH to your server
ssh user@your-server-ip

# Navigate to OzNet directory
cd /opt/oznet

# Pull latest changes (if using git on server)
git pull origin main

# Or copy files manually from local machine
# (see manual deployment section below)

# Run the update script
sudo bash scripts/update-config.sh --all --test
```

## Manual Deployment

If you prefer to copy files manually from your local development environment:

### 1. Copy Files to Server

From your local machine, copy the updated files:

```bash
# Create a temporary archive
tar -czf oznet-update.tar.gz \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='*.log' \
  --exclude='.env' \
  .

# Copy to server
scp oznet-update.tar.gz user@your-server-ip:/tmp/

# Clean up local archive
rm oznet-update.tar.gz
```

### 2. Extract and Deploy on Server

On your server:

```bash
# SSH to server
ssh user@your-server-ip

# Create backup
sudo cp -r /opt/oznet /opt/oznet.backup.$(date +%Y%m%d_%H%M%S)

# Extract update
cd /tmp
tar -xzf oznet-update.tar.gz

# Stop services
sudo systemctl stop nginx oznet

# Copy files
sudo cp -r * /opt/oznet/

# Set permissions
sudo chown -R root:root /opt/oznet
sudo chmod +x /opt/oznet/scripts/*.sh

# Run update
cd /opt/oznet
sudo bash scripts/update-config.sh --all --test

# Clean up
rm -rf /tmp/oznet-update.tar.gz /tmp/*
```

## SSL-Specific Deployment

If you only need to fix SSL issues:

```bash
# SSH to server
ssh user@your-server-ip

# Navigate to OzNet directory
cd /opt/oznet

# Run SSL fix
sudo bash scripts/fix-ssl-persistence.sh --all
```

## Deployment Options

### Full Update (Recommended)

Updates all components including SSL, DNS, and application:

```bash
sudo bash scripts/update-config.sh --all --test
```

### Adding New Services (OctoPrint Example)

To add a new service like OctoPrint to your OzNet setup:

1. **Update DNS Configuration** (if needed):
   - The `3dprint.oznet` entry is already configured in `config/dnsmasq.conf`
   - If adding a new subdomain, add it to the `address=/` section

2. **Update Nginx Configuration**:
   - Modify `config/nginx.conf` to include the new service
   - Create separate server blocks for different services if needed
   - Example: OctoPrint configuration is already included in the updated config

3. **Deploy the Changes**:
   ```bash
   # Update DNS and Nginx configurations
   sudo bash scripts/update-config.sh --dns --nginx --test
   
   # Or update everything
   sudo bash scripts/update-config.sh --all --test
   ```

4. **Verify the Service**:
   ```bash
   # Test DNS resolution
   nslookup 3dprint.oznet 127.0.0.1
   
   # Test HTTPS access
   curl -I -k https://3dprint.oznet
   
   # Check nginx configuration
   sudo nginx -t
   ```

### Selective Updates

Update only specific components:

```bash
# Update only Nginx configuration
sudo bash scripts/update-config.sh --nginx --test

# Update only DNS configuration
sudo bash scripts/update-config.sh --dns --test

# Update only SSL certificates
sudo bash scripts/update-config.sh --ssl --test

# Update only the application
sudo bash scripts/update-config.sh --app --test
```

### SSL Persistence Fix

If SSL stops working after restart:

```bash
# Check SSL status
sudo bash scripts/fix-ssl-persistence.sh --check

# Fix all SSL issues
sudo bash scripts/fix-ssl-persistence.sh --all

# Or fix specific issues
sudo bash scripts/fix-ssl-persistence.sh --fix-permissions
sudo bash scripts/fix-ssl-persistence.sh --regenerate
sudo bash scripts/fix-ssl-persistence.sh --create-service

# Force regenerate (clear all existing certificates)
sudo bash scripts/fix-ssl-persistence.sh --force-regenerate

# Create local certificate copies for distribution
sudo bash scripts/fix-ssl-persistence.sh --create-copies
```

## Certificate Distribution

After SSL setup, you can distribute certificates to clients:

### 1. Create Local Certificate Copies

```bash
# Create local copies for distribution
sudo bash scripts/fix-ssl-persistence.sh --create-copies
```

### 2. Access Certificate Files

The certificates are available at:
- **Web access**: `https://home.oznet/certs/oznet-ca.crt`
- **Local copies**: `./certs/local/` (in the directory where you run the script)
- **Distribution package**: `./certs/local/oznet-certificates.zip` (or `.tar.gz`)

**Note**: The distribution package is created in the current working directory where you run the script.

### Workflow Summary

1. **Server**: Run `--create-copies` to generate certificates and distribution package in current directory
2. **Local Machine**: Distribution package is already in your current directory
3. **Client Machines**: Install certificates from the distribution package

### 3. Distribute to Clients

The distribution package is already in your current directory. You can now distribute it to clients:

```bash
# The files are already in ./certs/local/
# You can copy them directly to client machines

# Or distribute the zip/tar.gz package
cp ./certs/local/oznet-certificates.zip /path/to/client/machine/

# Or copy individual files
cp ./certs/local/oznet-ca.crt /path/to/client/machine/
cp ./certs/local/install-ca.sh /path/to/client/machine/
```

### 4. Install on Client Devices

**Linux (Ubuntu/Debian):**
```bash
sudo cp oznet-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain oznet-ca.crt
```

**Windows:**
1. Double-click `oznet-ca.crt`
2. Click "Install Certificate"
3. Choose "Local Machine"
4. Choose "Trusted Root Certification Authorities"

## Verification

After deployment, verify everything is working:

### 1. Check Service Status

```bash
# Check all services
sudo systemctl status nginx
sudo systemctl status oznet
sudo systemctl status oznet-ssl
sudo systemctl status dnsmasq
```

### 2. Test Functionality

```bash
# Test web server
curl -I http://localhost:3000

# Test SSL (if configured)
curl -I -k https://localhost

# Test DNS resolution
nslookup home.oznet 127.0.0.1

# Test SSL certificate
sudo bash scripts/fix-ssl-persistence.sh --test
```

### 3. Check Logs

```bash
# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Check OzNet logs
sudo journalctl -u oznet -f

# Check SSL service logs
sudo journalctl -u oznet-ssl -f

# Check DNS logs
sudo tail -f /var/log/dnsmasq.log
```

## Rollback

If something goes wrong, you can rollback to the previous version:

```bash
# Stop services
sudo systemctl stop nginx oznet

# Restore backup
sudo cp -r /opt/oznet.backup.* /opt/oznet

# Restart services
sudo systemctl start nginx oznet

# Verify rollback
sudo systemctl status nginx oznet
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chown -R root:root /opt/oznet
   sudo chmod +x /opt/oznet/scripts/*.sh
   ```

2. **SSL Certificate Issues**
   ```bash
   sudo bash scripts/fix-ssl-persistence.sh --all
   ```

3. **Nginx Configuration Errors**
   ```bash
   sudo nginx -t
   sudo systemctl restart nginx
   ```

4. **Service Won't Start**
   ```bash
   sudo journalctl -u service-name -f
   sudo systemctl status service-name
   ```

### Emergency Recovery

If the system is completely broken:

```bash
# Stop all services
sudo systemctl stop nginx oznet dnsmasq

# Regenerate SSL certificates
sudo bash scripts/fix-ssl-persistence.sh --regenerate

# Recreate SSL service
sudo bash scripts/fix-ssl-persistence.sh --create-service

# Restart everything
sudo systemctl start oznet-ssl nginx oznet dnsmasq

# Test
sudo bash scripts/fix-ssl-persistence.sh --test
```

## Best Practices

1. **Always create backups** before major updates
2. **Test in staging** if possible
3. **Deploy during maintenance windows**
4. **Monitor logs** after deployment
5. **Verify functionality** before considering deployment complete
6. **Keep deployment logs** for troubleshooting

## Automation

For frequent deployments, consider creating a simple deployment script:

```bash
#!/bin/bash
# deploy.sh - Simple deployment script

set -e

echo "Starting OzNet deployment..."

# Backup
sudo cp -r /opt/oznet /opt/oznet.backup.$(date +%Y%m%d_%H%M%S)

# Update from git
cd /opt/oznet
git pull origin main

# Run update
sudo bash scripts/update-config.sh --all --test

echo "Deployment completed successfully!"
```

Make it executable and run:
```bash
chmod +x deploy.sh
./deploy.sh
```

## OctoPrint Integration

### Current Configuration

OctoPrint is configured to run on `https://3dprint.oznet` and proxy to `http://127.0.0.1:5000`.

### Prerequisites

Ensure OctoPrint is running on port 5000:
```bash
# Check if OctoPrint is running
sudo systemctl status octoprint

# If not running, start it
sudo systemctl start octoprint
sudo systemctl enable octoprint
```

### Configuration Details

The nginx configuration for OctoPrint includes:
- **SSL termination** with automatic HTTP to HTTPS redirect
- **WebSocket support** for real-time communication
- **Proper headers** for OctoPrint functionality
- **Health check endpoint** at `/health`

### Troubleshooting OctoPrint

If OctoPrint is not accessible:

1. **Check OctoPrint service**:
   ```bash
   sudo systemctl status octoprint
   sudo journalctl -u octoprint -f
   ```

2. **Verify port 5000 is listening**:
   ```bash
   sudo netstat -tlnp | grep :5000
   ```

3. **Test direct access**:
   ```bash
   curl -I http://127.0.0.1:5000
   ```

4. **Check nginx logs**:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

5. **Verify DNS resolution**:
   ```bash
   nslookup 3dprint.oznet 127.0.0.1
   ```

### OctoPrint Configuration

If you need to modify OctoPrint settings:
```bash
# Edit OctoPrint config
sudo nano /etc/octoprint/config.yaml

# Restart OctoPrint
sudo systemctl restart octoprint
```

## Support

If you encounter issues during deployment:

1. Check the logs: `sudo journalctl -u service-name -f`
2. Verify file permissions: `ls -la /opt/oznet/`
3. Test individual components
4. Check the troubleshooting guide: `docs/SSL_TROUBLESHOOTING.md`

For additional help, check the main documentation at `https://home.oznet/docs`. 