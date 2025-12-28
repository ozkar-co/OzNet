# Cloudflare Tunnel Setup Guide

## Prerequisites

1. A Cloudflare account with your domain (e.g., ozkar.co)
2. `cloudflared` installed on your server

## Installation

### Install cloudflared

```bash
# Ubuntu/Debian
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Or using package manager
sudo apt install cloudflared
```

## Setup Steps

### 1. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser to authorize cloudflared with your Cloudflare account.

### 2. Create a Tunnel

```bash
cloudflared tunnel create oznet
```

This creates a tunnel named "oznet" and generates credentials.

### 3. Configure DNS

For each service subdomain, add a CNAME record:

```bash
cloudflared tunnel route dns oznet home.ozkar.co
```

Or configure manually in Cloudflare dashboard:
- Type: CNAME
- Name: home (or your subdomain)
- Target: <tunnel-id>.cfargotunnel.com

### 4. Update Configuration

Edit `infrastructure/cloudflare/tunnel-config.yml`:
- Replace `<tunnel-id>` with your actual tunnel ID
- Add your service hostnames and ports

### 5. Run the Tunnel

Test run:
```bash
cloudflared tunnel --config infrastructure/cloudflare/tunnel-config.yml run
```

### 6. Install as Service

```bash
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

## Monitoring

Check tunnel status:
```bash
cloudflared tunnel info oznet
systemctl status cloudflared
```

View logs:
```bash
sudo journalctl -u cloudflared -f
```

## Adding New Services

When you deploy a new external service:

1. Service runs on localhost:PORT
2. Add entry to `tunnel-config.yml`:
   ```yaml
   - hostname: myservice.ozkar.co
     service: http://localhost:PORT
   ```
3. Add DNS record (if not using wildcard):
   ```bash
   cloudflared tunnel route dns oznet myservice.ozkar.co
   ```
4. Reload cloudflared:
   ```bash
   sudo systemctl restart cloudflared
   ```

## Security Notes

- All TLS/SSL is handled by Cloudflare
- Services only listen on localhost (not exposed directly)
- No ports need to be opened in firewall
- Cloudflare provides DDoS protection and WAF
