# OzNet Infrastructure Transition

## What Was Removed and Why

This document explains what was eliminated from OzNet and the reasoning behind each decision.

---

## 🗑️ Removed Components

### 1. Nginx Configuration & Services

**What was removed:**
- Complete Nginx reverse proxy setup
- SSL termination configuration
- Virtual host configurations for all services
- Service-specific location blocks

**Why:**
- Cloudflare Tunnel now handles all reverse proxy functionality
- Cloudflare manages TLS/SSL termination with their trusted certificates
- Eliminates need for local reverse proxy infrastructure
- Reduces complexity and maintenance burden

**Impact:**
- No local port 80/443 listening
- No need to manage Nginx configurations
- Services now access via Cloudflare Tunnel only

---

### 2. Internal SSL/TLS Infrastructure

**What was removed:**
- Custom Certificate Authority (CA)
- CA generation scripts (`create-ca.sh`)
- SSL certificate management scripts (`fix-ssl-persistence.sh`)
- Certificate distribution system
- Certificate persistence services
- All `/etc/ssl/oznet*` directories
- Client certificate installation scripts

**Why:**
- Cloudflare provides trusted, automatically-renewed certificates
- No need for self-signed certificates
- Eliminates certificate distribution to clients
- Removes certificate renewal burden
- Internal services (ZeroTier/VPN) don't require HTTPS

**Impact:**
- No custom certificates to install on client devices
- No certificate expiration management
- Simplified security model

---

### 3. Integrated Services

**What was removed:**
- `apps/home` - Home documentation service
- `apps/hub` - Service management dashboard
- `apps/files` - File server implementation
- All service-specific code in `server.js`

**Why:**
- Violates single responsibility principle
- Services should live in independent repositories
- Easier to maintain and deploy separately
- Better separation of concerns
- Independent scaling and updates

**Where they went:**
- Services migrated to external repositories (or will be)
- Each service now has its own deployment pipeline
- Services connect via Cloudflare Tunnel

---

### 4. Extensive DNS Entries

**What was removed:**
- `hub.oznet` (172.26.0.1)
- `files.oznet` (172.26.0.1)
- `mail.oznet` (172.26.0.1)
- `wiki.oznet` (172.26.0.1)
- `3dprint.oznet` (172.26.0.1)
- `cam.oznet` (172.26.0.1)

**What was kept:**
- `home.oznet` (172.26.0.1) - This infrastructure hub
- `server.oznet` (172.26.0.2) - Main server

**Why:**
- Public services now use Cloudflare domains (e.g., `files.oscar.co`)
- Internal DNS only for ZeroTier, VPN, and game servers
- Simplified DNS management
- Clear separation between public and private access

---

### 5. Legacy Scripts

**What was removed:**
- `scripts/setup.sh`
- `scripts/update-config.sh`
- `scripts/create-ca.sh`
- `scripts/fix-ssl-persistence.sh`

**Why:**
- No longer needed with new architecture
- SSL scripts obsolete with Cloudflare Tunnel
- Setup simplified dramatically
- Configuration now declarative (YAML)

**Replaced with:**
- `infrastructure/scripts/cleanup-*.sh` - Migration scripts
- Cloudflare Tunnel configuration files
- Simplified setup documentation

---

### 6. Documentation

**What was removed:**
- `docs/SSL_TROUBLESHOOTING.md`
- `docs/DEPLOY.md`
- `docs/INSTALL.md`

**Why:**
- SSL documentation no longer relevant
- Deployment process completely changed
- Installation simplified significantly

**Replaced with:**
- New `README.md` focused on current architecture
- `ARCHITECTURE.md` explaining design decisions
- `TRANSITION.md` (this document)
- Cloudflare-specific setup guides

---

## ✅ What Remains

### Core Infrastructure
1. **DNS (Minimal)**
   - For ZeroTier/VPN/game servers only
   - Only 2 entries: home.oznet, server.oznet

2. **Cloudflare Tunnel**
   - Handles all public access
   - Manages TLS/SSL
   - Routes to localhost services

3. **Home/Hub Service**
   - Status dashboard
   - Documentation hub
   - Service health monitoring

---

## 🎯 Benefits of Changes

### Simplified Architecture
- No reverse proxy to maintain
- No SSL certificates to manage
- No service integration complexity

### Better Separation
- Each service in its own repository
- Independent deployment cycles
- Clear boundaries

### Reduced Technical Debt
- Removed unused/legacy code
- Cleaner directory structure
- Focused purpose

### Easier Maintenance
- Cloudflare handles infrastructure concerns
- Fewer moving parts
- Declarative configuration

### Security Improvements
- Trusted Cloudflare certificates
- DDoS protection included
- WAF available
- No exposed ports

---

## 🚀 Migration Path

For users of the old system:

1. **Public Services**
   - Access via new Cloudflare domains (e.g., `home.oscar.co`)
   - No certificate installation needed
   - Bookmark new URLs

2. **Internal Access**
   - ZeroTier/VPN access still works
   - Only `home.oznet` and `server.oznet` available
   - Game servers unaffected

3. **Service Operators**
   - Migrate services to external repositories
   - Implement `/health` endpoint
   - Configure in Cloudflare Tunnel
   - Deploy independently

---

## 📝 Lessons Learned

1. **Start Simple**: Don't build infrastructure until you need it
2. **Avoid Coupling**: Services should be independent
3. **Use Managed Services**: Let Cloudflare handle TLS, DDoS, etc.
4. **Be Ruthless**: Remove code that doesn't serve current needs
5. **Document Decisions**: Explain why things were removed

---

## ❓ FAQ

**Q: Why remove working code?**
A: It wasn't serving the current architecture and created maintenance burden.

**Q: What if we need those services again?**
A: They're in git history and can be restored. But deploy them as independent services.

**Q: Why trust Cloudflare?**
A: Industry-standard, free tier available, handles TLS better than self-signed certs.

**Q: What about internal SSL?**
A: Not needed. ZeroTier/VPN traffic is already encrypted. Game servers don't need HTTPS.

---

**Date**: December 2024
**Version**: 2.0.0
