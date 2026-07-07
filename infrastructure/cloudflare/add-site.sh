#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

usage() {
    cat <<EOF
Uso: $(basename "$0") <nombre> <puerto> [opciones]

Crea un sitio nuevo en el tunnel de Cloudflare:
  - Agrega la regla de ingress en tunnel-config.yml
  - Asegura el symlink de configuración
  - Crea la ruta DNS en Cloudflare
  - Reinicia el servicio cloudflared

Argumentos:
  nombre    Subdominio (ej: mi-api) o hostname completo (ej: mi-api.ozkr.net)
  puerto    Puerto local donde corre el servicio (ej: 3004)

Opciones:
  --health-path PATH   Ruta de health check personalizada (default: /health)
  --tls                Agrega originRequest con noTLSVerify y httpHostHeader localhost
  -h, --help           Muestra esta ayuda

Ejemplos:
  $(basename "$0") mi-api 3004
  $(basename "$0") whisper 8001 --health-path /api/version
  $(basename "$0") ozro-api 3001 --tls
EOF
}

HEALTH_PATH=""
USE_TLS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --health-path)
            HEALTH_PATH="$2"
            shift 2
            ;;
        --tls)
            USE_TLS=true
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: opción desconocida: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -ne 2 ]]; then
    usage >&2
    exit 1
fi

NAME="$1"
PORT="$2"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    echo "Error: el puerto debe ser un número entre 1 y 65535." >&2
    exit 1
fi

if [[ "$NAME" == *.* ]]; then
    HOSTNAME="$NAME"
else
    HOSTNAME="${NAME}.${DOMAIN}"
fi

if ! [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    echo "Error: nombre de host inválido: $HOSTNAME" >&2
    exit 1
fi

if [[ ! -f "$YAML_PATH" ]]; then
    echo "Error: no se encontró $YAML_PATH" >&2
    exit 1
fi

if grep -q "hostname:[[:space:]]*${HOSTNAME}[[:space:]]*$" "$YAML_PATH"; then
    echo "Error: ya existe un sitio con hostname $HOSTNAME" >&2
    exit 1
fi

if grep -q "localhost:${PORT}[[:space:]]*$" "$YAML_PATH"; then
    EXISTING=$(grep -B1 "localhost:${PORT}" "$YAML_PATH" | grep "hostname:" | sed 's/.*hostname:[[:space:]]*//' || true)
    if [[ -n "$EXISTING" ]]; then
        echo "Advertencia: el puerto $PORT ya está en uso por $EXISTING"
        read -r -p "¿Continuar de todos modos? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            echo "Cancelado."
            exit 0
        fi
    fi
fi

echo "=== Creando sitio: $HOSTNAME → localhost:$PORT ==="

# --- 1. Agregar entrada al YAML (antes del catch-all) ---
echo ""
echo "--- 1. Actualizando tunnel-config.yml ---"

BLOCK="  # ${NAME}
  - hostname: ${HOSTNAME}
    service: http://localhost:${PORT}"

if [[ -n "$HEALTH_PATH" ]]; then
    BLOCK="${BLOCK}
    health_path: ${HEALTH_PATH}"
fi

if [[ "$USE_TLS" == true ]]; then
    BLOCK="${BLOCK}
    originRequest:
      noTLSVerify: true
      httpHostHeader: localhost"
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

INSERTED=false
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$INSERTED" == false && "$line" =~ ^[[:space:]]*-[[:space:]]service:[[:space:]]http_status:404 ]]; then
        printf '%s\n\n' "$BLOCK"
        INSERTED=true
    fi
    printf '%s\n' "$line"
done < "$YAML_PATH" > "$TMPFILE"

if [[ "$INSERTED" == false ]]; then
    echo "Error: no se encontró la regla catch-all (http_status:404) en $YAML_PATH" >&2
    exit 1
fi

mv "$TMPFILE" "$YAML_PATH"
trap - EXIT
echo "OK: entrada agregada."

# --- 2. Symlink de configuración ---
echo ""
echo "--- 2. Verificando link de configuración ---"
if [[ ! -L "$DEFAULT_CONF" ]]; then
    echo "Creando link simbólico..."
    sudo mkdir -p /etc/cloudflared
    sudo ln -sf "$YAML_PATH" "$DEFAULT_CONF"
else
    echo "OK: configuración ya linkeada."
fi

# --- 3. Ruta DNS ---
echo ""
echo "--- 3. Creando ruta DNS ---"
cloudflared tunnel route dns "$TUNNEL_NAME" "$HOSTNAME"
echo "OK: DNS configurado para $HOSTNAME"

# --- 4. Reiniciar servicios ---
echo ""
echo "--- 4. Reiniciando servicios ---"
sudo systemctl restart cloudflared
echo "OK: cloudflared reiniciado."

if systemctl is-active --quiet oznet-home 2>/dev/null; then
    sudo systemctl restart oznet-home
    echo "OK: oznet-home reiniciado."
fi

echo ""
echo "=== Sitio creado ==="
echo "  URL:    https://${HOSTNAME}"
echo "  Puerto: localhost:${PORT}"
echo ""
echo "Asegúrate de que el servicio esté corriendo en localhost:${PORT}"
echo "con un endpoint GET ${HEALTH_PATH:-/health} que responda 200."
