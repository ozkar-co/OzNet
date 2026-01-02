# Infrastructure

This directory contains all infrastructure-related configuration and scripts for OzNet.

## 📁 Structure

```
infrastructure/
├── cloudflare/
│   ├── tunnel-config.yml    # Cloudflare Tunnel routing configuration
│   └── README.md            # Setup guide for Cloudflare Tunnel
└── scripts/
    ├── cleanup-dns.sh       # Remove old DNS entries
    ├── cleanup-nginx.sh     # Remove Nginx configuration
    └── cleanup-ssl.sh       # Remove SSL infrastructure
```

## 🌐 Cloudflare Tunnel

The `cloudflare/` directory contains configuration for Cloudflare Tunnel, which provides secure public access to services without exposing ports.

**Key files:**
- `tunnel-config.yml` - Main configuration defining ingress rules
- `README.md` - Complete setup guide

**Quick start:**
```bash
cd infrastructure/cloudflare
# Follow instructions in README.md
```

## 🧹 Cleanup Scripts

The `scripts/` directory contains migration scripts to remove legacy infrastructure:

### cleanup-nginx.sh
Removes Nginx configuration and services:
- Stops and disables nginx service
- Removes OzNet-specific nginx configurations
- Removes systemd overrides

```bash
sudo ./infrastructure/scripts/cleanup-nginx.sh
```

### cleanup-ssl.sh
Removes internal SSL certificate infrastructure:
- Stops and disables oznet-ssl service
- Removes CA certificates and infrastructure
- Removes client certificate distribution

```bash
sudo ./infrastructure/scripts/cleanup-ssl.sh
```

### cleanup-dns.sh
Trims DNS configuration to essentials:
- Backs up existing configuration
- Creates minimal DNS config (only home.oznet and server.oznet)
- Restarts dnsmasq

```bash
sudo ./infrastructure/scripts/cleanup-dns.sh
```

## 🎯 Purpose

This infrastructure repository:
- ✅ Provides Cloudflare Tunnel configuration
- ✅ Manages minimal internal DNS
- ✅ Includes migration scripts from legacy setup
- ❌ Does NOT contain business services (those are external)

## 📖 Documentation

For more details:
- [ARCHITECTURE.md](../documentation/ARCHITECTURE.md) - System design
- [TRANSITION.md](../documentation/TRANSITION.md) - Migration details
- [Cloudflare README](cloudflare/README.md) - Tunnel setup

## ⚠️ Important Notes

1. **Run cleanup scripts only once** during migration from v1 to v2
2. **Backup your data** before running cleanup scripts
3. **Cleanup scripts require root** access (use sudo)
4. **Cloudflare Tunnel requires** a Cloudflare account and domain

## 🔄 Adding New Services

When adding a new service:

1. Deploy service in its own repository
2. Configure to run on `localhost:PORT`
3. Update `cloudflare/tunnel-config.yml` with new ingress rule
4. Add DNS record via `cloudflared tunnel route dns`
5. Restart cloudflared service

See [ARCHITECTURE.md](../documentation/ARCHITECTURE.md) for details.
