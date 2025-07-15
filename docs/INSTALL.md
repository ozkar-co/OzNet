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
git clone git@github.com:ozkar-co/OzNet.git
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

#### Opción A: Certificados Auto-Generados (Recomendado)

Generar CA y certificados SSL:

```bash
# Generar CA y certificados
sudo ./scripts/create-ca.sh

# Actualizar configuración
sudo ./scripts/update-config.sh --ssl --nginx --test
```

#### Opción B: Certificados Manuales

Crear certificado SSL básico:

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

**Importante**: El servicio debe ejecutarse como el usuario propietario del directorio del proyecto para evitar errores de permisos.

```bash
sudo tee /etc/systemd/system/oznet.service > /dev/null << EOF
[Unit]
Description=OzNet Web Server
After=network.target

[Service]
Type=simple
User=oz
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
nameserver 172.26.0.1
```

#### Windows
1. Configuración de Red
2. Propiedades del adaptador
3. Protocolo Internet versión 4 (TCP/IPv4)
4. Usar las siguientes direcciones DNS: `172.26.0.1`

#### macOS
1. Preferencias del Sistema → Red
2. Avanzado → DNS
3. Agregar: `172.26.0.1`

### Unirse a la Red ZeroTier

1. Instalar ZeroTier One en tu dispositivo
2. Unirse a la red: `9bee8941b563441a`
3. Esperar autorización del administrador

### Instalar Certificado SSL (Opcional pero Recomendado)

Para evitar advertencias de seguridad en el navegador, instala el certificado SSL:

#### Descargar el Certificado

```bash
# Desde el servidor
scp usuario@172.26.0.1:/var/oznet/certs/oznet-ca.crt ./

# O desde la web (si ya tienes acceso)
wget https://172.26.0.1/certs/oznet-ca.crt
```

#### Instalar en Linux

```bash
sudo cp oznet-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

#### Instalar en macOS

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain oznet-ca.crt
```

#### Instalar en Windows

1. Doble clic en `oznet-ca.crt`
2. "Instalar certificado" → "Máquina local"
3. "Entidades de certificación raíz de confianza"

**Nota**: Reinicia tu navegador después de instalar el certificado.

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

## Solución de Problemas

### Error de Servicio Systemd

Si el servicio `oznet` falla con error `status=200/CHDIR`:

1. **Verificar permisos del directorio**:
   ```bash
   ls -la /home/oz/OzNet
   ```

2. **Verificar que el usuario del servicio tenga acceso**:
   ```bash
   sudo -u oz ls /home/oz/OzNet
   ```

3. **Corregir el archivo de servicio**:
   ```bash
   sudo nano /etc/systemd/system/oznet.service
   ```
   
   Asegúrate de que `User=` coincida con el propietario del directorio del proyecto.

4. **Reiniciar el servicio**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart oznet
   ```

### Error de DNS

Si los dominios `.oznet` no se resuelven:

1. **Verificar que dnsmasq esté ejecutándose**:
   ```bash
   sudo systemctl status dnsmasq
   ```

2. **Verificar la configuración de DNS**:
   ```bash
   nslookup home.oznet 127.0.0.1
   ```

3. **Reiniciar dnsmasq**:
   ```bash
   sudo systemctl restart dnsmasq
   ```

### Error de ZeroTier

Si no puedes conectarte a la red ZeroTier:

1. **Verificar el estado del servicio**:
   ```bash
   sudo systemctl status zerotier-one
   ```

2. **Verificar la membresía**:
   ```bash
   sudo zerotier-cli listnetworks
   ```

3. **Reiniciar ZeroTier**:
   ```bash
   sudo systemctl restart zerotier-one
   ```

### Advertencias de Seguridad SSL

Si ves advertencias de "sitio no seguro" en el navegador:

1. **Verificar instalación del certificado**:
   ```bash
   # Linux
   ls /usr/local/share/ca-certificates/ | grep oznet
   
   # macOS
   security find-certificate -a -c "OzNet"
   ```

2. **Reiniciar navegador** después de instalar el certificado

3. **Verificar certificado en el servidor**:
   ```bash
   sudo ls -la /var/oznet/certs/
   sudo ls -la /etc/ssl/oznet/
   ```

4. **Probar conexión HTTPS**:
   ```bash
   curl -k https://172.26.0.1
   ```

### Verificar SSL

```bash
# Probar conexión HTTPS
curl -k https://172.26.0.1

# Verificar certificado (si está instalado)
openssl s_client -connect 172.26.0.1:443 -servername home.oznet
   ``` 