const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

// Importar las aplicaciones de cada servicio
const homeApp = require('./apps/home');
const hubApp = require('./apps/hub');
const filesApp = require('./apps/files');

const app = express();

// Middleware de seguridad y optimización
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));
app.use(compression());
app.use(morgan('combined'));

// Middleware para detectar subdominios
app.use((req, res, next) => {
  const host = req.get('Host');
  const subdomain = host ? host.split('.')[0] : '';
  
  console.log('=== REQUEST DEBUG ===');
  console.log('Host header:', host);
  console.log('Extracted subdomain:', subdomain);
  console.log('Request URL:', req.url);
  console.log('Request method:', req.method);
  console.log('====================');
  
  req.subdomain = subdomain;
  next();
});

// OctoPrint proxy configuration
const octoprintProxy = createProxyMiddleware({
  target: 'http://172.26.0.1:5000',
  changeOrigin: true,
  ws: true, // Enable WebSocket proxy
  secure: false, // Allow insecure connections
  logLevel: 'debug', // Enable logging for debugging
  onProxyReq: (proxyReq, req, res) => {
    // Set headers for OctoPrint according to official documentation
    proxyReq.setHeader('Host', '172.26.0.1:5000');
    proxyReq.setHeader('X-Forwarded-Host', req.get('Host'));
    proxyReq.setHeader('X-Forwarded-Proto', 'https'); // Force HTTPS
    proxyReq.setHeader('X-Forwarded-For', req.ip || req.connection.remoteAddress);
    proxyReq.setHeader('X-Real-IP', req.ip || req.connection.remoteAddress);
    proxyReq.setHeader('X-Script-Name', '/');
    proxyReq.setHeader('X-Scheme', 'https'); // Force HTTPS
    
    console.log('Proxying to OctoPrint:', req.method, req.url);
    console.log('Headers set:', {
      'X-Forwarded-Host': req.get('Host'),
      'X-Forwarded-Proto': 'https',
      'X-Forwarded-For': req.ip || req.connection.remoteAddress,
      'X-Script-Name': '/'
    });
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log('OctoPrint response:', proxyRes.statusCode, proxyRes.headers.location);
    
    // Handle redirects from OctoPrint
    if (proxyRes.headers.location) {
      const location = proxyRes.headers.location;
      console.log('Original redirect location:', location);
      
      // If OctoPrint tries to redirect to an internal URL, rewrite it
      if (location.startsWith('/')) {
        const newLocation = `https://3dprint.oznet${location}`;
        proxyRes.headers.location = newLocation;
        console.log('Rewritten redirect location:', newLocation);
      }
    }
    
    // Remove any problematic headers
    delete proxyRes.headers['x-frame-options'];
    delete proxyRes.headers['x-content-type-options'];
  },
  onError: (err, req, res) => {
    console.error('Proxy error:', err);
    res.status(500).send('Proxy error: ' + err.message);
  }
});

// Middleware para manejar subdominios
app.use((req, res, next) => {
  const subdomain = req.subdomain;
  
  console.log('=== SUBDOMAIN HANDLING ===');
  console.log('Subdomain:', subdomain);
  console.log('Request URL:', req.url);
  console.log('==========================');
  
  // Handle OctoPrint subdomain
  if (subdomain === '3dprint') {
    console.log('Handling 3dprint request:', req.method, req.url);
    return octoprintProxy(req, res, next);
  }
  
  // Rutas de desarrollo (funcionan sin subdominios)
  if (req.path.startsWith('/home')) {
    console.log('Handling /home route');
    return homeApp(req, res, next);
  }
  if (req.path.startsWith('/hub')) {
    console.log('Handling /hub route');
    return hubApp(req, res, next);
  }
  if (req.path.startsWith('/files')) {
    console.log('Handling /files route');
    return filesApp(req, res, next);
  }
  
  // Manejo de subdominios
  if (subdomain === 'home' || subdomain === 'server') {
    console.log('Handling home/server subdomain');
    return homeApp(req, res, next);
  }
  if (subdomain === 'hub') {
    console.log('Handling hub subdomain');
    return hubApp(req, res, next);
  }
  if (subdomain === 'files') {
    console.log('Handling files subdomain');
    return filesApp(req, res, next);
  }
  
  console.log('No specific handler found, continuing to default handler');
  next();
});

// Servir certificados SSL
app.get('/certs/:filename', (req, res) => {
  const filename = req.params.filename;
  const certPath = path.join('/var/oznet/certs', filename);
  
  console.log('Certificate request:', filename);
  console.log('Certificate path:', certPath);
  
  // Solo permitir descargar archivos .crt y .pem
  if (!filename.match(/\.(crt|pem)$/)) {
    return res.status(403).send('Acceso denegado');
  }
  
  // Verificar que el archivo existe
  const fs = require('fs');
  if (!fs.existsSync(certPath)) {
    console.log('Certificate file not found:', certPath);
    return res.status(404).send(`Certificado no encontrado: ${filename}`);
  }
  
  console.log('Certificate file found, downloading...');
  res.download(certPath, filename, (err) => {
    if (err) {
      console.error('Error downloading certificate:', err);
      res.status(500).send('Error al descargar certificado');
    } else {
      console.log('Certificate downloaded successfully');
    }
  });
});

// Servidor por defecto para desarrollo
app.get('/', (req, res) => {
  console.log('Serving default page');
  res.send(`
    <html>
      <head>
        <title>OzNet - Red Privada</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@1/css/pico.min.css">
      </head>
      <body>
        <main class="container">
          <h1>OzNet - Red Privada</h1>
          <p>Bienvenido a la red privada OzNet. Los servicios disponibles son:</p>
          <ul>
            <li><a href="https://home.oznet">home.oznet</a> - Documentación principal</li>
            <li><a href="https://hub.oznet">hub.oznet</a> - Gestión de servicios</li>
            <li><a href="https://files.oznet">files.oznet</a> - Servidor de archivos</li>
            <li><a href="https://server.oznet">server.oznet</a> - Servidor principal</li>
            <li><a href="https://3dprint.oznet">3dprint.oznet</a> - OctoPrint (manejado por Node.js)</li>
          </ul>
          <p><strong>Para desarrollo:</strong></p>
          <ul>
            <li><a href="/home">/home</a> - Documentación</li>
            <li><a href="/hub">/hub</a> - Gestión de servicios</li>
            <li><a href="/files">/files</a> - Servidor de archivos</li>
          </ul>
          <p><strong>Certificados SSL:</strong></p>
          <ul>
            <li><a href="/certs/oznet-ca.crt">Descargar Certificado CA</a></li>
          </ul>
        </main>
      </body>
    </html>
  `);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 OzNet server running on port ${PORT}`);
  console.log('📋 Available services:');
  console.log('   • home.oznet - Main documentation');
  console.log('   • hub.oznet - Service management');
  console.log('   • files.oznet - File server');
  console.log('   • server.oznet - Main server');
  console.log('   • mail.oznet - Mail server (coming soon)');
  console.log('   • wiki.oznet - Kiwix server (coming soon)');
  console.log('   • 3dprint.oznet - OctoPrint (proxied by Node.js)');
  console.log('');
  console.log('🔧 Development routes:');
  console.log('   • http://localhost:3000/home');
  console.log('   • http://localhost:3000/hub');
  console.log('   • http://localhost:3000/files');
}); 