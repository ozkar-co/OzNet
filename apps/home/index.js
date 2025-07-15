const express = require('express');
const exphbs = require('express-handlebars');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

const app = express();

// Registrar helper 'eq'
const hbs = exphbs.create({
  defaultLayout: 'main',
  layoutsDir: path.join(__dirname, 'views/layouts'),
  partialsDir: path.join(__dirname, 'views/partials'),
  helpers: {
    eq: (a, b) => a === b
  }
});
app.engine('handlebars', hbs.engine);
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));

// Servir archivos estáticos
app.use('/static', express.static(path.join(__dirname, 'public')));

// Función para obtener IP del cliente
function getClientIP(req) {
  // Obtener IP desde diferentes headers
  const ip = req.headers['x-forwarded-for'] || 
             req.headers['x-real-ip'] || 
             req.connection.remoteAddress || 
             req.socket.remoteAddress || 
             req.ip;
  
  // Limpiar la IP (remover prefijos como ::ffff:)
  const cleanIP = ip ? ip.replace(/^::ffff:/, '') : 'Desconocida';
  
  // Detectar si es IP de ZeroTier (rango 172.x.x.x)
  if (cleanIP.match(/^172\./)) {
    return cleanIP + ' (ZeroTier)';
  }
  
  return cleanIP;
}

// Rutas
app.get('/', (req, res) => {
  const clientIP = getClientIP(req);
  
  res.render('home', {
    title: 'OzNet - Red Privada',
    zerotierIP: clientIP,
    services: [
      {
        name: 'home.oznet',
        description: 'Documentación principal del proyecto',
        status: 'active',
        url: 'https://home.oznet'
      },
      {
        name: 'hub.oznet',
        description: 'Gestión y administración de servicios',
        status: 'active',
        url: 'https://hub.oznet'
      },
      {
        name: 'files.oznet',
        description: 'Servidor público de archivos',
        status: 'active',
        url: 'https://files.oznet'
      },
      {
        name: 'server.oznet',
        description: 'Servidor principal de OzNet',
        status: 'active',
        url: 'https://server.oznet'
      },
      {
        name: 'mail.oznet',
        description: 'Interfaz web del servidor de correos',
        status: 'coming-soon',
        url: '#'
      },
      {
        name: 'wiki.oznet',
        description: 'Servidor Kiwix para documentación offline',
        status: 'coming-soon',
        url: '#'
      },
      {
        name: '3dprint.oznet',
        description: 'OctoPrint para gestión de impresoras 3D',
        status: 'coming-soon',
        url: '#'
      }
    ]
  });
});

app.get('/setup', (req, res) => {
  res.render('setup', {
    title: 'Configuración - OzNet',
    networkId: '9bee8941b563441a',
    networkName: 'Oz Network',
    serverIp: '172.26.0.1'
  });
});

app.get('/docs', (req, res) => {
  res.render('docs', {
    title: 'Documentación - OzNet'
  });
});

module.exports = app; 