# OzNet - Red Privada

OzNet es una red privada basada en ZeroTier que proporciona múltiples servicios web a través de un dominio personalizado `.oznet`.

## 🏗️ Arquitectura

### Componentes Principales

- **ZeroTier VPN**: Conectividad segura entre dispositivos
- **DNS (dnsmasq)**: Resolución de nombres para servicios internos
- **Express.js**: Servidor web con virtual hosts
- **Nginx**: Proxy reverso y SSL termination
- **Handlebars**: Motor de plantillas
- **PicoCSS**: Framework CSS minimalista

### Servicios Disponibles

| Servicio | Dominio | Descripción | Estado |
|----------|---------|-------------|--------|
| home.oznet | Documentación principal | ✅ Activo |
| hub.oznet | Gestión de servicios | ✅ Activo |
| files.oznet | Servidor de archivos | ✅ Activo |
| server.oznet | Servidor principal | ✅ Activo |
| mail.oznet | Interfaz web de correo | 🚧 Próximamente |
| wiki.oznet | Servidor Kiwix | 🚧 Próximamente |
| 3dprint.oznet | OctoPrint | 🚧 Próximamente |

## 🚀 Instalación

### Requisitos Previos

- Node.js 18+ 
- ZeroTier One
- dnsmasq
- Nginx (opcional para producción)

### 1. Clonar el Repositorio

```bash
git clone <repository-url>
cd OzNet
```

### 2. Instalar Dependencias

```bash
npm install
```

### 3. Configurar Variables de Entorno

Crear un archivo `.env`:

```env
PORT=3000
FILES_ROOT=/var/oznet/files
NODE_ENV=production
```

### 4. Configurar ZeroTier

1. Instalar ZeroTier One
2. Unirse a la red: `9bee8941b563441a`
3. Configurar DNS: `172.26.0.1`

### 5. Configurar DNS

Editar `/etc/dnsmasq.d/oznet.conf`:

```
# Dominio personalizado
domain=oznet

# Entradas personalizadas
address=/home.oznet/172.26.0.1
address=/hub.oznet/172.26.0.1
address=/files.oznet/172.26.0.1
address=/server.oznet/172.26.0.1

# Asegura que escuche en la interfaz ZeroTier
interface=zt+
listen-address=172.26.0.1
```

### 6. Ejecutar el Servidor

```bash
# Desarrollo
npm run dev

# Producción
npm start
```

## 📁 Estructura del Proyecto

```
OzNet/
├── server.js              # Servidor principal
├── package.json           # Dependencias
├── apps/                  # Aplicaciones por servicio
│   ├── home/             # home.oznet
│   ├── hub/              # hub.oznet
│   └── files/            # files.oznet
├── config/               # Configuraciones
├── logs/                 # Logs del sistema
└── docs/                 # Documentación
```

## 🔧 Configuración de Servicios

### home.oznet
- Documentación principal del proyecto
- Guías de configuración
- Estado de servicios

### hub.oznet
- Gestión de servicios del sistema
- Monitoreo de procesos
- Logs del sistema
- Métricas de rendimiento

### files.oznet
- Servidor de archivos público
- Navegación de directorios
- Vista previa de archivos
- Descarga de archivos
- Límite: 100MB por archivo

### server.oznet
- Servidor principal de OzNet
- Punto de entrada central
- Redirección a servicios

## 🔒 Seguridad

### ZeroTier
- Red privada con autenticación
- Encriptación punto a punto
- Control de acceso por dispositivo

### DNS
- Resolución interna para `.oznet`
- No expuesto a Internet
- Configuración local

### Web Server
- Validación de rutas
- Límites de tamaño de archivo
- Headers de seguridad (Helmet)
- Compresión de respuesta

## 📊 Monitoreo

### Métricas Disponibles
- Uso de CPU y memoria
- Espacio en disco
- Estado de servicios
- Logs de acceso

### Logs
- `/var/log/oznet/` - Logs de aplicación
- `/var/log/syslog` - Logs del sistema
- `/var/log/nginx/` - Logs de Nginx

## 🛠️ Desarrollo

### Scripts Disponibles

```bash
npm start          # Ejecutar en producción
npm run dev        # Ejecutar en desarrollo
npm test           # Ejecutar tests
```

### Agregar Nuevo Servicio

1. Crear directorio en `apps/`
2. Implementar aplicación Express
3. Agregar virtual host en `server.js`
4. Configurar DNS y Nginx

### Estructura de una Aplicación

```javascript
// apps/mi-servicio/index.js
const express = require('express');
const exphbs = require('express-handlebars');

const app = express();

// Configurar Handlebars
app.engine('handlebars', exphbs.engine({
  defaultLayout: 'main',
  layoutsDir: path.join(__dirname, 'views/layouts')
}));
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));

// Rutas
app.get('/', (req, res) => {
  res.render('home', { title: 'Mi Servicio' });
});

module.exports = app;
```

## 🌐 Configuración de Red

### ZeroTier Network
- **Network ID**: `9bee8941b563441a`
- **Nombre**: Oz Network
- **Rango IP**: `172.26.0.0/24`

### DNS Configuration
- **Servidor**: `172.26.0.1`
- **Dominio**: `.oznet`
- **Servicios**: Todos los subdominios

### Puertos
- **53**: DNS (dnsmasq)
- **3000**: Web Server (Express)
- **9993**: ZeroTier

## 📝 Licencia

MIT License - Ver archivo LICENSE para detalles.

## 🤝 Contribuir

1. Fork el proyecto
2. Crear rama para feature (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

## 📞 Soporte

Para soporte técnico o preguntas:
- Crear un issue en GitHub
- Contactar al administrador de la red

## 🔄 Actualizaciones

### v1.0.0
- ✅ Servidor principal con virtual hosts
- ✅ home.oznet - Documentación
- ✅ hub.oznet - Gestión de servicios
- ✅ files.oznet - Servidor de archivos
- ✅ server.oznet - Servidor principal
- ✅ Integración con ZeroTier
- ✅ Configuración DNS automática

### Próximas Versiones
- 🚧 mail.oznet - Servidor de correo
- 🚧 wiki.oznet - Kiwix server
- 🚧 3dprint.oznet - OctoPrint
- 🚧 SSL automático
- 🚧 Backup automático 