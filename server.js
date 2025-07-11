const express = require('express');
const vhost = require('express-vhost');
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

// Configurar virtual hosts
app.use(vhost('home.oznet', homeApp));
app.use(vhost('hub.oznet', hubApp));
app.use(vhost('files.oznet', filesApp));

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
  console.log('   • mail.oznet - Mail server (coming soon)');
  console.log('   • wiki.oznet - Kiwix server (coming soon)');
  console.log('   • 3dprint.oznet - OctoPrint (coming soon)');
}); 