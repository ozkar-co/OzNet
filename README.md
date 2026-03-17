# OzNet - Infrastructure Repository

> Simplified, decoupled infrastructure for personal services using Cloudflare Tunnel

---

## 🎯 What is OzNet?

OzNet is a **minimal infrastructure repository** that provides:

1. **Cloudflare Tunnel** - Secure public access to services
2. **Home/Hub** - Service status dashboard and documentation

**Important**: This repository does **NOT** contain business services. All services live in separate, independent repositories.

---

## ✨ Features

- ✅ **No Nginx** - Cloudflare Tunnel handles reverse proxy
- ✅ **No SSL Management** - Cloudflare manages certificates  
- ✅ **No Coupled Services** - Each service is independent
- ✅ **Declarative Config** - YAML-based tunnel configuration
- ✅ **Health Monitoring** - Track service status from Home/Hub
- ✅ **Zero Open Ports** - Everything through Cloudflare Tunnel

---

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Cloudflare account with a domain

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

### 4. Install Dependencies

```bash
npm install
```

### 5. Start Services

```bash
# Start Home/Hub
./run.sh

# In another terminal, start Cloudflare Tunnel
cloudflared tunnel --config infrastructure/cloudflare/tunnel-config.yml run
```

### 6. Access

Visit `https://home.ozkar.co` (or your configured domain)

---

## 📁 Repository Structure

```
OzNet/
├── documentation/
│   └── ARCHITECTURE.md           # System design
├── infrastructure/
│   └── cloudflare/
│       ├── tunnel-config.yml    # Tunnel routing config (source of truth for services)
│       └── README.md            # Setup guide
├── views/                        # Web interface templates
├── server.js                     # Home/Hub service
├── run.sh                        # Startup script
├── package.json                  # Dependencies and scripts
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

The service will automatically appear in the Home/Hub dashboard.

### 3. Restart Services

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

Services defined here are automatically loaded into the dashboard.

---

## 🔐 Security

### Public Services
- **TLS**: Cloudflare-managed, trusted certificates
- **DDoS**: Cloudflare protection included
- **WAF**: Available through Cloudflare
- **Exposure**: No direct port exposure
- **Isolation**: Services on localhost only

---

## 📖 Documentation

- [ARCHITECTURE.md](documentation/ARCHITECTURE.md) - Detailed system design
- [Cloudflare Setup](infrastructure/cloudflare/README.md) - Tunnel configuration

---

## 🛠️ Development

### Run Home/Hub Locally

```bash
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

**Q: How do I add a service to the dashboard?**  
A: Just add it to `infrastructure/cloudflare/tunnel-config.yml`. The dashboard loads services automatically from that file.

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
- [Express.js](https://expressjs.com/)

---

**Version**: 2.0.0  
**Last Updated**: March 2026

> Built with simplicity in mind. Ready to grow without technical debt.
 