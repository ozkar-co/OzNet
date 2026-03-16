#!/bin/bash

# Configuración de rutas
YAML_PATH="/home/oz/oznet/infrastructure/cloudflare/tunnel-config.yml"
DEFAULT_CONF="/etc/cloudflared/config.yml"
TUNNEL_NAME="ozkrnet"

echo "--- 1. Verificando Link de Configuración ---"
if [ ! -L "$DEFAULT_CONF" ]; then
    echo "Creando link simbólico..."
    sudo mkdir -p /etc/cloudflared
    sudo ln -sf "$YAML_PATH" "$DEFAULT_CONF"
else
    echo "OK: Configuración ya linkeada."
fi

echo -e "\n--- 2. Extrayendo Hostnames del YAML ---"
# Esta línea busca 'hostname:', quita los espacios y extrae solo el valor
HOSTNAMES=$(grep "hostname:" "$YAML_PATH" | sed 's/.*hostname:[[:space:]]*//' | tr -d '\r')

if [ -z "$HOSTNAMES" ]; then
    echo "Error: No se encontraron dominios válidos en el archivo."
    exit 1
fi

echo "Dominios detectados:"
echo "$HOSTNAMES"

echo -e "\n--- 3. Verificando/Creando Rutas DNS ---"
for HOST in $HOSTNAMES; do
    echo "Configurando DNS para: $HOST"
    # El flag --overwrite-dns es útil por si ya existía apuntando a otro lado
    cloudflared tunnel route dns "$TUNNEL_NAME" "$HOST"
done

echo -e "\n--- Proceso completado ---"
echo "Prueba ahora con: cloudflared tunnel run"
