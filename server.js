const express = require('express');
const { engine } = require('express-handlebars');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');
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
        url: rule.service
      }));
  } catch (err) {
    console.error('Failed to load tunnel config from', configPath, ':', err.message);
    process.exit(1);
  }
}

const SERVICES = loadServices();

// Health check function
async function checkServiceHealth(service) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000); // 5 second timeout
    
    const response = await fetch(`${service.url}/health`, {
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

// Routes
app.get('/', async (req, res) => {
  try {
    // Check all services in parallel
    const serviceChecks = await Promise.all(
      SERVICES.map(service => checkServiceHealth(service))
    );
    
    res.render('index', {
      title: 'OzNet - Infrastructure Hub',
      services: serviceChecks
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
    const serviceChecks = await Promise.all(
      SERVICES.map(service => checkServiceHealth(service))
    );
    
    res.json({
      timestamp: new Date().toISOString(),
      services: serviceChecks
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
