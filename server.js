const express = require('express');
const { engine } = require('express-handlebars');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
const net = require('net');
const dgram = require('dgram');
const yaml = require('js-yaml');
const fetch = require('node-fetch');

const app = express();

// Handlebars setup
app.engine('handlebars', engine({
  defaultLayout: 'main',
  layoutsDir: path.join(__dirname, 'views/layouts'),
  helpers: {
    json: (context) => JSON.stringify(context, null, 2),
    eq: (a, b) => a === b
  }
}));
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));
app.use(compression());
app.use(morgan('combined'));
app.use(express.static(path.join(__dirname, 'public')));

// Load services dynamically from Cloudflare Tunnel config
function loadServices() {
  const configPath = path.join(__dirname, 'infrastructure/cloudflare/tunnel-config.yml');
  try {
    const config = yaml.load(fs.readFileSync(configPath, 'utf8'));
    return config.ingress
      .filter(rule => rule.hostname && !rule.service.startsWith('http_status:'))
      .map(rule => ({
        name: rule.hostname,
        url: rule.service,
        healthPath: rule.health_path || '/health'
      }));
  } catch (err) {
    console.error('Failed to load tunnel config from', configPath, ':', err.message);
    process.exit(1);
  }
}

const SERVICES = loadServices();

// Load internal services (not exposed through Cloudflare Tunnel)
function loadInternalServices() {
  const configPath = path.join(__dirname, 'infrastructure/services/internal-services.yml');
  try {
    if (!fs.existsSync(configPath)) return [];
    const config = yaml.load(fs.readFileSync(configPath, 'utf8')) || {};
    return (config.services || []).map(service => ({
      host: 'localhost',
      ...service
    }));
  } catch (err) {
    console.error('Failed to load internal services from', configPath, ':', err.message);
    return [];
  }
}

const INTERNAL_SERVICES = loadInternalServices();

// Health check function
async function checkServiceHealth(service) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000); // 5 second timeout
    
    const response = await fetch(`${service.url}${service.healthPath}`, {
      signal: controller.signal,
      method: 'GET'
    });
    
    clearTimeout(timeout);
    
    return {
      ...service,
      status: response.status === 200 ? 'UP' : 'DOWN',
      statusCode: response.status,
      responseTime: Date.now()
    };
  } catch (error) {
    return {
      ...service,
      status: 'DOWN',
      statusCode: null,
      error: error.message,
      responseTime: Date.now()
    };
  }
}

// Node sometimes reports ECONNREFUSED with an empty message, keep the code
function describeError(err) {
  return err.code || err.message || String(err);
}

// TCP health check: UP when the port accepts a connection
function checkTcpHealth(service) {
  return new Promise((resolve) => {
    const start = Date.now();
    const socket = new net.Socket();
    let done = false;

    const finish = (status, extra = {}) => {
      if (done) return;
      done = true;
      socket.destroy();
      resolve({ ...service, status, responseTime: Date.now() - start, ...extra });
    };

    socket.setTimeout(5000);
    socket.once('connect', () => finish('UP'));
    socket.once('timeout', () => finish('DOWN', { error: 'timeout' }));
    socket.once('error', (err) => finish('DOWN', { error: describeError(err) }));
    socket.connect(service.port, service.host);
  });
}

// UDP best-effort check: a closed local port answers with ICMP port-unreachable,
// an open port stays silent. Only reliable against the local machine.
function checkUdpHealth(service) {
  return new Promise((resolve) => {
    const start = Date.now();
    const socket = dgram.createSocket('udp4');
    let done = false;

    const finish = (status, extra = {}) => {
      if (done) return;
      done = true;
      try { socket.close(); } catch (_) { /* already closed */ }
      resolve({ ...service, status, responseTime: Date.now() - start, ...extra });
    };

    socket.once('error', (err) => finish('DOWN', { error: describeError(err) }));

    try {
      socket.connect(service.port, service.host, () => {
        socket.send(Buffer.from([0x00]), (err) => {
          if (err) finish('DOWN', { error: describeError(err) });
        });
      });
    } catch (err) {
      finish('DOWN', { error: describeError(err) });
    }

    // No ICMP error within the window: assume the port is open
    setTimeout(() => finish('UP'), 1500);
  });
}

// Dispatch an internal service to the right checker based on its type
function checkInternalService(service) {
  switch ((service.type || 'tcp').toLowerCase()) {
    case 'http':
      return checkServiceHealth(service);
    case 'udp':
      return checkUdpHealth(service);
    case 'tcp':
      return checkTcpHealth(service);
    default:
      return Promise.resolve({
        ...service,
        status: 'UNKNOWN',
        error: `Unknown check type: ${service.type}`
      });
  }
}

// Routes
app.get('/', async (req, res) => {
  try {
    // Check all services in parallel
    const [serviceChecks, internalChecks] = await Promise.all([
      Promise.all(SERVICES.map(service => checkServiceHealth(service))),
      Promise.all(INTERNAL_SERVICES.map(service => checkInternalService(service)))
    ]);

    res.render('index', {
      title: 'OzNet - Infrastructure Hub',
      services: serviceChecks,
      internalServices: internalChecks
    });
  } catch (error) {
    console.error('Error rendering home page:', error);
    res.status(500).send('Internal server error');
  }
});

// Health endpoint for this service
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', service: 'oznet-home' });
});

// API endpoint to check all services
app.get('/api/services/status', async (req, res) => {
  try {
    const [serviceChecks, internalChecks] = await Promise.all([
      Promise.all(SERVICES.map(service => checkServiceHealth(service))),
      Promise.all(INTERNAL_SERVICES.map(service => checkInternalService(service)))
    ]);

    res.json({
      timestamp: new Date().toISOString(),
      services: serviceChecks,
      internalServices: internalChecks
    });
  } catch (error) {
    console.error('Error checking services:', error);
    res.status(500).json({ error: 'Failed to check services' });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log('🚀 OzNet Home/Hub running on port', PORT);
  console.log('📊 Service status dashboard available at http://localhost:' + PORT);
  console.log('🔧 Health endpoint: http://localhost:' + PORT + '/health');
  console.log('🌐 Public access: Through Cloudflare Tunnel');
});
