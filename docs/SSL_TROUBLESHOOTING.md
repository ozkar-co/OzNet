# SSL Troubleshooting Guide

This guide helps you resolve SSL certificate issues that occur after server restarts.

## Quick Fix

If SSL stops working after a server restart, run this command on your server:

```bash
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --all
```

## Common Issues and Solutions

### 1. SSL Certificates Missing After Restart

**Symptoms:**
- Nginx fails to start
- SSL connection errors
- Certificate file not found errors

**Solution:**
```bash
# Check certificate status
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --check

# Fix all SSL issues
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --all
```

### 2. Permission Issues

**Symptoms:**
- Nginx cannot read certificate files
- Permission denied errors

**Solution:**
```bash
# Fix certificate permissions
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --fix-permissions
```

### 3. Invalid Certificates

**Symptoms:**
- Certificate validation errors
- Browser security warnings

**Solution:**
```bash
# Regenerate certificates
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --regenerate
```

### 4. Service Dependencies

**Symptoms:**
- Nginx starts before certificates are ready
- Intermittent SSL failures

**Solution:**
```bash
# Create SSL service dependency
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --create-service
```

## Manual Troubleshooting Steps

### Check Certificate Status

```bash
# Check if certificates exist
ls -la /etc/ssl/oznet/
ls -la /etc/ssl/oznet-ca/certs/

# Check certificate validity
openssl x509 -in /etc/ssl/oznet/cert.pem -text -noout

# Check certificate expiration
openssl x509 -in /etc/ssl/oznet/cert.pem -noout -enddate
```

### Check Service Status

```bash
# Check all related services
sudo systemctl status nginx
sudo systemctl status oznet
sudo systemctl status oznet-ssl

# Check service logs
sudo journalctl -u nginx -f
sudo journalctl -u oznet-ssl -f
```

### Test SSL Configuration

```bash
# Test nginx configuration
sudo nginx -t

# Test SSL connection
curl -k https://localhost

# Test certificate chain
openssl s_client -connect localhost:443 -servername home.oznet
```

## Deployment from Local Development

To deploy SSL fixes from your local development environment:

```bash
# Deploy SSL fix only
./scripts/deploy.sh --host YOUR_SERVER_IP --ssl-fix

# Deploy full update
./scripts/deploy.sh --host YOUR_SERVER_IP --full-update

# Using environment variables
export OZNET_SERVER_HOST=YOUR_SERVER_IP
./scripts/deploy.sh --ssl-fix
```

## Prevention

To prevent SSL issues in the future:

1. **Use the SSL persistence service**: The `oznet-ssl` service ensures certificates are properly set up before nginx starts.

2. **Regular maintenance**: Run the SSL check periodically:
   ```bash
   sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --check
   ```

3. **Monitor logs**: Keep an eye on the SSL service logs:
   ```bash
   sudo journalctl -u oznet-ssl -f
   ```

## Certificate Installation on Clients

After fixing server SSL issues, install the CA certificate on client devices:

1. **Download the CA certificate**:
   ```
   https://home.oznet/certs/oznet-ca.crt
   ```

2. **Install on different platforms**:

   **Ubuntu/Debian:**
   ```bash
   sudo cp oznet-ca.crt /usr/local/share/ca-certificates/
   sudo update-ca-certificates
   ```

   **macOS:**
   ```bash
   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain oznet-ca.crt
   ```

   **Windows:**
   - Double-click the certificate file
   - Choose "Install Certificate"
   - Select "Local Machine"
   - Choose "Trusted Root Certification Authorities"

## Emergency Recovery

If SSL is completely broken:

1. **Stop all services**:
   ```bash
   sudo systemctl stop nginx oznet
   ```

2. **Regenerate everything**:
   ```bash
   sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --regenerate
   sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --create-service
   ```

3. **Restart services**:
   ```bash
   sudo systemctl restart oznet-ssl nginx oznet
   ```

4. **Test**:
   ```bash
   sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --test
   ```

## Certificate Conflicts

If you get "certificate already exists" errors:

```bash
# Force regenerate (clears all existing certificates)
sudo bash /opt/oznet/scripts/fix-ssl-persistence.sh --force-regenerate

# This will:
# 1. Stop services using certificates
# 2. Backup existing certificates
# 3. Remove all certificate files
# 4. Regenerate fresh certificates
```

## Support

If you continue to experience SSL issues:

1. Check the logs: `sudo journalctl -u oznet-ssl -f`
2. Verify network connectivity to the server
3. Ensure DNS resolution is working correctly
4. Check firewall settings

For additional help, check the main documentation at `https://home.oznet/docs`. 