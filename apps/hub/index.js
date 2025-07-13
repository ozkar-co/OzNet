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
    eq: (a, b) => a === b,
    formatDate: function(date) {
      if (!date) return '';
      const d = new Date(date);
      return d.toLocaleString('es-ES', { dateStyle: 'short', timeStyle: 'short' });
    },
    countActiveServices: function(services) {
      if (!Array.isArray(services)) return 0;
      return services.filter(s => s.status === 'running').length;
    },
    json: function(context) {
      return JSON.stringify(context);
    }
  }
});
app.engine('handlebars', hbs.engine);
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));

// Middleware para parsear JSON
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir archivos estáticos
app.use('/static', express.static(path.join(__dirname, 'public')));

// Servicios disponibles
const services = [
  {
    id: 'oznet-home',
    name: 'OzNet Home',
    description: 'Servidor principal de documentación',
    domain: 'home.oznet',
    port: 3000,
    status: 'running',
    type: 'web'
  },
  {
    id: 'oznet-hub',
    name: 'OzNet Hub',
    description: 'Gestión de servicios',
    domain: 'hub.oznet',
    port: 3000,
    status: 'running',
    type: 'web'
  },
  {
    id: 'oznet-files',
    name: 'OzNet Files',
    description: 'Servidor de archivos',
    domain: 'files.oznet',
    port: 3000,
    status: 'running',
    type: 'web'
  },
  {
    id: 'dnsmasq',
    name: 'DNS Server',
    description: 'Servidor DNS interno',
    port: 53,
    status: 'running',
    type: 'system'
  },
  {
    id: 'zerotier',
    name: 'ZeroTier',
    description: 'Servicio VPN',
    status: 'running',
    type: 'system'
  }
];

// Función para obtener el estado de un proceso
async function getProcessStatus(serviceId) {
  try {
    if (serviceId === 'dnsmasq') {
      const { stdout } = await execAsync('systemctl is-active dnsmasq');
      return stdout.trim() === 'active' ? 'running' : 'stopped';
    } else if (serviceId === 'zerotier') {
      const { stdout } = await execAsync('systemctl is-active zerotier-one');
      return stdout.trim() === 'active' ? 'running' : 'stopped';
    } else {
      // Para servicios web, verificar si el puerto está en uso
      const { stdout } = await execAsync(`netstat -tlnp | grep :3000 | wc -l`);
      return parseInt(stdout.trim()) > 0 ? 'running' : 'stopped';
    }
  } catch (error) {
    return 'error';
  }
}

// Función para actualizar estados de todos los servicios
async function updateServiceStatuses() {
  for (let service of services) {
    service.status = await getProcessStatus(service.id);
  }
}

// Rutas
app.get('/', async (req, res) => {
  await updateServiceStatuses();
  res.render('dashboard', {
    title: 'Hub - Gestión de Servicios',
    services: services
  });
});

app.get('/api/services', async (req, res) => {
  await updateServiceStatuses();
  res.json(services);
});

app.post('/api/services/:id/start', async (req, res) => {
  const serviceId = req.params.id;
  const service = services.find(s => s.id === serviceId);
  
  if (!service) {
    return res.status(404).json({ error: 'Servicio no encontrado' });
  }

  try {
    if (service.type === 'system') {
      await execAsync(`sudo systemctl start ${serviceId}`);
    } else {
      // Para servicios web, reiniciar el proceso principal
      await execAsync('sudo systemctl restart oznet');
    }
    
    service.status = 'running';
    res.json({ success: true, status: 'running' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/services/:id/stop', async (req, res) => {
  const serviceId = req.params.id;
  const service = services.find(s => s.id === serviceId);
  
  if (!service) {
    return res.status(404).json({ error: 'Servicio no encontrado' });
  }

  try {
    if (service.type === 'system') {
      await execAsync(`sudo systemctl stop ${serviceId}`);
    } else {
      // Para servicios web, detener el proceso principal
      await execAsync('sudo systemctl stop oznet');
    }
    
    service.status = 'stopped';
    res.json({ success: true, status: 'stopped' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/services/:id/restart', async (req, res) => {
  const serviceId = req.params.id;
  const service = services.find(s => s.id === serviceId);
  
  if (!service) {
    return res.status(404).json({ error: 'Servicio no encontrado' });
  }

  try {
    if (service.type === 'system') {
      await execAsync(`sudo systemctl restart ${serviceId}`);
    } else {
      // Para servicios web, reiniciar el proceso principal
      await execAsync('sudo systemctl restart oznet');
    }
    
    service.status = 'running';
    res.json({ success: true, status: 'running' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/logs', async (req, res) => {
  try {
    const { stdout } = await execAsync('journalctl -u oznet --no-pager -n 50');
    res.render('logs', {
      title: 'Logs del Sistema',
      logs: stdout
    });
  } catch (error) {
    res.render('logs', {
      title: 'Logs del Sistema',
      logs: 'Error al obtener logs: ' + error.message
    });
  }
});

app.get('/system', async (req, res) => {
  try {
    const [cpu, memory, disk, network] = await Promise.all([
      execAsync("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"),
      execAsync("free | grep Mem | awk '{print $3/$2 * 100.0}'"),
      execAsync("df / | tail -1 | awk '{print $5}' | sed 's/%//'"),
      execAsync("ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1")
    ]);

    res.render('system', {
      title: 'Estado del Sistema',
      stats: {
        cpu: parseFloat(cpu.stdout.trim()),
        memory: parseFloat(memory.stdout.trim()),
        disk: parseFloat(disk.stdout.trim()),
        network: network.stdout.trim()
      }
    });
  } catch (error) {
    res.render('system', {
      title: 'Estado del Sistema',
      stats: {
        cpu: 0,
        memory: 0,
        disk: 0,
        network: 'Error'
      }
    });
  }
});

module.exports = app; 