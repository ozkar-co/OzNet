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

### Opción rápida (recomendada)

Con el servicio corriendo en `localhost:PORT`:

```bash
cd infrastructure/cloudflare
./add-site.sh <nombre> <puerto>
```

Ejemplo:

```bash
./add-site.sh mi-api 3004
```

El script hace todo automáticamente:
1. Agrega la entrada en `tunnel-config.yml`
2. Asegura el symlink en `/etc/cloudflared/config.yml`
3. Crea la ruta DNS en Cloudflare
4. Reinicia `cloudflared` (y `oznet-home` si está activo)

Opciones adicionales:

```bash
./add-site.sh whisper 8001 --health-path /api/version
./add-site.sh ozro-api 3001 --tls
```

### Manual

When you deploy a new external service:

1. Service runs on localhost:PORT
2. Add entry to `tunnel-config.yml`:
   ```yaml
   - hostname: myservice.ozkr.net
     service: http://localhost:PORT
   ```
3. Add DNS record (if not using wildcard):
   ```bash
   cloudflared tunnel route dns ozkrnet myservice.ozkr.net
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
