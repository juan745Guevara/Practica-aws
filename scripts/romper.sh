#!/usr/bin/env bash
# Mete fallos para practicar el diagnóstico (Parte 4 del examen).
# Uso:
#   sudo ./scripts/romper.sh            -> mete 1 fallo al azar (no dice cuál)
#   sudo ./scripts/romper.sh 3          -> mete el fallo número 3
#   sudo ./scripts/romper.sh lista      -> muestra los fallos posibles
#   sudo ./scripts/romper.sh restaurar  -> deshace todo
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Ejecuta con sudo."; exit 1; fi

BK=/root/lab-backup
WEB=/var/www/html
SITE=/etc/apache2/sites-available/000-default.conf
mkdir -p "$BK"

respaldar() {
  [[ -f "$BK/.hecho" ]] && return
  cp -a "$WEB/config.php" "$BK/config.php" 2>/dev/null || true
  cp -a "$WEB/index.php"  "$BK/index.php"  2>/dev/null || true
  cp -a "$SITE" "$BK/000-default.conf"
  cp -a /etc/apache2/ports.conf "$BK/ports.conf"
  touch "$BK/.hecho"
}

lista() {
cat <<'EOF'
  1  Apache detenido y deshabilitado
  2  Error de sintaxis en la configuración de Apache
  3  Contraseña de la BD incorrecta en config.php
  4  Endpoint de RDS mal escrito en config.php
  5  Permisos: index.php sin lectura para Apache
  6  Apache escuchando en otro puerto (no en el 80)
  7  Módulo PHP desactivado (el navegador descarga el .php)
  8  Contenedor lab-app detenido
Fallos que debes provocar a mano en la consola de AWS (pídeselo a un compañero):
  A  Borrar la regla HTTP 80 del Security Group de la EC2
  B  Cambiar el origen de la regla 3306 del SG de RDS a otra IP
  C  Detener y volver a iniciar la EC2 (cambia la IP pública)
EOF
}

romper() {
  respaldar
  case "$1" in
    1) systemctl stop apache2; systemctl disable apache2 >/dev/null 2>&1 ;;
    2) echo "    DirectoryIndx index.php" >> "$SITE"; systemctl restart apache2 || true ;;
    3) sed -i "s/getenv('DB_PASS') ?: '[^']*'/getenv('DB_PASS') ?: 'clave_equivocada'/" "$WEB/config.php" ;;
    4) sed -i "s/\.rds\.amazonaws\.com/.rds.amazonaws.co/" "$WEB/config.php" ;;
    5) chmod 000 "$WEB/index.php" ;;
    6) sed -i 's/^Listen 80$/Listen 8081/' /etc/apache2/ports.conf
       sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8081>/' "$SITE"; systemctl restart apache2 ;;
    7) a2dismod -f "$(ls /etc/apache2/mods-enabled | grep -oP '^php[0-9.]+(?=\.load)' | head -1)" >/dev/null
       systemctl restart apache2 ;;
    8) docker stop lab-app >/dev/null 2>&1 || echo "(no hay contenedor lab-app)" ;;
    *) echo "Fallo desconocido: $1"; exit 1 ;;
  esac
  echo "$1" >> "$BK/aplicados"
}

restaurar() {
  [[ -f "$BK/.hecho" ]] || { echo "No hay nada que restaurar."; exit 0; }
  cp -a "$BK/config.php" "$WEB/config.php" 2>/dev/null || true
  cp -a "$BK/index.php"  "$WEB/index.php"  2>/dev/null || true
  cp -a "$BK/000-default.conf" "$SITE"
  cp -a "$BK/ports.conf" /etc/apache2/ports.conf
  chown www-data:www-data "$WEB"/*.php; chmod 644 "$WEB/index.php"; chmod 640 "$WEB/config.php"
  a2enmod "$(ls /etc/apache2/mods-available | grep -oP '^php[0-9.]+(?=\.load)' | head -1)" >/dev/null 2>&1 || true
  systemctl enable --now apache2 >/dev/null 2>&1; systemctl restart apache2
  docker start lab-app >/dev/null 2>&1 || true
  rm -rf "$BK"
  echo "Todo restaurado."
}

case "${1:-azar}" in
  lista)     lista ;;
  restaurar) restaurar ;;
  azar)      n=$(( RANDOM % 7 + 1 )); romper "$n"
             echo "Listo: metí un fallo. Abre la web, encuéntralo y arréglalo."
             echo "(Si te rindes: sudo cat $BK/aplicados)" ;;
  *)         romper "$1"; echo "Fallo $1 aplicado." ;;
esac
