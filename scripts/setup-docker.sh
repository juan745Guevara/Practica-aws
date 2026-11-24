#!/usr/bin/env bash
# Despliega la app en un contenedor Docker en Ubuntu 24.04.
# Uso: sudo ./scripts/setup-docker.sh <endpoint-rds> <usuario> <clave> [puerto]
#   o:  sudo ./scripts/setup-docker.sh            (lee los datos de .env)
#   puerto por defecto: 8080 (así no choca con Apache en el 80)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Ejecuta con sudo."; exit 1; fi
DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -ge 3 ]]; then
  DB_HOST="$1"; DB_USER="$2"; DB_PASS="$3"; PORT="${4:-8080}"
elif [[ -f "$DIR/.env" ]]; then
  set -a; source "$DIR/.env"; set +a
  PORT="${1:-8080}"
else
  echo "(Sin datos de BD: la app dirá 'Sin conexión'. Pasa <endpoint> <usuario> <clave> o crea .env)"
  DB_HOST=""; DB_USER=""; DB_PASS=""; DB_NAME="appdb"; PORT="${1:-8080}"
fi

if ! command -v docker >/dev/null; then
  echo "==> Instalando Docker"
  apt-get update -y
  apt-get install -y docker.io
  systemctl enable --now docker
  usermod -aG docker "${SUDO_USER:-ubuntu}"
  echo "(Para usar docker sin sudo: sal y vuelve a entrar por SSH)"
fi

echo "==> Construyendo la imagen lab-app"
docker build -f "$DIR/docker/Dockerfile" -t lab-app "$DIR"

echo "==> (Re)creando el contenedor lab-app en el puerto $PORT"
docker rm -f lab-app >/dev/null 2>&1 || true
docker run -d --name lab-app --restart unless-stopped \
  -p "$PORT:80" \
  -e DB_HOST="$DB_HOST" -e DB_USER="$DB_USER" -e DB_PASS="$DB_PASS" -e DB_NAME="${DB_NAME:-appdb}" \
  lab-app

sleep 3
docker ps --filter name=lab-app
curl -s "http://localhost:$PORT/health.php" || true
echo
echo "Listo. Recuerda abrir el puerto $PORT en el Security Group y entrar a http://<IP-PUBLICA>:$PORT/"
