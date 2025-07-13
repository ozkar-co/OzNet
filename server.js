const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const path = require('path');

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
  
  req.subdomain = subdomain;
  next();
});

// Rutas de desarrollo (funcionan sin subdominios)
app.use('/home', homeApp);
app.use('/hub', hubApp);
app.use('/files', filesApp);

// Rutas principales para cada subdominio
app.get('/', (req, res, next) => {
  if (req.subdomain === 'home' || req.subdomain === 'server') {
    return homeApp(req, res, next);
  }
  if (req.subdomain === 'hub') {
    return hubApp(req, res, next);
  }
  if (req.subdomain === 'files') {
    return filesApp(req, res, next);
  }
  next();
});

// Servidor por defecto para desarrollo
app.get('/', (req, res) => {
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
            <li><a href="http://home.oznet">home.oznet</a> - Documentación principal</li>
            <li><a href="http://hub.oznet">hub.oznet</a> - Gestión de servicios</li>
            <li><a href="http://files.oznet">files.oznet</a> - Servidor de archivos</li>
            <li><a href="http://server.oznet">server.oznet</a> - Servidor principal</li>
          </ul>
          <p><strong>Para desarrollo:</strong></p>
          <ul>
            <li><a href="/home">/home</a> - Documentación</li>
            <li><a href="/hub">/hub</a> - Gestión de servicios</li>
            <li><a href="/files">/files</a> - Servidor de archivos</li>
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
  console.log('   • 3dprint.oznet - OctoPrint (coming soon)');
  console.log('');
  console.log('🔧 Development routes:');
  console.log('   • http://localhost:3000/home');
  console.log('   • http://localhost:3000/hub');
  console.log('   • http://localhost:3000/files');
}); 