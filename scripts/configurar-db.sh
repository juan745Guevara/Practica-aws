#!/usr/bin/env bash
# Escribe los datos de RDS en /var/www/html/config.php y reinicia Apache.
# Uso: sudo ./scripts/configurar-db.sh <endpoint-rds> <usuario> <clave>
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Ejecuta con sudo."; exit 1; fi
if [[ $# -lt 3 ]]; then echo "Uso: sudo $0 <endpoint-rds> <usuario> <clave>"; exit 1; fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG=/var/www/html/config.php
esc() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }

cp "$DIR/app/config.php" "$CONFIG"          # parte de la plantilla limpia
sed -i "s|__DB_HOST__|$(esc "$1")|; s|__DB_USER__|$(esc "$2")|; s|__DB_PASS__|$(esc "$3")|" "$CONFIG"
chown www-data:www-data "$CONFIG"
chmod 640 "$CONFIG"
systemctl restart apache2

echo "==> config.php actualizado. Estado de la conexión:"
curl -s http://localhost/health.php || true
echo
