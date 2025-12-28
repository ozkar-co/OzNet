# OzNet - Infrastructure Repository

> Simplified, decoupled infrastructure for personal services using Cloudflare Tunnel

---

## 🎯 What is OzNet?

OzNet is a **minimal infrastructure repository** that provides:

1. **Cloudflare Tunnel** - Secure public access to services
2. **Internal DNS** - For ZeroTier, VPN, and game servers  
3. **Home/Hub** - Service status dashboard and documentation

**Important**: This repository does **NOT** contain business services. All services live in separate, independent repositories.

---

## ✨ Features

- ✅ **No Nginx** - Cloudflare Tunnel handles reverse proxy
- ✅ **No SSL Management** - Cloudflare manages certificates  
- ✅ **No Coupled Services** - Each service is independent
- ✅ **Declarative Config** - YAML-based tunnel configuration
- ✅ **Health Monitoring** - Track service status from Home/Hub
- ✅ **Minimal DNS** - Only for internal/VPN access
- ✅ **Zero Open Ports** - Everything through Cloudflare Tunnel

---

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Cloudflare account with a domain
- (Optional) ZeroTier for internal access

### 1. Install Cloudflare Tunnel

```bash
# Ubuntu/Debian
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

### 2. Setup Cloudflare Tunnel

```bash
# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create oznet

# Configure DNS (for each service)
cloudflared tunnel route dns oznet home.ozkar.co
```

### 3. Configure Tunnel

Edit `infrastructure/cloudflare/tunnel-config.yml`:

```yaml
credentials-file: /root/.cloudflared/<your-tunnel-id>.json

ingress:
  - hostname: home.ozkar.co
    service: http://localhost:3000
  - service: http_status:404

tunnel: oznet
```

See [infrastructure/cloudflare/README.md](infrastructure/cloudflare/README.md) for details.

### 4. Install Home/Hub Service

```bash
cd home
npm install
```

### 5. Start Services

```bash
# Start Home/Hub
cd home
npm start

# In another terminal, start Cloudflare Tunnel
cloudflared tunnel --config infrastructure/cloudflare/tunnel-config.yml run
```

### 6. Access

Visit `https://home.ozkar.co` (or your configured domain)

---

## 📁 Repository Structure

```
OzNet/
├── config/
│   └── dnsmasq.conf              # Minimal DNS (ZeroTier/VPN only)
├── documentation/
│   ├── ARCHITECTURE.md           # System design
│   └── TRANSITION.md             # What changed from v1
├── home/
│   ├── index.js                  # Home/Hub service
│   ├── package.json
│   └── views/                    # Web interface
├── infrastructure/
│   ├── cloudflare/
│   │   ├── tunnel-config.yml    # Tunnel routing config
│   │   └── README.md            # Setup guide
│   └── scripts/
│       ├── cleanup-dns.sh       # Remove old DNS entries
│       ├── cleanup-nginx.sh     # Remove Nginx config
│       └── cleanup-ssl.sh       # Remove SSL infrastructure
└── README.md                     # This file
```

---

## 🏗️ Architecture

### Public Access Model

```
Internet → Cloudflare (TLS) → Tunnel → localhost:PORT → Service
```

- All TLS handled by Cloudflare
- Services listen on localhost only
- No ports exposed to internet
- Each service has its own subdomain

### Internal Access Model

Via ZeroTier VPN:
- `172.26.0.1` → `home.oznet` (Home/Hub)
- `172.26.0.2` → `server.oznet` (Main server)

**Use for**: VPN access, game servers, internal tools  
**NOT for**: Public HTTP services (use Cloudflare instead)

---

## 📊 Adding a Service

### 1. Create Service (External Repo)

Your service should:
- Run on `localhost:PORT`
- Implement `GET /health` endpoint (returns 200 when healthy)
- Be in its own repository

Example:
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});
```

### 2. Add to Tunnel Config

Edit `infrastructure/cloudflare/tunnel-config.yml`:

```yaml
ingress:
  - hostname: myservice.ozkar.co
    service: http://localhost:3001
```

### 3. Configure DNS

```bash
cloudflared tunnel route dns oznet myservice.ozkar.co
```

### 4. Update Home/Hub Monitoring

Edit `home/index.js`:

```javascript
const SERVICES = [
  {
    name: 'My Service',
    url: 'http://localhost:3001',
    description: 'Service description',
    external: true
  }
];
```

### 5. Restart Services

```bash
systemctl restart cloudflared
systemctl restart oznet-home
```

---

## 🔧 Configuration

### Cloudflare Tunnel

Main config: `infrastructure/cloudflare/tunnel-config.yml`

Key sections:
- `credentials-file`: Path to tunnel credentials
- `ingress`: Routing rules (hostname → localhost:port)
- `tunnel`: Tunnel name

### Internal DNS

Main config: `config/dnsmasq.conf`

Only includes:
- `home.oznet` → 172.26.0.1
- `server.oznet` → 172.26.0.2

For ZeroTier/VPN/game servers only.

---

## 🔐 Security

### Public Services
- **TLS**: Cloudflare-managed, trusted certificates
- **DDoS**: Cloudflare protection included
- **WAF**: Available through Cloudflare
- **Exposure**: No direct port exposure
- **Isolation**: Services on localhost only

### Internal Services  
- **Network**: ZeroTier encrypted VPN
- **Access**: Controlled by ZeroTier ACLs
- **DNS**: Internal resolution only

---

## 📖 Documentation

- [ARCHITECTURE.md](documentation/ARCHITECTURE.md) - Detailed system design
- [TRANSITION.md](documentation/TRANSITION.md) - Migration from v1
- [Cloudflare Setup](infrastructure/cloudflare/README.md) - Tunnel configuration

---

## 🧹 Migrating from v1

If you're upgrading from the old architecture:

### Run Cleanup Scripts

```bash
# Remove Nginx configuration
sudo infrastructure/scripts/cleanup-nginx.sh

# Remove SSL infrastructure
sudo infrastructure/scripts/cleanup-ssl.sh

# Trim DNS to essentials
sudo infrastructure/scripts/cleanup-dns.sh
```

### Update Access

- Public services: Access via new Cloudflare domains
- Internal services: Still available via ZeroTier
- No certificate installation needed

See [TRANSITION.md](documentation/TRANSITION.md) for full details.

---

## 🛠️ Development

### Run Home/Hub Locally

```bash
cd home
npm install
npm run dev  # Hot reload with nodemon
```

Access at `http://localhost:3000`

### Test Tunnel Config

```bash
cloudflared tunnel --config infrastructure/cloudflare/tunnel-config.yml run
```

---

## 🎯 Design Principles

1. **Minimal Infrastructure** - Only essential components
2. **Separation of Concerns** - Infrastructure ≠ Services  
3. **Declarative Configuration** - YAML over scripts
4. **No Local Complexity** - Leverage Cloudflare
5. **Ready to Scale** - Add services without core changes

---

## 📝 Service Requirements

All external services must:

1. ✅ Run on `localhost:PORT`
2. ✅ Implement `/health` endpoint
3. ✅ Live in separate repository
4. ✅ Have independent deployment
5. ✅ Return HTTP 200 on `/health` when healthy

---

## ❓ FAQ

**Q: Where are the actual services?**  
A: In separate repositories. This is infrastructure only.

**Q: Why not use Nginx?**  
A: Cloudflare Tunnel replaces it. No need for local reverse proxy.

**Q: Do I need SSL certificates?**  
A: No. Cloudflare handles all TLS with trusted certificates.

**Q: Can I use path-based routing?**  
A: No. Each service gets its own subdomain. Cleaner and more flexible.

**Q: What about databases?**  
A: Deploy them with the services that need them, not here.

---

## 🤝 Contributing

This is a personal infrastructure repository, but suggestions are welcome:

1. Open an issue for discussion
2. Keep changes minimal and focused
3. Follow existing architecture principles

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🔗 Links

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [ZeroTier](https://www.zerotier.com/)
- [Express.js](https://expressjs.com/)

---

**Version**: 2.0.0  
**Last Updated**: December 2024

> Built with simplicity in mind. Ready to grow without technical debt.
 