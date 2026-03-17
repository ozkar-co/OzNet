# OzNet Architecture

## Overview

OzNet is a **minimal infrastructure repository** designed to provide a clean foundation for deploying personal services without technical debt.

**Core Principle**: This repository contains NO business services. All actual services live in external, independent repositories.

---

## 🎯 What This Repository Provides

1. **Cloudflare Tunnel Configuration**
   - Public access routing
   - TLS/SSL termination (managed by Cloudflare)
   - DDoS protection and WAF

2. **Home/Hub Service**
   - Central documentation
   - Service status monitoring
   - Architecture explanation

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │   Cloudflare Network   │
            │  - TLS Termination     │
            │  - DDoS Protection     │
            │  - WAF                 │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Cloudflare Tunnel     │
            │  (cloudflared)         │
            └────────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    localhost:3000  localhost:3001  localhost:5000
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐   ┌──────────┐    ┌──────────┐
    │  Home   │   │  Service │    │  Service │
    │  Hub    │   │  (ext.)  │    │  (ext.)  │
    └─────────┘   └──────────┘    └──────────┘
    (This repo)   (External repo) (External repo)
```

---

## 🌐 Public Access Flow

1. **User Request**
   ```
   https://home.ozkar.co
   ```

2. **Cloudflare Processing**
   - TLS termination
   - DDoS protection
   - WAF rules applied

3. **Tunnel Routing**
   - Cloudflare Tunnel forwards to `localhost:3000`
   - Based on `tunnel-config.yml` ingress rules

4. **Service Response**
   - Service listens on localhost only
   - Returns response through tunnel
   - Cloudflare encrypts and delivers to user

**Key Points:**
- No ports exposed to internet
- No local SSL certificates needed
- Cloudflare handles all security
- Services remain isolated on localhost

---

## 📦 Service Model

### External Services

All business services follow this pattern:

1. **Independent Repository**
   - Own git repository
   - Own deployment pipeline
   - Own dependencies

2. **Local Port**
   - Listens on `localhost:PORT`
   - Not exposed to internet directly
   - Accessible via Cloudflare Tunnel

3. **Health Endpoint**
   - Implements `GET /health`
   - Returns HTTP 200 when healthy
   - Used for monitoring by Home/Hub
   - For services with a non-standard health path, set `health_path` in the tunnel config

4. **Cloudflare Tunnel Entry**
   ```yaml
   ingress:
     - hostname: myservice.ozkar.co
       service: http://localhost:PORT
       health_path: /api/version  # Optional: custom health check path (defaults to /health)
   ```

### Example Service Structure

```
my-service/
├── package.json
├── index.js
├── Dockerfile
├── README.md
└── src/
    └── routes/
        └── health.js  # Returns 200 OK
```

**Health endpoint example:**
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});
```

---

## 🔧 Configuration

### Cloudflare Tunnel

**Location**: `infrastructure/cloudflare/tunnel-config.yml`

```yaml
ingress:
  - hostname: home.ozkar.co
    service: http://localhost:3000
  
  - hostname: myservice.ozkar.co
    service: http://localhost:3001
  
  # Catch-all
  - service: http_status:404
```

Services defined here are automatically loaded into the dashboard. No manual updates to `server.js` required.

**To add a service:**
1. Deploy service on localhost:PORT
2. Add ingress entry to `tunnel-config.yml`
3. Restart cloudflared

---

## 📊 Monitoring

### Service Health Checks

The Home/Hub service monitors all services defined in `tunnel-config.yml`:

**Health check logic:**
1. HTTP GET to `{url}{health_path}` (defaults to `{url}/health`)
2. Check status code (200 = UP)
3. Timeout after 5 seconds
4. Display on dashboard

To use a custom health check path, add `health_path` to the ingress rule:
```yaml
- hostname: myservice.ozkar.co
  service: http://localhost:PORT
  health_path: /api/version
```

Services are loaded dynamically from `infrastructure/cloudflare/tunnel-config.yml` at startup.

---

## 🚀 Deployment Workflow

### Adding a New Service

1. **Develop Service**
   - Create in separate repository
   - Implement `/health` endpoint
   - Test locally

2. **Deploy Service**
   - Deploy to server
   - Configure to run on `localhost:PORT`
   - Ensure it starts on boot (systemd)

3. **Configure Tunnel**
   - Edit `infrastructure/cloudflare/tunnel-config.yml`
   - Add ingress entry with hostname and port
   - Restart cloudflared: `systemctl restart cloudflared`

4. **Verify**
   - Check service at `https://myservice.ozkar.co`
   - Verify status on Home/Hub dashboard (updates automatically)

---

## 🔐 Security Model

### Public Services
- **TLS**: Handled by Cloudflare (trusted certificates)
- **DDoS**: Cloudflare protection
- **WAF**: Available through Cloudflare
- **Firewall**: No inbound ports needed
- **Isolation**: Services on localhost only

---

## 📏 Design Principles

1. **Separation of Concerns**
   - Infrastructure ≠ Services
   - Each service = own repository
   - Clear boundaries

2. **Minimal Infrastructure**
   - Only essential components
   - Leverage managed services (Cloudflare)
   - Avoid premature optimization

3. **Declarative Configuration**
   - YAML over scripts
   - Version-controlled
   - Easy to review

4. **No Local Complexity**
   - No reverse proxy (Nginx)
   - No SSL management
   - No service coupling

5. **Ready to Scale**
   - Add services without changing core
   - Independent deployment
   - No shared state

---

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Tunnel | Cloudflare Tunnel | Public access, TLS |
| Home/Hub | Node.js + Express | Status & docs |
| Config | YAML | Declarative setup |

---

## 📚 Directory Structure

```
OzNet/
├── documentation/
│   └── ARCHITECTURE.md       # This file
├── infrastructure/
│   └── cloudflare/
│       ├── tunnel-config.yml # Tunnel routing (source of truth for services)
│       └── README.md         # Setup guide
├── views/                    # Templates
├── server.js                 # Home/Hub service
├── run.sh                    # Startup script
├── package.json              # Dependencies
└── README.md                 # Getting started
```

---

## ❓ Common Questions

**Q: Why not use Nginx?**
A: Cloudflare Tunnel replaces it. No need for local reverse proxy.

**Q: Where are the services?**
A: In external repositories. This is infrastructure only.

**Q: How to add a service?**
A: Deploy it independently, add to tunnel config, the dashboard updates automatically.

**Q: What about databases?**
A: Deploy with the service that needs them, not here.

**Q: Can I use paths instead of subdomains?**
A: No. Each service gets its own subdomain. Cleaner and more flexible.

---

**Last Updated**: March 2026  
**Version**: 2.0.0
