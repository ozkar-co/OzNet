#!/bin/bash
# Configuración compartida para scripts de Cloudflare Tunnel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_PATH="${SCRIPT_DIR}/tunnel-config.yml"
DEFAULT_CONF="/etc/cloudflared/config.yml"
TUNNEL_NAME="ozkrnet"
DOMAIN="ozkr.net"
