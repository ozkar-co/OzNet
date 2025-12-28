# OzNet Home/Hub Service

> Status dashboard and documentation hub for OzNet infrastructure

## 🎯 Purpose

This is the **Home/Hub** service - the central entry point for OzNet infrastructure. It provides:

1. **Service Status Dashboard** - Monitor health of all configured services
2. **Documentation Hub** - Links to architecture and setup guides  
3. **System Overview** - Explains the infrastructure model

## ✨ Features

- ✅ Health monitoring for all services
- ✅ Simple, clean web interface (PicoCSS)
- ✅ REST API for service status
- ✅ Auto-refresh every 30 seconds
- ✅ Minimal dependencies

## 🚀 Quick Start

### Install Dependencies

```bash
npm install
```

### Development

```bash
npm run dev  # Starts with nodemon for hot reload
```

### Production

```bash
npm start
```

The service will run on `http://localhost:3000` by default.

## 📋 API Endpoints

### Health Check
```
GET /health
```

Returns health status of this service.

**Response:**
```json
{
  "status": "UP",
  "service": "oznet-home"
}
```

### Service Status
```
GET /api/services/status
```

Returns status of all configured services.

**Response:**
```json
{
  "timestamp": "2024-12-28T00:00:00.000Z",
  "services": [
    {
      "name": "Home/Hub",
      "url": "http://localhost:3000",
      "description": "Infrastructure hub",
      "external": false,
      "status": "UP",
      "statusCode": 200
    }
  ]
}
```

## 🔧 Configuration

### Adding Services to Monitor

Edit `index.js` and add to the `SERVICES` array:

```javascript
const SERVICES = [
  {
    name: 'My Service',
    url: 'http://localhost:3001',
    description: 'Service description',
    external: true  // true for external repos, false for this repo
  }
];
```

### Health Check Requirements

Services must implement a `/health` endpoint:

```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});
```

**Special case - OctoPrint:**
- Use `/` or `/api/version` instead of `/health`
- Only HTTP status code is checked (200 = UP)

## 📁 Directory Structure

```
home/
├── index.js                    # Main Express application
├── package.json                # Dependencies
├── views/
│   ├── layouts/
│   │   └── main.handlebars    # Main layout template
│   └── index.handlebars        # Home page template
└── public/                     # Static assets (if any)
```

## 🎨 Templates

Templates use Handlebars with PicoCSS for styling.

### Available Helpers

- `json` - Pretty-print JSON
- `eq` - Check equality (for conditionals)

### Main Template

Located at `views/index.handlebars`, displays:
- System overview
- Architecture explanation
- Service status grid
- Documentation links

## 🔒 Security

- Uses Helmet.js for security headers
- Compression enabled
- Content Security Policy configured
- Only allows HTTPS resources (except self)

## 🌐 Public Access

This service is accessed via Cloudflare Tunnel:

```yaml
# In infrastructure/cloudflare/tunnel-config.yml
ingress:
  - hostname: home.ozkar.co
    service: http://localhost:3000
```

## 📊 Monitoring Logic

Health checks work as follows:

1. **HTTP GET** to `{service.url}/health`
2. **Timeout** after 5 seconds
3. **Status codes:**
   - 200 = Service is UP
   - Other/timeout = Service is DOWN
4. **Display** on dashboard

No response body parsing - only status codes matter.

## 🛠️ Development

### Local Testing

```bash
npm install
npm run dev
```

Visit `http://localhost:3000`

### Adding Features

1. Edit `index.js` for backend logic
2. Edit `views/index.handlebars` for UI
3. Test locally
4. No build step required

### Dependencies

- `express` - Web framework
- `express-handlebars` - Templating
- `helmet` - Security headers
- `compression` - Response compression
- `morgan` - HTTP logging
- `node-fetch` - HTTP client for health checks

## 📝 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Port to listen on |
| `NODE_ENV` | development | Environment mode |

## 🔄 Deployment

### As systemd Service

Create `/etc/systemd/system/oznet-home.service`:

```ini
[Unit]
Description=OzNet Home/Hub Service
After=network.target

[Service]
Type=simple
User=oznet
WorkingDirectory=/opt/OzNet/home
ExecStart=/usr/bin/node index.js
Restart=always
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable oznet-home
sudo systemctl start oznet-home
```

### With Docker (Optional)

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
```

## 📖 Documentation

- [Main README](../README.md)
- [Architecture](../documentation/ARCHITECTURE.md)
- [Transition Guide](../documentation/TRANSITION.md)

## 🤝 Contributing

This is the infrastructure hub - keep it simple:
- ✅ Add service monitoring
- ✅ Improve documentation display
- ✅ Add system information
- ❌ Don't add business logic
- ❌ Don't couple with external services

## 📄 License

MIT License - See [LICENSE](../LICENSE) file

---

**Version:** 2.0.0  
**Last Updated:** December 2024
