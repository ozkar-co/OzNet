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

2. **Minimal Internal DNS**
   - For ZeroTier network only
   - For VPN access only
   - For game servers only
   - **NOT for public HTTP services**

3. **Home/Hub Service**
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
    │  Home   │   │  Files   │    │OctoPrint │
    │  Hub    │   │  Server  │    │          │
    └─────────┘   └──────────┘    └──────────┘
    (This repo)   (External repo) (External repo)
```

---

## 🌐 Public Access Flow

1. **User Request**
   ```
   https://home.ozkar.co
   ```

2. **DNS Resolution**
   - CNAME points to Cloudflare Tunnel
   - Handled by Cloudflare DNS

3. **Cloudflare Processing**
   - TLS termination
   - DDoS protection
   - WAF rules applied

4. **Tunnel Routing**
   - Cloudflare Tunnel forwards to `localhost:3000`
   - Based on `tunnel-config.yml` ingress rules

5. **Service Response**
   - Service listens on localhost only
   - Returns response through tunnel
   - Cloudflare encrypts and delivers to user

**Key Points:**
- No ports exposed to internet
- No local SSL certificates needed
- Cloudflare handles all security
- Services remain isolated on localhost

---

## 🔒 Internal Access Flow

Internal access uses ZeroTier for VPN connectivity:

```
┌──────────────┐
│  ZeroTier    │
│  Network     │
│ 172.26.0.0/24│
└──────┬───────┘
       │
   ┌───┴────┐
   │        │
   ▼        ▼
home.oznet  server.oznet
172.26.0.1  172.26.0.2
```

**Usage:**
- Game servers
- VPN access
- Internal tools
- **NOT for public web services**

**DNS Entries:**
- `home.oznet` → 172.26.0.1 (This hub)
- `server.oznet` → 172.26.0.2 (Main server)

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
   - Used for monitoring

4. **Cloudflare Tunnel Entry**
   ```yaml
   ingress:
     - hostname: myservice.ozkar.co
       service: http://localhost:PORT
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

## 🔧 Configuration Files

### Cloudflare Tunnel

**Location**: `infrastructure/cloudflare/tunnel-config.yml`

```yaml
ingress:
  - hostname: home.ozkar.co
    service: http://localhost:3000
  
  - hostname: files.ozkar.co
    service: http://localhost:3001
  
  # Catch-all
  - service: http_status:404
```

**To add a service:**
1. Deploy service on localhost:PORT
2. Add ingress entry
3. Configure DNS CNAME
4. Restart cloudflared

### DNS Configuration

**Location**: `config/dnsmasq.conf`

Minimal configuration:
```
address=/home.oznet/172.26.0.1
address=/server.oznet/172.26.0.2
```

**Do NOT add:**
- Public web services
- Services accessed via Cloudflare
- Temporary services

---

## 📊 Monitoring

### Service Health Checks

The Home/Hub service monitors all configured services:

```javascript
// In server.js
const SERVICES = [
  {
    name: 'My Service',
    url: 'http://localhost:3001',
    description: 'Service description'
  }
];
```

**Health check logic:**
1. HTTP GET to `{url}/health`
2. Check status code (200 = UP)
3. Timeout after 5 seconds
4. Display on dashboard

**Special case - OctoPrint:**
- Use `/` or `/api/version` instead
- Only check HTTP status code
- Don't parse response body

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

4. **Configure DNS**
   ```bash
   cloudflared tunnel route dns oznet myservice.ozkar.co
   ```

5. **Update Home/Hub**
   - Add service to `SERVICES` array in `server.js`
   - Restart home service

6. **Verify**
   - Check service at `https://myservice.ozkar.co`
   - Verify status on Home/Hub dashboard

---

## 🔐 Security Model

### Public Services
- **TLS**: Handled by Cloudflare (trusted certificates)
- **DDoS**: Cloudflare protection
- **WAF**: Available through Cloudflare
- **Firewall**: No inbound ports needed
- **Isolation**: Services on localhost only

### Internal Services
- **Network**: ZeroTier encrypted tunnel
- **Access**: Controlled by ZeroTier ACLs
- **DNS**: Internal only (dnsmasq)
- **No HTTPS**: VPN already encrypted

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
| DNS | dnsmasq | Internal name resolution |
| VPN | ZeroTier | Private network |
| Home/Hub | Node.js + Express | Status & docs |
| Config | YAML | Declarative setup |

---

## 📚 Directory Structure

```
OzNet/
├── config/
│   └── dnsmasq.conf          # Minimal DNS config
├── documentation/
│   ├── ARCHITECTURE.md       # This file
│   └── TRANSITION.md         # What changed
├── infrastructure/
│   ├── cloudflare/
│   │   ├── tunnel-config.yml # Tunnel routing
│   │   └── README.md         # Setup guide
│   └── scripts/
│       ├── cleanup-dns.sh
│       ├── cleanup-nginx.sh
│       └── cleanup-ssl.sh
├── views/                    # Templates
├── server.js                 # Home/Hub service
├── package.json              # Dependencies
└── README.md                 # Getting started
```

---

## ❓ Common Questions

**Q: Why not use Nginx?**
A: Cloudflare Tunnel replaces it. No need for local reverse proxy.

**Q: Why no internal SSL?**
A: Cloudflare provides trusted certificates. Internal traffic uses VPN encryption.

**Q: Where are the services?**
A: In external repositories. This is infrastructure only.

**Q: How to add a service?**
A: Deploy it independently, add to tunnel config, update Home/Hub monitoring.

**Q: What about databases?**
A: Deploy with the service that needs them, not here.

**Q: Can I use paths instead of subdomains?**
A: No. Each service gets its own subdomain. Cleaner and more flexible.

---

**Last Updated**: December 2024  
**Version**: 2.0.0
