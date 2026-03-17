# Infrastructure

This directory contains all infrastructure-related configuration for OzNet.

## 📁 Structure

```
infrastructure/
└── cloudflare/
    ├── tunnel-config.yml    # Cloudflare Tunnel routing configuration (source of truth for services)
    └── README.md            # Setup guide for Cloudflare Tunnel
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

## 🎯 Purpose

This infrastructure directory:
- ✅ Provides Cloudflare Tunnel configuration
- ✅ Serves as the single source of truth for all services and ports
- ❌ Does NOT contain business services (those are external)

## 📖 Documentation

For more details:
- [ARCHITECTURE.md](../documentation/ARCHITECTURE.md) - System design
- [Cloudflare README](cloudflare/README.md) - Tunnel setup

## 🔄 Adding New Services

When adding a new service:

1. Deploy service in its own repository
2. Configure to run on `localhost:PORT`
3. Update `cloudflare/tunnel-config.yml` with new ingress rule
4. Restart cloudflared service

The Home/Hub dashboard will automatically pick up the new service.

See [ARCHITECTURE.md](../documentation/ARCHITECTURE.md) for details.
