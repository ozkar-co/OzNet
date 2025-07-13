const express = require('express');
const exphbs = require('express-handlebars');
const path = require('path');

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

// Rutas
app.get('/', (req, res) => {
  res.render('home', {
    title: 'OzNet - Red Privada',
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