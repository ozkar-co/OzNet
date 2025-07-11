const express = require('express');
const exphbs = require('express-handlebars');
const path = require('path');

const app = express();

// Configurar Handlebars
app.engine('handlebars', exphbs.engine({
  defaultLayout: 'main',
  layoutsDir: path.join(__dirname, 'views/layouts'),
  partialsDir: path.join(__dirname, 'views/partials')
}));
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
        url: 'http://home.oznet'
      },
      {
        name: 'hub.oznet',
        description: 'Gestión y administración de servicios',
        status: 'active',
        url: 'http://hub.oznet'
      },
      {
        name: 'files.oznet',
        description: 'Servidor público de archivos',
        status: 'active',
        url: 'http://files.oznet'
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
    networkName: 'Oz Network'
  });
});

app.get('/docs', (req, res) => {
  res.render('docs', {
    title: 'Documentación - OzNet'
  });
});

module.exports = app; 