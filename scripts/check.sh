#!/usr/bin/env bash
# Diagnóstico rápido: revisa capa por capa y dice dónde está el fallo.
# Uso: sudo ./scripts/check.sh
set -uo pipefail

VERDE='\e[32m'; ROJO='\e[31m'; AMAR='\e[33m'; NC='\e[0m'
ok()   { echo -e "  ${VERDE}[OK]${NC}   $*"; }
mal()  { echo -e "  ${ROJO}[FALLA]${NC} $*"; }
info() { echo -e "  ${AMAR}[INFO]${NC} $*"; }

CONFIG=/var/www/html/config.php
leer() { grep -oP "getenv\('$1'\) \?: '\K[^']*" "$CONFIG" 2>/dev/null; }

echo "== 1. Apache =="
if systemctl is-active --quiet apache2; then ok "apache2 activo"
else mal "apache2 no está activo  -> sudo systemctl status apache2 ; sudo journalctl -u apache2 -n 30"; fi
systemctl is-enabled --quiet apache2 2>/dev/null && ok "apache2 arranca al reiniciar" \
  || info "apache2 no está habilitado -> sudo systemctl enable apache2"
if apache2ctl configtest >/dev/null 2>&1; then ok "configuración válida (Syntax OK)"
else mal "error de sintaxis -> sudo apache2ctl configtest"; fi

echo "== 2. Puertos que escuchan =="
ss -tlnp 2>/dev/null | awk 'NR==1 || /:80 |:8080 /' | sed 's/^/  /'

echo "== 3. HTTP local =="
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/ || echo 000)
case "$code" in
  200) ok "http://localhost/ -> 200" ;;
  000) mal "nadie responde en el puerto 80" ;;
  *)   mal "http://localhost/ -> $code  -> sudo tail -n 30 /var/log/apache2/error.log" ;;
esac
[[ -f /var/www/html/index.php ]] && ok "index.php existe" || mal "falta /var/www/html/index.php"
perm=$(stat -c '%U:%G %a' /var/www/html/index.php 2>/dev/null || echo "-")
info "index.php -> $perm (esperado www-data:www-data y lectura permitida)"

echo "== 4. Docker =="
if command -v docker >/dev/null; then
  systemctl is-active --quiet docker && ok "docker activo" || mal "docker no está activo -> sudo systemctl start docker"
  docker ps -a --format '  {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null
  if docker ps -a --format '{{.Names}} {{.State}}' 2>/dev/null | grep -q '^lab-app exited'; then
    mal "lab-app está detenido -> docker logs lab-app ; docker start lab-app"
  fi
else
  info "docker no instalado (ok si usas solo Apache)"
fi

echo "== 5. Base de datos (RDS) =="
HOST=$(leer DB_HOST); USER=$(leer DB_USER); PASS=$(leer DB_PASS)
if [[ -z "$HOST" ]]; then
  info "no se pudo leer $CONFIG (¿usas solo Docker? revisa: docker inspect lab-app | grep DB_)"
else
  info "endpoint: $HOST"
  if getent hosts "$HOST" >/dev/null; then ok "DNS resuelve el endpoint"
  else mal "el endpoint no resuelve -> revisa que esté bien copiado y que RDS esté Available"; fi
  if timeout 5 bash -c "</dev/tcp/$HOST/3306" 2>/dev/null; then ok "puerto 3306 alcanzable"
  else mal "3306 bloqueado -> SG de RDS debe aceptar 3306 desde el SG de la EC2"; fi
  if command -v mysql >/dev/null; then
    if out=$(mysql -h "$HOST" -u "$USER" -p"$PASS" -e 'SELECT COUNT(*) FROM appdb.productos' -N 2>&1); then
      ok "login correcto, productos en appdb: $out"
    else
      mal "MySQL respondió: $(echo "$out" | grep -v Warning | head -1)"
    fi
  fi
fi

echo "== 6. Últimos errores de Apache =="
tail -n 5 /var/log/apache2/error.log 2>/dev/null | sed 's/^/  /' || true
