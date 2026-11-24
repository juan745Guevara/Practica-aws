#!/usr/bin/env bash
# Despliega la app con Apache + PHP en Ubuntu (24.04 o superior).
# Uso:
#   sudo ./scripts/setup-apache.sh                                 -> despliega sin BD (se configura después)
#   sudo ./scripts/setup-apache.sh <endpoint-rds> <usuario> <clave> -> despliega y configura la BD
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Ejecuta con sudo."; exit 1; fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WEB=/var/www/html

echo "==> Instalando Apache, PHP y cliente MySQL"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 php libapache2-mod-php php-mysql mysql-client curl

echo "==> Copiando la app a $WEB"
rm -f "$WEB/index.html"                     # quita la página por defecto de Ubuntu
cp -r "$DIR/app/." "$WEB/"
chown -R www-data:www-data "$WEB"

echo "==> Activando Apache"
systemctl enable --now apache2
systemctl restart apache2

if [[ $# -ge 3 ]]; then
  "$DIR/scripts/configurar-db.sh" "$1" "$2" "$3"
else
  echo "(BD sin configurar: la página dirá 'Sin conexión'. Configúrala en la Parte 4 con scripts/configurar-db.sh)"
fi

echo "==> Prueba local"
curl -s -o /dev/null -w "http://localhost/ -> HTTP %{http_code}\n" http://localhost/

TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' || true)
IP=$(curl -s --max-time 2 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
echo
echo "Listo. Abre en el navegador: http://${IP:-<IP-PUBLICA>}/"
