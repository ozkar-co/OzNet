# Guía de Instalación de OzNet

Esta guía te ayudará a instalar y configurar OzNet en tu servidor.

## Requisitos del Sistema

### Hardware Mínimo
- CPU: 1 núcleo
- RAM: 512MB
- Disco: 10GB
- Red: Conexión a Internet

### Software Requerido
- Ubuntu 20.04 LTS o superior
- Acceso root al servidor
- Conexión a Internet para descargar dependencias

## Instalación Automática

### 1. Clonar el Repositorio

```bash
git clone <repository-url>
cd OzNet
```

### 2. Ejecutar el Script de Instalación

```bash
sudo ./scripts/setup.sh
```

El script automáticamente:
- Actualiza el sistema
- Instala todas las dependencias
- Configura ZeroTier
- Configura DNS (dnsmasq)
- Configura Nginx
- Instala y configura la aplicación OzNet
- Configura el firewall

### 3. Autorizar el Dispositivo

Durante la instalación, el script te pedirá que autorices el dispositivo en la red ZeroTier:

1. Ve a [my.zerotier.com](https://my.zerotier.com)
2. Inicia sesión en tu cuenta
3. Ve a la red `9bee8941b563441a`
4. Busca tu dispositivo en la lista de miembros
5. Haz clic en "Auth" para autorizarlo
6. Regresa al terminal y presiona Enter

## Instalación Manual

Si prefieres instalar manualmente, sigue estos pasos:

### 1. Actualizar el Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Instalar Dependencias

```bash
sudo apt install -y curl wget git build-essential dnsmasq nginx certbot python3-certbot-nginx
```

### 3. Instalar Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs
```

### 4. Instalar ZeroTier

```bash
curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg' | gpg --import && \
if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | sudo bash; fi

sudo systemctl enable zerotier-one
sudo systemctl start zerotier-one
```

### 5. Unirse a la Red ZeroTier

```bash
sudo zerotier-cli join 9bee8941b563441a
```

### 6. Configurar DNS

Editar `/etc/dnsmasq.conf`:

```bash
sudo nano /etc/dnsmasq.conf
```

Agregar al final:

```
# OzNet Configuration
address=/.oznet/10.147.20.1
server=8.8.8.8
server=1.1.1.1
cache-size=1000
log-queries
```

Reiniciar dnsmasq:

```bash
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq
```

### 7. Configurar Nginx

Crear certificado SSL:

```bash
sudo mkdir -p /etc/ssl/oznet
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/oznet/key.pem \
    -out /etc/ssl/oznet/cert.pem \
    -subj "/C=ES/ST=State/L=City/O=OzNet/CN=*.oznet"
```

Copiar configuración de Nginx:

```bash
sudo cp config/nginx.conf /etc/nginx/sites-available/oznet
sudo ln -sf /etc/nginx/sites-available/oznet /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 8. Crear Directorios

```bash
sudo mkdir -p /var/oznet/{files,logs,static}
sudo mkdir -p /var/log/oznet
sudo chown -R www-data:www-data /var/oznet
sudo chmod -R 755 /var/oznet
```

### 9. Instalar Aplicación OzNet

```bash
npm install
```

Crear archivo de entorno:

```bash
cat > .env << EOF
PORT=3000
FILES_ROOT=/var/oznet/files
NODE_ENV=production
EOF
```

### 10. Crear Servicio del Sistema

```bash
sudo tee /etc/systemd/system/oznet.service > /dev/null << EOF
[Unit]
Description=OzNet Web Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$(pwd)
Environment=NODE_ENV=production
Environment=FILES_ROOT=/var/oznet/files
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable oznet
sudo systemctl start oznet
```

### 11. Configurar Firewall

```bash
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 53
sudo ufw allow 9993
sudo ufw --force enable
```

## Configuración de Clientes

### Configurar DNS en Dispositivos

Para que los dispositivos puedan acceder a los servicios `.oznet`, necesitas configurar el DNS:

#### Linux
Editar `/etc/resolv.conf`:

```
nameserver 10.147.20.1
```

#### Windows
1. Configuración de Red
2. Propiedades del adaptador
3. Protocolo Internet versión 4 (TCP/IPv4)
4. Usar las siguientes direcciones DNS: `10.147.20.1`

#### macOS
1. Preferencias del Sistema → Red
2. Avanzado → DNS
3. Agregar: `10.147.20.1`

### Unirse a la Red ZeroTier

1. Instalar ZeroTier One en tu dispositivo
2. Unirse a la red: `9bee8941b563441a`
3. Esperar autorización del administrador

## Verificación de la Instalación

### Verificar Servicios

```bash
sudo systemctl status oznet
sudo systemctl status dnsmasq
sudo systemctl status nginx
sudo systemctl status zerotier-one
```

### Verificar DNS

```bash
nslookup home.oznet 127.0.0.1
nslookup hub.oznet 127.0.0.1
nslookup files.oznet 127.0.0.1
```

### Verificar Web Server

```bash
curl -I http://localhost:3000
```

### Verificar ZeroTier

```bash
sudo zerotier-cli status
sudo zerotier-cli listnetworks
```

## Acceso a los Servicios

Una vez configurado, puedes acceder a:

- **Documentación**: http://home.oznet
- **Gestión de Servicios**: http://hub.oznet
- **Servidor de Archivos**: http://files.oznet

## Solución de Problemas

### DNS no funciona
```bash
sudo systemctl restart dnsmasq
sudo systemctl restart systemd-resolved
```

### Web server no responde
```bash
sudo systemctl restart oznet
sudo journalctl -u oznet -f
```

### ZeroTier no conecta
```bash
sudo systemctl restart zerotier-one
sudo zerotier-cli status
```

### Nginx no funciona
```bash
sudo nginx -t
sudo systemctl restart nginx
sudo journalctl -u nginx -f
```

## Logs del Sistema

- **Aplicación**: `/var/log/oznet/`
- **Sistema**: `/var/log/syslog`
- **Nginx**: `/var/log/nginx/`
- **ZeroTier**: `/var/log/zerotier-one.log`

## Actualizaciones

Para actualizar OzNet:

```bash
git pull
npm install
sudo systemctl restart oznet
```

## Desinstalación

Para desinstalar completamente:

```bash
sudo systemctl stop oznet
sudo systemctl disable oznet
sudo rm /etc/systemd/system/oznet.service
sudo rm -rf /var/oznet
sudo systemctl daemon-reload
```

## Soporte

Si tienes problemas con la instalación:

1. Revisa los logs del sistema
2. Verifica la conectividad de red
3. Confirma que ZeroTier esté funcionando
4. Contacta al administrador de la red

Para más información, consulta la documentación en: http://home.oznet/docs 